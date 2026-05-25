param(
  [int]$ProcessId = 41272,
  [string]$OutputRoot = "C:\Users\QF100\Documents\New project\tia_rtpro_learning",
  [string]$SourceSnapshot = "C:\Users\QF100\Documents\New project\tia_rtpro_learning\exports\rtpro_vb_find_delete_body\DATA_Auto_CSV_original_current_20260514_031954.vbs"
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName Microsoft.VisualBasic

Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class CodexFindDeleteBodyWin32 {
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int X,int Y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint f,uint dx,uint dy,uint data, UIntPtr extra);
  [DllImport("user32.dll")] public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, UIntPtr dwExtraInfo);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
}
"@

function Click-Relative {
  param([System.Diagnostics.Process]$Process, [int]$X, [int]$Y)
  [CodexFindDeleteBodyWin32+RECT]$rect = New-Object CodexFindDeleteBodyWin32+RECT
  [CodexFindDeleteBodyWin32]::GetWindowRect($Process.MainWindowHandle, [ref]$rect) | Out-Null
  [CodexFindDeleteBodyWin32]::SetCursorPos($rect.Left + $X, $rect.Top + $Y) | Out-Null
  [CodexFindDeleteBodyWin32]::mouse_event(0x0002, 0, 0, 0, [UIntPtr]::Zero)
  Start-Sleep -Milliseconds 60
  [CodexFindDeleteBodyWin32]::mouse_event(0x0004, 0, 0, 0, [UIntPtr]::Zero)
  Start-Sleep -Milliseconds 250
}

function KeyDown([byte]$Vk) { [CodexFindDeleteBodyWin32]::keybd_event($Vk, 0, 0, [UIntPtr]::Zero) }
function KeyUp([byte]$Vk) { [CodexFindDeleteBodyWin32]::keybd_event($Vk, 0, 0x0002, [UIntPtr]::Zero) }
function Tap([byte]$Vk, [int]$DelayMs = 25) {
  KeyDown $Vk
  Start-Sleep -Milliseconds $DelayMs
  KeyUp $Vk
  Start-Sleep -Milliseconds $DelayMs
}
function CtrlTap([byte]$Vk) {
  KeyDown 0x11
  Tap $Vk 25
  KeyUp 0x11
  Start-Sleep -Milliseconds 150
}
function ShiftTap([byte]$Vk) {
  KeyDown 0x10
  Tap $Vk 25
  KeyUp 0x10
  Start-Sleep -Milliseconds 150
}
function CtrlShiftTap([byte]$Vk) {
  KeyDown 0x11
  KeyDown 0x10
  Tap $Vk 25
  KeyUp 0x10
  KeyUp 0x11
  Start-Sleep -Milliseconds 150
}

function Copy-Selection([string]$Path) {
  Set-Clipboard -Value "__empty__"
  Start-Sleep -Milliseconds 100
  CtrlTap 0x43
  Start-Sleep -Milliseconds 250
  $text = Get-Clipboard -Raw
  [IO.File]::WriteAllText($Path, $text, [Text.Encoding]::UTF8)
  return $text
}

function Export-All([System.Diagnostics.Process]$Process, [string]$Path) {
  Click-Relative -Process $Process -X 460 -Y 300
  [System.Windows.Forms.SendKeys]::SendWait("{ESC}")
  Start-Sleep -Milliseconds 100
  CtrlTap 0x41
  $text = Copy-Selection -Path $Path
  return $text
}

function New-CleanBody {
  param([string]$SnapshotPath)
  $text = [IO.File]::ReadAllText($SnapshotPath, [Text.Encoding]::UTF8) -replace "`r`n", "`n"
  $lines = $text -split "`n", -1
  $subIndex = -1
  for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^\s*Sub\s+DATA_Auto_CSV\(\)\s*$') { $subIndex = $i; break }
  }
  if ($subIndex -lt 0) { throw "Cannot find Sub line in snapshot." }

  $badIndex = -1
  for ($i = $subIndex + 1; $i -lt $lines.Count; $i++) {
    if ($lines[$i].Contains("SmartTa'")) { $badIndex = $i; break }
  }
  if ($badIndex -lt 0) {
    for ($i = $lines.Count - 1; $i -gt $subIndex; $i--) {
      if ($lines[$i] -match '^\s*End\s+Sub\s*$') { $badIndex = $i; break }
    }
  }
  if ($badIndex -le $subIndex) { throw "Cannot find body end in snapshot." }

  $bodyLines = @()
  if ($badIndex -gt ($subIndex + 1)) {
    $bodyLines = $lines[($subIndex + 1)..($badIndex - 1)]
  }
  $bodyLines += 'SmartTags("last_back_date") = DTP2'
  $body = $bodyLines -join "`r`n"

  $envField = -join ([char[]](0x73AF,0x5883,0x68C0,0x6D4B))
  $envLine = 'TagName(9) = "DATA1\' + $envField + '"'
  $body = [regex]::Replace($body, [regex]::Escape("Dim TagName(8),iLen"), "Dim TagName(9),iLen", 1)
  if (-not $body.Contains($envLine)) {
    $body = [regex]::Replace($body, '(?m)^(\s*TagName\(8\)\s*=\s*"DATA1\\[^"]*"\s*)$', {
      param($match)
      $match.Groups[1].Value + "`r`n" + $envLine
    }, 1)
  }
  return $body + "`r`n"
}

