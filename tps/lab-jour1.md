# Lab Jour 1 — Diagnostic complet d'un service de production

> Modules couverts : 1 (Internals Linux), 2 (Debug live), 3 (Mémoire)
> Durée estimée : 1h30
> Difficulté : 4 / 5
> Type : Lab de synthèse, niveau professionnel

## Mise en situation

Vous êtes ingénieur d'astreinte chez un infogérant. Un client e-commerce héberge sur un serveur dédié OVH (Bare Metal, Ubuntu 22.04) un démon de facturation interne nommé `billingd`. Trois tickets sont ouverts depuis cette nuit, vous avez 1h30 pour produire un compte rendu de diagnostic.

```
[TICKET-4821] sev:HIGH   billingd a été relancé 3x dans la nuit (systemd Restart=on-failure)
[TICKET-4822] sev:HIGH   transactions bloquées >30s, opérateurs perdent du temps
[TICKET-4823] sev:MED    alerte Prometheus "node_memory > 90%" toutes les 4h, sans corrélation visible
```

Le client demande pour chaque ticket :
- Cause racine (preuve, pas hypothèse)
- Action immédiate (sans déploiement code)
- Recommandation moyen terme (avec impact estimé)

Vous avez **un accès SSH unique**, **pas de root direct sur le code** du service, **pas le droit d'arrêter `billingd`** sans ticket de changement (mais vous pouvez l'inspecter, l'attacher, le tracer). Le client vous fournit les sources Python pour information mais vous indique que **lire le code n'est pas la méthode attendue** : c'est l'observation système qui doit produire le diagnostic. Le code servira uniquement à valider votre conclusion.

## Mise en place

```bash
sudo bash setup-lab-jour1-billingd.sh
```

Le script :
- Crée `/opt/billingd/billingd.py` (worker multi-threadé)
- Installe l'unité `billingd.service` avec `Restart=on-failure`
- Configure le `core_pattern` vers `/var/lib/coredumps/`
- Active un swap de 1 Go pour reproduire le scénario OOM réaliste
- Démarre le service automatiquement (vous arrivez sur un système déjà en incident)

À l'issue du setup, attendez **2 à 3 minutes** avant de commencer le diagnostic : le service met du temps à atteindre son régime nominal et à reproduire les symptômes.

## Objectifs pédagogiques

À la fin du Lab vous devez être capable de :

- Cartographier un processus multi-threadé en lisant uniquement `/proc`
- Identifier un syscall bloquant via `strace` filtré et `/proc/$PID/stack`
- Quantifier une fuite mémoire avec `pmap` (T0 vs T+N) et corréler avec l'OOM
- Reconnaître un état zombie (Z) et son origine (parent qui ne `wait()` pas)
- Produire un livrable client avec preuves, actions et recommandations

## Prérequis techniques

```bash
# Versions minimales
strace --version    # ≥ 5
ltrace --version    # ≥ 0.7
gdb --version       # ≥ 10 (optionnel pour la partie bonus)
bpftrace --version  # ≥ 0.14 (optionnel pour la partie bonus)
```

Outils standard requis : `procps` (`ps`, `pmap`, `vmstat`, `free`), `coreutils`.

## Architecture cible

```
serveur dédié OVH (4 vCPU, 4 Go RAM, 1 Go swap)
  └── /opt/billingd/billingd.py    (service Python multi-threadé)
        ├── thread main            (boucle de scheduling)
        ├── thread accounting      (qui alloue de la mémoire en cache)
        ├── thread sync_remote     (qui appelle un service externe)
        └── thread cleanup         (qui fork des sous-process)
```

## Étapes

### Étape 1 — État des lieux et cartographie (15 min)

Objectif : connaître la cible avant de creuser. Pas d'outil avancé à ce stade.

