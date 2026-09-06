#Requires -Version 5.1

[CmdletBinding()]
param(
    [string]$ObsPath = ""
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

$cleanerPath = Join-Path $PSScriptRoot "miao-clean-title.ps1"
if ([string]::IsNullOrWhiteSpace($ObsPath)) {
    if ([string]::IsNullOrWhiteSpace($env:ProgramFiles)) {
        throw "La variable ProgramFiles est introuvable."
    }

    $ObsPath = Join-Path $env:ProgramFiles "obs-studio\bin\64bit\obs64.exe"
}
$ObsPath = [System.IO.Path]::GetFullPath($ObsPath)

if (-not (Test-Path $cleanerPath)) {
    Add-Type -AssemblyName PresentationFramework
    [System.Windows.MessageBox]::Show(
        "Le fichier miao-clean-title.ps1 est introuvable.",
        "M.I.A.O."
    )
    exit
}

if (-not (Test-Path $ObsPath)) {
    Add-Type -AssemblyName PresentationFramework
    [System.Windows.MessageBox]::Show(
        "OBS est introuvable a l'adresse :`n$ObsPath",
        "M.I.A.O."
    )
    exit
}

$cleaner = Start-Process powershell.exe `
    -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$cleanerPath`"" `
    -WindowStyle Hidden `
    -PassThru

try {
    $obs = Get-Process "obs64" -ErrorAction SilentlyContinue |
        Select-Object -First 1

    if (-not $obs) {
        $obs = Start-Process $ObsPath `
            -WorkingDirectory (Split-Path $ObsPath) `
            -PassThru
    }

    $obs.WaitForExit()
}
finally {
    if ($cleaner -and -not $cleaner.HasExited) {
        Stop-Process -Id $cleaner.Id -Force
    }
}
