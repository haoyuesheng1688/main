param(
    [int]$ClickX = -1,
    [int]$ClickY = -1,
    [ValidateSet('left','right')]
    [string]$Button = 'left',
    [switch]$DoubleClick,
    [string]$Keys = '',
    [int]$PreDelayMs = 500,
    [int]$PostDelayMs = 500
)

$ErrorActionPreference = 'Stop'

Start-Sleep -Milliseconds $PreDelayMs

Add-Type -AssemblyName System.Windows.Forms
Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class Win32Input {
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int X, int Y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint dwFlags, uint dx, uint dy, uint dwData, UIntPtr dwExtraInfo);
  public const uint MOUSEEVENTF_LEFTDOWN = 0x0002;
  public const uint MOUSEEVENTF_LEFTUP = 0x0004;
  public const uint MOUSEEVENTF_RIGHTDOWN = 0x0008;
  public const uint MOUSEEVENTF_RIGHTUP = 0x0010;
}
"@

function Invoke-MouseClick {
    param([string]$WhichButton)

    if ($WhichButton -eq 'right') {
        [Win32Input]::mouse_event([Win32Input]::MOUSEEVENTF_RIGHTDOWN, 0, 0, 0, [UIntPtr]::Zero)
        Start-Sleep -Milliseconds 50
        [Win32Input]::mouse_event([Win32Input]::MOUSEEVENTF_RIGHTUP, 0, 0, 0, [UIntPtr]::Zero)
    } else {
        [Win32Input]::mouse_event([Win32Input]::MOUSEEVENTF_LEFTDOWN, 0, 0, 0, [UIntPtr]::Zero)
        Start-Sleep -Milliseconds 50
        [Win32Input]::mouse_event([Win32Input]::MOUSEEVENTF_LEFTUP, 0, 0, 0, [UIntPtr]::Zero)
    }
}

if ($ClickX -ge 0 -and $ClickY -ge 0) {
    [Win32Input]::SetCursorPos($ClickX, $ClickY) | Out-Null
    Start-Sleep -Milliseconds 150
    Invoke-MouseClick -WhichButton $Button
    if ($DoubleClick) {
        Start-Sleep -Milliseconds 120
        Invoke-MouseClick -WhichButton $Button
    }
}

if ($Keys) {
    Start-Sleep -Milliseconds 150
    [System.Windows.Forms.SendKeys]::SendWait($Keys)
}

Start-Sleep -Milliseconds $PostDelayMs