1. Identifier le PID principal du service :
   ```bash
   systemctl status billingd --no-pager
   # Methode robuste (le process s'appelle 'python3', pas 'billingd') :
   PID=$(systemctl show -p MainPID --value billingd)
   echo "PID = $PID"
   # Alternative par le nom du script :
   pgrep -af billingd.py
   ```
2. Lire la fiche système du process :
   ```bash
   cat /proc/<pid>/status | grep -E '^(State|Pid|Threads|Uid|VmRSS|RssAnon|VmSwap|voluntary|nonvoluntary)'
   tr '\0' ' ' < /proc/<pid>/cmdline; echo
   readlink /proc/<pid>/exe
   ```
3. Lister les threads et leurs états :
   ```bash
   ls /proc/<pid>/task/
   for t in /proc/<pid>/task/*; do
     tid=$(basename $t)
     state=$(awk '/^State:/ {print $2, $3}' $t/status 2>/dev/null)
     echo "TID $tid -> $state"
   done
   ```
4. Vérifier l'arborescence de processus liée à `billingd` :
   ```bash
   ps --forest -o pid,ppid,stat,comm --ppid <pid>
   ps -eo pid,ppid,stat,comm | awk -v p="<pid>" '$2 == p && $3 ~ /Z/'
   ```

Point de contrôle : vous devez avoir noté le **nombre de threads**, leurs **états respectifs**, et avoir **repéré au moins une anomalie** dans `ps`.

### Étape 2 — Trois pistes en parallèle (45 min)

Mission : ouvrir une enquête par ticket. Vous pouvez choisir l'ordre. Astuce : commencez par celui dont la cause se laisse voir avec le moins d'effort.

#### Piste A — Ticket 4823 (mémoire / alerte 4h)

1. Échantillonner la consommation mémoire du processus :
   ```bash
   while true; do
     date +%T
     grep -E '^(VmRSS|RssAnon|VmSwap):' /proc/<pid>/status
     echo "---"
     sleep 15
   done | tee billingd-mem.log
   ```
2. Pendant ce temps, prendre deux snapshots `pmap` espacés de 2 minutes :
   ```bash
   sudo pmap -x <pid> > pmap-t0.txt
   sleep 120
   sudo pmap -x <pid> > pmap-t2.txt
   diff <(sort -k2 -n -r pmap-t0.txt | head -10) \
        <(sort -k2 -n -r pmap-t2.txt | head -10)
   ```
   Note : `sudo` est nécessaire si le service tourne en root (cas ici via systemd), sinon `pmap` n'affiche qu'une seule ligne.
3. Vérifier si l'OOM Killer est intervenu récemment :
   ```bash
   sudo dmesg -T | grep -iE 'killed process|out of memory' | tail -10
   sudo journalctl -u billingd --since "6 hours ago" | grep -iE 'oom|killed|signal' | head
   ```
4. Lire `oom_score` et `oom_score_adj` du processus :
   ```bash
   cat /proc/<pid>/oom_score
   cat /proc/<pid>/oom_score_adj
   ```

Point de contrôle : nommer la zone mémoire qui croît, donner sa pente (Mo/min), et indiquer si un kill OOM est déjà survenu.

#### Piste B — Ticket 4822 (transactions bloquées >30s)

1. Repérer le thread qui dort dans un syscall bloquant :
   ```bash
   for t in /proc/<pid>/task/*; do
     tid=$(basename $t)
     state=$(awk '/^State:/ {print $2}' $t/status)
     stack=$(sudo cat $t/stack 2>/dev/null | head -3 | tr '\n' '|')
     echo "TID $tid state=$state stack=$stack"
   done
   ```
2. Sur le thread suspect, attacher strace en filtrant le réseau :
   ```bash
   sudo timeout 8 strace -f -e trace=network -p <tid_suspect> 2>&1 | tail -20
   ```
3. Confirmer la cible réseau :
   ```bash
   sudo ss -tnp | grep -E "pid=<pid>"
   sudo lsof -p <pid> -i 2>/dev/null
   ```
