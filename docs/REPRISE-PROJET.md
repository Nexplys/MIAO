# Reprise du développement M.I.A.O.

État vérifié le 6 septembre 2026. Point d'entrée pour reprendre le projet après un changement de conversation. Mettre ce document à jour après chaque étape livrée. Les constats techniques ci-dessous décrivent la base auditée, pas des fonctionnalités futures.

## Mise à jour locale : 4.1.0

Publication confirmée après cette livraison : l'utilisateur a poussé le commit `0a71bafb13f957e2611c9393f3fada219716d7b1` (Independent modules & docks setup) sur `main`. Le workflow [Tests 34032276639](https://github.com/Nexplys/MIAO/actions/runs/34032276639) est terminé avec succès. Cette publication devient la référence distante pour la prochaine étape. La copie de développement de cette tâche n'a pas encore été réalignée sur ce commit ; vérifier son diff avant toute synchronisation.

Une copie de développement a été extraite dans le dossier de cette tâche depuis le commit audité, sur la branche `codex/reliability-and-module-docks`. L'installation du Bureau reste inchangée. Aucun commit ni push n'a été créé. La nouvelle version locale apporte des docks séparés `/control/<id>`, le dock Broadcast historique compatible, un transport TCP asynchrone borné, un remplacement atomique corrigé pour PowerShell 5.1 et des tests d'intégration. Lire le CHANGELOG et les guides actualisés ; les sections suivantes décrivent l'état de référence 4.0.0 avant ces corrections.

Décision utilisateur complémentaire : chaque module possède son propre dock et son widget, utilisables séparément dans OBS. La coquille HTML et le serveur sont partagés, mais aucun dock ne charge les ressources d'un autre module. L'ancienne proposition de pupitre regroupant tous les modules est remplacée.

## Sources et niveau de certitude

