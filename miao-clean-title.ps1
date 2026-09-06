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
    if ([string]::IsNullOrWhiteSpace($SourcePath)) {
        if ([string]::IsNullOrWhiteSpace($env:APPDATA)) {
            throw "La variable APPDATA est introuvable."
        }

        $moobotFiles = Join-Path $env:APPDATA "moobot-assistant\User files"
        $resolverModule = Join-Path $PSScriptRoot "src\Miao.Moobot.psm1"
        if (-not [System.IO.File]::Exists($resolverModule)) {
            throw "Le module de detection Moobot est introuvable."
        }

        Import-Module $resolverModule -Force
        $resolution = Resolve-MiaoMoobotSource `
            -DirectoryPath $moobotFiles `
            -Channel $Channel
        $SourcePath = $resolution.Path

        if ($resolution.Mode -eq "automatic") {
            Write-Host "Source Moobot detectee : $($resolution.SelectedName)" -ForegroundColor Cyan
            if ($resolution.CandidateCount -gt 1) {
                Write-Host "Plusieurs sources trouvees ; le fichier le plus recent est utilise." -ForegroundColor Yellow
            }
        }
    }

    $SourcePath = [System.IO.Path]::GetFullPath($SourcePath)

    $applicationModule = Join-Path $PSScriptRoot "src\Miao.App.psm1"
    if (-not [System.IO.File]::Exists($applicationModule)) {
        throw "Le module principal de M.I.A.O. est introuvable."
    }

    Import-Module $applicationModule -Force
    Start-MiaoApplication `
        -RootPath $PSScriptRoot `
        -SourcePath $SourcePath `
        -Port $Port
}
catch {
    Write-Host ""
    Write-Host "ERREUR M.I.A.O. : $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Read-Host "Appuie sur Entree pour fermer"
    exit 1
}
