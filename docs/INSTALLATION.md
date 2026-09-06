# Installation et mise à jour de M.I.A.O.

## Mise à jour depuis la version précédente

1. Fermer le script PowerShell M.I.A.O.
2. Conserver les fichiers actuels `miao-mission.txt` et `miao-settings.json`.
3. Extraire tout le nouveau dossier `MIAO-Widget` par-dessus l’ancien.
4. Vérifier que les dossiers `config`, `public` et `src` sont présents.
5. Relancer le fichier `.bat` habituel.
6. Actualiser le dock et la source navigateur dans OBS si l’ancienne interface reste en cache.

Le paquet ne contient plus de `miao-mission.txt` ni de `miao-settings.json`. Une extraction normale ne peut donc pas remplacer tes données. Au premier lancement, les anciens réglages sont validés et migrés automatiquement vers le schéma actuel. Une copie `miao-settings.json.v2.bak` est conservée avant la migration ; un JSON illisible est lui aussi sauvegardé avec le suffixe `invalid-...bak` avant le retour aux valeurs par défaut.

Les anciens fichiers `miao-widget.html` et `miao-control.html` placés à la racine ne sont plus utilisés. Ils peuvent rester sur place sans gêner le fonctionnement.

## Nouvelle installation

1. Extraire le dossier complet dans l’emplacement souhaité.
2. Créer ou conserver un fichier `.bat` lançant `miao-clean-title.ps1`.
3. Lancer le script une première fois.
4. Vérifier que la fenêtre affiche les deux adresses M.I.A.O.

Exemple de fichier `.bat` :

```bat
@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0miao-clean-title.ps1"
pause
```

Le lanceur déduit automatiquement le chemin Moobot depuis `%APPDATA%` et utilise le nom de chaîne `nexplys`. Il continue donc de lire :

```text
%APPDATA%\moobot-assistant\User files\nexplys.song-player.current.txt
```

Pour une autre chaîne ou un autre port :

```bat
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0miao-clean-title.ps1" -Channel "autrechaine" -Port 8975
```

## OBS

### Source navigateur

- URL : `http://127.0.0.1:8974/`
- largeur conseillée : `800`
- hauteur conseillée : `360`
- images par seconde : `30`
- **Fichier local** : désactivé

### Dock navigateur

Dans **Affichage → Docks → Docks de navigateur personnalisés** :

- nom : `MIAO - Console de bord`
- URL : `http://127.0.0.1:8974/control`

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

- widget : `http://127.0.0.1:8974/`
- console : `http://127.0.0.1:8974/control`
- état de santé : `http://127.0.0.1:8974/health`

Le serveur écoute uniquement sur `127.0.0.1` : il n’est pas exposé au réseau local ni à Internet.