4. Vérifier la routabilité de la cible :
   ```bash
   ip route get <ip_cible>
   timeout 3 nc -zv <ip_cible> <port>; echo "exit=$?"
   ```

Point de contrôle : identifier le syscall (`connect`/`recvfrom`/`read`), nommer la cible (IP:port), expliquer pourquoi le syscall ne rendra jamais la main.

#### Piste C — Ticket 4821 (relances systemd)

1. Récupérer l'historique des relances :
   ```bash
   sudo journalctl -u billingd --since "12 hours ago" | grep -E 'Started|Stopped|Failed|Killed|signal' | head -30
   sudo systemctl show billingd | grep -E 'NRestarts|Result|ExecMainStatus|MainPID'
   ```
2. Si un core dump a été généré, l'inspecter :
   ```bash
   ls -lat /var/lib/coredumps/ 2>/dev/null
   ```
3. Croiser avec les pistes A et B : la cause des relances est-elle déjà identifiée ?

Point de contrôle : la cause des relances est explicable par une des pistes A ou B (ou par les deux).

### Étape 3 — Synthèse et livrable (30 min)

Produire `rapport-billingd.md` avec, pour chaque ticket :

```markdown
## Ticket 4821/4822/4823

**Cause racine**
- Symptôme observé : ...
- Mécanisme : ...
- Preuve (commandes + extraits) : ...

**Action immédiate** (sans déploiement code)
- ...
- Risque résiduel : ...

**Recommandation moyen terme**
- ...
- Impact estimé : ...

**Détection future**
- Métrique à monitorer : ...
- Seuil d'alerte proposé : ...
```


## Pour aller plus loin

- **Bonus 1** : utiliser `bpftrace` pour mesurer la distribution de latence des `connect()` du processus pendant 60 secondes. Comparer baseline vs incident.
- **Bonus 2** : avec `gdb -p <pid>` (puis `info threads` et `py-bt`) afficher la pile **Python** des threads bloqués (nécessite `python3-dbg` installé). Comparer avec ce que vous a appris `/proc/<tid>/stack`.
- **Bonus 3** : protéger `billingd` contre l'OOM Killer en modifiant `oom_score_adj` à -500. Quel est le risque de cette mitigation ? Quels processus deviennent alors plus probables comme victimes ?

## Dépannage courant

<details>
<summary>strace renvoie "Operation not permitted"</summary>

Le service tourne en root (systemd par défaut), votre shell est en `ubuntu`. Préfixer toutes les commandes d'inspection par `sudo` (`sudo strace`, `sudo cat /proc/<pid>/stack`, `sudo pmap`). Sur Ubuntu, `yama/ptrace_scope=1` exige aussi soit sudo, soit le bit `CAP_SYS_PTRACE`.

</details>

<details>
<summary>pmap n'affiche qu'une seule ligne</summary>

Cause : vous lancez `pmap` sans sudo sur un PID qui ne vous appartient pas. Solution : `sudo pmap -x <pid>`.

</details>

<details>
<summary>Le service redémarre tout seul pendant le diagnostic</summary>

C'est attendu : `Restart=on-failure` est volontairement configuré pour reproduire le ticket 4821. Si cela vous gêne pour observer un état stable, attendez quelques secondes après une relance pour reprendre les commandes. Le PID change à chaque relance — utilisez `pgrep` à chaque fois.

</details>

<details>
<summary>Aucun thread n'est dans l'état Z (zombie) au moment de l'observation</summary>

Les zombies sont éphémères : le thread `cleanup` les crée mais le système les nettoie dès qu'un `wait()` finit par arriver. Faites plusieurs passages successifs avec `ps -eo pid,ppid,stat,comm | awk '$3 ~ /Z/'`, ou laissez tourner une boucle `while sleep 1; do ps ... ; done` pendant quelques minutes pour les capturer.

</details>

