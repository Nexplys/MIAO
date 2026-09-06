# Module Tunic : décisions et état de préparation

Spécification récupérée le 6 septembre 2026 depuis **MIAO Dev**. Le module est désormais implémenté dans M.I.A.O. 4.2.0 ; voir le [guide actuel](TUNIC.md). Les sections ci-dessous conservent le contexte et les propositions de la reprise initiale.

## Objectif validé

Créer un widget OBS qui permette aux viewers de comprendre l'avancement du randomizer TUNIC/Archipelago. Montrer la progression utile plutôt qu'un inventaire exhaustif. Intégration dans M.I.A.O. comme module optionnel isolé sous `modules/tunic/`, avec données locales sous `var/tunic/`. Décision ultérieure de l'utilisateur : dock indépendant `/control/tunic` et widget `/tunic`, ajoutés séparément dans OBS ; aucun onglet Tunic dans le dock Broadcast.

La capture récupérée montre le jeu au centre, la caméra en bas à gauche, le timer juste au-dessus et Broadcast en bas à droite. La bande inférieure centrale est l'emplacement envisagé. L'ancienne estimation de 1200 x 115 pixels à l'échelle 1080p reste approximative : la capture accessible est de 920 x 520 et le stream est déclaré en 2K. Vérifier l'encombrement réel des deux rangées dans OBS.

## Grille finale explicitement demandée : 2 x 5

| Position | Ligne 1 : progression principale | Ligne 2 : outils secondaires |
| --- | --- | --- |
| 1 | Trois Hexagones réunis dans une seule case | Baguette |
| 2 | Épée et sa progression | Orbe |
| 3 | Lauriers | Lanterne |
| 4 | Prière | Masque |
| 5 | Sainte-Croix | Clé de la maison |

Les Hexagones rouge, vert et bleu s'activent individuellement dans une case commune. Ne pas rétablir la proposition 2 x 6 ni séparer les trois Hexagones en trois cases. La clé de maison a finalement été réintégrée. Le bouclier, la dague et Icebolt ont été écartés pour cette seed : l'utilisateur veut privilégier les objets qui débloquent des checks.

L'utilisateur demande les véritables représentations des objets. La proposition associée est : quatre représentations successives pour bâton/épée/améliorations, images des objets et pages 24 et 43 pour les capacités, éléments absents désaturés à environ 20 % d'opacité, couleur et courte illumination à l'acquisition. La disponibilité et l'exactitude des images doivent être vérifiées avant intégration. Le pourcentage et les animations sont des propositions de rendu, pas une mesure issue du code.

Références historiques à examiner au moment d'implémenter :

