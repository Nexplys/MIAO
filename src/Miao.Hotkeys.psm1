Set-StrictMode -Version 2.0

Import-Module (Join-Path $PSScriptRoot "Miao.Files.psm1") -ErrorAction Stop

function Import-MiaoPlayerActions {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $configuration = Read-MiaoUtf8File -Path $Path | ConvertFrom-Json
    if ($null -eq $configuration -or $null -eq $configuration.actions) {
        throw "La configuration des raccourcis est invalide."
    }

    return $configuration
}

function Initialize-MiaoKeyboardType {
    if ("MiaoKeyboard" -as [type]) {
        return
    }

    Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
using System.Threading;

public static class MiaoKeyboard
{
    [DllImport("user32.dll")]
    private static extern void keybd_event(byte key, byte scan, uint flags, UIntPtr extra);

    private const uint KeyUp = 0x0002;
    private const byte Control = 0x11;
    private const byte Alt = 0x12;
    private const byte Shift = 0x10;

    private static void Down(byte key) { keybd_event(key, 0, 0, UIntPtr.Zero); }
    private static void Up(byte key) { keybd_event(key, 0, KeyUp, UIntPtr.Zero); }

    public static void SendCtrlAltShift(byte key)
    {
        Down(Control);
        Down(Alt);
        Down(Shift);
        Down(key);
        Thread.Sleep(35);
        Up(key);
        Up(Shift);
        Up(Alt);
        Up(Control);
    }
}
"@
}

function Invoke-MiaoPlayerAction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$ActionId,
        [Parameter(Mandatory = $true)]$Configuration
    )

    $action = $Configuration.actions |
        Where-Object { [string]$_.id -eq $ActionId } |
        Select-Object -First 1

    if ($null -eq $action) {
        throw "Action Moobot inconnue."
    }

    $key = [string]$action.key
    if ($key -notmatch '^[0-9]$') {
        throw "Raccourci Moobot invalide."
    }

    Initialize-MiaoKeyboardType
    [byte]$virtualKey = [int][char]$key
    [MiaoKeyboard]::SendCtrlAltShift($virtualKey)
    return $action
}

Export-ModuleMember -Function Import-MiaoPlayerActions, Invoke-MiaoPlayerAction
