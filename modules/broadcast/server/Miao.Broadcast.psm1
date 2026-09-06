Set-StrictMode -Version 2.0

$script:CorePath = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\..\..\src"))
Import-Module (Join-Path $script:CorePath "Miao.Files.psm1") -ErrorAction Stop
Import-Module (Join-Path $script:CorePath "Miao.Http.psm1") -ErrorAction Stop
Import-Module (Join-Path $script:CorePath "Miao.Settings.psm1") -ErrorAction Stop
Import-Module (Join-Path $script:CorePath "Miao.Web.psm1") -ErrorAction Stop
Import-Module (Join-Path $PSScriptRoot "Miao.Hotkeys.psm1") -ErrorAction Stop
Import-Module (Join-Path $PSScriptRoot "Miao.Mission.psm1") -ErrorAction Stop
Import-Module (Join-Path $PSScriptRoot "Miao.Moobot.psm1") -ErrorAction Stop
Import-Module (Join-Path $PSScriptRoot "Miao.TitleCleaner.psm1") -ErrorAction Stop

function Get-MiaoBroadcastOption {
    param($Options, [string]$Name, $Fallback)

    if ($Options -is [System.Collections.IDictionary]) {
        if ($Options.Contains($Name)) {
            return $Options[$Name]
        }
        return $Fallback
    }

    if ($null -ne $Options) {
        $property = $Options.PSObject.Properties[$Name]
        if ($null -ne $property -and $null -ne $property.Value) {
            return $property.Value
        }
    }

    return $Fallback
}

function Find-MiaoBroadcastSource {
    param($State)

    if (-not [string]::IsNullOrWhiteSpace($State.ExplicitSourcePath)) {
        $State.SourcePath = [System.IO.Path]::GetFullPath($State.ExplicitSourcePath)
        $State.SourceMode = "explicit"
        return [System.IO.File]::Exists($State.SourcePath)
    }

    if ([string]::IsNullOrWhiteSpace($State.MoobotDirectory)) {
        $State.SourcePath = ""
        $State.SourceMode = "unavailable"
        return $false
    }

    try {
        $resolution = Resolve-MiaoMoobotSource `
            -DirectoryPath $State.MoobotDirectory `
            -Channel $State.Channel
        $sourceChanged = $State.SourcePath -ne $resolution.Path
        $State.SourcePath = $resolution.Path
        $State.SourceMode = $resolution.Mode
        $State.CandidateCount = $resolution.CandidateCount

        if ($sourceChanged) {
            Write-Host "Source Moobot detectee : $($resolution.SelectedName)" -ForegroundColor Cyan
            if ($resolution.CandidateCount -gt 1) {
                Write-Host "Plusieurs sources trouvees ; le fichier le plus recent est utilise." -ForegroundColor Yellow
            }
        }
        return [System.IO.File]::Exists($State.SourcePath)
    }
    catch {
        $State.SourcePath = ""
        $State.SourceMode = "waiting"
        $State.CandidateCount = 0
        return $false
    }
}

function Copy-MiaoBroadcastLegacyDataFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$LegacyPath,
        [Parameter(Mandatory = $true)][string]$DestinationPath
    )

    if ([System.IO.File]::Exists($DestinationPath) -or
        -not [System.IO.File]::Exists($LegacyPath)) {
        return $false
    }

    $destinationDirectory = [System.IO.Path]::GetDirectoryName($DestinationPath)
    [void][System.IO.Directory]::CreateDirectory($destinationDirectory)
    [System.IO.File]::Copy($LegacyPath, $DestinationPath, $false)
    return $true
}

