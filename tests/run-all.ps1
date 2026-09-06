#Requires -Version 5.1

[CmdletBinding()]
param()

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

$root = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$node = Get-Command "node" -ErrorAction SilentlyContinue
if ($null -eq $node) {
    throw "Node.js est requis pour les tests de contrat JavaScript."
}

& $node.Path (Join-Path $root "tests\contracts.test.js")
if ($LASTEXITCODE -ne 0) {
    throw "Les tests de contrat JavaScript ont echoue."
}

& (Join-Path $root "tests\Miao.Tests.ps1")
Write-Host "OK - Toutes les suites M.I.A.O. sont valides." -ForegroundColor Green
