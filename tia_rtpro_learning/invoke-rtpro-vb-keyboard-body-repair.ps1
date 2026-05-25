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
public static class CodexKeyboardBodyRepairWin32 {
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int X, int Y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint dwFlags, uint dx, uint dy, uint dwData, UIntPtr dwExtraInfo);
  [DllImport("user32.dll")] public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, UIntPtr dwExtraInfo);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
}
"@

$EnvField = -join ([char[]](0x73AF, 0x5883, 0x68C0, 0x6D4B))
$EnvLine = 'TagName(9) = "DATA1\' + $EnvField + '"'

function Activate-Portal([System.Diagnostics.Process]$Process) {
  [Microsoft.VisualBasic.Interaction]::AppActivate($Process.Id) | Out-Null
  [CodexKeyboardBodyRepairWin32]::SetForegroundWindow($Process.MainWindowHandle) | Out-Null
  Start-Sleep -Milliseconds 700
}

function Click-Relative([System.Diagnostics.Process]$Process, [int]$X, [int]$Y) {
  [CodexKeyboardBodyRepairWin32+RECT]$rect = New-Object CodexKeyboardBodyRepairWin32+RECT
  [CodexKeyboardBodyRepairWin32]::GetWindowRect($Process.MainWindowHandle, [ref]$rect) | Out-Null
  [CodexKeyboardBodyRepairWin32]::SetCursorPos($rect.Left + $X, $rect.Top + $Y) | Out-Null
  [CodexKeyboardBodyRepairWin32]::mouse_event(0x0002, 0, 0, 0, [UIntPtr]::Zero)
  Start-Sleep -Milliseconds 60
  [CodexKeyboardBodyRepairWin32]::mouse_event(0x0004, 0, 0, 0, [UIntPtr]::Zero)
  Start-Sleep -Milliseconds 250
}

function Send-Keys([string]$Keys, [int]$DelayMs = 250) {
  [System.Windows.Forms.SendKeys]::SendWait($Keys)
  Start-Sleep -Milliseconds $DelayMs
}

function KeyDown([byte]$Vk) { [CodexKeyboardBodyRepairWin32]::keybd_event($Vk, 0, 0, [UIntPtr]::Zero) }
function KeyUp([byte]$Vk) { [CodexKeyboardBodyRepairWin32]::keybd_event($Vk, 0, 0x0002, [UIntPtr]::Zero) }
function Tap([byte]$Vk, [int]$DelayMs = 20) {
  KeyDown $Vk
  Start-Sleep -Milliseconds $DelayMs
  KeyUp $Vk
  Start-Sleep -Milliseconds $DelayMs
}
function ShiftTap([byte]$Vk, [int]$DelayMs = 10) {
  KeyDown 0x10
  Tap $Vk $DelayMs
  KeyUp 0x10
  Start-Sleep -Milliseconds $DelayMs
}

function Export-EditorText([System.Diagnostics.Process]$Process, [string]$Path) {
  Activate-Portal $Process
  Click-Relative $Process 520 230
  Send-Keys "{ESC}" 150
  Send-Keys "^(a)" 250
  Set-Clipboard -Value "__codex_empty__"
  Start-Sleep -Milliseconds 120
  Send-Keys "^(c)" 500
  $text = Get-Clipboard -Raw
  [IO.File]::WriteAllText($Path, $text, [Text.Encoding]::UTF8)
  return $text
}

function Find-InEditor([System.Diagnostics.Process]$Process, [string]$Text) {
  Activate-Portal $Process
  Click-Relative $Process 520 230
  Send-Keys "{ESC}" 100
  Set-Clipboard -Value $Text
  Start-Sleep -Milliseconds 120
  Send-Keys "^(f)" 250
  Send-Keys "^(a)" 120
  Send-Keys "^(v)" 120
  Tap 0x0D 30
  Start-Sleep -Milliseconds 500
  Tap 0x1B 30
  Start-Sleep -Milliseconds 250
}

