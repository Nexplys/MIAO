# Journal des versions

## 3.0.0 — Refonte maintenable

- séparation du serveur, des fichiers, des réglages, du nettoyage des titres et des raccourcis en modules PowerShell ;
- séparation complète du HTML, du CSS et du JavaScript ;
- ajout d’un noyau fonctionnel testable pour le widget ;
- schéma unique pour les 42 réglages, leur interface, leurs valeurs par défaut, leur validation et leur migration ;
- configuration unique des huit commandes Moobot ;
- écritures atomiques des données utilisateur ;
- sauvegarde automatique avant migration ou récupération d’un fichier de réglages invalide ;
- conservation des routes OBS et du lanceur historiques ;
- ajout de tests de contrat JavaScript et de tests PowerShell sans dépendance externe.