function Test-Final([string]$Text) {
  $envField = -join ([char[]](0x73AF,0x5883,0x68C0,0x6D4B))
  $envLine = 'TagName(9) = "DATA1\' + $envField + '"'
  $subCount = ([regex]::Matches($Text, '(?m)^\s*Sub\s+DATA_Auto_CSV\(\)\s*$')).Count
  $endCount = ([regex]::Matches($Text, '(?m)^\s*End\s+Sub\s*$')).Count
  $bad = $Text.Contains("SmartTa'") -or ($Text -match '(?m)^\s*s\("last_back_date"\)\s*=\s*DTP2\s*$')
  return ($subCount -eq 1 -and $endCount -eq 1 -and -not $bad -and $Text.Contains("Dim TagName(9),iLen") -and $Text.Contains($envLine) -and -not $Text.Contains("Dim TagName(8),iLen"))
}

$process = Get-Process -Id $ProcessId -ErrorAction Stop
[Microsoft.VisualBasic.Interaction]::AppActivate($process.Id) | Out-Null
[CodexFindDeleteBodyWin32]::SetForegroundWindow($process.MainWindowHandle) | Out-Null
Start-Sleep -Milliseconds 700

$root = Resolve-Path -LiteralPath $OutputRoot
$verifyDir = Join-Path $root "verify"
$importDir = Join-Path $root "imports\rtpro_vb_find_delete_body"
New-Item -ItemType Directory -Force -Path $verifyDir, $importDir | Out-Null
$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$bodyPath = Join-Path $importDir "DATA_Auto_CSV_clean_body_$stamp.vbs"
$selectionPath = Join-Path $verifyDir "DATA_Auto_CSV_body_selection_$stamp.vbs"
$afterPath = Join-Path $verifyDir "DATA_Auto_CSV_after_find_delete_body_$stamp.vbs"
$logPath = Join-Path $verifyDir "DATA_Auto_CSV_find_delete_body_$stamp.txt"

$body = New-CleanBody -SnapshotPath $SourceSnapshot
[IO.File]::WriteAllText($bodyPath, $body, [Text.Encoding]::UTF8)

Click-Relative -Process $process -X 460 -Y 300
[System.Windows.Forms.SendKeys]::SendWait("{ESC}")
Start-Sleep -Milliseconds 100

# Put caret at body start: document start + 3 lines. This avoids the protected Sub line.
CtrlTap 0x24
for ($i = 0; $i -lt 3; $i++) { Tap 0x28 15 }
Tap 0x24 15

# Select body through the end, then shrink until the generated End Sub line is not included.
CtrlShiftTap 0x23
$selected = Copy-Selection -Path $selectionPath
$shrinkCount = 0
while ($selected -match '(?m)^\s*End\s+Sub\s*$' -and $shrinkCount -lt 10) {
  ShiftTap 0x26
  $shrinkCount++
  $selected = Copy-Selection -Path $selectionPath
}

$hasSub = $selected -match '(?m)^\s*Sub\s+DATA_Auto_CSV\(\)\s*$'
$hasEnd = $selected -match '(?m)^\s*End\s+Sub\s*$'
if ($hasSub -or $hasEnd -or [string]::IsNullOrWhiteSpace($selected)) {
  throw "Unsafe body selection. Sub=$hasSub End=$hasEnd SelectionPath=$selectionPath"
}

Tap 0x2E 50
Set-Clipboard -Value $body
Start-Sleep -Milliseconds 150
CtrlTap 0x56
Start-Sleep -Milliseconds 700
CtrlTap 0x53
Start-Sleep -Milliseconds 700

$after = Export-All -Process $process -Path $afterPath
$ok = Test-Final -Text $after
$log = @(
  "SourceSnapshot=$SourceSnapshot",
  "BodyPath=$bodyPath",
  "SelectionPath=$selectionPath",
  "AfterPath=$afterPath",
  "ShrinkCount=$shrinkCount",
  "SelectedLength=$($selected.Length)",
  "Ok=$ok"
)
[IO.File]::WriteAllLines($logPath, $log, [Text.Encoding]::UTF8)
Write-Output $logPath
if (-not $ok) { throw "Final readback did not verify cleanly. See $logPath" }