function Test-Expected([string]$Text) {
  $subCount = ([regex]::Matches($Text, '(?m)^\s*Sub\s+DATA_Auto_CSV\(\)\s*$')).Count
  $endCount = ([regex]::Matches($Text, '(?m)^\s*End\s+Sub\s*$')).Count
  $bad = $Text.Contains("SmartTa'") -or ($Text -match '(?m)^\s*s\("last_back_date"\)\s*=\s*DTP2\s*$')
  return ($subCount -eq 1 -and $endCount -eq 1 -and -not $bad -and $Text.Contains("Dim TagName(9),iLen") -and $Text.Contains($EnvLine))
}

$process = Get-Process -Id $ProcessId -ErrorAction Stop
$verifyDir = Join-Path $OutputRoot "verify"
New-Item -ItemType Directory -Force -Path $verifyDir | Out-Null
$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$beforePath = Join-Path $verifyDir "DATA_Auto_CSV_before_keyboard_repair_$stamp.vbs"
$afterPath = Join-Path $verifyDir "DATA_Auto_CSV_after_keyboard_repair_$stamp.vbs"
$logPath = Join-Path $verifyDir "DATA_Auto_CSV_keyboard_repair_$stamp.txt"

$before = Export-EditorText $process $beforePath
$lines = ($before -replace "`r`n", "`n") -split "`n", -1
$startLine = -1
$endLine = -1
for ($i = 0; $i -lt $lines.Count; $i++) {
  if ($startLine -lt 0 -and $lines[$i].Contains("SmartTa'")) { $startLine = $i + 1 }
  if ($lines[$i] -match '^\s*s\("last_back_date"\)\s*=\s*DTP2\s*$') { $endLine = $i + 1 }
}

if ($startLine -gt 0 -and $endLine -ge $startLine) {
  $downCount = $endLine - $startLine
  Find-InEditor $process "SmartTa'"
  Tap 0x24 30
  for ($i = 0; $i -lt $downCount; $i++) { ShiftTap 0x28 2 }
  ShiftTap 0x23 20
  Set-Clipboard -Value ('SmartTags("last_back_date") = DTP2' + "`r`n")
  Start-Sleep -Milliseconds 120
  Send-Keys "^(v)" 500
}

$midPath = Join-Path $verifyDir "DATA_Auto_CSV_mid_keyboard_repair_$stamp.vbs"
$mid = Export-EditorText $process $midPath

if ($mid.Contains("Dim TagName(8),iLen")) {
  Find-InEditor $process "Dim TagName(8),iLen"
  Set-Clipboard -Value "Dim TagName(9),iLen"
  Start-Sleep -Milliseconds 120
  Send-Keys "^(v)" 400
}

$mid2Path = Join-Path $verifyDir "DATA_Auto_CSV_mid2_keyboard_repair_$stamp.vbs"
$mid2 = Export-EditorText $process $mid2Path
if (-not $mid2.Contains($EnvLine)) {
  Find-InEditor $process "iLen =UBound(TagName)"
  Tap 0x24 20
  Set-Clipboard -Value ($EnvLine + "`r`n")
  Start-Sleep -Milliseconds 120
  Send-Keys "^(v)" 500
}

Send-Keys "^(s)" 700
$after = Export-EditorText $process $afterPath
$ok = Test-Expected $after

$log = @(
  "BeforePath=$beforePath",
  "MidPath=$midPath",
  "Mid2Path=$mid2Path",
  "AfterPath=$afterPath",
  "StartLine=$startLine",
  "EndLine=$endLine",
  "Ok=$ok",
  "HasDim8=$($after.Contains('Dim TagName(8),iLen'))",
  "HasDim9=$($after.Contains('Dim TagName(9),iLen'))",
  "HasEnv=$($after.Contains($EnvLine))",
  "HasSmartTa=$($after.Contains(""SmartTa'""))",
  "HasBrokenTail=$($after -match '(?m)^\s*s\(""last_back_date""\)\s*=\s*DTP2\s*$')"
)
[IO.File]::WriteAllLines($logPath, $log, [Text.Encoding]::UTF8)
Write-Output $logPath
if (-not $ok) { throw "Keyboard repair did not verify cleanly. See $logPath" }
