Set-StrictMode -Version 2.0

$script:Utf8NoBom = [System.Text.UTF8Encoding]::new($false)

function Read-MiaoUtf8File {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    return [System.IO.File]::ReadAllText($Path, $script:Utf8NoBom)
}

function Write-MiaoUtf8FileAtomic {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Content
    )

    $directory = [System.IO.Path]::GetDirectoryName($Path)
    if ([string]::IsNullOrWhiteSpace($directory)) {
        $directory = [System.IO.Directory]::GetCurrentDirectory()
        $Path = Join-Path $directory $Path
    }
    if (-not [System.IO.Directory]::Exists($directory)) {
        [void][System.IO.Directory]::CreateDirectory($directory)
    }

    $temporaryName = ".{0}.{1}.{2}.tmp" -f `
        [System.IO.Path]::GetFileName($Path),
        $PID,
        [System.Guid]::NewGuid().ToString("N")
    $temporaryPath = Join-Path $directory $temporaryName

    try {
        [System.IO.File]::WriteAllText($temporaryPath, $Content, $script:Utf8NoBom)

        if ([System.IO.File]::Exists($Path)) {
            try {
                [System.IO.File]::Replace($temporaryPath, $Path, $null)
            }
            catch {
                [System.IO.File]::Copy($temporaryPath, $Path, $true)
                [System.IO.File]::Delete($temporaryPath)
            }
        }
        else {
            [System.IO.File]::Move($temporaryPath, $Path)
        }
    }
    finally {
        if ([System.IO.File]::Exists($temporaryPath)) {
            [System.IO.File]::Delete($temporaryPath)
        }
    }
}

Export-ModuleMember -Function Read-MiaoUtf8File, Write-MiaoUtf8FileAtomic
