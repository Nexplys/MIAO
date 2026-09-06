Set-StrictMode -Version 2.0

Import-Module (Join-Path $PSScriptRoot "Miao.Files.psm1") -Force

function Initialize-MiaoMission {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$MissionPath,
        [Parameter(Mandatory = $true)][string]$DefaultMissionPath
    )

    if ([System.IO.File]::Exists($MissionPath)) {
        return
    }

    $defaultMission = (Read-MiaoUtf8File -Path $DefaultMissionPath).Trim()
    Write-MiaoUtf8FileAtomic -Path $MissionPath -Content $defaultMission
}

function Read-MiaoMission {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Path
    )

    try {
        return (Read-MiaoUtf8File -Path $Path).Trim()
    }
    catch {
        return ""
    }
}

function ConvertTo-MiaoLegacyMission {
    param($Payload)

    $objective = [regex]::Replace([string]$Payload.objective, '[\r\n]+', ' ').Trim()
    $rank = [regex]::Replace([string]$Payload.rank, '[\r\n]+', ' ').Trim()
    if ([string]::IsNullOrWhiteSpace($objective)) { $objective = "LEGENDE" }
    if ([string]::IsNullOrWhiteSpace($rank)) { $rank = "A RENSEIGNER" }

    $wins = 0
    $losses = 0
    [void][int]::TryParse([string]$Payload.wins, [ref]$wins)
    [void][int]::TryParse([string]$Payload.losses, [ref]$losses)
    $wins = [System.Math]::Max(0, [System.Math]::Min(999, $wins))
    $losses = [System.Math]::Max(0, [System.Math]::Min(999, $losses))

    return "M.I.A.O. // RAPPORT DE MISSION`n" +
           "OBJECTIF : $objective`n" +
           "RANG : $rank`n" +
           "BILAN : $wins V / $losses D"
}

function Save-MiaoMissionPayload {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]$Payload,
        [Parameter(Mandatory = $true)][string]$Path
    )

    $textProperty = $Payload.PSObject.Properties["text"]
    if ($null -ne $textProperty) {
        $text = [string]$Payload.text
        $text = $text.Replace("`0", "")
        $text = $text.Replace("`r`n", "`n").Replace("`r", "`n").Trim()
    }
    else {
        $text = ConvertTo-MiaoLegacyMission -Payload $Payload
    }

    if ($text.Length -gt 2000) {
        throw "Transmission trop longue."
    }

    Write-MiaoUtf8FileAtomic -Path $Path -Content $text
    return $text
}

Export-ModuleMember -Function `
    Initialize-MiaoMission, `
    Read-MiaoMission, `
    Save-MiaoMissionPayload
