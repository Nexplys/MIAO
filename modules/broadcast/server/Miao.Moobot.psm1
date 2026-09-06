Set-StrictMode -Version 2.0

function Resolve-MiaoMoobotSource {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DirectoryPath,

        [AllowEmptyString()]
        [ValidatePattern('^$|^[A-Za-z0-9_]+$')]
        [string]$Channel = ""
    )

    $directory = [System.IO.Path]::GetFullPath($DirectoryPath)

    if (-not [string]::IsNullOrWhiteSpace($Channel)) {
        return [pscustomobject]@{
            Path = Join-Path $directory "$Channel.song-player.current.txt"
            CandidateCount = 0
            SelectedName = "$Channel.song-player.current.txt"
            Mode = "channel"
        }
    }

    if (-not [System.IO.Directory]::Exists($directory)) {
        throw "Le dossier de fichiers Moobot est introuvable : $directory"
    }

    $candidatePaths = @([System.IO.Directory]::GetFiles(
        $directory,
        "*.song-player.current.txt",
        [System.IO.SearchOption]::TopDirectoryOnly
    ))
    if ($candidatePaths.Count -eq 0) {
        throw "Aucun fichier Song Player Moobot n'a ete trouve dans : $directory"
    }

    $candidates = @(
        $candidatePaths |
            ForEach-Object { [System.IO.FileInfo]::new($_) } |
            Sort-Object `
                @{ Expression = { $_.LastWriteTimeUtc }; Descending = $true }, `
                @{ Expression = { $_.Name }; Descending = $false }
    )
    $selected = $candidates[0]

    return [pscustomobject]@{
        Path = $selected.FullName
        CandidateCount = $candidates.Count
        SelectedName = $selected.Name
        Mode = "automatic"
    }
}

Export-ModuleMember -Function Resolve-MiaoMoobotSource
