Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

$root = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
Import-Module (Join-Path $root "src\Miao.Files.psm1") -Force
Import-Module (Join-Path $root "src\Miao.Settings.psm1") -Force
Import-Module (Join-Path $root "src\Miao.Modules.psm1") -Force
Import-Module (Join-Path $root "modules\broadcast\server\Miao.TitleCleaner.psm1") -Force
Import-Module (Join-Path $root "modules\broadcast\server\Miao.Mission.psm1") -Force
Import-Module (Join-Path $root "modules\broadcast\server\Miao.Moobot.psm1") -Force
Import-Module (Join-Path $root "modules\broadcast\server\Miao.Broadcast.psm1") -Force

function Assert-Equal {
    param($Actual, $Expected, [string]$Message)

    if ($Actual -ne $Expected) {
        throw "$Message. Attendu: '$Expected'. Recu: '$Actual'."
    }
}

$titleCases = @(
    @("Artiste - Titre (Official Music Video)", "Artiste - Titre"),
    @("Artiste - Titre [Official Lyric Video]", "Artiste - Titre"),
    @("Artiste - Titre (Official Audio)", "Artiste - Titre"),
    @("Artiste - Titre [4K]", "Artiste - Titre"),
    @("Artiste - Titre (Official Music Video) [HD]", "Artiste - Titre"),
    @("Artiste - Titre", "Artiste - Titre")
)

