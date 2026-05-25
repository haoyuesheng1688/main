param(
  [int]$ProcessId = 36644,
  [string]$OutputRoot = "C:\Users\QF100\Documents\New project\tia_rtpro_learning"
)

$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName Microsoft.VisualBasic

Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class CodexTmpUndoReadWin32 {
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int X,int Y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint f,uint dx,uint dy,uint data, UIntPtr extra);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
}
"@

function Click-Relative {
  param([System.Diagnostics.Process]$Process, [int]$X, [int]$Y)
  [CodexTmpUndoReadWin32+RECT]$rect = New-Object CodexTmpUndoReadWin32+RECT
  [CodexTmpUndoReadWin32]::GetWindowRect($Process.MainWindowHandle, [ref]$rect) | Out-Null
  [CodexTmpUndoReadWin32]::SetCursorPos($rect.Left + $X, $rect.Top + $Y) | Out-Null
  [CodexTmpUndoReadWin32]::mouse_event(0x0002, 0, 0, 0, [UIntPtr]::Zero)
  Start-Sleep -Milliseconds 60
  [CodexTmpUndoReadWin32]::mouse_event(0x0004, 0, 0, 0, [UIntPtr]::Zero)
  Start-Sleep -Milliseconds 250
}

function Send-Keys {
  param([string]$Keys, [int]$DelayMs = 250)
  [System.Windows.Forms.SendKeys]::SendWait($Keys)
  Start-Sleep -Milliseconds $DelayMs
}

$process = Get-Process -Id $ProcessId -ErrorAction Stop
[Microsoft.VisualBasic.Interaction]::AppActivate($process.Id) | Out-Null
[CodexTmpUndoReadWin32]::SetForegroundWindow($process.MainWindowHandle) | Out-Null
Start-Sleep -Milliseconds 700

Click-Relative -Process $process -X 520 -Y 230
Send-Keys "{ESC}"
Send-Keys "^(z)" 1000
Send-Keys "^(s)" 700

Click-Relative -Process $process -X 520 -Y 230
Send-Keys "{ESC}"
Send-Keys "^(a)" 250
Set-Clipboard -Value "__empty__"
Start-Sleep -Milliseconds 100
Send-Keys "^(c)" 500

$text = Get-Clipboard -Raw
$verifyDir = Join-Path $OutputRoot "verify"
New-Item -ItemType Directory -Force -Path $verifyDir | Out-Null
$out = Join-Path $verifyDir ("DATA_Auto_CSV_after_undo_" + (Get-Date -Format "yyyyMMdd_HHmmss") + ".vbs")
[IO.File]::WriteAllText($out, $text, [Text.Encoding]::UTF8)

Write-Output $out
Write-Output ("HasDim8=" + $text.Contains("Dim TagName(8),iLen"))
Write-Output ("HasDim9=" + $text.Contains("Dim TagName(9),iLen"))
Write-Output ("HasCorrupt=" + $text.Contains("SmartTa'"))
