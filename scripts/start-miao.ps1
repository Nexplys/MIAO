#Requires -Version 5.1

[CmdletBinding()]
param(
    [AllowEmptyString()]
    [ValidatePattern('^$|^[A-Za-z0-9_]+$')]
    [string]$Channel = "",

    [ValidateRange(1024, 65535)]
    [int]$Port = 8974,

    [string]$SourcePath = ""
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

try {
    $rootPath = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
    $applicationModule = Join-Path $rootPath "src\Miao.App.psm1"
    if (-not [System.IO.File]::Exists($applicationModule)) {
        throw "Le module principal de M.I.A.O. est introuvable."
    }

    Import-Module $applicationModule -Force
    $moduleOptions = @{
        broadcast = @{
            AppDataPath = [string]$env:APPDATA
            Channel = $Channel
            SourcePath = $SourcePath
        }
    }
    Start-MiaoApplication `
        -RootPath $rootPath `
        -Port $Port `
        -ModuleOptions $moduleOptions
}
catch {
    Write-Host ""
    Write-Host "ERREUR M.I.A.O. : $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Read-Host "Appuie sur Entree pour fermer"
    exit 1
}