function Initialize-MiaoBroadcastModule {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]$ApplicationContext,
        [Parameter(Mandatory = $true)][string]$ModulePath,
        $Options = @{}
    )

    $schemaPath = Join-Path $ModulePath "config\settings.schema.json"
    $playerActionsPath = Join-Path $ModulePath "config\player-actions.json"
    $defaultMissionPath = Join-Path $ModulePath "config\default-mission.txt"
    $dataPath = Join-Path $ApplicationContext.RuntimePath "broadcast"
    $missionPath = Join-Path $dataPath "mission.txt"
    $settingsPath = Join-Path $dataPath "settings.json"

    foreach ($requiredFile in @($schemaPath, $playerActionsPath, $defaultMissionPath)) {
        if (-not [System.IO.File]::Exists($requiredFile)) {
            throw "Fichier du module Broadcast manquant : $requiredFile"
        }
    }

    [void][System.IO.Directory]::CreateDirectory($dataPath)
    $legacyFileCount = 0
    if (Copy-MiaoBroadcastLegacyDataFile `
        -LegacyPath (Join-Path $ApplicationContext.RootPath "miao-mission.txt") `
        -DestinationPath $missionPath) {
        $legacyFileCount++
    }
    if (Copy-MiaoBroadcastLegacyDataFile `
        -LegacyPath (Join-Path $ApplicationContext.RootPath "miao-settings.json") `
        -DestinationPath $settingsPath) {
        $legacyFileCount++
    }
    if ($legacyFileCount -gt 0) {
        Write-Host "Donnees Broadcast importees dans var\broadcast." -ForegroundColor Cyan
    }

    Initialize-MiaoMission `
        -MissionPath $missionPath `
        -DefaultMissionPath $defaultMissionPath

    $schema = Import-MiaoSettingsSchema -Path $schemaPath
    $settings = Read-MiaoSettings -Path $settingsPath -Schema $schema
    $playerActions = Import-MiaoPlayerActions -Path $playerActionsPath
    $appDataPath = [string](Get-MiaoBroadcastOption $Options "AppDataPath" "")
    $moobotDirectory = ""
    if (-not [string]::IsNullOrWhiteSpace($appDataPath)) {
        $moobotDirectory = Join-Path $appDataPath "moobot-assistant\User files"
    }

    $state = [pscustomobject]@{
        ModulePath = $ModulePath
        DataPath = $dataPath
        MissionPath = $missionPath
        SettingsPath = $settingsPath
        Schema = $schema
        Settings = $settings
        PlayerActions = $playerActions
        CurrentSong = ""
        LastRawSong = $null
        ExplicitSourcePath = [string](Get-MiaoBroadcastOption $Options "SourcePath" "")
        Channel = [string](Get-MiaoBroadcastOption $Options "Channel" "")
        MoobotDirectory = $moobotDirectory
        SourcePath = ""
        SourceMode = "waiting"
        CandidateCount = 0
        NextSourceDetectionUtc = [System.DateTime]::UtcNow
    }

    if ($state.Channel -notmatch '^$|^[A-Za-z0-9_]+$') {
        throw "Nom de chaine Moobot invalide."
    }

    if (Find-MiaoBroadcastSource -State $state) {
        try {
            $state.LastRawSong = Read-MiaoUtf8File -Path $state.SourcePath
            $state.CurrentSong = Remove-MiaoTitleSuffix -Title $state.LastRawSong
        }
        catch {
            $state.LastRawSong = $null
            $state.CurrentSong = ""
        }
    }
    else {
        Write-Warning "Moobot n'est pas encore disponible ; le module Broadcast reste actif."
    }

    return $state
}

function Update-MiaoBroadcastModule {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]$State,
        [Parameter(Mandatory = $true)][System.DateTime]$Now
    )

    if ($State.SourceMode -eq "automatic" -and
        -not [string]::IsNullOrWhiteSpace($State.SourcePath) -and
        -not [System.IO.File]::Exists($State.SourcePath)) {
        $State.SourcePath = ""
        $State.LastRawSong = $null
        $State.CurrentSong = ""
        $State.NextSourceDetectionUtc = $Now
    }

    if ([string]::IsNullOrWhiteSpace($State.SourcePath) -and
        $Now -ge $State.NextSourceDetectionUtc) {
        [void](Find-MiaoBroadcastSource -State $State)
        $State.NextSourceDetectionUtc = $Now.AddSeconds(5)
    }

    if (-not [string]::IsNullOrWhiteSpace($State.SourcePath)) {
        [void](Update-MiaoSongTitle `
            -State $State `
            -SourcePath $State.SourcePath)
    }
}

