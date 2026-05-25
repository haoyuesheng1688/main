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
public static class CodexTargetedRepairWin32 {
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int X, int Y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint dwFlags, uint dx, uint dy, uint dwData, UIntPtr dwExtraInfo);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
}
"@

$EnvField = -join ([char[]](0x73AF, 0x5883, 0x68C0, 0x6D4B))
$EnvLine = 'TagName(9) = "DATA1\' + $EnvField + '"'

function Activate-Portal([System.Diagnostics.Process]$Process) {
  [Microsoft.VisualBasic.Interaction]::AppActivate($Process.Id) | Out-Null
  [CodexTargetedRepairWin32]::SetForegroundWindow($Process.MainWindowHandle) | Out-Null
  Start-Sleep -Milliseconds 700
}

function Click-Relative([System.Diagnostics.Process]$Process, [int]$X, [int]$Y) {
  [CodexTargetedRepairWin32+RECT]$rect = New-Object CodexTargetedRepairWin32+RECT
  [CodexTargetedRepairWin32]::GetWindowRect($Process.MainWindowHandle, [ref]$rect) | Out-Null
  [CodexTargetedRepairWin32]::SetCursorPos($rect.Left + $X, $rect.Top + $Y) | Out-Null
  [CodexTargetedRepairWin32]::mouse_event(0x0002, 0, 0, 0, [UIntPtr]::Zero)
  Start-Sleep -Milliseconds 60
  [CodexTargetedRepairWin32]::mouse_event(0x0004, 0, 0, 0, [UIntPtr]::Zero)
  Start-Sleep -Milliseconds 250
}

function Send-Keys([string]$Keys, [int]$DelayMs = 250) {
  [System.Windows.Forms.SendKeys]::SendWait($Keys)
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

function Import-FullBySelectAll([System.Diagnostics.Process]$Process, [string]$Text) {
  Activate-Portal $Process
  Click-Relative $Process 520 230
  Send-Keys "{ESC}" 150
  Send-Keys "^(a)" 250
  Set-Clipboard -Value $Text
  Start-Sleep -Milliseconds 150
  Send-Keys "^(v)" 800
  Send-Keys "^(s)" 700
}

function Repair-Text([string]$Text) {
  $fixed = $Text -replace "`r`n", "`n"

  # Remove the accidental duplicate body that was inserted into the middle of
  # SmartTags("last_back_date") = DTP2, then restore that statement.
  $fixed = [regex]::Replace(
    $fixed,
    "(?s)SmartTa'提示：.*?^\s*s\(`"last_back_date`"\)\s*=\s*DTP2\s*$",
    'SmartTags("last_back_date") = DTP2',
    1
  )

  $fixed = [regex]::Replace($fixed, [regex]::Escape("Dim TagName(8),iLen"), "Dim TagName(9),iLen", 1)
  if (-not $fixed.Contains($EnvLine)) {
    $fixed = [regex]::Replace($fixed, '(?m)^(\s*TagName\(8\)\s*=\s*"DATA1\\[^"]*"\s*)$', {
      param($match)
      $match.Groups[1].Value + "`n" + $EnvLine
    }, 1)
  }

  $fixed = $fixed -replace "`n", "`r`n"
  return $fixed
}

function Test-Expected([string]$Text) {
  $subCount = ([regex]::Matches($Text, '(?m)^\s*Sub\s+DATA_Auto_CSV\(\)\s*$')).Count
  $endCount = ([regex]::Matches($Text, '(?m)^\s*End\s+Sub\s*$')).Count
  $bad = $Text.Contains("SmartTa'") -or ($Text -match '(?m)^\s*s\("last_back_date"\)\s*=\s*DTP2\s*$')
  return ($subCount -eq 1 -and $endCount -eq 1 -and -not $bad -and $Text.Contains("Dim TagName(9),iLen") -and $Text.Contains($EnvLine))
}

$process = Get-Process -Id $ProcessId -ErrorAction Stop
$verifyDir = Join-Path $OutputRoot "verify"
$importDir = Join-Path $OutputRoot "imports\rtpro_vb_targeted_repair"
New-Item -ItemType Directory -Force -Path $verifyDir, $importDir | Out-Null
$stamp = Get-Date -Format "yyyyMMdd_HHmmss"

$beforePath = Join-Path $verifyDir "DATA_Auto_CSV_before_targeted_repair_$stamp.vbs"
$fixedPath = Join-Path $importDir "DATA_Auto_CSV_fixed_full_$stamp.vbs"
$afterPath = Join-Path $verifyDir "DATA_Auto_CSV_after_targeted_repair_$stamp.vbs"
$logPath = Join-Path $verifyDir "DATA_Auto_CSV_targeted_repair_$stamp.txt"

$before = Export-EditorText $process $beforePath
$fixed = Repair-Text $before
[IO.File]::WriteAllText($fixedPath, $fixed, [Text.Encoding]::UTF8)

if (-not (Test-Expected $fixed)) {
  throw "Local repaired text does not pass expected checks. See $fixedPath"
}

Import-FullBySelectAll $process $fixed
$after = Export-EditorText $process $afterPath
$ok = Test-Expected $after

$log = @(
  "BeforePath=$beforePath",
  "FixedPath=$fixedPath",
  "AfterPath=$afterPath",
  "Ok=$ok",
  "HasDim8=$($after.Contains('Dim TagName(8),iLen'))",
  "HasDim9=$($after.Contains('Dim TagName(9),iLen'))",
  "HasEnv=$($after.Contains($EnvLine))",
  "HasCorrupt=$($after.Contains(""SmartTa'"") -or ($after -match '(?m)^\s*s\(""last_back_date""\)\s*=\s*DTP2\s*$'))"
)
[IO.File]::WriteAllLines($logPath, $log, [Text.Encoding]::UTF8)
Write-Output $logPath
if (-not $ok) { throw "Targeted repair did not verify cleanly. See $logPath" }
