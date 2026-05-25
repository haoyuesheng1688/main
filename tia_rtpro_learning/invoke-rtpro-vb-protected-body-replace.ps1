param(
  [int]$ProcessId = 36644,
  [string]$OutputRoot = "C:\Users\QF100\Documents\New project\tia_rtpro_learning",
  [string]$ScriptName = "DATA_Auto_CSV"
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName Microsoft.VisualBasic

$EnvField = -join ([char[]](0x73AF, 0x5883, 0x68C0, 0x6D4B))
$EnvLine = 'TagName(9) = "DATA1\' + $EnvField + '"'

Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class CodexProtectedBodyReplaceWin32 {
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int X, int Y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint dwFlags, uint dx, uint dy, uint dwData, UIntPtr dwExtraInfo);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
}
"@

function Activate-Portal {
  param([System.Diagnostics.Process]$Process)
  [Microsoft.VisualBasic.Interaction]::AppActivate($Process.Id) | Out-Null
  [CodexProtectedBodyReplaceWin32]::SetForegroundWindow($Process.MainWindowHandle) | Out-Null
  Start-Sleep -Milliseconds 700
}

function Click-Relative {
  param([System.Diagnostics.Process]$Process, [int]$X, [int]$Y)
  [CodexProtectedBodyReplaceWin32+RECT]$rect = New-Object CodexProtectedBodyReplaceWin32+RECT
  [CodexProtectedBodyReplaceWin32]::GetWindowRect($Process.MainWindowHandle, [ref]$rect) | Out-Null
  [CodexProtectedBodyReplaceWin32]::SetCursorPos(($rect.Left + $X), ($rect.Top + $Y)) | Out-Null
  [CodexProtectedBodyReplaceWin32]::mouse_event(0x0002, 0, 0, 0, [UIntPtr]::Zero)
  Start-Sleep -Milliseconds 60
  [CodexProtectedBodyReplaceWin32]::mouse_event(0x0004, 0, 0, 0, [UIntPtr]::Zero)
  Start-Sleep -Milliseconds 250
}

function Send-Keys {
  param([string]$Keys, [int]$DelayMs = 250)
  [System.Windows.Forms.SendKeys]::SendWait($Keys)
  Start-Sleep -Milliseconds $DelayMs
}

function Set-FieldByClick {
  param([System.Diagnostics.Process]$Process, [int]$X, [int]$Y, [string]$Text)
  Click-Relative -Process $Process -X $X -Y $Y
  Send-Keys "^(a)" 150
  Set-Clipboard -Value $Text
  Start-Sleep -Milliseconds 150
  Send-Keys "^(v)" 250
}

function Export-EditorText {
  param([System.Diagnostics.Process]$Process, [string]$OutPath)
  Activate-Portal -Process $Process
  Click-Relative -Process $Process -X 520 -Y 230
  Send-Keys "{ESC}" 150
  Send-Keys "^(a)" 250
  Set-Clipboard -Value "__codex_empty__"
  Start-Sleep -Milliseconds 120
  Send-Keys "^(c)" 500
  $text = Get-Clipboard -Raw
  [IO.File]::WriteAllText($OutPath, $text, [Text.Encoding]::UTF8)
  return $text
}

function Get-VbParts {
  param([string]$Text)
  $normalized = $Text -replace "`r`n", "`n"
  $lines = $normalized -split "`n", -1
  $subIndex = -1
  $endIndex = -1
  for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($subIndex -lt 0 -and $lines[$i] -match ("^\s*Sub\s+" + [regex]::Escape($ScriptName) + "\(\)\s*$")) {
      $subIndex = $i
    }
    if ($lines[$i] -match '^\s*End\s+Sub\s*$') {
      $endIndex = $i
    }
  }
  if ($subIndex -lt 0 -or $endIndex -le $subIndex) {
    throw "Cannot locate protected Sub/End Sub skeleton."
  }
  $bodyLines = @()
  if ($endIndex -gt ($subIndex + 1)) {
    $bodyLines = $lines[($subIndex + 1)..($endIndex - 1)]
  }
  [pscustomobject]@{
    SubLine = $lines[$subIndex]
    EndLine = $lines[$endIndex]
    BodyText = ($bodyLines -join "`r`n")
  }
}

function Test-CleanSource {
  param([string]$Text)
  $subCount = ([regex]::Matches($Text, ("(?m)^\s*Sub\s+" + [regex]::Escape($ScriptName) + "\(\)\s*$"))).Count
  $endCount = ([regex]::Matches($Text, '(?m)^\s*End\s+Sub\s*$')).Count
  if ($subCount -ne 1 -or $endCount -ne 1) { return $false }
  if ($Text.Contains("SmartTa'")) { return $false }
  if ($Text -match '(?m)^\s*s\("last_back_date"\)\s*=\s*DTP2\s*$') { return $false }
  return $true
}

