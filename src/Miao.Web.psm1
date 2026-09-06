Set-StrictMode -Version 2.0

Import-Module (Join-Path $PSScriptRoot "Miao.Http.psm1") -ErrorAction Stop

function Send-MiaoApiError {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][System.Net.Sockets.TcpClient]$Client,
        [Parameter(Mandatory = $true)][string]$Message,
        [int]$StatusCode = 400,
        [string]$StatusText = "Bad Request"
    )

    Send-MiaoJsonResponse `
        -Client $Client `
        -Value ([ordered]@{ ok = $false; error = $Message }) `
        -StatusCode $StatusCode `
        -StatusText $StatusText
}

function Test-MiaoRequestMethod {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]$Request,
        [Parameter(Mandatory = $true)][string]$Expected,
        [Parameter(Mandatory = $true)][System.Net.Sockets.TcpClient]$Client
    )

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
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]$Request,
        [Parameter(Mandatory = $true)]$ApplicationContext,
        [Parameter(Mandatory = $true)][System.Net.Sockets.TcpClient]$Client
    )

    if ($Request.Method -eq "GET" -or -not $Request.Headers.ContainsKey("origin")) {
        return $true
    }

    $allowedOrigins = @(
        "http://127.0.0.1:$($ApplicationContext.Port)",
        "http://localhost:$($ApplicationContext.Port)"
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

Export-ModuleMember -Function `
    Send-MiaoApiError, `
    Test-MiaoRequestMethod, `
    Test-MiaoMutationOrigin
