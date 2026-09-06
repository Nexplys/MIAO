# Tracker Tunic Randomizer

Disponible depuis M.I.A.O. 4.2.0. Le module lit le fichier du randomizer toutes les 500 ms. Il ne se connecte pas à Archipelago et ne modifie aucune sauvegarde.

## Installation OBS

1. Arrêter M.I.A.O., extraire la mise à jour dans son dossier puis relancer `Lancer MIAO.bat`.
2. Ajouter une source navigateur : `http://127.0.0.1:8974/tunic`.
3. Ajouter un dock navigateur personnalisé : `http://127.0.0.1:8974/control/tunic`.
4. Pour les réglages par défaut, utiliser une source de **408 x 120 pixels**, fond transparent. Avec les noms affichés, prévoir **408 x 152 pixels**.

Le dock propose un aperçu et trois presets de simulation pour placer la grille dans la scène. **La simulation s'affiche aussi dans OBS**, avec un badge explicite. La désactiver avant de jouer. Elle s'arrête au redémarrage de M.I.A.O.

## Source et partie

Le chemin automatique est `%USERPROFILE%/AppData/LocalLow/Andrew Shouldice/Secret Legend/Randomizer/ItemTracker.json`. Un chemin local différent peut être renseigné dans le dock. Les chemins réseau UNC ne sont pas acceptés ; copier ou synchroniser le fichier sur un disque local si nécessaire.

Par défaut, le widget se masque lorsque le processus `TUNIC` est fermé, lorsque le tracker est réinitialisé ou lorsque sa scène est `TitleScreen` ou `Loading`. Au lancement du jeu, il attend une écriture du tracker postérieure au lancement pour éviter l'affichage d'une ancienne partie. La détection du processus est actualisée toutes les deux secondes. Pour lire une copie provenant d'un autre ordinateur, désactiver « Masquer lorsque TUNIC est fermé ».

Une écriture partielle conserve le dernier inventaire valide de la session. Un fichier absent masque le widget ; une erreur de lecture est indiquée dans le dock. Un fichier inchangé pendant une partie reste valide : le randomizer n'écrit pas en continu.

## Configuration Archipelago

Importer le YAML dans le dock pour appliquer `sword_progression`, `ability_shuffling`, `hexagon_quest` et `hexagon_goal`. Les quatre options sont requises, sous forme de valeurs simples dans une section `TUNIC:` indentée de deux espaces. Les booléens doivent être `true` ou `false` et l'objectif entre 1 et 100. Pour un YAML pondéré, saisir les valeurs finales dans le dock.

Le fichier YAML, le nom du joueur et les informations de connexion ne sont pas conservés. La grille cible les objets de progression retenus pour cette partie ; ce n'est pas un tracker exhaustif des checks, entrées, échelles ou fusibles. L'import signale les options de mélange d'objets non représentés par cette grille.

## Grille et présentation

| Colonne | Ligne 1 | Ligne 2 |
| --- | --- | --- |
| 1 | Hexagones rouge, vert et bleu | Baguette |
| 2 | Bâton, épée et deux améliorations | Orbe |
| 3 | Lauriers | Lanterne |
| 4 | Prière | Masque |
| 5 | Sainte-Croix | Clé de maison |

En Hexagon Quest, la première case devient un compteur d'hexagones dorés. Les objets absents sont désaturés et à 20 % d'opacité par défaut. Les nouvelles acquisitions s'illuminent brièvement ; le chargement initial et les changements de session ne déclenchent pas cette animation.

La taille des icônes, l'espacement, l'opacité, les noms, les fonds et les animations se règlent dans le dock. Les dimensions utiles sont `7,5 × taille + 4 × espacement + 16` en largeur et `2 × taille + espacement + 16` en hauteur, plus 32 pixels avec les noms.

## Validation et limites

Tests automatisés sous Windows PowerShell 5.1 : format de l'inventaire, mapping baguette/orbe, progression de l'épée, sessions, fichiers incomplets, YAML déterministe, confidentialité de l'import, routes HTTP et ressources binaires. Rendu et presets vérifiés dans le navigateur. Le fichier réel réinitialisé et le YAML fourni ont été reconnus. Une acquisition pendant une vraie partie et l'intégration dans la scène OBS restent à vérifier en conditions de stream.

Les images et leurs sources sont documentées dans les [notices tierces](../modules/tunic/THIRD_PARTY_NOTICES.md).
