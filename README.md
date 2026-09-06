# M.I.A.O. - Console de bord modulaire pour OBS

M.I.A.O. est une application locale pour OBS composée d’un noyau léger et de modules indépendants. Le module **Broadcast** fourni avec le projet affiche la radio de bord et une transmission libre, nettoie les titres produits par Moobot Assistant et pilote son Song Player par raccourcis globaux.

Cette architecture prépare l’ajout de nouveaux widgets - notamment le tracker Tunic - sans mélanger leur code, leur état ou leur interface avec la radio.

## Démarrage rapide

1. Double-cliquer sur `Lancer MIAO.bat`.
2. Utiliser `http://127.0.0.1:8974/` comme source navigateur OBS.
3. Utiliser `http://127.0.0.1:8974/control/broadcast` comme dock navigateur OBS. L'ancienne URL `/control` reste compatible.

Les URL historiques restent compatibles avec M.I.A.O. 3. Le serveur écoute uniquement sur `127.0.0.1` et ne transmet aucune donnée sur Internet.

Le guide complet se trouve dans [docs/INSTALLATION.md](docs/INSTALLATION.md).

## Modules

Chaque sous-dossier de `modules/` possède son propre manifeste, son serveur éventuel, ses fichiers de configuration et ses ressources web.

| Module | État | Fonction |
| --- | --- | --- |
| `broadcast` | inclus | radio, transmission, apparence et commandes Moobot |
| `tunic` | prévu | tracker de progression Archipelago pour les viewers |

Le noyau découvre les modules actifs au démarrage. Chaque module dispose de son propre widget et de son propre dock `/control/<id>`, à ajouter séparément dans OBS. Chaque dock charge uniquement les onglets et ressources de son module ; les autres docks peuvent être ouverts ou fermés indépendamment. Le serveur et la coquille HTML restent partagés.

## Données locales

Les données modifiables sont créées dans `var/<module>/`, un dossier ignoré par Git et absent des archives distribuées. Broadcast utilise :

- `var/broadcast/mission.txt` ;
- `var/broadcast/settings.json`.

Lors du premier démarrage après une ancienne version, M.I.A.O. copie automatiquement `miao-mission.txt` et `miao-settings.json` depuis la racine si leurs nouvelles destinations n’existent pas. Les originaux sont conservés pour permettre un retour en arrière.

M.I.A.O. détecte automatiquement `*.song-player.current.txt` dans le dossier de Moobot Assistant, sans nom de chaîne personnel dans le projet. Le titre nettoyé reste uniquement en mémoire. Si Moobot n’est pas encore ouvert, M.I.A.O. démarre quand même et réessaie la détection en arrière-plan.

## Structure

```text
MIAO/
├── .github/                   Intégration continue
├── .gitignore                 Exclusions des données locales
├── CHANGELOG.md               Historique des versions
├── LICENSE                    Licence MIT du code M.I.A.O.
├── Lancer MIAO.bat            Lanceur utilisateur stable
├── README.md                  Présentation du projet
├── VERSION                    Version de l’application
├── docs/                      Guides utilisateur et développeur
├── modules/
│   └── broadcast/             Fonctionnalité radio et transmission
│       ├── config/            Schéma et configuration distribuée
│       ├── public/            Widget et fragments du dock
│       ├── server/            Logique PowerShell du module
│       └── module.json        Contrat du module
├── public/                    Coquille commune du dock
├── scripts/                   Points d’entrée PowerShell
├── src/                       Noyau technique générique
├── tests/                     Tests PowerShell et contrats statiques
├── tools/                     Construction des distributions
└── var/                       Données locales générées et ignorées par Git
```

## Principes du projet

- aucune dépendance à installer pour utiliser M.I.A.O. en stream ;
- compatibilité Windows PowerShell 5.1 ;
- modules isolés et chargés dans un ordre déterministe ;
- chemins publics confinés au dossier de leur module ;
- configuration utilisateur validée et écrite atomiquement ;
- URL OBS et données existantes préservées ;
- paquets différentiels pour les mises à jour de développement.

Le code propre à M.I.A.O. est distribué sous [licence MIT](LICENSE). Les ressources tierces ajoutées par de futurs modules conservent leurs propres conditions et doivent être documentées dans le module concerné.

Lire [l’architecture](docs/ARCHITECTURE.md), le [contrat des modules](docs/MODULES.md) et le [guide de développement](docs/DEVELOPPEMENT.md) avant toute évolution structurelle.
