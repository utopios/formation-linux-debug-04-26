# Exercice 2 — Identifier l'appel bloquant d'un processus

> Module : 2 — Debugger une application en cours d'exécution
> Durée estimée : 30 min
> Difficulté : 3 / 5
> Type : Exercice d'application

## Objectifs pédagogiques

À la fin de cet exercice, vous serez capable de :

- Attacher strace à un processus vivant sans le tuer
- Identifier quel appel système bloque un processus apparemment figé

## Prérequis

- Avoir suivi la partie « strace en profondeur » du module 2
- Environnement : VM Linux avec `strace` installé et droits `sudo` pour attacher à un process hors de votre uid
- Outils : `strace`, `ps`, `cat`

## Mise en place

Le formateur vous fournit le script `setup-m2-exo02-dnsfreeze.sh`. Sur votre VM :

```bash
# Si le script n'est pas déjà sur la VM, le copier (le formateur indique comment)
sudo bash setup-m2-exo02-dnsfreeze.sh
```

Le script crée `~/demo-linux/dns_freeze.py`. Il n'y a aucun binaire pré-fourni : tout est généré par le script.

## Contexte

Un petit script Python tourne sur la machine et semble figé : il affiche un message de démarrage puis plus rien pendant plusieurs minutes. Vous ne connaissez pas son code. Votre mission : dire avec certitude ce qu'il attend.

Lancez-le :

```bash
python3 ~/demo-linux/dns_freeze.py &
echo "PID cible : $!"
```

Note : ce script est **différent** de celui de la démo 2. Vous devez refaire le raisonnement, pas recopier la solution montrée en cours. Le syscall coupable n'est pas `connect()`.

## Énoncé

### Partie 1 — Attacher strace et filtrer

1. Trouver le PID du processus Python.
2. Attacher `strace` en suivant les threads éventuels, en écrivant la sortie dans `trace.log`.
3. Ajouter un filtre pour ne garder que les appels liés au réseau.
4. Observer la sortie pendant au moins 30 secondes.

Résultat attendu : un fichier `trace.log` contenant un ou deux appels système visibles, sans bruit parasite.

### Partie 2 — Conclure

1. Identifier le dernier appel système visible dans la trace.
2. Expliquer en une phrase pourquoi il bloque (indice à chercher dans les arguments de l'appel).
3. Proposer ce que le développeur devrait modifier pour que le freeze devienne une erreur rapide plutôt qu'un blocage long.

Résultat attendu : un court compte rendu de 3 à 5 lignes avec l'appel identifié, la cause et la piste de correction côté code.

## Indices (à consulter si bloqué)

<details>
<summary>Indice 1</summary>

`strace -e trace=network -f -p <pid> -o trace.log` filtre toutes les familles de syscalls réseau. Laissez tourner puis faites Ctrl-C.

</details>

<details>
<summary>Indice 2</summary>

L'IP `10.255.255.1` n'est pas routée sur le réseau de la machine. Un `connect()` TCP vers une IP non joignable se comporte autrement qu'un refus immédiat.

</details>

## Pour aller plus loin (bonus)

Refaites l'exercice avec `strace -c -p <pid>` pendant 20 secondes. Que vous apprend le comptage par syscall par rapport à la trace complète ? Dans quel cas le comptage seul aurait pu suffire ?
