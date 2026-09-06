Set-StrictMode -Version 2.0

Import-Module (Join-Path $PSScriptRoot "Miao.Files.psm1") -ErrorAction Stop
Import-Module (Join-Path $PSScriptRoot "Miao.Modules.psm1") -ErrorAction Stop
Import-Module (Join-Path $PSScriptRoot "Miao.Routes.psm1") -ErrorAction Stop

function New-MiaoContext {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$RootPath,
        [ValidateRange(1024, 65535)][int]$Port,
        $ModuleOptions = @{}
    )

    $RootPath = [System.IO.Path]::GetFullPath($RootPath)
    $versionPath = Join-Path $RootPath "VERSION"
    $requiredFiles = @(
        $versionPath,
        (Join-Path $RootPath "public\control.html"),
        (Join-Path $RootPath "public\css\control.css"),
        (Join-Path $RootPath "public\js\api.js"),
        (Join-Path $RootPath "public\js\control.js")
    )

    foreach ($requiredFile in $requiredFiles) {
        if (-not [System.IO.File]::Exists($requiredFile)) {
            throw "Fichier M.I.A.O. manquant : $requiredFile"
        }
    }

    $version = (Read-MiaoUtf8File -Path $versionPath).Trim()
    if ($version -notmatch '^\d+\.\d+\.\d+$') {
        throw "Version M.I.A.O. invalide : $version"
    }

    $runtimePath = Join-Path $RootPath "var"
    [void][System.IO.Directory]::CreateDirectory($runtimePath)

    $context = [pscustomobject]@{
        RootPath = $RootPath
        RuntimePath = $runtimePath
        Version = $version
        Port = $Port
        Modules = @()
    }
    $context.Modules = @(
        Import-MiaoApplicationModules `
            -RootPath $RootPath `
            -ApplicationContext $context `
            -Options $ModuleOptions
    )

    if ($context.Modules.Count -eq 0) {
        throw "Aucun module M.I.A.O. actif n'a ete trouve."
    }

    return $context
}

function Start-MiaoApplication {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$RootPath,
        [ValidateRange(1024, 65535)][int]$Port = 8974,
        $ModuleOptions = @{}
    )

    $context = New-MiaoContext `
        -RootPath $RootPath `
        -Port $Port `
        -ModuleOptions $ModuleOptions

    $listener = $null
    try {
        $listener = [System.Net.Sockets.TcpListener]::new(
            [System.Net.IPAddress]::Loopback,
            $Port
        )
        $listener.Start()

        Write-Host ""
        Write-Host "M.I.A.O. est en ligne : http://127.0.0.1:$Port/" -ForegroundColor Cyan
        Write-Host "Console OBS : http://127.0.0.1:$Port/control"
        Write-Host "Modules actifs : $([string]::Join(', ', @($context.Modules.Id)))"
        Write-Host "Laisse cette fenetre ouverte ou reduite pendant le stream."
        Write-Host ""

        while ($true) {
            Update-MiaoApplicationModules -ApplicationContext $context

            while ($listener.Pending()) {
                $client = $listener.AcceptTcpClient()
                Invoke-MiaoClient -Client $client -ApplicationContext $context
            }

            Start-Sleep -Milliseconds 20
        }
    }
    finally {
        if ($null -ne $listener) {
            $listener.Stop()
        }
        Stop-MiaoApplicationModules -ApplicationContext $context
    }
}

Export-ModuleMember -Function Start-MiaoApplication