- [TunicTracker de SapphireSapphic](https://github.com/SapphireSapphic/TunicTracker) pour les assets ; l'ancien chat mentionnait MIT et des crédits SapphireSapphic, ScoutJD et Br00ty.
- [Tunic Randomizer](https://github.com/silent-destroyer/tunic-randomizer) et [ItemTracker.cs](https://github.com/silent-destroyer/tunic-randomizer/blob/main/src/Data/ItemTracker.cs) pour le format et la sémantique.

Ces sources ont été vérifiées pendant l'implémentation. Les icônes sont issues d'une révision épinglée de TunicTracker ; leur licence et leurs attributions sont conservées dans `modules/tunic/THIRD_PARTY_NOTICES.md`. La licence M.I.A.O. ne remplace pas les conditions applicables aux graphismes de TUNIC.

## Source locale confirmée

Fichier trouvé et lu : `%USERPROFILE%/AppData/LocalLow/Andrew Shouldice/Secret Legend/Randomizer/ItemTracker.json`, 1548 octets, état réinitialisé.

Structure racine observée :

```json
{
  "Seed": 0,
  "CurrentScene": { "SceneId": 0, "SceneName": null },
  "ImportantItems": {},
  "DiscoveredEntrances": {},
  "ItemsCollected": []
}
```

Dans cet exemple structurel, `ImportantItems` est abrégé. Le fichier réel contient 50 clés ; toutes valent zéro sauf `Trinket Slot`, qui vaut 1. Aucun passage découvert ni objet collecté. Il n'y a pas de réglages de seed dans ce fichier.

Clés observées directement et pertinentes pour le MVP :

| Fonction | Clés présentes dans ImportantItems |
| --- | --- |
| Objectif | `Hexagon Red`, `Hexagon Green`, `Hexagon Blue`, `Hexagon Gold` |
| Épée | `Stick`, `Sword`, `Sword Progression` |
| Outils magiques | `Techbow`, `Wand`, `Stundagger` |
| Mobilité et accès | `Hyperdash`, `Lantern`, `Mask`, `Key (House)` |
| Capacités | `Prayer`, `Holy Cross`, `Icebolt` |
| À ne pas confondre | `Vault Key (Red)` est distinct de `Hexagon Red` |

La correspondance exacte Techbow/Wand avec baguette/orbe, les niveaux d'épée et les règles de capacités doivent être vérifiés dans le code du randomizer ou un fichier de partie active. L'échantillon initial confirme les noms de champs mais pas leur évolution en jeu. Ne pas déduire une progression réelle à partir d'un inventaire à zéro.

La capture montre Randomizer 4.2.7 avec une mise à jour 5.0.2 proposée. C'est un constat sur une capture ancienne, pas la version installée vérifiée aujourd'hui. Tenir compte des éventuelles différences de format.

## Réglages de seed : récupération partielle

Le YAML avait été joint dans l'ancien chat mais son contenu brut n'est pas exposé par l'outil de lecture. Le résumé de l'ancien assistant indique un objectif classique, `hexagon_quest: false`, `keys_behind_bosses: false`, une progression d'épée, Ice Grappling désactivé et pas de mélange des échelles/fusibles/cloches à afficher. Ces éléments sont des indications historiques à confirmer avec le vrai YAML avant de coder des règles de seed.

Ne pas publier le YAML personnel ni ses informations de slot/connexion. Une importation depuis le dock devrait ne conserver que les options pertinentes. La prise en charge d'autres seeds, de Hexagon Quest et des fonctionnalités randomisées était envisagée ; elle ne doit pas remplacer la grille finale décidée pour la première version.

## Proposition technique à réaliser

- Manifeste v1 conforme à `docs/MODULES.md`, état privé, hooks d'initialisation, mise à jour et routage.
- Source `/tunic` et API `/api/tunic/state`, ressources sous `/modules/tunic/`.
- Lecture seule du fichier du randomizer, autodétection et chemin réglable depuis le dock.
- Aucun besoin identifié de connexion directe à Archipelago pour lire l'inventaire local.
- Dernier état valide conservé si le JSON est momentanément incomplet ou verrouillé pendant une écriture.
- État initial : widget masqué ; partie chargée : apparition ; acquisition : courte animation ; changement de scène : rafraîchissement calme.
- Mode de simulation depuis le dock pour préparer OBS sans lancer le jeu.
- Paramètres locaux gérés par le dock ; import du YAML proposé, sans imposer une dépendance supplémentaire à installer.
- Module absent ou désactivé : Broadcast et le dock restent utilisables.

Le masquage lorsque le jeu est fermé ne peut pas être déduit du seul fait que le fichier existe : définir comment détecter une source périmée, la fermeture du jeu et les changements de seed. Éviter de rejouer toutes les acquisitions à chaque rafraîchissement ou reconnexion.

Les interactions futures avec Alertes passeraient par une infrastructure commune, sans import direct entre modules. Aucun bus d'événements n'est présent dans le noyau actuel : ce n'est pas un prérequis déjà disponible.

## Ordre de réalisation proposé pour la reprise

1. Confirmer le dossier de code utilisé pour le développement et repartir du commit vérifié.
2. Récupérer le YAML réel et un échantillon actif ; vérifier la sémantique dans la version pertinente du randomizer.
3. Vérifier les assets et leurs notices, puis préparer la grille 2 x 5 et le mode de simulation pour valider les dimensions.
4. Implémenter le module, son état, ses réglages et son onglet, sans logique Tunic dans le noyau.
5. Tester fichier absent/invalide/incomplet, valeurs manquantes, changement de seed, progression d'épée et des Hexagones, démarrage tardif et non-régression Broadcast.
6. Exécuter `tests/run-all.ps1`, vérifier en source navigateur OBS, mettre à jour les guides et livrer localement. L'utilisateur publie ensuite.

Les flux détaillés d'objets envoyés/reçus entre joueurs, alertes événementielles et autres intégrations sont hors du premier périmètre validé.
