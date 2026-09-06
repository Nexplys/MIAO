Set-StrictMode -Version 2.0

$script:Utf8NoBom = [System.Text.UTF8Encoding]::new($false)
$script:Connections = @{}

function New-MiaoHttpConnection {
    param([Parameter(Mandatory = $true)][System.Net.Sockets.TcpClient]$Client)

    $connection = [pscustomobject]@{
        Client = $Client
        Stream = $Client.GetStream()
        Buffer = [byte[]]::new(16384)
        Input = [System.IO.MemoryStream]::new()
        ReadOperation = $null
        WriteOperation = $null
        Output = $null
        HeaderLength = -1
        ContentLength = 0
        Request = $null
        Phase = "reading"
        DeadlineUtc = [System.DateTime]::UtcNow.AddSeconds(3)
    }
    $script:Connections[$Client] = $connection
    return $connection
}

function Close-MiaoHttpConnection {
    param([Parameter(Mandatory = $true)]$Connection)

    $Connection.Client.Close()
    # Closing the socket completes any outstanding asynchronous operation.
    foreach ($kind in @("Read", "Write")) {
        $operation = $Connection."$($kind)Operation"
        if ($null -ne $operation) {
            try {
                if ($kind -eq "Read") { [void]$Connection.Stream.EndRead($operation) }
                else { $Connection.Stream.EndWrite($operation) }
            }
            catch { }
            $Connection."$($kind)Operation" = $null
        }
    }
    $Connection.Input.Dispose()
    $Connection.Output = $null
    $Connection.Phase = "closed"
    [void]$script:Connections.Remove($Connection.Client)
}

function Complete-MiaoHttpResponse {
    param([Parameter(Mandatory = $true)]$Connection)

    if ($null -eq $Connection.WriteOperation -or
        -not $Connection.WriteOperation.IsCompleted) {
        return $false
    }
    $operation = $Connection.WriteOperation
    $Connection.WriteOperation = $null
    $Connection.Stream.EndWrite($operation)
    return $true
}

function Receive-MiaoHttpRequest {
    param(
        [Parameter(Mandatory = $true)]$Connection,
        [int]$MaximumBodyLength = 262144,
        [int]$MaximumHeaderLength = 16384
    )

    if ($null -eq $Connection.ReadOperation) {
        $Connection.ReadOperation = $Connection.Stream.BeginRead(
            $Connection.Buffer, 0, $Connection.Buffer.Length, $null, $null
        )
        return $null
    }
    if (-not $Connection.ReadOperation.IsCompleted) { return $null }

    $operation = $Connection.ReadOperation
    $Connection.ReadOperation = $null
    $count = $Connection.Stream.EndRead($operation)
    if ($count -eq 0) { throw "Connexion fermee avant la fin de la requete." }
    $Connection.Input.Write($Connection.Buffer, 0, $count)

    if ($Connection.HeaderLength -lt 0) {
        $bytes = $Connection.Input.GetBuffer()
        $start = [System.Math]::Max(0, [int]$Connection.Input.Length - $count - 3)
        for ($i = $start; $i -le $Connection.Input.Length - 4; $i++) {
            if ($bytes[$i] -eq 13 -and $bytes[$i + 1] -eq 10 -and
                $bytes[$i + 2] -eq 13 -and $bytes[$i + 3] -eq 10) {
                $Connection.HeaderLength = $i + 4
                break
            }
        }
        if ($Connection.HeaderLength -gt $MaximumHeaderLength -or
            ($Connection.HeaderLength -lt 0 -and
             $Connection.Input.Length -ge $MaximumHeaderLength)) {
            throw "En-tetes HTTP trop volumineux."
        }
        if ($Connection.HeaderLength -lt 0) { return $null }

        $headerText = [System.Text.Encoding]::ASCII.GetString(
            $bytes, 0, $Connection.HeaderLength - 4
        )
        $lines = $headerText -split "\r\n"
        $parts = $lines[0] -split " "
        if ($parts.Count -ne 3 -or $parts[0] -cnotmatch '^[A-Z]+$' -or
            $parts[1] -notmatch '^/[^#\s]*$' -or
            $parts[2] -notmatch '^HTTP/1\.[01]$') {
            throw "Ligne de requete HTTP invalide."
        }
        $headers = @{}
        foreach ($line in @($lines | Select-Object -Skip 1)) {
            $separator = $line.IndexOf(':')
            if ($separator -le 0) { throw "En-tete HTTP invalide." }
            $name = $line.Substring(0, $separator).ToLowerInvariant()
            if ($name -notmatch '^[a-z0-9!#$%&''*+.^_|~-]+$' -or
                $headers.ContainsKey($name)) {
                throw "En-tete HTTP invalide ou duplique."
            }
            $headers[$name] = $line.Substring($separator + 1).Trim()
        }
        if ($headers.ContainsKey("transfer-encoding")) {
            throw "Transfer-Encoding non pris en charge."
        }
        $length = 0
        if ($headers.ContainsKey("content-length")) {
            if ($headers["content-length"] -notmatch '^\d+$' -or
                -not [int]::TryParse($headers["content-length"], [ref]$length)) {
                throw "Content-Length invalide."
            }
        }
        if ($length -gt $MaximumBodyLength) { throw "Corps de requete trop volumineux." }
        $Connection.ContentLength = $length
        $uri = [System.Uri]::new("http://127.0.0.1$($parts[1])")
        $Connection.Request = [pscustomobject]@{
            Method = $parts[0]
            Path = $uri.AbsolutePath
            Headers = $headers
            Body = ""
        }
    }

    $expectedLength = $Connection.HeaderLength + $Connection.ContentLength
    if ($Connection.Input.Length -gt $expectedLength) {
        throw "Donnees inattendues apres la requete."
    }
    if ($Connection.Input.Length -lt $expectedLength) { return $null }

    $Connection.Request.Body = $script:Utf8NoBom.GetString(
        $Connection.Input.GetBuffer(), $Connection.HeaderLength, $Connection.ContentLength
    )
    return $Connection.Request
}

