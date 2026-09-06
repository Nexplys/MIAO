# Développer un module M.I.A.O.

## Convention de dossier

```text
modules/exemple/
├── module.json
├── config/                    Valeurs distribuées, jamais les données utilisateur
├── public/
│   ├── control/               Fragments ajoutés au dock commun
│   ├── css/
│   ├── images/
│   ├── js/
│   └── widget.html
└── server/                    Point d’entrée et logique PowerShell
```

Seul `module.json` est obligatoire. Un module sans interface publique peut omettre `public` et `control`.

## Manifeste v1

```json
{
  "schemaVersion": 1,
  "id": "exemple",
  "name": "Module exemple",
  "version": "1.0.0",
  "enabled": true,
  "entry": "server/Miao.Exemple.psm1",
  "hooks": {
    "initialize": "Initialize-MiaoExampleModule",
    "update": "Update-MiaoExampleModule",
    "route": "Invoke-MiaoExampleRoute",
    "shutdown": "Stop-MiaoExampleModule"
  },
  "updateIntervalMs": 500,
  "public": {
    "root": "public",
    "aliases": [
      { "route": "/exemple", "file": "widget.html" }
    ]
  },
  "control": {
    "styles": ["/modules/exemple/css/control.css"],
    "scripts": ["/modules/exemple/js/control.js"],
    "tabs": [
      {
        "id": "exemple",
        "label": "Exemple",
        "fragment": "/modules/exemple/control/exemple.html"
      }
    ]
  }
}
```

| Champ | Règle |
| --- | --- |
| `id` | minuscules, chiffres et tirets ; identique au nom du dossier |
| `version` | version SemVer indépendante de la version globale |
| `enabled` | booléen permettant de retirer le module du démarrage |
| `entry` | fichier `.psm1` contenu dans le dossier du module |
| `hooks.initialize` | obligatoire et exporté par le point d’entrée |
| autres hooks | facultatifs, mais exportés lorsqu’ils sont déclarés |
| `updateIntervalMs` | entier compris entre 50 et 60 000 ms |
| `public.root` | dossier auquel toutes les ressources web sont confinées |
| `public.aliases` | routes courtes facultatives, uniques et non réservées |
| `control` | ressources et onglets injectés dans le dock commun |

Les chemins utilisent `/` dans le JSON. Une ressource de dock doit commencer par `/modules/<id>/` et exister au démarrage. Les alias ne peuvent pas utiliser `/api/`, `/modules/` ni une route centrale.

## Hooks PowerShell

Le point d’entrée exporte uniquement les hooks déclarés et, si nécessaire, une petite API destinée aux tests.

```powershell
function Initialize-MiaoExampleModule {
    param($ApplicationContext, [string]$ModulePath, $Options)
    return [pscustomobject]@{ Value = 0 }
}

function Update-MiaoExampleModule {
    param($State, [System.DateTime]$Now)
}

function Invoke-MiaoExampleRoute {
    param($Request, $State, $ApplicationContext, $Client)
    if ($Request.Path -ne "/api/exemple/state") { return $false }
    # Envoyer exactement une réponse, puis indiquer que la route est traitée.
    return $true
}

function Stop-MiaoExampleModule {
    param($State)
}
```

`initialize` retourne zéro ou un objet d’état privé. Cet objet est ensuite transmis aux trois autres hooks ; aucune variable fonctionnelle ne doit être ajoutée au contexte central. Le hook `route` retourne un seul booléen : `$true` après avoir envoyé une réponse, `$false` lorsqu’il ne reconnaît pas la route. Les hooks ne doivent produire aucune autre sortie dans le pipeline PowerShell.

Une route API nouvelle doit être préfixée par `/api/<id>/`. Broadcast est la seule exception : il conserve les routes historiques de M.I.A.O. 3 pour ne pas casser OBS.

## Interface du dock

- Préfixer chaque `id` HTML par l’identifiant du module.
- Limiter les fragments à leur contenu : aucun `<html>`, `<head>`, script ou style inline.
- Charger les scripts et styles par le manifeste.
- Utiliser `window.MiaoApi` pour les appels locaux.
- Enregistrer l’initialiseur asynchrone avec `window.MiaoControlHost.registerModule(id, initializer)`.
- Utiliser `window.MiaoControlHost.setStatus(message, type)` pour le bandeau commun.
- Encapsuler le CSS spécifique sous `[data-module="<id>"]`.

## Ressources et données

Les ressources distribuées appartiennent au module : configuration par défaut, images, sons, CSS et JavaScript. Les données modifiées par l’utilisateur doivent être écrites dans `$ApplicationContext.RuntimePath/<id>/`, qui correspond à `var/<id>/`, jamais à la racine ni dans `modules/<id>/config`.

Chaque module est responsable de la structure et de la migration de son propre dossier runtime. Une ressource tierce doit conserver sa licence ou ses crédits dans un fichier `THIRD_PARTY_NOTICES.md` placé dans le module concerné.

Les formats statiques pris en charge incluent HTML, CSS, JavaScript, JSON, SVG, PNG, JPEG, WebP, GIF, MP3, OGG, WAV, WOFF et WOFF2.

## Validation minimale

Avant d’intégrer un module :

1. lancer `tests/run-all.ps1` ;
2. vérifier son widget dans une vraie source navigateur OBS ;
3. vérifier ses onglets avec les autres modules actifs ;
4. tester son démarrage sans sa source externe éventuelle ;
5. documenter ses routes, ses fichiers runtime et sa procédure de mise à jour.
