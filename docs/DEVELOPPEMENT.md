# Développer M.I.A.O.

## Prérequis

- Windows PowerShell 5.1 pour les tests des modules et le test réel avec Moobot ;
- Node.js récent uniquement pour les tests de contrat JavaScript.

Node.js n’est pas nécessaire pour utiliser M.I.A.O. en stream.

## Lancer les tests

Depuis la racine du projet :

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\run-all.ps1
```

Les suites peuvent aussi être lancées séparément :

```powershell
node .\tests\contracts.test.js
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\Miao.Tests.ps1
```

## Ajouter ou modifier un réglage

1. Modifier `config/settings.schema.json`.
2. Consommer la nouvelle clé dans `public/js/widget.js` ou `public/js/widget-core.js`.
3. Lancer les tests.

Le dock génère le champ correspondant. Le module de réglages génère sa valeur par défaut, le valide et migre les anciens fichiers. Aucune autre copie de la valeur par défaut ne doit être ajoutée.

## Modifier une commande Moobot

Modifier uniquement `config/player-actions.json`, puis lancer les tests. Le serveur n’accepte que les identifiants présents dans ce fichier et uniquement une touche numérique avec le préfixe `Ctrl+Alt+Shift`.

## Modifier le widget

- placer les calculs sans accès au DOM dans `public/js/widget-core.js` afin de pouvoir les tester ;
- garder l’animation et les interactions avec le DOM dans `public/js/widget.js` ;
- ne pas ajouter de script ou de style inline dans le HTML.

## Créer l’archive

Après les tests :

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\build-release.ps1
```

Le script relance toutes les suites puis construit `MIAO-Widget-OBS.zip` à côté du dossier du projet depuis une liste explicite de fichiers. Les données runtime `miao-mission.txt` et `miao-settings.json` ne peuvent pas entrer dans l’archive.

## Vérifications manuelles Windows

1. Démarrer M.I.A.O. avec le lanceur habituel.
2. Ouvrir `/health`, `/` et `/control`.
3. Modifier une transmission et plusieurs réglages rapidement.
4. Tester les huit commandes avec Moobot Assistant ouvert.
5. Vérifier les modes radio seule, mission seule, alternance et écran vide.
