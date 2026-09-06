# Journal des versions

## 4.0.0 - Architecture modulaire

- séparation du noyau technique et des fonctionnalités de stream ;
- ajout d’un chargeur de modules piloté par des manifestes validés ;
- migration complète de la radio, de la transmission et de Moobot vers `modules/broadcast` ;
- composition dynamique des onglets du dock à partir des modules actifs ;
- conservation des URL OBS, des routes API et des fichiers utilisateur existants ;
- prise en charge des ressources statiques binaires pour les futurs widgets ;
- confinement des fichiers publics dans le dossier de leur module ;
- détection Moobot non bloquante avec nouvelle tentative automatique ;
- tests génériques du contrat de module et de l’interface assemblée ;
- ajout d’un constructeur reproductible de mises à jour différentielles ;
- documentation du contrat à suivre pour le futur tracker Tunic ;
- stabilisation de l’arborescence avant l’ajout de nouveaux modules ;
- regroupement des scripts opérationnels dans `scripts/` ;
- déplacement non destructif des données locales vers `var/<module>/` ;
- ajout de la licence MIT au nom de Nexplys.

## 3.0.1 - Finalisation du déplacement

- conservation du titre Moobot nettoyé uniquement en mémoire ;
- arrêt de l’écriture du fichier `*.cleaned.txt` dans le dossier de Moobot Assistant ;
- détection automatique de la source Moobot sans nom de chaîne personnel dans le code ;
- ajout des deux lanceurs au paquet de distribution ;
- correction et paramétrage du lanceur combiné M.I.A.O. + OBS ;
- nettoyage des exclusions Git et ajout d’un contrôle continu sur Windows ;
- ajout d’une procédure sûre pour retirer l’ancienne installation.

## 3.0.0 - Refonte maintenable

- séparation du serveur, des fichiers, des réglages, du nettoyage des titres et des raccourcis en modules PowerShell ;
- séparation complète du HTML, du CSS et du JavaScript ;
- ajout d’un noyau fonctionnel testable pour le widget ;
- schéma unique pour les 42 réglages, leur interface, leurs valeurs par défaut, leur validation et leur migration ;
- configuration unique des huit commandes Moobot ;
- écritures atomiques des données utilisateur ;
- sauvegarde automatique avant migration ou récupération d’un fichier de réglages invalide ;
- conservation des routes OBS et du lanceur historiques ;
- ajout de tests de contrat JavaScript et de tests PowerShell sans dépendance externe.
