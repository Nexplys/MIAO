# Développer M.I.A.O.

## Prérequis

- Windows PowerShell 5.1 pour le serveur et les tests PowerShell ;
- Node.js récent uniquement pour les contrats JavaScript et structurels ;
- Git pour construire une mise à jour différentielle.

Node.js et Git ne sont pas nécessaires sur le poste qui utilise simplement M.I.A.O. en stream.

## Lancer les tests

Depuis la racine :

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\run-all.ps1
```

Les suites peuvent aussi être lancées séparément :

```powershell
node .\tests\contracts.test.js
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\Miao.Tests.ps1
```

GitHub Actions exécute la suite complète sous Windows à chaque push et pour chaque pull request vers `main`.

La suite comprend aussi `tests/dock.test.js` (chargement isolé du code du dock dans un DOM simulé) et `tests/http.integration.test.js` (vrai serveur PowerShell sur un port temporaire avec trois modules). Cette dernière vérifie les clients lents, les délais, les requêtes invalides, les données binaires, l'Unicode et la continuité des mises à jour. Elle utilise une copie temporaire, ne lit pas les données personnelles et n'envoie aucun raccourci Moobot. Les tests de fichiers vérifient également l'échec d'un remplacement verrouillé sans perte de l'ancien contenu.

Les contrats vérifient notamment les manifestes, l’isolation des chemins publics, les alias, les fragments du dock, les 42 réglages Broadcast, les huit actions Moobot, la syntaxe JavaScript, l’ASCII PowerShell, l’arborescence racine figée et l’absence de chemin utilisateur figé.

## Ajouter un module

Lire [MODULES.md](MODULES.md), puis créer `modules/<id>/module.json` et seulement les sous-dossiers nécessaires. Le noyau ne doit recevoir aucune condition portant sur l’identifiant du nouveau module.

Si le nouveau module a besoin d’un type MIME statique qui n’existe pas encore, l’ajouter une seule fois dans `Get-MiaoContentType`. Toute sa logique fonctionnelle, ses API et son interface restent dans son dossier. Ses données locales sont stockées sous `$ApplicationContext.RuntimePath/<id>/`.

## Modifier Broadcast

### Réglage d’affichage

1. Modifier `modules/broadcast/config/settings.schema.json`.
2. Consommer la clé dans `modules/broadcast/public/js/widget.js` ou `widget-core.js`.
3. Lancer les tests.

Le dock génère les champs à partir du schéma. Ne recopier aucune valeur par défaut dans son contrôleur.

### Commande Moobot

Modifier uniquement `modules/broadcast/config/player-actions.json`. Le serveur n’accepte que les identifiants présents dans ce fichier et une touche numérique avec le préfixe `Ctrl+Alt+Shift`.

### Widget

- placer les calculs purs dans `widget-core.js` ;
- garder le DOM et l’animation dans `widget.js` ;
- ne pas ajouter de script ou de style inline ;
- conserver `/` comme alias du widget Broadcast tant qu’OBS l’utilise.

## Construire une distribution complète

Pour une nouvelle installation :

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\build-release.ps1
```

Le script relance les tests puis construit `MIAO-Widget-OBS.zip` depuis une liste explicite. Les fichiers runtime ne peuvent pas entrer dans l’archive.

## Construire une mise à jour différentielle

Pour transmettre seulement les fichiers ajoutés ou modifiés depuis le dernier commit :

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\build-update.ps1
```

Pour comparer avec une autre base :

```powershell
.\tools\build-update.ps1 -BaseRef origin/main -DestinationPath .\MIAO-Update.zip
```

L’archive reproduit directement l’arborescence du dépôt, sans dossier complet superflu. Les suppressions et les anciennes sources des renommages sont inscrites dans un fichier voisin `MIAO-Update-files-to-delete.txt` : elles ne sont jamais exécutées automatiquement.

## Vérifications manuelles Windows

1. Démarrer M.I.A.O. sans Moobot et vérifier que `/health`, `/control` et `/control/broadcast` répondent.
2. Ouvrir Moobot et vérifier que le morceau apparaît sans relancer M.I.A.O.
3. Vérifier `/`, `/miao-widget.html` et le dock existant dans OBS.
4. Modifier rapidement plusieurs réglages et une transmission.
5. Tester les huit commandes avec Moobot Assistant ouvert.
6. Vérifier les modes radio seule, mission seule, alternance et écran vide.

## Arborescence stable

La topologie du projet est figée à partir de M.I.A.O. 4.0. Les nouvelles fonctionnalités ajoutent un dossier `modules/<id>/` et, à l’exécution, éventuellement `var/<id>/`. Elles ne déplacent pas les lanceurs, le noyau, le dock commun, la documentation ou les outils existants.

Les seuls fichiers de projet conservés à la racine sont `.gitignore`, `CHANGELOG.md`, `LICENSE`, `Lancer MIAO.bat`, `README.md` et `VERSION`. Le test de contrat bloque l’ajout accidentel d’un autre fichier de code ou de documentation à cet emplacement.
