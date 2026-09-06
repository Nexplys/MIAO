#Requires -Version 5.1

[CmdletBinding()]
param(
    [ValidatePattern('^[A-Za-z0-9_]+$')]
    [string]$Channel = "nexplys",

    [ValidateRange(1024, 65535)]
    [int]$Port = 8974,

    [string]$SourcePath = "",

    [string]$CleanPath = ""
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

try {
    $needsDefaultPath = (
        [string]::IsNullOrWhiteSpace($SourcePath) -or
        [string]::IsNullOrWhiteSpace($CleanPath)
    )
    if ($needsDefaultPath) {
        if ([string]::IsNullOrWhiteSpace($env:APPDATA)) {
            throw "La variable APPDATA est introuvable."
        }

        $moobotFiles = Join-Path $env:APPDATA "moobot-assistant\User files"
        if ([string]::IsNullOrWhiteSpace($SourcePath)) {
            $SourcePath = Join-Path $moobotFiles "$Channel.song-player.current.txt"
        }
        if ([string]::IsNullOrWhiteSpace($CleanPath)) {
            $CleanPath = Join-Path $moobotFiles "$Channel.song-player.current.cleaned.txt"
        }
    }

    $SourcePath = [System.IO.Path]::GetFullPath($SourcePath)
    $CleanPath = [System.IO.Path]::GetFullPath($CleanPath)
    if ([string]::Equals(
        $SourcePath,
        $CleanPath,
        [System.StringComparison]::OrdinalIgnoreCase
    )) {
        throw "Le fichier nettoye doit etre different du fichier source Moobot."
    }

    $applicationModule = Join-Path $PSScriptRoot "src\Miao.App.psm1"
    if (-not [System.IO.File]::Exists($applicationModule)) {
        throw "Le module principal de M.I.A.O. est introuvable."
    }

    Import-Module $applicationModule -Force
    Start-MiaoApplication `
        -RootPath $PSScriptRoot `
        -SourcePath $SourcePath `
        -CleanPath $CleanPath `
        -Port $Port
}
catch {
    Write-Host ""
    Write-Host "ERREUR M.I.A.O. : $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Read-Host "Appuie sur Entree pour fermer"
    exit 1
}