- Historique complet accessible de la tâche **MIAO Dev**, identifiant `6a9802f8-ef80-83eb-97ca-d8180a90cbb3` : 74 échanges récupérés, jusqu'à la demande « parfait, commençons le module tunic ». Les six images accessibles ont été examinées. Les anciennes archives de livraison et le YAML joint ne sont pas restitués par cet historique.
- Dépôt [Nexplys/MIAO](https://github.com/Nexplys/MIAO), branche `main`, commit `c8f8acfacc4d6ffdfa730aa90259c964c0e9d0cf` (Files cleanup).
- Copie existante `%USERPROFILE%/Desktop/MIAO` : même commit, arbre de travail propre, 47 fichiers suivis, origine GitHub correspondante.
- Documentation, code principal, manifeste Broadcast, configuration et tests de cette copie examinés. Ceci constitue une reprise technique, pas une revue exhaustive de chaque ligne.
- Fichier réel Tunic lu avec autorisation : `%USERPROFILE%/AppData/LocalLow/Andrew Shouldice/Secret Legend/Randomizer/ItemTracker.json`.
- Archive brute locale de la conversation dans `var/reprise/miao-dev-history.json`, à ne pas publier. Les propos de l'ancien assistant restent des éléments historiques ; une proposition ne vaut pas validation utilisateur et un ancien résultat ne vaut pas vérification actuelle.

Le dossier de cette tâche, `%USERPROFILE%/Documents/ChatGPT/MIAO`, était vide hormis un dépôt Git initialisé sans commit ni remote. Les documents de reprise y sont déposés. Le choix du dossier de développement reste à confirmer ; le code de l'installation du Bureau n'a pas été déplacé ni modifié.

## Intention produit et identité

M.I.A.O. signifie **Module Intelligent d'Ambiance Opérationnelle**. C'est l'intelligence de bord fictive du stream : compétente, sérieuse à l'excès, sèche et légèrement absurde, dans un univers de chatons dans l'espace. Le vocabulaire de vaisseau, équipage, radio et transmission a remplacé les premières propositions autour de « l'orbite musicale ».

L'application locale sert OBS pour les streams de jeux et de travail. L'utilisateur privilégie les améliorations visibles pour les viewers, la lisibilité et un écran peu chargé. Il a écarté les profils de préparation comme priorité, puisque son setup prend déjà environ vingt secondes. L'interface doit permettre de régler les fonctionnalités depuis le dock OBS sans édition manuelle des fichiers.

La direction visuelle existante utilise mauve, bleu nuit, ivoire, étoiles jaunes, nuages et chats. L'emplacement dépend du HUD du jeu. Le stream est déclaré en 2K 60 FPS ; l'ancienne observation d'une VOD en 720p ne doit pas être prise pour la configuration réelle. Aitum Vertical est configuré d'après l'utilisateur.

## Préférences et règles utilisateur à conserver

- Développer proprement et de façon maintenable, au niveau attendu d'un développeur senior.
- Développement en local. **L'utilisateur gère la publication GitHub** : ne pas pousser, créer une PR ou publier une release sur la seule base de cette reprise. Son instruction explicite figure dans l'échange `1416e7cf-44f5-46b1-85ad-34b4cb0c69df`.
- Utiliser le tiret simple `-` à la place du tiret cadratin dans les nouvelles productions et fichiers.
- Licence du code : MIT, Nexplys. Les ressources tierces gardent leurs conditions propres.
- Conserver l'arborescence validée en 4.0.0. Ajouter les fonctionnalités sous `modules/<id>/`, les données sous `var/<id>/`. Pas de nouveau fichier de documentation à la racine : le contrat de tests l'interdit actuellement.
- Préserver les URL OBS et les données utilisateur ; migrations non destructives.
- Si une archive de mise à jour est nécessaire, ne livrer que les fichiers ajoutés ou modifiés, avec les suppressions indiquées séparément. La distribution complète est destinée aux nouvelles installations.
- Application utilisable telle quelle par une autre personne : aucun nom de chaîne ni chemin personnel figé dans le code. L'adresse d'auteur des commits a été explicitement acceptée par l'utilisateur.
- Ne pas démarrer automatiquement la diffusion. Un lanceur peut ouvrir OBS et M.I.A.O., mais le démarrage du direct reste manuel.

## Avancement vérifié

| Élément | État au 6 septembre 2026 |
| --- | --- |
| Application | Version 4.0.0 |
| Architecture modulaire | Livrée, validée par l'utilisateur, présente dans le code |
| Broadcast | Seul module livré, version de module 1.0.0 |
| Tunic | Spécification discutée et choix visuels validés ; aucun dossier ni code de module livré |
| Alertes | Piste future discutée ; aucun module ni intégration livrés |
| GitHub | Une branche `main`, aucune issue ni PR dans les collections consultées, aucune release publiée |
| Tags | Aucun tag local ; la lecture distante de la collection tags n'est pas prise en charge par le connecteur utilisé |
| CI | [Tests réussis sur c8f8acf](https://github.com/Nexplys/MIAO/actions/runs/34029596287) |
| Tests locaux | Suite complète réussie sur Windows pendant cette reprise |

Historique Git disponible :

1. `febd18b` : Initial commit.
2. `a09699b` : import de la version existante.
3. `51c613d` : finalisation du déplacement et autodétection Moobot.
4. `e4cd2e5` : suppression des rechargements forcés des dépendances PowerShell.
5. `c8f8acf` : architecture 4.0.0, nettoyage final, licence et données runtime.

Avant Git, le projet est passé d'un nettoyeur de titres PowerShell à un widget navigateur animé, puis à un dock de transmission libre, puis à la refonte 3.0.0. Ces anciens livrables sont remplacés par la version actuelle. Ne pas restaurer les anciens scripts à la racine ni l'écriture du fichier `.cleaned.txt`.

## Application livrée

### Infrastructure

- Windows PowerShell 5.1 pour l'exécution. HTML, CSS et JavaScript sans framework pour les interfaces.
- Aucune dépendance supplémentaire à installer pour utiliser l'application en stream. Node.js sert aux tests ; Git sert aux outils de mises à jour.
- Serveur `TcpListener` limité à `127.0.0.1:8974` ; boucle principale et hooks de mise à jour.
- Noyau : `Miao.App`, `Miao.Files`, `Miao.Http`, `Miao.Modules`, `Miao.Routes`, `Miao.Settings`, `Miao.Web` sous `src/`.
- Le nom réel du routeur est `Miao.Routes.psm1`, même si une ancienne proposition parlait de `Miao.Router`.
- Manifestes v1 validés avant initialisation, chargement déterministe, états privés par module, hooks initialize/update/route/shutdown, ressources confinées et prise en charge des images et sons binaires.
- Le dock commun découvre `/api/modules` et compose styles, scripts, fragments et onglets. Aucun branchement fonctionnel Broadcast/Tunic dans le noyau.
- Validation des méthodes et origines pour les mutations, écritures atomiques et sauvegardes avant migration/récupération.
- Un bus d'événements intermodules a été évoqué pour l'avenir mais n'est pas implémenté dans le noyau examiné. Ne pas supposer qu'il existe.

### Broadcast

- Autodétection du fichier Moobot `*.song-player.current.txt` ; le plus récent est choisi lorsqu'il y en a plusieurs.
- Démarrage possible avant Moobot, avec nouvelle détection périodique. Options avancées de canal et de chemin explicite conservées.
- Nettoyage des suffixes vidéo/audio/lyrics et variantes ; résultat conservé en mémoire seulement.
- Radio et transmission libre avec effet de frappe, gestion des titres longs, curseur, fondu et alternance configurable.
- Radio seule, transmission seule, alternance ou transparence complète. Masquage radio sans titre configurable, désactivé par défaut dans le schéma actuel.
- 42 réglages dans un schéma unique, version de schéma 3 (distincte de la version 4.0.0 de l'application).
- Dock : Transmission, Affichage et Radio. Sauvegardes différées et mises en file pour éviter les courses entre requêtes.
- Huit actions Moobot : démarrer, pause/reprendre, suivant, mute, volume moins, volume plus, playlist secondaire, blacklist du morceau et du demandeur. Raccourcis `Ctrl+Alt+Shift+1` à `8`, dans cet ordre ; blacklist avec confirmation.
- Les boutons pause et mute expriment une demande de bascule, pas une preuve de l'état réel du lecteur. Aucun bouton Stop distinct n'est livré.
- Données : `var/broadcast/settings.json` et `var/broadcast/mission.txt`. Copie des anciens fichiers de racine uniquement si la destination n'existe pas ; originaux conservés.

### Routes à préserver

| Domaine | Routes |
| --- | --- |
| Widget Broadcast | `/`, `/miao-widget.html`, anciens alias `/assets/widget*` |
| Dock | `/control`, `/miao-control.html` |
| Noyau | `/health`, `/api/modules`, `/assets/api.js`, `/assets/control.js`, `/assets/control.css`, `/modules/<id>/...` |
| Broadcast GET | `/api/state`, `/api/song`, `/api/schema`, `/api/player/actions` |
| Broadcast POST | `/api/mission`, `/api/settings`, `/api/settings/reset`, `/api/player` |

### Contexte externe au code

Moobot gère les song requests et la lecture YouTube. L'utilisateur a confirmé un routage audio par câble du PC vers la table, puis retour sur le canal musique séparé également utilisé par le Bluetooth du téléphone. Le ducking OBS est déclaré fonctionnel. Ces réglages externes ne constituent pas un moteur audio implémenté dans M.I.A.O.

Commandes retenues : `!miaoplay`, `!next`, `!skip`, `!queue`, `!askmiao`. `!miao` sert à rappeler les commandes disponibles. `!askmiao` provient de la personnalisation Moobot 8ball, pas d'un modèle d'IA intégré à l'application. Les anciens alias `!sr` et `!miao` comme question sont historiques.

## Mise à jour : Tunic 4.2.0

Le développement du module Tunic a été réalisé sur `codex/tunic-tracker`, depuis la version 4.1.0 publiée (`0a71bafb13f957e2611c9393f3fada219716d7b1`). Voir [TUNIC.md](TUNIC.md) pour le fonctionnement livré et [TUNIC-SPEC.md](TUNIC-SPEC.md) pour le cahier des charges historique. Le YAML utilisateur et le fichier réel réinitialisé sont reconnus. Les tests automatisés et la simulation dans le navigateur sont validés ; une acquisition en vraie partie et le placement dans OBS restent à vérifier. La copie de stream du Bureau n'a pas été modifiée.

## Suite envisagée après Tunic

Un module `alerts` indépendant a été envisagé : follows, abonnements et cadeaux, raids, puis éventuellement bits, points de chaîne, `!askmiao` et `!miaoplay`. Propositions : source `/alerts`, onglet dédié, file d'attente et priorités, temporisations, modèles personnalisables et boutons de test. Streamer.bot comme pont local a été suggéré, mais ni installé ni choisi définitivement par une validation technique dans cette reprise.

Direction envisagée : terminal spatial discret, trois lignes maximum, animations courtes, son synthétique doux, absence de TTS permanente. Dimensions, durées et niveaux audio de l'ancien assistant étaient des recommandations, pas des valeurs imposées. Les profils, cycles focus/pause, statistiques Hearthstone, voix et avatar restent des idées secondaires, pas des fonctionnalités acquises.

## Validation et prochaine reprise

Commande exécutée avec succès sur la copie du Bureau :

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\run-all.ps1
```

Résultat : M.I.A.O. 4.0.0, un module, 42 réglages, huit actions et 18 fichiers PowerShell validés ; tests PowerShell réussis, y compris migration et récupération de fichiers invalides. Les avertissements sur les données de test invalides et l'absence de Moobot sont attendus dans les fixtures. Aucun raccourci réel ni direct OBS n'a été déclenché. Les essais visuels et interactions réelles OBS/Moobot restent à refaire après un changement fonctionnel.

Pour reprendre : lire ce document puis les guides existants `docs/ARCHITECTURE.md`, `docs/MODULES.md` et `docs/DEVELOPPEMENT.md` dans le dépôt de code. Vérifier de nouveau l'état Git avant d'éditer. Respecter la séparation entre données privées et documentation publiable. Les chemins des machines et l'archive brute restent dans la zone locale ignorée.
