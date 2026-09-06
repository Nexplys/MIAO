#Requires -Version 5.1

[CmdletBinding()]
param(
    [string]$BaseRef = "HEAD",
    [string]$DestinationPath = "",
    [switch]$SkipTests
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

$root = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$parent = [System.IO.Directory]::GetParent($root).FullName
if ([string]::IsNullOrWhiteSpace($DestinationPath)) {
    $DestinationPath = Join-Path $parent "MIAO-Update.zip"
}
$DestinationPath = [System.IO.Path]::GetFullPath($DestinationPath)

$git = Get-Command "git" -ErrorAction SilentlyContinue
if ($null -eq $git) {
    throw "Git est requis pour construire une mise a jour differentielle."
}

if (-not $SkipTests) {
    & (Join-Path $root "tests\run-all.ps1")
}

$includePaths = [System.Collections.Generic.HashSet[string]]::new(
    [System.StringComparer]::OrdinalIgnoreCase
)
$deletePaths = [System.Collections.Generic.HashSet[string]]::new(
    [System.StringComparer]::OrdinalIgnoreCase
)

$changeLines = @(
    & $git.Path -C $root diff --name-status --find-renames $BaseRef --
)
if ($LASTEXITCODE -ne 0) {
    throw "Impossible de comparer le projet avec la reference Git '$BaseRef'."
}

foreach ($line in $changeLines) {
    if ([string]::IsNullOrWhiteSpace($line)) {
        continue
    }

    $parts = @($line -split "`t")
    $status = $parts[0]
    if ($status -match '^R') {
        if ($parts.Count -ne 3) {
            throw "Renommage Git illisible : $line"
        }
        [void]$deletePaths.Add($parts[1])
        [void]$includePaths.Add($parts[2])
    }
    elseif ($status -match '^C') {
        if ($parts.Count -ne 3) {
            throw "Copie Git illisible : $line"
        }
        [void]$includePaths.Add($parts[2])
    }
    elseif ($status -eq "D") {
        [void]$deletePaths.Add($parts[1])
    }
    elseif ($status -match '^[AMT]$') {
        [void]$includePaths.Add($parts[1])
    }
    else {
        throw "Etat Git non pris en charge : $line"
    }
}

$untrackedPaths = @(
    & $git.Path -C $root ls-files --others --exclude-standard
)
if ($LASTEXITCODE -ne 0) {
    throw "Impossible de lister les nouveaux fichiers Git."
}
foreach ($relativePath in $untrackedPaths) {
    if (-not [string]::IsNullOrWhiteSpace($relativePath)) {
        [void]$includePaths.Add($relativePath)
    }
}

# Rename detection is heuristic. A path can be reused by a new file in the same
# update (for example the shared control host), so an included path must never
# also appear in the deletion manifest.
foreach ($relativePath in @($includePaths)) {
    [void]$deletePaths.Remove($relativePath)
}

if ($includePaths.Count -eq 0 -and $deletePaths.Count -eq 0) {
    throw "Aucun changement a empaqueter depuis '$BaseRef'."
}

$temporaryRoot = Join-Path `
    ([System.IO.Path]::GetTempPath()) `
    ("miao-update-" + [System.Guid]::NewGuid().ToString("N"))
$payloadRoot = Join-Path $temporaryRoot "payload"
$destinationDirectory = [System.IO.Path]::GetDirectoryName($DestinationPath)
$destinationBaseName = [System.IO.Path]::GetFileNameWithoutExtension($DestinationPath)
$deletionManifestPath = Join-Path `
    $destinationDirectory `
    "$destinationBaseName-files-to-delete.txt"

try {
    [void][System.IO.Directory]::CreateDirectory($payloadRoot)
    foreach ($relativePath in @($includePaths | Sort-Object)) {
        if ([System.IO.Path]::IsPathRooted($relativePath) -or
            $relativePath -match '(^|[\\/])\.\.([\\/]|$)') {
            throw "Chemin Git dangereux refuse : $relativePath"
        }

        $source = Join-Path $root $relativePath
        if (-not [System.IO.File]::Exists($source)) {
            throw "Fichier modifie introuvable : $relativePath"
        }
        $target = Join-Path $payloadRoot $relativePath
        $targetDirectory = [System.IO.Path]::GetDirectoryName($target)
        if (-not [System.IO.Directory]::Exists($targetDirectory)) {
            [void][System.IO.Directory]::CreateDirectory($targetDirectory)
        }
        Copy-Item -LiteralPath $source -Destination $target -Force
    }

    if (-not [System.IO.Directory]::Exists($destinationDirectory)) {
        [void][System.IO.Directory]::CreateDirectory($destinationDirectory)
    }
    if ([System.IO.File]::Exists($DestinationPath)) {
        [System.IO.File]::Delete($DestinationPath)
    }

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::CreateFromDirectory(
        $payloadRoot,
        $DestinationPath,
        [System.IO.Compression.CompressionLevel]::Optimal,
        $false
    )

    if ($deletePaths.Count -gt 0) {
        $deletionLines = @(
            "Fichiers devenus obsoletes dans cette mise a jour :",
            ""
        ) + @($deletePaths | Sort-Object)
        $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
        [System.IO.File]::WriteAllLines(
            $deletionManifestPath,
            [string[]]$deletionLines,
            $utf8NoBom
        )
        Write-Host "Suppressions a appliquer : $deletionManifestPath" -ForegroundColor Yellow
    }
    elseif ([System.IO.File]::Exists($deletionManifestPath)) {
        [System.IO.File]::Delete($deletionManifestPath)
    }

    Write-Host `
        "Mise a jour creee : $DestinationPath ($($includePaths.Count) fichiers)" `
        -ForegroundColor Green
}
finally {
    if ([System.IO.Directory]::Exists($temporaryRoot)) {
        [System.IO.Directory]::Delete($temporaryRoot, $true)
    }
}
