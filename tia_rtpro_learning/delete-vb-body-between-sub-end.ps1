param(
  [int]$ProcessId = 40192,
  [string]$OutputRoot = "C:\Users\QF100\Documents\New project\tia_rtpro_learning"
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName Microsoft.VisualBasic
Add-Type -AssemblyName System.Drawing

Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class CodexDeleteVbBodyWin32 {
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
  [CodexDeleteVbBodyWin32+RECT]$rect = New-Object CodexDeleteVbBodyWin32+RECT
  [CodexDeleteVbBodyWin32]::GetWindowRect($Process.MainWindowHandle, [ref]$rect) | Out-Null
  [CodexDeleteVbBodyWin32]::SetCursorPos($rect.Left + $X, $rect.Top + $Y) | Out-Null
  [CodexDeleteVbBodyWin32]::mouse_event(0x0002, 0, 0, 0, [UIntPtr]::Zero)
  Start-Sleep -Milliseconds 60
  [CodexDeleteVbBodyWin32]::mouse_event(0x0004, 0, 0, 0, [UIntPtr]::Zero)
  Start-Sleep -Milliseconds 250
}

function KeyDown([byte]$Vk) { [CodexDeleteVbBodyWin32]::keybd_event($Vk, 0, 0, [UIntPtr]::Zero) }
function KeyUp([byte]$Vk) { [CodexDeleteVbBodyWin32]::keybd_event($Vk, 0, 0x0002, [UIntPtr]::Zero) }
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
  Start-Sleep -Milliseconds 180
}
function ShiftTap([byte]$Vk) {
  KeyDown 0x10
  Tap $Vk 25
  KeyUp 0x10
  Start-Sleep -Milliseconds 100
}
function CtrlShiftTap([byte]$Vk) {
  KeyDown 0x11
  KeyDown 0x10
  Tap $Vk 25
  KeyUp 0x10
  KeyUp 0x11
  Start-Sleep -Milliseconds 180
}

function Copy-All {
  param([System.Diagnostics.Process]$Process, [string]$Path)
  Click-Relative -Process $Process -X 460 -Y 300
  [System.Windows.Forms.SendKeys]::SendWait("{ESC}")
  Start-Sleep -Milliseconds 150
  CtrlTap 0x41
  Set-Clipboard -Value "__empty__"
  Start-Sleep -Milliseconds 100
  CtrlTap 0x43
  Start-Sleep -Milliseconds 300
  $text = Get-Clipboard -Raw
  [IO.File]::WriteAllText($Path, $text, [Text.Encoding]::UTF8)
  return $text
}

function Screenshot {
  param([string]$Path)
  $bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
  $bmp = New-Object System.Drawing.Bitmap $bounds.Width, $bounds.Height
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.CopyFromScreen($bounds.Location, [System.Drawing.Point]::Empty, $bounds.Size)
  $bmp.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
  $g.Dispose()
  $bmp.Dispose()
}

$process = Get-Process -Id $ProcessId -ErrorAction Stop
[Microsoft.VisualBasic.Interaction]::AppActivate($process.Id) | Out-Null
[CodexDeleteVbBodyWin32]::SetForegroundWindow($process.MainWindowHandle) | Out-Null
Start-Sleep -Milliseconds 700

$verifyDir = Join-Path $OutputRoot "verify"
New-Item -ItemType Directory -Force -Path $verifyDir | Out-Null
$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$beforePath = Join-Path $verifyDir "DATA_Auto_CSV_before_delete_body_$stamp.vbs"
$selectedPath = Join-Path $verifyDir "DATA_Auto_CSV_selected_delete_body_$stamp.vbs"
$afterPath = Join-Path $verifyDir "DATA_Auto_CSV_after_delete_body_$stamp.vbs"
$screenPath = Join-Path $verifyDir "screen_after_delete_body_$stamp.png"
$logPath = Join-Path $verifyDir "DATA_Auto_CSV_delete_body_$stamp.txt"

$before = Copy-All -Process $process -Path $beforePath
$lines = ($before -replace "`r`n", "`n") -split "`n", -1
$subIndex = -1
$endIndex = -1
for ($i = 0; $i -lt $lines.Count; $i++) {
  if ($subIndex -lt 0 -and $lines[$i] -match '^\s*Sub\s+DATA_Auto_CSV\(\)\s*$') { $subIndex = $i }
  if ($lines[$i] -match '^\s*End\s+Sub\s*$') { $endIndex = $i }
}
if ($subIndex -lt 0 -or $endIndex -le $subIndex) { throw "Cannot find Sub/End Sub from copied source." }

# Start after the generated Sub line. Ctrl+Home lands at the beginning of the editor,
# then Down moves by visible source lines.
Click-Relative -Process $process -X 460 -Y 300
[System.Windows.Forms.SendKeys]::SendWait("{ESC}")
Start-Sleep -Milliseconds 150
CtrlTap 0x24
for ($i = 0; $i -lt ($subIndex + 1); $i++) { Tap 0x28 8 }
Tap 0x24 10

# Select to document end, then shrink until End Sub is not in the selected text.
CtrlShiftTap 0x23
$selected = "__empty__"
$shrink = 0
do {
  Set-Clipboard -Value "__empty__"
  Start-Sleep -Milliseconds 100
  CtrlTap 0x43
  Start-Sleep -Milliseconds 250
  $selected = Get-Clipboard -Raw
  [IO.File]::WriteAllText($selectedPath, $selected, [Text.Encoding]::UTF8)
  if ($selected -match '(?m)^\s*End\s+Sub\s*$') {
    ShiftTap 0x26
    $shrink++
  }
} while (($selected -match '(?m)^\s*End\s+Sub\s*$') -and $shrink -lt 20)

if ($selected -match '(?m)^\s*Sub\s+DATA_Auto_CSV\(\)\s*$') { throw "Unsafe selection included Sub line." }
if ($selected -match '(?m)^\s*End\s+Sub\s*$') { throw "Unsafe selection still included End Sub line." }
if ([string]::IsNullOrWhiteSpace($selected) -or $selected -eq "__empty__") { throw "Selection was empty." }

Tap 0x2E 50
Start-Sleep -Milliseconds 600
CtrlTap 0x53
Start-Sleep -Milliseconds 700

$after = Copy-All -Process $process -Path $afterPath
Screenshot -Path $screenPath

$afterLineCount = (($after -replace "`r`n", "`n") -split "`n", -1).Count
$bodyEmpty = ($after -match '(?s)Sub\s+DATA_Auto_CSV\(\)\s*\r?\n\s*\r?\n\s*End\s+Sub')
$log = @(
  "BeforePath=$beforePath",
  "SelectedPath=$selectedPath",
  "AfterPath=$afterPath",
  "ScreenPath=$screenPath",
  "SubLine=$($subIndex + 1)",
  "EndLine=$($endIndex + 1)",
  "SelectedLength=$($selected.Length)",
  "ShrinkCount=$shrink",
  "AfterLineCount=$afterLineCount",
  "BodyEmpty=$bodyEmpty"
)
[IO.File]::WriteAllLines($logPath, $log, [Text.Encoding]::UTF8)
Write-Output $logPath
Write-Output $screenPath
