#Requires -Version 5.1

[CmdletBinding()]
param(
    [string]$DestinationPath = ""
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

$root = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$parent = [System.IO.Directory]::GetParent($root).FullName
if ([string]::IsNullOrWhiteSpace($DestinationPath)) {
    $DestinationPath = Join-Path $parent "MIAO-Widget-OBS.zip"
}
$DestinationPath = [System.IO.Path]::GetFullPath($DestinationPath)

$temporaryRoot = Join-Path `
    ([System.IO.Path]::GetTempPath()) `
    ("miao-release-" + [System.Guid]::NewGuid().ToString("N"))
$packageRoot = Join-Path $temporaryRoot "MIAO-Widget"

$releaseEntries = @(
    ".gitignore",
    "CHANGELOG.md",
    "INSTALLATION-MIAO.md",
    "Lancer MIAO.bat",
    "README.md",
    "VERSION",
    "miao-clean-title.ps1",
    "miao-launch-stream.ps1",
    "config",
    "docs",
    "public",
    "src",
    "tests",
    "tools"
)

try {
    & (Join-Path $root "tests\run-all.ps1")

    [void][System.IO.Directory]::CreateDirectory($packageRoot)
    foreach ($entry in $releaseEntries) {
        $source = Join-Path $root $entry
        if (-not (Test-Path -LiteralPath $source)) {
            throw "Element de distribution manquant : $entry"
        }
        Copy-Item `
            -LiteralPath $source `
            -Destination $packageRoot `
            -Recurse `
            -Force
    }

    if (Test-Path -LiteralPath $DestinationPath) {
        Remove-Item -LiteralPath $DestinationPath -Force
    }
    Compress-Archive `
        -LiteralPath $packageRoot `
        -DestinationPath $DestinationPath `
        -CompressionLevel Optimal

    Write-Host "Archive creee : $DestinationPath" -ForegroundColor Green
}
finally {
    if ([System.IO.Directory]::Exists($temporaryRoot)) {
        [System.IO.Directory]::Delete($temporaryRoot, $true)
    }
}
