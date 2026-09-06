Set-StrictMode -Version 2.0

Import-Module (Join-Path $PSScriptRoot "Miao.Files.psm1") -Force
Import-Module (Join-Path $PSScriptRoot "Miao.Settings.psm1") -Force
Import-Module (Join-Path $PSScriptRoot "Miao.TitleCleaner.psm1") -Force
Import-Module (Join-Path $PSScriptRoot "Miao.Hotkeys.psm1") -Force
Import-Module (Join-Path $PSScriptRoot "Miao.Mission.psm1") -Force
Import-Module (Join-Path $PSScriptRoot "Miao.Routes.psm1") -Force

function Write-MiaoLog {
    param([string]$Message, [string]$Level = "INFO")

    $timestamp = [System.DateTime]::Now.ToString("HH:mm:ss")
    Write-Host "[$timestamp] [$Level] $Message"
}

function New-MiaoContext {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$RootPath,
        [Parameter(Mandatory = $true)][string]$SourcePath,
        [ValidateRange(1024, 65535)][int]$Port
    )

    $schemaPath = Join-Path $RootPath "config\settings.schema.json"
    $playerActionsPath = Join-Path $RootPath "config\player-actions.json"
    $defaultMissionPath = Join-Path $RootPath "config\default-mission.txt"
    $versionPath = Join-Path $RootPath "VERSION"
    $missionPath = Join-Path $RootPath "miao-mission.txt"
    $settingsPath = Join-Path $RootPath "miao-settings.json"

    $requiredFiles = @(
        $schemaPath,
        $playerActionsPath,
        $defaultMissionPath,
        $versionPath,
        (Join-Path $RootPath "public\widget.html"),
        (Join-Path $RootPath "public\control.html"),
        (Join-Path $RootPath "public\css\widget.css"),
        (Join-Path $RootPath "public\css\control.css"),
        (Join-Path $RootPath "public\js\api.js"),
        (Join-Path $RootPath "public\js\widget-core.js"),
        (Join-Path $RootPath "public\js\widget.js"),
        (Join-Path $RootPath "public\js\control.js")
    )

    foreach ($requiredFile in $requiredFiles) {
        if (-not [System.IO.File]::Exists($requiredFile)) {
            throw "Fichier M.I.A.O. manquant : $requiredFile"
        }
    }

    Initialize-MiaoMission `
        -MissionPath $missionPath `
        -DefaultMissionPath $defaultMissionPath

    $schema = Import-MiaoSettingsSchema -Path $schemaPath
    $settings = Read-MiaoSettings -Path $settingsPath -Schema $schema
    $playerActions = Import-MiaoPlayerActions -Path $playerActionsPath
    $version = (Read-MiaoUtf8File -Path $versionPath).Trim()
    if ($version -notmatch '^\d+\.\d+\.\d+$') {
        throw "Version M.I.A.O. invalide : $version"
    }

    $currentSong = ""
    $lastRawSong = $null
    if ([System.IO.File]::Exists($SourcePath)) {
        try {
            $lastRawSong = Read-MiaoUtf8File -Path $SourcePath
            $currentSong = Remove-MiaoTitleSuffix -Title $lastRawSong
        }
        catch {
            $currentSong = ""
            $lastRawSong = $null
        }
    }

    return [pscustomobject]@{
        RootPath = $RootPath
        SourcePath = $SourcePath
        MissionPath = $missionPath
        SettingsPath = $settingsPath
        Schema = $schema
        Settings = $settings
        PlayerActions = $playerActions
        Version = $version
        CurrentSong = $currentSong
        LastRawSong = $lastRawSong
        Port = $Port
    }
}

function Start-MiaoApplication {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$RootPath,
        [Parameter(Mandatory = $true)][string]$SourcePath,
        [ValidateRange(1024, 65535)][int]$Port = 8974
    )

    $context = New-MiaoContext `
        -RootPath $RootPath `
        -SourcePath $SourcePath `
        -Port $Port

    $listener = [System.Net.Sockets.TcpListener]::new(
        [System.Net.IPAddress]::Loopback,
        $Port
    )
    $listener.Start()

    Write-Host ""
    Write-Host "M.I.A.O. est en ligne : http://127.0.0.1:$Port/" -ForegroundColor Cyan
    Write-Host "Console OBS : http://127.0.0.1:$Port/control"
    Write-Host "Laisse cette fenetre ouverte ou reduite pendant le stream."
    Write-Host ""
    Write-MiaoLog -Message "Surveillance Moobot active."

    $nextTitleCheck = [System.DateTime]::UtcNow

    try {
        while ($true) {
            $now = [System.DateTime]::UtcNow
            if ($now -ge $nextTitleCheck) {
                [void](Update-MiaoSongTitle `
                    -State $context `
                    -SourcePath $context.SourcePath)
                $nextTitleCheck = $now.AddMilliseconds(500)
            }

            while ($listener.Pending()) {
                $client = $listener.AcceptTcpClient()
                Invoke-MiaoClient -Client $client -Context $context
            }

            Start-Sleep -Milliseconds 20
        }
    }
    finally {
        $listener.Stop()
    }
}

Export-ModuleMember -Function Start-MiaoApplication
