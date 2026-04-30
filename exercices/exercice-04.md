# Exercice 4 — Interpréter un rapport iostat

> Module : 6 — Disque, I/O et systèmes de fichiers
> Durée estimée : 30 min
> Difficulté : 3 / 5
> Type : Exercice d'application

## Objectifs pédagogiques

À la fin de cet exercice, vous serez capable de :

- Lire les colonnes d'iostat sans les confondre
- Distinguer saturation logique et saturation physique d'un disque

## Prérequis

- Avoir suivi la partie « iostat et iotop » du module 6
- Environnement : tout éditeur de texte
- Outils : aucun, l'exercice se fait sur des rapports textuels

## Contexte

Un service de logs écrit beaucoup sur un disque. On vous remet deux captures d'iostat, prises à 5 minutes d'intervalle, sur la même machine.

Rapport A :

```
iostat -xz 1 3

Device   r/s     w/s   rkB/s   wkB/s   rrqm/s  wrqm/s  await  r_await  w_await  aqu-sz  %util
nvme0n1  12.0   380.0  96.0    22800.0  0.0    4.0     3.2    1.1      3.3      1.2     68.0
sda      0.0      8.0   0.0      320.0  0.0    0.0    45.6    0.0     45.6      0.4     12.0
```

Rapport B :

```
iostat -xz 1 3

Device   r/s     w/s   rkB/s   wkB/s   rrqm/s  wrqm/s  await  r_await  w_await  aqu-sz  %util
nvme0n1   8.0   410.0  64.0    24000.0  0.0    6.0     4.1    0.9      4.2      1.3     72.0
sda       2.0    220.0  64.0    14000.0  0.0    2.0   185.0    3.0    186.6     41.0    99.8
```

## Énoncé

### Partie 1 — Rapport A

1. Dire quel disque semble supporter la charge principale d'écriture.
2. Calculer approximativement le débit en Mo/s sur ce disque.
3. Juger si le disque est saturé, en justifiant avec au moins deux colonnes.

Résultat attendu : 3 à 5 lignes avec disque, débit et verdict.

### Partie 2 — Rapport B

1. Identifier la différence majeure entre les deux rapports.
2. Expliquer pourquoi `sda` a un `%util` à 99.8 % alors que ses IOPS ne sont pas très élevés.
3. Proposer une prochaine commande pour trouver le process responsable.

Résultat attendu : comparaison, explication de la saturation, commande suivante.

## Indices (à consulter si bloqué)

<details>
<summary>Indice 1</summary>

`%util` mesure la fraction de temps où le device a au moins une requête en vol. Sur un disque capable de paralléliser (NVMe, RAID), 100 % n'implique pas la saturation. Sur un disque série, c'est plus révélateur.

</details>

<details>
<summary>Indice 2</summary>

`aqu-sz` (profondeur moyenne de file d'attente) couplé à `await` donne une idée de l'engorgement. Un `aqu-sz` de 40 avec `await` de 185 ms raconte une file d'attente, pas un disque rapide.

</details>

## Pour aller plus loin (bonus)

Dans le rapport B, estimez le temps moyen passé par une requête dans la file d'attente du block layer (en ms), et comparez à `r_await` et `w_await`. Que déduisez-vous sur la nature du goulot ?
