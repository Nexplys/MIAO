Set-StrictMode -Version 2.0

$script:Utf8NoBom = [System.Text.UTF8Encoding]::new($false)

function Receive-MiaoHttpRequest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Net.Sockets.TcpClient]$Client,

        [int]$MaximumBodyLength = 262144
    )

    $reader = $null

    try {
        $stream = $Client.GetStream()
        $stream.ReadTimeout = 3000
        $reader = [System.IO.StreamReader]::new(
            $stream,
            [System.Text.Encoding]::ASCII,
            $false,
            4096,
            $true
        )

        $requestLine = $reader.ReadLine()
        if ([string]::IsNullOrWhiteSpace($requestLine)) {
            throw "Requete HTTP vide."
        }

        $requestParts = $requestLine.Split(' ')
        if ($requestParts.Length -lt 2) {
            throw "Ligne de requete HTTP invalide."
        }

        $headers = @{}
        while ($true) {
            $line = $reader.ReadLine()
            if ([string]::IsNullOrEmpty($line)) {
                break
            }

            $separator = $line.IndexOf(':')
            if ($separator -gt 0) {
                $name = $line.Substring(0, $separator).Trim().ToLowerInvariant()
                $value = $line.Substring($separator + 1).Trim()
                $headers[$name] = $value
            }
        }

        $contentLength = 0
        if ($headers.ContainsKey("content-length")) {
            if (-not [int]::TryParse($headers["content-length"], [ref]$contentLength)) {
                throw "Content-Length invalide."
            }
        }

        if ($contentLength -lt 0 -or $contentLength -gt $MaximumBodyLength) {
            throw "Corps de requete trop volumineux."
        }

        $body = ""
        if ($contentLength -gt 0) {
            $builder = [System.Text.StringBuilder]::new()
            $buffer = [char[]]::new([System.Math]::Min(4096, $contentLength))
            $remaining = $contentLength

            while ($remaining -gt 0) {
                $wanted = [System.Math]::Min($buffer.Length, $remaining)
                $read = $reader.Read($buffer, 0, $wanted)
                if ($read -le 0) {
                    break
                }

                [void]$builder.Append($buffer, 0, $read)
                $remaining -= $read
            }

            if ($remaining -ne 0) {
                throw "Corps de requete incomplet."
            }

            $body = $builder.ToString()
        }

        $target = $requestParts[1]
        $uri = [System.Uri]::new("http://127.0.0.1$target")

        return [pscustomobject]@{
            Method = $requestParts[0].ToUpperInvariant()
            Path = $uri.AbsolutePath
            Headers = $headers
            Body = $body
            Reader = $reader
        }
    }
    catch {
        if ($null -ne $reader) {
            $reader.Dispose()
        }
        throw
    }
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

    $stream = $Client.GetStream()
    $bodyBytes = $script:Utf8NoBom.GetBytes($Body)
    $header = "HTTP/1.1 $StatusCode $StatusText`r`n" +
              "Content-Type: $ContentType`r`n" +
              "Content-Length: $($bodyBytes.Length)`r`n" +
              "Cache-Control: no-store, no-cache, must-revalidate, max-age=0`r`n" +
              "Pragma: no-cache`r`n" +
              "X-Content-Type-Options: nosniff`r`n" +
              "Content-Security-Policy: default-src 'self'; style-src 'self' 'unsafe-inline'; script-src 'self'; connect-src 'self'; img-src 'self' data:`r`n" +
              "Connection: close`r`n`r`n"
    $headerBytes = [System.Text.Encoding]::ASCII.GetBytes($header)

    $stream.Write($headerBytes, 0, $headerBytes.Length)
    if ($bodyBytes.Length -gt 0) {
        $stream.Write($bodyBytes, 0, $bodyBytes.Length)
    }
    $stream.Flush()
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
    Receive-MiaoHttpRequest, `
    Send-MiaoHttpResponse, `
    Send-MiaoJsonResponse, `
    ConvertFrom-MiaoEncodedJson
