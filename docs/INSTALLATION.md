# Installation et mise à jour de M.I.A.O.

## Mise à jour depuis M.I.A.O. 3

Les URL OBS et les données utilisateur restent compatibles.

1. Fermer M.I.A.O.
2. Conserver `miao-mission.txt` et `miao-settings.json` à la racine pour leur import automatique.
3. Copier les nouveaux fichiers par-dessus l’installation actuelle.
4. Vérifier la présence de `modules/broadcast/module.json`, de `public/` et de `src/`.
5. Relancer `Lancer MIAO.bat`.
6. Vérifier que `var/broadcast/mission.txt` et `var/broadcast/settings.json` ont été créés.
7. Actualiser le cache du dock et de la source navigateur si nécessaire.

M.I.A.O. copie les deux anciens fichiers dans `var/broadcast/` uniquement si leur nouvelle destination n’existe pas. Après avoir validé le widget et le dock, les anciennes copies à la racine peuvent être archivées ou supprimées manuellement.

Avec Git, les renommages et suppressions sont appliqués normalement lors de la mise à jour de la branche. Avec un paquet différentiel, consulter le fichier `*-files-to-delete.txt` fourni à côté de l’archive et supprimer uniquement les chemins qu’il énumère.

Les anciens fichiers de Broadcast situés dans `config/`, `public/widget.html`, `public/css/widget.css`, `public/js/widget*.js` et les modules fonctionnels correspondants dans `src/` sont ignorés par M.I.A.O. 4. Ils peuvent donc rester le temps du premier test, puis être retirés selon le manifeste de suppression.

## Nouvelle installation

1. Extraire la distribution complète dans l’emplacement souhaité.
2. Vérifier que le dossier `modules/broadcast` est présent.
3. Double-cliquer sur `Lancer MIAO.bat`.
4. Laisser la fenêtre PowerShell ouverte ou réduite pendant le stream.

Le lanceur fourni exécute :

```bat
@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\start-miao.ps1"
pause
```

## Détection de Moobot

Broadcast cherche automatiquement :

```text
%APPDATA%\moobot-assistant\User files\*.song-player.current.txt
```

S’il trouve plusieurs fichiers, il sélectionne le plus récemment modifié. Moobot peut être lancé avant ou après M.I.A.O. : tant que la source n’est pas disponible, le module réessaie périodiquement sans empêcher le dock ou les autres modules de fonctionner.

Le fichier de Moobot est uniquement lu. Le titre nettoyé reste en mémoire et aucun `*.song-player.current.cleaned.txt` n’est créé.

Pour imposer une chaîne, une source ou un autre port :

```powershell
.\scripts\start-miao.ps1 -Channel "autrechaine" -Port 8975
.\scripts\start-miao.ps1 -SourcePath "D:\Titres\radio.song-player.current.txt"
```

## Lancement coordonné avec OBS

Le lanceur optionnel démarre M.I.A.O. en arrière-plan, ouvre OBS si nécessaire, puis arrête M.I.A.O. à la fermeture d’OBS :

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\start-with-obs.ps1
```

Un chemin OBS non standard peut être fourni avec `-ObsPath`.

## Configuration OBS

### Widget Broadcast

- URL : `http://127.0.0.1:8974/`
- alias équivalent : `http://127.0.0.1:8974/miao-widget.html`
- largeur conseillée : `800`
- hauteur conseillée : `360`
- images par seconde : `30`
- **Fichier local** : désactivé

### Dock commun

Dans **Affichage → Docks → Docks de navigateur personnalisés** :

- nom : `MIAO - Console de bord`
- URL : `http://127.0.0.1:8974/control`

Les onglets sont ajoutés automatiquement par les modules actifs.

## Raccourcis Moobot Assistant

Dans **Assistant → Hotkeys**, activer :

| Action | Raccourci |
| --- | --- |
| Démarrer | `Ctrl + Alt + Shift + 1` |
| Pause / reprendre | `Ctrl + Alt + Shift + 2` |
| Morceau suivant | `Ctrl + Alt + Shift + 3` |
| Mute / réactiver | `Ctrl + Alt + Shift + 4` |
| Volume − | `Ctrl + Alt + Shift + 5` |
| Volume + | `Ctrl + Alt + Shift + 6` |
| Ajouter à la playlist secondaire | `Ctrl + Alt + Shift + 7` |
| Blacklister le morceau et son demandeur | `Ctrl + Alt + Shift + 8` |

Moobot Assistant doit rester ouvert. Si les boutons ne répondent pas, vérifier que Moobot et PowerShell utilisent le même niveau d’autorisation Windows.

## Diagnostic

- Broadcast : `http://127.0.0.1:8974/`
- console : `http://127.0.0.1:8974/control`
- état de santé : `http://127.0.0.1:8974/health`

`/health` indique la version de M.I.A.O. et les modules actifs. Le serveur reste limité à `127.0.0.1` : il n’est exposé ni au réseau local ni à Internet.
