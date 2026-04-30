# Exercice 3 — Diagnostiquer un load élevé à partir d'un snapshot

> Module : 4 — CPU et analyse de performance
> Durée estimée : 30 min
> Difficulté : 3 / 5
> Type : Exercice d'application

## Objectifs pédagogiques

À la fin de cet exercice, vous serez capable de :

- Interpréter un load average relativement au nombre de CPUs
- Décomposer l'usage CPU pour distinguer contention CPU, I/O et softirq

## Prérequis

- Avoir suivi la partie « Load average et états CPU » du module 4
- Environnement : tout éditeur de texte, lecture seule
- Outils : aucun, l'exercice se fait sur un snapshot textuel

## Contexte

Un serveur 8 cœurs sert une API REST. Une alerte Prometheus dit « load élevé ». On vous donne trois snapshots pris à la même heure (à quelques secondes près) avec trois outils différents : `uptime`+`top`, `pidstat`, et `mpstat -P ALL`. Les applicatifs installés sont `api` (Go), `worker` (Python) et `collector` (agent de métriques).

Snapshot A — `uptime` et `top` :

```
 10:32:07 up 14 days,  2:11,  2 users,  load average: 12.4, 11.9, 7.2
Tasks: 432 total,   5 running, 427 sleeping
%Cpu(s):  78.2 us,  8.4 sy,  0.0 ni,  6.1 id,  5.9 wa,  0.0 hi,  1.4 si,  0.0 st
```

Snapshot B — `pidstat 1 1` (extrait) :

```
10:32:08  UID  PID   %usr %system  %CPU  Command
10:32:08 1000  4210  92.0    6.0  98.0   api
10:32:08 1000  4231  88.0    8.0  96.0   api
10:32:08 1000  4255  85.0    9.0  94.0   api
10:32:08 1000  5102   1.0   12.0  13.0   collector
10:32:08 1000  6331   0.5    0.5   1.0   worker
```

Snapshot C — `mpstat -P ALL 1 1` (extrait) :

```
10:32:09  CPU   %usr  %sys  %iowait  %irq  %soft  %idle
10:32:09  all   78.3   8.3     5.9   0.0    1.4    6.1
10:32:09    0   95.2   4.0     0.0   0.0    0.8    0.0
10:32:09    1   92.1   5.5     0.0   0.0    1.2    1.2
10:32:09    2   88.4   7.0     0.0   0.0    2.3    2.3
10:32:09    3   82.0  10.0     0.0   0.0    2.0    6.0
10:32:09    4    0.0   0.0    45.0   0.0    0.0   55.0
10:32:09    5   68.0   9.0     3.0   0.0    1.0   19.0
10:32:09    6   70.0  12.0     8.0   0.0    2.0    8.0
10:32:09    7   65.0  11.0     6.0   0.0    1.0   17.0
```

## Énoncé

### Partie 1 — Premier verdict

1. Indiquer si la machine est saturée CPU, en tenant compte des 8 cœurs.
2. Pointer le ou les processus qui consomment le plus.
3. Qualifier la nature de la charge : user-bound, kernel-bound, I/O bound ?

Résultat attendu : un paragraphe de 4 à 6 lignes avec la conclusion argumentée.

### Partie 2 — Lecture fine mpstat

1. Identifier le cœur qui sort du lot et en quoi son profil diffère des autres.
2. Proposer une hypothèse sur ce qui tourne spécifiquement sur ce cœur.
3. Lister deux commandes de suivi à lancer pour confirmer cette hypothèse sur un serveur réel.

Résultat attendu : hypothèse formulée et deux commandes (à exécuter en direct pour confirmer).

## Indices (à consulter si bloqué)

<details>
<summary>Indice 1</summary>

Load / nombre de cœurs donne le facteur de saturation. Un load de 12 sur 8 cœurs ne signifie pas automatiquement « CPU bound » : il faut regarder `%wa` et `%si`.

</details>

<details>
<summary>Indice 2</summary>

`%iowait` local élevé sur un seul cœur pointe souvent une affinité d'interruption (IRQ) ou un thread noyau lié à un device précis.

</details>

## Pour aller plus loin (bonus)

Si on double le nombre d'instances de `api` sur cette machine, que prédisez-vous pour le load, le `%us` et le `%wa` ? Justifiez en une phrase chacun.
