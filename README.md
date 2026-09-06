# M.I.A.O. — Console de bord OBS

M.I.A.O. 3 est un widget local pour OBS qui alterne une radio de bord et une transmission libre, nettoie les titres produits par Moobot Assistant et pilote le Song Player par ses raccourcis globaux.

## Démarrage rapide

1. Double-cliquer sur `Lancer MIAO.bat`.
2. Utiliser `http://127.0.0.1:8974/` comme source navigateur OBS.
3. Utiliser `http://127.0.0.1:8974/control` comme dock navigateur OBS.

Les fichiers `miao-mission.txt` et `miao-settings.json` sont créés automatiquement à côté du lanceur. Ils contiennent les données personnelles de l’installation et ne font volontairement pas partie du paquet distribué.

Le guide complet se trouve dans [docs/INSTALLATION.md](docs/INSTALLATION.md).

M.I.A.O. détecte automatiquement le fichier de titre créé par Moobot Assistant, sans nom de chaîne configuré dans le projet. Il ne modifie pas le dossier de Moobot : le titre nettoyé est conservé uniquement en mémoire par le serveur local.

## Principes du projet

- zéro dépendance à installer pour streamer ;
- compatibilité Windows PowerShell 5.1 ;
- serveur accessible uniquement depuis l’ordinateur local ;
- un schéma unique pour les valeurs par défaut, la validation et la génération du dock ;
- fichiers utilisateur préservés lors des mises à jour ;
- URL OBS et point d’entrée historiques conservés.

## Structure

```text
MIAO/
├── Lancer MIAO.bat            Lanceur utilisateur
├── miao-clean-title.ps1       Point d’entrée PowerShell stable
├── VERSION                    Version applicative unique
├── config/                    Schémas et valeurs distribuées
├── public/                    Interfaces servies à OBS
├── src/                       Modules PowerShell
├── docs/                      Guides techniques et utilisateur
└── tests/                     Tests de contrat et tests PowerShell
```

Voir [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) avant toute évolution du code et [docs/DEVELOPPEMENT.md](docs/DEVELOPPEMENT.md) pour lancer les tests ou produire une archive.