function Invoke-MiaoBroadcastRoute {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]$Request,
        [Parameter(Mandatory = $true)]$State,
        [Parameter(Mandatory = $true)]$ApplicationContext,
        [Parameter(Mandatory = $true)][System.Net.Sockets.TcpClient]$Client
    )

    switch ($Request.Path) {
        "/api/state" {
            if (-not (Test-MiaoRequestMethod -Request $Request -Expected "GET" -Client $Client)) { return $true }
            Send-MiaoJsonResponse -Client $Client -Value ([ordered]@{
                ok = $true
                song = $State.CurrentSong
                mission = (Read-MiaoMission -Path $State.MissionPath)
                settings = $State.Settings
            })
            return $true
        }
        "/api/song" {
            if (-not (Test-MiaoRequestMethod -Request $Request -Expected "GET" -Client $Client)) { return $true }
            Send-MiaoJsonResponse -Client $Client -Value ([ordered]@{
                ok = $true
                song = $State.CurrentSong
            })
            return $true
        }
        "/api/schema" {
            if (-not (Test-MiaoRequestMethod -Request $Request -Expected "GET" -Client $Client)) { return $true }
            Send-MiaoJsonResponse -Client $Client -Value ([ordered]@{
                ok = $true
                schema = $State.Schema
            })
            return $true
        }
        "/api/player/actions" {
            if (-not (Test-MiaoRequestMethod -Request $Request -Expected "GET" -Client $Client)) { return $true }
            Send-MiaoJsonResponse -Client $Client -Value ([ordered]@{
                ok = $true
                configuration = $State.PlayerActions
            })
            return $true
        }
        "/api/mission" {
            if (-not (Test-MiaoRequestMethod -Request $Request -Expected "POST" -Client $Client)) { return $true }
            $payload = ConvertFrom-MiaoEncodedJson -Body $Request.Body
            $mission = Save-MiaoMissionPayload `
                -Payload $payload `
                -Path $State.MissionPath
            Send-MiaoJsonResponse -Client $Client -Value ([ordered]@{
                ok = $true
                mission = $mission
            })
            return $true
        }
        "/api/settings" {
            if (-not (Test-MiaoRequestMethod -Request $Request -Expected "POST" -Client $Client)) { return $true }
            $payload = ConvertFrom-MiaoEncodedJson -Body $Request.Body
            $settings = ConvertTo-MiaoSettings `
                -InputObject $payload `
                -Schema $State.Schema
            Save-MiaoSettings -Settings $settings -Path $State.SettingsPath
            $State.Settings = $settings
            Send-MiaoJsonResponse -Client $Client -Value ([ordered]@{
                ok = $true
                settings = $settings
            })
            return $true
        }
        "/api/settings/reset" {
            if (-not (Test-MiaoRequestMethod -Request $Request -Expected "POST" -Client $Client)) { return $true }
            $settings = Get-MiaoDefaultSettings -Schema $State.Schema
            Save-MiaoSettings -Settings $settings -Path $State.SettingsPath
            $State.Settings = $settings
            Send-MiaoJsonResponse -Client $Client -Value ([ordered]@{
                ok = $true
                settings = $settings
            })
            return $true
        }
        "/api/player" {
            if (-not (Test-MiaoRequestMethod -Request $Request -Expected "POST" -Client $Client)) { return $true }
            $payload = ConvertFrom-MiaoEncodedJson -Body $Request.Body
            $action = Invoke-MiaoPlayerAction `
                -ActionId ([string]$payload.action) `
                -Configuration $State.PlayerActions
            Send-MiaoJsonResponse -Client $Client -Value ([ordered]@{
                ok = $true
                action = $action.id
                message = $action.message
            })
            return $true
        }
        default {
            return $false
        }
    }
}

Export-ModuleMember -Function `
    Initialize-MiaoBroadcastModule, `
    Update-MiaoBroadcastModule, `
    Invoke-MiaoBroadcastRoute
