Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

$root = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
Import-Module (Join-Path $root "src\Miao.Files.psm1") -Force
Import-Module (Join-Path $root "src\Miao.Settings.psm1") -Force
Import-Module (Join-Path $root "src\Miao.TitleCleaner.psm1") -Force
Import-Module (Join-Path $root "src\Miao.Mission.psm1") -Force
Import-Module (Join-Path $root "src\Miao.Moobot.psm1") -Force

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

$schema = Import-MiaoSettingsSchema -Path (Join-Path $root "config\settings.schema.json")
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
}
finally {
    if ([System.IO.Directory]::Exists($temporaryDirectory)) {
        [System.IO.Directory]::Delete($temporaryDirectory, $true)
    }
}

Write-Host "OK - Tests PowerShell M.I.A.O. valides." -ForegroundColor Green