function Patch-Body {
  param([string]$Text)
  $body = (Get-VbParts -Text $Text).BodyText
  $body = [regex]::Replace($body, [regex]::Escape("Dim TagName(8),iLen"), "Dim TagName(9),iLen", 1)
  if (-not $body.Contains($EnvLine)) {
    $body = [regex]::Replace($body, '(?m)^(\s*TagName\(8\)\s*=\s*"DATA1\\[^"]*"\s*)$', {
      param($match)
      $match.Groups[1].Value + "`r`n" + $EnvLine
    }, 1)
  }
  if (-not $body.Contains("Dim TagName(9),iLen")) { throw "Patched body missing Dim TagName(9)." }
  if (-not $body.Contains($EnvLine)) { throw "Patched body missing environment field." }
  return $body
}

$process = Get-Process -Id $ProcessId -ErrorAction Stop
$verifyDir = Join-Path $OutputRoot "verify"
$exportDir = Join-Path $OutputRoot "exports\rtpro_vb_protected_body"
$importDir = Join-Path $OutputRoot "imports\rtpro_vb_protected_body"
New-Item -ItemType Directory -Force -Path $verifyDir, $exportDir, $importDir | Out-Null

$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$currentPath = Join-Path $exportDir "$($ScriptName)_current_before_replace_$stamp.vbs"
$bodyPath = Join-Path $importDir "$($ScriptName)_patched_body_$stamp.vbs"
$afterPath = Join-Path $verifyDir "$($ScriptName)_after_protected_body_replace_$stamp.vbs"
$logPath = Join-Path $verifyDir "$($ScriptName)_protected_body_replace_$stamp.txt"

$current = Export-EditorText -Process $process -OutPath $currentPath

$base = $current
$basePath = $currentPath
if (-not (Test-CleanSource -Text $current)) {
  $candidates = @(
    Get-ChildItem -Path (Join-Path $OutputRoot "exports") -Recurse -Filter "$($ScriptName)_export_full_*.vbs" -ErrorAction SilentlyContinue
    Get-ChildItem -Path (Join-Path $OutputRoot "verify") -Recurse -Filter "$($ScriptName)_*.vbs" -ErrorAction SilentlyContinue
  ) | Sort-Object LastWriteTime -Descending
  foreach ($candidate in $candidates) {
    $candidateText = [IO.File]::ReadAllText($candidate.FullName, [Text.Encoding]::UTF8)
    if (Test-CleanSource -Text $candidateText) {
      $base = $candidateText
      $basePath = $candidate.FullName
      break
    }
  }
}

if (-not (Test-CleanSource -Text $base)) {
  throw "No clean base source found. Current editor snapshot is saved at $currentPath"
}

$patchedBody = Patch-Body -Text $base
[IO.File]::WriteAllText($bodyPath, $patchedBody, [Text.Encoding]::UTF8)

# Match only the editable body. The protected Sub and End Sub lines are lookaround
# boundaries and are not part of the replacement text.
$findRegex = "(?s)(?<=Sub\s+$([regex]::Escape($ScriptName))\(\)\s*\r?\n).*?(?=\r?\nEnd\s+Sub\s*$)"

Activate-Portal -Process $process
Click-Relative -Process $process -X 520 -Y 230
Send-Keys "{ESC}" 150
Send-Keys "^(h)" 500
Set-FieldByClick -Process $process -X 2320 -Y 230 -Text $findRegex
Set-FieldByClick -Process $process -X 2320 -Y 515 -Text $patchedBody

# Assumption: the Find/Replace card is already in regular-expression mode, as
# shown in the user's screenshot. We do not toggle the checkbox here.
Click-Relative -Process $process -X 2420 -Y 614
Start-Sleep -Seconds 1
Send-Keys "^(s)" 700

$after = Export-EditorText -Process $process -OutPath $afterPath
$cleanAfter = Test-CleanSource -Text $after
$dim9 = $after.Contains("Dim TagName(9),iLen")
$env = $after.Contains($EnvLine)
$corrupt = $after.Contains("SmartTa'") -or ($after -match '(?m)^\s*s\("last_back_date"\)\s*=\s*DTP2\s*$')

$log = @(
  "ProcessId=$ProcessId",
  "ScriptName=$ScriptName",
  "CurrentPath=$currentPath",
  "BasePath=$basePath",
  "BodyPath=$bodyPath",
  "AfterPath=$afterPath",
  "FindRegex=$findRegex",
  "CleanAfter=$cleanAfter",
  "Dim9=$dim9",
  "Env=$env",
  "Corrupt=$corrupt"
)
[IO.File]::WriteAllLines($logPath, $log, [Text.Encoding]::UTF8)
Write-Output $logPath

if (-not ($cleanAfter -and $dim9 -and $env -and -not $corrupt)) {
  throw "Protected body replace did not verify cleanly. See $logPath"
}
