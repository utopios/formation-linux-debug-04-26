# Exercice 1 — Cartographier un processus suspect avec /proc et ps

> Module : 1 — Internals Linux pour le debug
> Durée estimée : 20 min
> Difficulté : 2 / 5
> Type : Exercice d'application

## Objectifs pédagogiques

À la fin de cet exercice, vous serez capable de :

- Lister les threads d'un processus et lire leur état
- Extraire la ligne de commande, l'exécutable et le répertoire de travail d'un PID

## Prérequis

- Avoir suivi la partie « Processus, threads et ordonnancement » du module 1
- Environnement : une VM Linux avec un utilisateur ayant le droit de lire `/proc/<pid>/`
- Outils : `ps`, `cat`, `ls`, `readlink`

## Contexte

Un collègue vous signale qu'un processus `worker` consomme beaucoup de CPU sur un serveur partagé. Vous n'avez pas encore l'outillage avancé, mais vous avez un shell. Vous allez construire une fiche d'identité du processus à partir de `/proc` et `ps`.

Pour simuler le processus cible, lancez dans un terminal :

```bash
yes > /dev/null &
echo "PID cible : $!"
```

Notez le PID retourné, il remplacera `<pid>` dans les instructions.

## Énoncé

### Partie 1 — Identité du processus

1. Afficher la ligne de commande complète du processus.
2. Afficher le chemin absolu de l'exécutable.
3. Afficher le répertoire de travail courant.
4. Afficher le nom d'utilisateur propriétaire.

Résultat attendu : une fiche listant les 4 informations, extraites depuis `/proc/<pid>/` ou `ps`.

### Partie 2 — Threads et état

1. Lister tous les threads du processus.
2. Pour chaque thread, afficher son état (R, S, D, Z, T).
3. Relever la valeur de `VmRSS` et `Threads` dans `/proc/<pid>/status`.
4. Relever le nombre de context switches volontaires et forcés dans `/proc/<pid>/status` (`voluntary_ctxt_switches`, `nonvoluntary_ctxt_switches`).

Résultat attendu : un tableau thread/état plus les 4 métriques système du processus.

## Indices (à consulter si bloqué)

<details>
<summary>Indice 1</summary>

La commande `tr '\0' ' ' < /proc/<pid>/cmdline` transforme les séparateurs NUL de `cmdline` en espaces lisibles.

</details>

<details>
<summary>Indice 2</summary>

Les threads d'un processus sont listés dans `/proc/<pid>/task/`. Chaque sous-dossier est un TID et contient lui aussi un `status`.

</details>

## Pour aller plus loin (bonus)

Écrivez un petit script shell qui prend un PID en argument et produit la fiche des deux parties en une seule sortie formatée. Le script doit fonctionner même si le processus n'a qu'un seul thread.
