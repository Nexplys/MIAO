$cleanerPath = Join-Path $PSScriptRoot "miao-clean-title.ps1"
$obsPath = "C:\Program Files\obs-studio\bin\64bit\obs64.exe"

if (-not (Test-Path $cleanerPath)) {
    Add-Type -AssemblyName PresentationFramework
    [System.Windows.MessageBox]::Show(
        "Le fichier miao-clean-title.ps1 est introuvable.",
        "M.I.A.O."
    )
    exit
}

if (-not (Test-Path $obsPath)) {
    Add-Type -AssemblyName PresentationFramework
    [System.Windows.MessageBox]::Show(
        "OBS est introuvable à l'adresse :`n$obsPath",
        "M.I.A.O."
    )
    exit
}

$cleaner = Start-Process powershell.exe `
    -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$cleanerPath`"" `
    -WindowStyle Hidden `
    -PassThru

try {
    $obs = Get-Process "obs64" -ErrorAction SilentlyContinue |
        Select-Object -First 1

    if (-not $obs) {
        $obs = Start-Process $obsPath `
            -WorkingDirectory (Split-Path $obsPath) `
            -PassThru
    }

    $obs.WaitForExit()
}
finally {
    if ($cleaner -and -not $cleaner.HasExited) {
        Stop-Process -Id $cleaner.Id -Force
    }
}