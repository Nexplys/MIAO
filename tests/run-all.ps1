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
& (Join-Path $root "tests\Tunic.Tests.ps1")
foreach ($suite in @("dock.test.js", "tunic.test.js", "http.integration.test.js")) {
    & $node.Path (Join-Path $root "tests\$suite")
    if ($LASTEXITCODE -ne 0) { throw "La suite $suite a echoue." }
}
Write-Host "OK - Toutes les suites M.I.A.O. sont valides." -ForegroundColor Green
