param(
  [int]$ProcessId = 41272,
  [string]$OutputRoot = "C:\Users\QF100\Documents\New project\tia_rtpro_learning"
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName Microsoft.VisualBasic

Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class CodexCopyCurrentVbWin32 {
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int X,int Y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint f,uint dx,uint dy,uint data, UIntPtr extra);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
}
"@

function Click-Relative {
  param([System.Diagnostics.Process]$Process, [int]$X, [int]$Y)
  [CodexCopyCurrentVbWin32+RECT]$rect = New-Object CodexCopyCurrentVbWin32+RECT
  [CodexCopyCurrentVbWin32]::GetWindowRect($Process.MainWindowHandle, [ref]$rect) | Out-Null
  [CodexCopyCurrentVbWin32]::SetCursorPos($rect.Left + $X, $rect.Top + $Y) | Out-Null
  [CodexCopyCurrentVbWin32]::mouse_event(0x0002, 0, 0, 0, [UIntPtr]::Zero)
  Start-Sleep -Milliseconds 60
  [CodexCopyCurrentVbWin32]::mouse_event(0x0004, 0, 0, 0, [UIntPtr]::Zero)
  Start-Sleep -Milliseconds 250
}

$process = Get-Process -Id $ProcessId -ErrorAction Stop
[Microsoft.VisualBasic.Interaction]::AppActivate($process.Id) | Out-Null
[CodexCopyCurrentVbWin32]::SetForegroundWindow($process.MainWindowHandle) | Out-Null
Start-Sleep -Milliseconds 700

Click-Relative -Process $process -X 460 -Y 300
[System.Windows.Forms.SendKeys]::SendWait("{ESC}")
Start-Sleep -Milliseconds 150
[System.Windows.Forms.SendKeys]::SendWait("^(a)")
Start-Sleep -Milliseconds 250
Set-Clipboard -Value "__empty__"
Start-Sleep -Milliseconds 100
[System.Windows.Forms.SendKeys]::SendWait("^(c)")
Start-Sleep -Milliseconds 500
$text = Get-Clipboard -Raw

$dir = Join-Path $OutputRoot "exports\rtpro_vb_find_delete_body"
New-Item -ItemType Directory -Force -Path $dir | Out-Null
$out = Join-Path $dir ("DATA_Auto_CSV_original_current_" + (Get-Date -Format "yyyyMMdd_HHmmss") + ".vbs")
[IO.File]::WriteAllText($out, $text, [Text.Encoding]::UTF8)
$envField = -join ([char[]](0x73AF,0x5883,0x68C0,0x6D4B))

Write-Output $out
Write-Output ("Length=" + $text.Length)
Write-Output ("SubCount=" + ([regex]::Matches($text,'(?m)^\s*Sub\s+DATA_Auto_CSV\(\)\s*$').Count))
Write-Output ("EndCount=" + ([regex]::Matches($text,'(?m)^\s*End\s+Sub\s*$').Count))
Write-Output ("HasDim8=" + $text.Contains("Dim TagName(8),iLen"))
Write-Output ("HasEnv=" + $text.Contains($envField))