foreach ($case in $titleCases) {
    Assert-Equal `
        -Actual (Remove-MiaoTitleSuffix -Title $case[0]) `
        -Expected $case[1] `
        -Message "Nettoyage de titre incorrect"
}

$manifest = Read-MiaoModuleManifest `
    -Path (Join-Path $root "modules\broadcast\module.json")
Assert-Equal -Actual $manifest.id -Expected "broadcast" -Message "Identifiant de module incorrect"
Assert-Equal -Actual $manifest.schemaVersion -Expected 1 -Message "Version de manifeste incorrecte"

$broadcastModule = [pscustomobject]@{
    Id = "broadcast"
    Name = [string]$manifest.name
    Version = [string]$manifest.version
    Manifest = $manifest
    PublicRoot = Join-Path $root "modules\broadcast\public"
}
$legacyWidgetRoute = Resolve-MiaoModuleStaticRoute `
    -RequestPath "/" `
    -Modules @($broadcastModule)
Assert-Equal `
    -Actual $legacyWidgetRoute.FilePath `
    -Expected (Join-Path $root "modules\broadcast\public\widget.html") `
    -Message "Alias historique du widget incorrect"
$moduleAssetRoute = Resolve-MiaoModuleStaticRoute `
    -RequestPath "/modules/broadcast/js/widget.js" `
    -Modules @($broadcastModule)
Assert-Equal `
    -Actual $moduleAssetRoute.ContentType `
    -Expected "text/javascript; charset=utf-8" `
    -Message "Type MIME de ressource modulaire incorrect"
$blockedRoute = Resolve-MiaoModuleStaticRoute `
    -RequestPath "/modules/broadcast/../module.json" `
    -Modules @($broadcastModule)
Assert-Equal `
    -Actual $blockedRoute `
    -Expected $null `
    -Message "Une traversee de dossier modulaire doit etre bloquee"
$clientModules = @(Get-MiaoClientModuleDescriptors -Modules @($broadcastModule))
Assert-Equal -Actual $clientModules.Count -Expected 1 -Message "Descripteur client absent"
Assert-Equal `
    -Actual @($clientModules[0].control.tabs).Count `
    -Expected 3 `
    -Message "Nombre d'onglets Broadcast incorrect"

$schema = Import-MiaoSettingsSchema `
    -Path (Join-Path $root "modules\broadcast\config\settings.schema.json")
$defaults = Get-MiaoDefaultSettings -Schema $schema
Assert-Equal -Actual $defaults.Count -Expected 43 -Message "Nombre de reglages incorrect"

$legacy = [pscustomobject]@{
    radioHoldSeconds = 0
    missionEnabled = $false
    textColor = "couleur-invalide"
}
$migrated = ConvertTo-MiaoSettings -InputObject $legacy -Schema $schema
Assert-Equal -Actual $migrated.version -Expected 3 -Message "Version de migration incorrecte"
Assert-Equal -Actual $migrated.radioHoldSeconds -Expected 1 -Message "Limite numerique incorrecte"
Assert-Equal -Actual $migrated.missionEnabled -Expected $false -Message "Booleen non preserve"
Assert-Equal -Actual $migrated.textColor -Expected "#ffffff" -Message "Couleur invalide non corrigee"

$invalid = [pscustomobject]@{
    radioHoldSeconds = "invalide"
    missionEnabled = "invalide"
    compactThreshold = 300
    veryCompactThreshold = 100
}
$repaired = ConvertTo-MiaoSettings -InputObject $invalid -Schema $schema
Assert-Equal -Actual $repaired.radioHoldSeconds -Expected 80 -Message "Entier invalide non remplace"
Assert-Equal -Actual $repaired.missionEnabled -Expected $true -Message "Booleen invalide non remplace"
Assert-Equal -Actual $repaired.veryCompactThreshold -Expected 300 -Message "Seuils incoherents non repares"

$temporaryDirectory = Join-Path ([System.IO.Path]::GetTempPath()) ("miao-tests-" + [System.Guid]::NewGuid().ToString("N"))
[void][System.IO.Directory]::CreateDirectory($temporaryDirectory)

try {
    $fakeRoot = Join-Path $temporaryDirectory "fake-application"
    $fakeModuleRoot = Join-Path $fakeRoot "modules\example"
    $fakeServerRoot = Join-Path $fakeModuleRoot "server"
    [void][System.IO.Directory]::CreateDirectory($fakeServerRoot)
    Write-MiaoUtf8FileAtomic `
        -Path (Join-Path $fakeModuleRoot "module.json") `
        -Content '{"schemaVersion":1,"id":"example","name":"Example","version":"1.0.0","enabled":true,"entry":"server/Example.psm1","hooks":{"initialize":"Initialize-Example"},"updateIntervalMs":1000}'
    Write-MiaoUtf8FileAtomic `
        -Path (Join-Path $fakeServerRoot "Example.psm1") `
        -Content @'
function Initialize-Example {
    param($ApplicationContext, [string]$ModulePath, $Options)
    return [pscustomobject]@{ Marker = [string]$Options.Marker }
}
Export-ModuleMember -Function Initialize-Example
'@
    $fakeContext = [pscustomobject]@{
        RootPath = $fakeRoot
        RuntimePath = Join-Path $fakeRoot "var"
        Version = "1.0.0"
        Port = 8974
        Modules = @()
    }
    $fakeModules = @(Import-MiaoApplicationModules `
        -RootPath $fakeRoot `
        -ApplicationContext $fakeContext `
        -Options @{ example = @{ Marker = "charge" } })
    Assert-Equal -Actual $fakeModules.Count -Expected 1 -Message "Module factice non charge"
    Assert-Equal -Actual $fakeModules[0].Id -Expected "example" -Message "Mauvais module charge"
    Assert-Equal -Actual $fakeModules[0].State.Marker -Expected "charge" -Message "Options de module non transmises"
    Remove-Module "Example" -Force -ErrorAction SilentlyContinue

    $fakePublicRoot = Join-Path $fakeModuleRoot "public"
    [void][System.IO.Directory]::CreateDirectory($fakePublicRoot)
    Write-MiaoUtf8FileAtomic `
        -Path (Join-Path $fakePublicRoot "icon.png") `
        -Content "image factice"
    $fakeStaticModule = [pscustomobject]@{
        Id = "example"
        PublicRoot = $fakePublicRoot
        Manifest = [pscustomobject]@{
            public = [pscustomobject]@{ root = "public"; aliases = @() }
        }
    }
    $imageRoute = Resolve-MiaoModuleStaticRoute `
        -RequestPath "/modules/example/icon.png" `
        -Modules @($fakeStaticModule)
    Assert-Equal `
        -Actual $imageRoute.ContentType `
        -Expected "image/png" `
        -Message "Les modules doivent pouvoir servir leurs images PNG"

    $testFile = Join-Path $temporaryDirectory "atomic.txt"
    Write-MiaoUtf8FileAtomic -Path $testFile -Content "premiere version"
    Write-MiaoUtf8FileAtomic -Path $testFile -Content "seconde version"
    Assert-Equal -Actual (Read-MiaoUtf8File -Path $testFile) -Expected "seconde version" -Message "Ecriture atomique incorrecte"

    $songSourceFile = Join-Path $temporaryDirectory "test.song-player.current.txt"
    Write-MiaoUtf8FileAtomic `
        -Path $songSourceFile `
        -Content "Artiste - Titre (Official Music Video)"
    $songState = [pscustomobject]@{
        LastRawSong = $null
        CurrentSong = ""
    }
    $songChanged = Update-MiaoSongTitle `
        -State $songState `
        -SourcePath $songSourceFile
    Assert-Equal -Actual $songChanged -Expected $true -Message "Titre Moobot non detecte"
    Assert-Equal -Actual $songState.CurrentSong -Expected "Artiste - Titre" -Message "Titre courant non nettoye"
    Assert-Equal `
        -Actual (Update-MiaoSongTitle -State $songState -SourcePath $songSourceFile) `
        -Expected $false `
        -Message "Titre Moobot inchange detecte a tort"
    Assert-Equal `
        -Actual @([System.IO.Directory]::GetFiles($temporaryDirectory, "*.song-player.*.txt")).Count `
        -Expected 1 `
        -Message "Le nettoyage ne doit creer aucun fichier Moobot"

    $moobotDirectory = Join-Path $temporaryDirectory "moobot"
    [void][System.IO.Directory]::CreateDirectory($moobotDirectory)
    $olderSource = Join-Path $moobotDirectory "first.song-player.current.txt"
    $newerSource = Join-Path $moobotDirectory "second.song-player.current.txt"
    $legacyCleaned = Join-Path $moobotDirectory "second.song-player.current.cleaned.txt"
    Write-MiaoUtf8FileAtomic -Path $olderSource -Content "Ancien titre"
    Write-MiaoUtf8FileAtomic -Path $newerSource -Content "Titre recent"
    Write-MiaoUtf8FileAtomic -Path $legacyCleaned -Content "Ancien fichier nettoye"
    [System.IO.File]::SetLastWriteTimeUtc($olderSource, [System.DateTime]::UtcNow.AddMinutes(-2))
    [System.IO.File]::SetLastWriteTimeUtc($newerSource, [System.DateTime]::UtcNow.AddMinutes(-1))

    $detectedSource = Resolve-MiaoMoobotSource -DirectoryPath $moobotDirectory
    Assert-Equal -Actual $detectedSource.Path -Expected $newerSource -Message "Mauvaise source Moobot detectee"
    Assert-Equal -Actual $detectedSource.CandidateCount -Expected 2 -Message "Nombre de sources Moobot incorrect"

    $selectedChannel = Resolve-MiaoMoobotSource `
        -DirectoryPath $moobotDirectory `
        -Channel "chaine_test"
    Assert-Equal `
        -Actual $selectedChannel.Path `
        -Expected (Join-Path $moobotDirectory "chaine_test.song-player.current.txt") `
        -Message "Selection explicite de chaine incorrecte"

    $defaultMissionFile = Join-Path $temporaryDirectory "default-mission.txt"
    $missionFile = Join-Path $temporaryDirectory "mission.txt"
    Write-MiaoUtf8FileAtomic -Path $defaultMissionFile -Content "MISSION PAR DEFAUT"
    Initialize-MiaoMission -MissionPath $missionFile -DefaultMissionPath $defaultMissionFile
    Assert-Equal -Actual (Read-MiaoMission -Path $missionFile) -Expected "MISSION PAR DEFAUT" -Message "Initialisation de mission incorrecte"

    $savedMission = Save-MiaoMissionPayload `
        -Payload ([pscustomobject]@{ text = "LIGNE 1`r`nLIGNE 2" }) `
        -Path $missionFile
    Assert-Equal -Actual $savedMission -Expected "LIGNE 1`nLIGNE 2" -Message "Normalisation de mission incorrecte"

    $legacySettingsFile = Join-Path $temporaryDirectory "legacy-settings.json"
    Write-MiaoUtf8FileAtomic `
        -Path $legacySettingsFile `
        -Content '{"version":2,"radioHoldSeconds":45}'
    $loadedSettings = Read-MiaoSettings -Path $legacySettingsFile -Schema $schema
    Assert-Equal -Actual $loadedSettings.version -Expected 3 -Message "Migration de fichier incorrecte"
    Assert-Equal `
        -Actual ([System.IO.File]::Exists("$legacySettingsFile.v2.bak")) `
        -Expected $true `
        -Message "Sauvegarde de migration absente"

    $invalidSettingsFile = Join-Path $temporaryDirectory "invalid-settings.json"
    Write-MiaoUtf8FileAtomic -Path $invalidSettingsFile -Content '{JSON INVALIDE'
    $fallbackSettings = Read-MiaoSettings -Path $invalidSettingsFile -Schema $schema
    Assert-Equal -Actual $fallbackSettings.version -Expected 3 -Message "Repli apres JSON invalide incorrect"
    $invalidBackups = @([System.IO.Directory]::GetFiles(
        $temporaryDirectory,
        "invalid-settings.json.invalid-*.bak"
    ))
    Assert-Equal -Actual $invalidBackups.Count -Expected 1 -Message "Sauvegarde du JSON invalide absente"

    $legacyApplicationRoot = Join-Path $temporaryDirectory "legacy-application"
    $legacyRuntimePath = Join-Path $legacyApplicationRoot "var"
    [void][System.IO.Directory]::CreateDirectory($legacyApplicationRoot)
    $legacyMissionPath = Join-Path $legacyApplicationRoot "miao-mission.txt"
    $legacySettingsPath = Join-Path $legacyApplicationRoot "miao-settings.json"
    Write-MiaoUtf8FileAtomic -Path $legacyMissionPath -Content "TRANSMISSION CONSERVEE"
    Write-MiaoUtf8FileAtomic `
        -Path $legacySettingsPath `
        -Content '{"version":3,"radioHoldSeconds":45}'

    $legacyContext = [pscustomobject]@{
        RootPath = $legacyApplicationRoot
        RuntimePath = $legacyRuntimePath
        Version = "4.0.0"
        Port = 8974
        Modules = @()
    }
    $broadcastState = Initialize-MiaoBroadcastModule `
        -ApplicationContext $legacyContext `
        -ModulePath (Join-Path $root "modules\broadcast") `
        -Options @{}
    Assert-Equal `
        -Actual $broadcastState.MissionPath `
        -Expected (Join-Path $legacyRuntimePath "broadcast\mission.txt") `
        -Message "Chemin runtime de la mission incorrect"
    Assert-Equal `
        -Actual $broadcastState.SettingsPath `
        -Expected (Join-Path $legacyRuntimePath "broadcast\settings.json") `
        -Message "Chemin runtime des reglages incorrect"
    Assert-Equal `
        -Actual (Read-MiaoMission -Path $broadcastState.MissionPath) `
        -Expected "TRANSMISSION CONSERVEE" `
        -Message "Mission historique non importee"
    Assert-Equal `
        -Actual $broadcastState.Settings.radioHoldSeconds `
        -Expected 45 `
        -Message "Reglages historiques non importes"
    Assert-Equal `
        -Actual ([System.IO.File]::Exists($legacyMissionPath)) `
        -Expected $true `
        -Message "La migration ne doit pas supprimer la mission historique"
    Assert-Equal `
        -Actual ([System.IO.File]::Exists($legacySettingsPath)) `
        -Expected $true `
        -Message "La migration ne doit pas supprimer les reglages historiques"

    Write-MiaoUtf8FileAtomic -Path $legacyMissionPath -Content "ANCIEN FICHIER MODIFIE"
    $secondBroadcastState = Initialize-MiaoBroadcastModule `
        -ApplicationContext $legacyContext `
        -ModulePath (Join-Path $root "modules\broadcast") `
        -Options @{}
    Assert-Equal `
        -Actual (Read-MiaoMission -Path $secondBroadcastState.MissionPath) `
        -Expected "TRANSMISSION CONSERVEE" `
        -Message "Une donnee runtime existante ne doit pas etre ecrasee"
}
finally {
    if ([System.IO.Directory]::Exists($temporaryDirectory)) {
        [System.IO.Directory]::Delete($temporaryDirectory, $true)
    }
}

Write-Host "OK - Tests PowerShell M.I.A.O. valides." -ForegroundColor Green