function Send-MiaoBytesResponse {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][System.Net.Sockets.TcpClient]$Client,
        [Parameter(Mandatory = $true)][int]$StatusCode,
        [Parameter(Mandatory = $true)][string]$StatusText,
        [Parameter(Mandatory = $true)][string]$ContentType,
        [AllowEmptyCollection()][byte[]]$BodyBytes = @()
    )

    $stream = $Client.GetStream()
    $header = "HTTP/1.1 $StatusCode $StatusText`r`n" +
              "Content-Type: $ContentType`r`n" +
              "Content-Length: $($BodyBytes.Length)`r`n" +
              "Cache-Control: no-store, no-cache, must-revalidate, max-age=0`r`n" +
              "Pragma: no-cache`r`n" +
              "X-Content-Type-Options: nosniff`r`n" +
              "Content-Security-Policy: default-src 'self'; style-src 'self' 'unsafe-inline'; script-src 'self'; connect-src 'self'; img-src 'self' data:`r`n" +
              "Connection: close`r`n`r`n"
    $headerBytes = [System.Text.Encoding]::ASCII.GetBytes($header)

    if (-not $script:Connections.ContainsKey($Client)) {
        throw "Connexion HTTP non enregistree."
    }
    $connection = $script:Connections[$Client]
    if ($connection.Phase -eq "writing") { throw "Reponse HTTP deja envoyee." }
    $connection.Output = [byte[]]::new($headerBytes.Length + $BodyBytes.Length)
    [System.Buffer]::BlockCopy($headerBytes, 0, $connection.Output, 0, $headerBytes.Length)
    [System.Buffer]::BlockCopy($BodyBytes, 0, $connection.Output, $headerBytes.Length, $BodyBytes.Length)
    $connection.Phase = "writing"
    $connection.DeadlineUtc = [System.DateTime]::UtcNow.AddSeconds(3)
    $connection.WriteOperation = $stream.BeginWrite(
        $connection.Output, 0, $connection.Output.Length, $null, $null
    )
}

function Send-MiaoHttpResponse {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][System.Net.Sockets.TcpClient]$Client,
        [Parameter(Mandatory = $true)][int]$StatusCode,
        [Parameter(Mandatory = $true)][string]$StatusText,
        [Parameter(Mandatory = $true)][string]$ContentType,
        [AllowEmptyString()][string]$Body = ""
    )

    Send-MiaoBytesResponse `
        -Client $Client `
        -StatusCode $StatusCode `
        -StatusText $StatusText `
        -ContentType $ContentType `
        -BodyBytes ($script:Utf8NoBom.GetBytes($Body))
}

function Send-MiaoFileResponse {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][System.Net.Sockets.TcpClient]$Client,
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$ContentType
    )

    $bytes = [System.IO.File]::ReadAllBytes($Path)
    Send-MiaoBytesResponse `
        -Client $Client `
        -StatusCode 200 `
        -StatusText "OK" `
        -ContentType $ContentType `
        -BodyBytes $bytes
}

function Send-MiaoJsonResponse {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][System.Net.Sockets.TcpClient]$Client,
        [Parameter(Mandatory = $true)]$Value,
        [int]$StatusCode = 200,
        [string]$StatusText = "OK"
    )

    $json = $Value | ConvertTo-Json -Depth 12 -Compress
    Send-MiaoHttpResponse `
        -Client $Client `
        -StatusCode $StatusCode `
        -StatusText $StatusText `
        -ContentType "application/json; charset=utf-8" `
        -Body $json
}

function ConvertFrom-MiaoEncodedJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Body
    )

    $bytes = [System.Convert]::FromBase64String($Body.Trim())
    $json = $script:Utf8NoBom.GetString($bytes)
    return $json | ConvertFrom-Json
}

Export-ModuleMember -Function `
    New-MiaoHttpConnection, `
    Close-MiaoHttpConnection, `
    Complete-MiaoHttpResponse, `
    Receive-MiaoHttpRequest, `
    Send-MiaoBytesResponse, `
    Send-MiaoHttpResponse, `
    Send-MiaoFileResponse, `
    Send-MiaoJsonResponse, `
    ConvertFrom-MiaoEncodedJson
