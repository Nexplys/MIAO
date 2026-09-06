Set-StrictMode -Version 2.0

Import-Module (Join-Path $PSScriptRoot "Miao.Files.psm1") -ErrorAction Stop
Import-Module (Join-Path $PSScriptRoot "Miao.Settings.psm1") -ErrorAction Stop
Import-Module (Join-Path $PSScriptRoot "Miao.Mission.psm1") -ErrorAction Stop
Import-Module (Join-Path $PSScriptRoot "Miao.Hotkeys.psm1") -ErrorAction Stop
Import-Module (Join-Path $PSScriptRoot "Miao.Http.psm1") -ErrorAction Stop

function Get-MiaoStaticRoute {
    param([string]$Path, [string]$RootPath)

    $routes = @{
        "/" = @("public\widget.html", "text/html; charset=utf-8")
        "/miao-widget.html" = @("public\widget.html", "text/html; charset=utf-8")
        "/control" = @("public\control.html", "text/html; charset=utf-8")
        "/miao-control.html" = @("public\control.html", "text/html; charset=utf-8")
        "/assets/widget.css" = @("public\css\widget.css", "text/css; charset=utf-8")
        "/assets/control.css" = @("public\css\control.css", "text/css; charset=utf-8")
        "/assets/api.js" = @("public\js\api.js", "text/javascript; charset=utf-8")
        "/assets/widget-core.js" = @("public\js\widget-core.js", "text/javascript; charset=utf-8")
        "/assets/widget.js" = @("public\js\widget.js", "text/javascript; charset=utf-8")
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

function Send-MiaoApiError {
    param(
        [System.Net.Sockets.TcpClient]$Client,
        [string]$Message,
        [int]$StatusCode = 400,
        [string]$StatusText = "Bad Request"
    )

    Send-MiaoJsonResponse `
        -Client $Client `
        -Value ([ordered]@{ ok = $false; error = $Message }) `
        -StatusCode $StatusCode `
        -StatusText $StatusText
}

function Test-MiaoMethod {
    param($Request, [string]$Expected, [System.Net.Sockets.TcpClient]$Client)

    if ($Request.Method -eq $Expected) {
        return $true
    }

    Send-MiaoApiError `
        -Client $Client `
        -Message "Methode HTTP non autorisee." `
        -StatusCode 405 `
        -StatusText "Method Not Allowed"
    return $false
}

function Test-MiaoMutationOrigin {
    param($Request, $Context, [System.Net.Sockets.TcpClient]$Client)

    if ($Request.Method -eq "GET" -or -not $Request.Headers.ContainsKey("origin")) {
        return $true
    }

    $allowedOrigins = @(
        "http://127.0.0.1:$($Context.Port)",
        "http://localhost:$($Context.Port)"
    )
    if ($allowedOrigins -contains [string]$Request.Headers["origin"]) {
        return $true
    }

    Send-MiaoApiError `
        -Client $Client `
        -Message "Origine HTTP refusee." `
        -StatusCode 403 `
        -StatusText "Forbidden"
    return $false
}

function Invoke-MiaoRoute {
    param($Request, $Context, [System.Net.Sockets.TcpClient]$Client)

    if (-not (Test-MiaoMutationOrigin -Request $Request -Context $Context -Client $Client)) {
        return
    }

    $staticRoute = Get-MiaoStaticRoute -Path $Request.Path -RootPath $Context.RootPath
    if ($null -ne $staticRoute) {
        if (-not (Test-MiaoMethod -Request $Request -Expected "GET" -Client $Client)) { return }
        $content = Read-MiaoUtf8File -Path $staticRoute.FilePath
        Send-MiaoHttpResponse -Client $Client -StatusCode 200 -StatusText "OK" -ContentType $staticRoute.ContentType -Body $content
        return
    }

    switch ($Request.Path) {
        "/api/state" {
            if (-not (Test-MiaoMethod -Request $Request -Expected "GET" -Client $Client)) { return }
            Send-MiaoJsonResponse -Client $Client -Value ([ordered]@{
                ok = $true
                song = $Context.CurrentSong
                mission = (Read-MiaoMission -Path $Context.MissionPath)
                settings = $Context.Settings
            })
        }
        "/api/song" {
            if (-not (Test-MiaoMethod -Request $Request -Expected "GET" -Client $Client)) { return }
            Send-MiaoJsonResponse -Client $Client -Value ([ordered]@{ ok = $true; song = $Context.CurrentSong })
        }
        "/api/schema" {
            if (-not (Test-MiaoMethod -Request $Request -Expected "GET" -Client $Client)) { return }
            Send-MiaoJsonResponse -Client $Client -Value ([ordered]@{ ok = $true; schema = $Context.Schema })
        }
        "/api/player/actions" {
            if (-not (Test-MiaoMethod -Request $Request -Expected "GET" -Client $Client)) { return }
            Send-MiaoJsonResponse -Client $Client -Value ([ordered]@{ ok = $true; configuration = $Context.PlayerActions })
        }
        "/api/mission" {
            if (-not (Test-MiaoMethod -Request $Request -Expected "POST" -Client $Client)) { return }
            $payload = ConvertFrom-MiaoEncodedJson -Body $Request.Body
            $mission = Save-MiaoMissionPayload -Payload $payload -Path $Context.MissionPath
            Send-MiaoJsonResponse -Client $Client -Value ([ordered]@{ ok = $true; mission = $mission })
        }
        "/api/settings" {
            if (-not (Test-MiaoMethod -Request $Request -Expected "POST" -Client $Client)) { return }
            $payload = ConvertFrom-MiaoEncodedJson -Body $Request.Body
            $settings = ConvertTo-MiaoSettings -InputObject $payload -Schema $Context.Schema
            Save-MiaoSettings -Settings $settings -Path $Context.SettingsPath
            $Context.Settings = $settings
            Send-MiaoJsonResponse -Client $Client -Value ([ordered]@{ ok = $true; settings = $settings })
        }
        "/api/settings/reset" {
            if (-not (Test-MiaoMethod -Request $Request -Expected "POST" -Client $Client)) { return }
            $settings = Get-MiaoDefaultSettings -Schema $Context.Schema
            Save-MiaoSettings -Settings $settings -Path $Context.SettingsPath
            $Context.Settings = $settings
            Send-MiaoJsonResponse -Client $Client -Value ([ordered]@{ ok = $true; settings = $settings })
        }
        "/api/player" {
            if (-not (Test-MiaoMethod -Request $Request -Expected "POST" -Client $Client)) { return }
            $payload = ConvertFrom-MiaoEncodedJson -Body $Request.Body
            $action = Invoke-MiaoPlayerAction -ActionId ([string]$payload.action) -Configuration $Context.PlayerActions
            Send-MiaoJsonResponse -Client $Client -Value ([ordered]@{ ok = $true; action = $action.id; message = $action.message })
        }
        "/health" {
            if (-not (Test-MiaoMethod -Request $Request -Expected "GET" -Client $Client)) { return }
            Send-MiaoJsonResponse -Client $Client -Value ([ordered]@{
                ok = $true
                service = "MIAO"
                version = $Context.Version
            })
        }
        "/favicon.ico" {
            if (-not (Test-MiaoMethod -Request $Request -Expected "GET" -Client $Client)) { return }
            Send-MiaoHttpResponse -Client $Client -StatusCode 204 -StatusText "No Content" -ContentType "image/x-icon" -Body ""
        }
        default {
            Send-MiaoHttpResponse -Client $Client -StatusCode 404 -StatusText "Not Found" -ContentType "text/plain; charset=utf-8" -Body "Introuvable."
        }
    }
}

function Invoke-MiaoClient {
    param($Client, $Context)

    $request = $null
    try {
        $request = Receive-MiaoHttpRequest -Client $Client
        Invoke-MiaoRoute -Request $request -Context $Context -Client $Client
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
