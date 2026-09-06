Set-StrictMode -Version 2.0

Import-Module (Join-Path $PSScriptRoot "Miao.Http.psm1") -ErrorAction Stop
Import-Module (Join-Path $PSScriptRoot "Miao.Modules.psm1") -ErrorAction Stop
Import-Module (Join-Path $PSScriptRoot "Miao.Web.psm1") -ErrorAction Stop

function Get-MiaoCoreStaticRoute {
    param([string]$Path, [string]$RootPath)

    $routes = @{
        "/control" = @("public\control.html", "text/html; charset=utf-8")
        "/miao-control.html" = @("public\control.html", "text/html; charset=utf-8")
        "/assets/control.css" = @("public\css\control.css", "text/css; charset=utf-8")
        "/assets/api.js" = @("public\js\api.js", "text/javascript; charset=utf-8")
        "/assets/control.js" = @("public\js\control.js", "text/javascript; charset=utf-8")
    }

    if (-not $routes.ContainsKey($Path)) {
        return $null
    }

    return [pscustomobject]@{
        FilePath = Join-Path $RootPath $routes[$Path][0]
        ContentType = $routes[$Path][1]
    }
}

function Invoke-MiaoRoute {
    param(
        $Request,
        $ApplicationContext,
        [System.Net.Sockets.TcpClient]$Client
    )

    if (-not (Test-MiaoMutationOrigin `
        -Request $Request `
        -ApplicationContext $ApplicationContext `
        -Client $Client)) {
        return
    }

    $staticRoute = Get-MiaoCoreStaticRoute `
        -Path $Request.Path `
        -RootPath $ApplicationContext.RootPath
    if ($null -eq $staticRoute) {
        $staticRoute = Resolve-MiaoModuleStaticRoute `
            -RequestPath $Request.Path `
            -Modules $ApplicationContext.Modules
    }
    if ($null -ne $staticRoute) {
        if (-not (Test-MiaoRequestMethod `
            -Request $Request `
            -Expected "GET" `
            -Client $Client)) {
            return
        }
        Send-MiaoFileResponse `
            -Client $Client `
            -Path $staticRoute.FilePath `
            -ContentType $staticRoute.ContentType
        return
    }

    switch ($Request.Path) {
        "/api/modules" {
            if (-not (Test-MiaoRequestMethod -Request $Request -Expected "GET" -Client $Client)) { return }
            Send-MiaoJsonResponse -Client $Client -Value ([ordered]@{
                ok = $true
                modules = @(
                    Get-MiaoClientModuleDescriptors `
                        -Modules $ApplicationContext.Modules
                )
            })
            return
        }
        "/health" {
            if (-not (Test-MiaoRequestMethod -Request $Request -Expected "GET" -Client $Client)) { return }
            Send-MiaoJsonResponse -Client $Client -Value ([ordered]@{
                ok = $true
                service = "MIAO"
                version = $ApplicationContext.Version
                modules = @($ApplicationContext.Modules.Id)
            })
            return
        }
        "/favicon.ico" {
            if (-not (Test-MiaoRequestMethod -Request $Request -Expected "GET" -Client $Client)) { return }
            Send-MiaoHttpResponse `
                -Client $Client `
                -StatusCode 204 `
                -StatusText "No Content" `
                -ContentType "image/x-icon" `
                -Body ""
            return
        }
    }

    if (Invoke-MiaoApplicationModuleRoute `
        -Request $Request `
        -ApplicationContext $ApplicationContext `
        -Client $Client) {
        return
    }

    Send-MiaoHttpResponse `
        -Client $Client `
        -StatusCode 404 `
        -StatusText "Not Found" `
        -ContentType "text/plain; charset=utf-8" `
        -Body "Introuvable."
}

function Invoke-MiaoClient {
    param(
        $Client,
        $ApplicationContext
    )

    $request = $null
    try {
        $request = Receive-MiaoHttpRequest -Client $Client
        Invoke-MiaoRoute `
            -Request $request `
            -ApplicationContext $ApplicationContext `
            -Client $Client
    }
    catch {
        $timestamp = [System.DateTime]::Now.ToString("HH:mm:ss")
        Write-Host "[$timestamp] [HTTP] $($_.Exception.Message)"
        try {
            Send-MiaoApiError `
                -Client $Client `
                -Message $_.Exception.Message `
                -StatusCode 400 `
                -StatusText "Bad Request"
        }
        catch {
            # The browser may already have closed the connection.
        }
    }
    finally {
        if ($null -ne $request -and $null -ne $request.Reader) {
            $request.Reader.Dispose()
        }
        $Client.Close()
    }
}

Export-ModuleMember -Function Invoke-MiaoClient
