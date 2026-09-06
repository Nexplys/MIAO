Set-StrictMode -Version 2.0

$corePath = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\..\..\src"))
Import-Module (Join-Path $corePath "Miao.Files.psm1") -ErrorAction Stop

$script:CleanupPatterns = @(
    '(?i)\s*(?:[-\u2013\u2014|]\s*)?(?:\(|\[|\uFF08|\u3010)\s*official\s+music\s+video(?:\s+(?:HD|4K|1080p))?\s*(?:\)|\]|\uFF09|\u3011)\s*$',
    '(?i)\s*(?:[-\u2013\u2014|]\s*)?[\[(]\s*(?:(?:official\s+)?(?:music\s+)?video|(?:official\s+)?lyrics?(?:\s+video)?|(?:official\s+)?audio|(?:official\s+)?visuali[sz]er|HD|4K|1080p)\s*[\])]\s*$'
)

function Remove-MiaoTitleSuffix {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [string]$Title
    )

    $cleaned = ([string]$Title).Trim()

    do {
        $previous = $cleaned
        foreach ($pattern in $script:CleanupPatterns) {
            $cleaned = [regex]::Replace($cleaned, $pattern, "").TrimEnd()
        }
    }
    while ($cleaned -ne $previous)

    return $cleaned
}

function Update-MiaoSongTitle {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]$State,
        [Parameter(Mandatory = $true)][string]$SourcePath
    )

    try {
        if (-not [System.IO.File]::Exists($SourcePath)) {
            return $false
        }

        $raw = Read-MiaoUtf8File -Path $SourcePath
        if ($raw -eq $State.LastRawSong) {
            return $false
        }

        $cleaned = Remove-MiaoTitleSuffix -Title $raw
        $State.LastRawSong = $raw
        $State.CurrentSong = $cleaned
        return $true
    }
    catch {
        # Moobot can briefly lock its file while updating it.
        return $false
    }
}

Export-ModuleMember -Function Remove-MiaoTitleSuffix, Update-MiaoSongTitle
