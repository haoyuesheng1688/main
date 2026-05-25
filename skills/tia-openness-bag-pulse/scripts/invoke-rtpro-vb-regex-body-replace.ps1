param(
  [int]$ProcessId = 0,
  [string]$OutputRoot = ".\tia_rtpro_learning",
  [string]$ScriptName = "DATA_Auto_CSV",
  [string]$OldDim = "Dim TagName(8),iLen",
  [string]$NewDim = "Dim TagName(9),iLen",
  [string]$AfterLine = 'TagName(8) = "DATA1\露点温度"',
  [string]$InsertLine = 'TagName(9) = "DATA1\环境检测"'
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName Microsoft.VisualBasic

Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class CodexRegexReplaceWin32 {
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int X, int Y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint dwFlags, uint dx, uint dy, uint dwData, UIntPtr dwExtraInfo);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
}
'@

function Get-PortalProcess {
  if ($ProcessId -ne 0) {
    return Get-Process -Id $ProcessId -ErrorAction Stop
  }
  Get-Process -Name "Siemens.Automation.Portal" -ErrorAction Stop |
    Where-Object { $_.MainWindowHandle -ne [IntPtr]::Zero -and $_.MainWindowTitle } |
    Select-Object -First 1
}

function Activate-Portal {
  param([System.Diagnostics.Process]$Process)
  [Microsoft.VisualBasic.Interaction]::AppActivate($Process.Id) | Out-Null
  [CodexRegexReplaceWin32]::SetForegroundWindow($Process.MainWindowHandle) | Out-Null
  Start-Sleep -Milliseconds 500
}

function Click-Relative {
  param(
    [System.Diagnostics.Process]$Process,
    [int]$X,
    [int]$Y
  )
  [CodexRegexReplaceWin32+RECT]$rect = New-Object CodexRegexReplaceWin32+RECT
  [CodexRegexReplaceWin32]::GetWindowRect($Process.MainWindowHandle, [ref]$rect) | Out-Null
  [CodexRegexReplaceWin32]::SetCursorPos(($rect.Left + $X), ($rect.Top + $Y)) | Out-Null
  [CodexRegexReplaceWin32]::mouse_event(0x0002, 0, 0, 0, [UIntPtr]::Zero)
  Start-Sleep -Milliseconds 60
  [CodexRegexReplaceWin32]::mouse_event(0x0004, 0, 0, 0, [UIntPtr]::Zero)
  Start-Sleep -Milliseconds 250
}

function Send-Keys {
  param([string]$Keys, [int]$DelayMs = 250)
  [System.Windows.Forms.SendKeys]::SendWait($Keys)
  Start-Sleep -Milliseconds $DelayMs
}

function Set-FieldByClick {
  param(
    [System.Diagnostics.Process]$Process,
    [int]$X,
    [int]$Y,
    [string]$Text
  )
  Click-Relative -Process $Process -X $X -Y $Y
  Send-Keys "^(a)"
  Set-Clipboard -Value $Text
  Start-Sleep -Milliseconds 150
  Send-Keys "^(v)"
}

function Export-EditorText {
  param([System.Diagnostics.Process]$Process)
  Activate-Portal $Process
  Click-Relative -Process $Process -X 520 -Y 230
  Send-Keys "{ESC}"
  Send-Keys "^(a)"
  Set-Clipboard -Value "__codex_empty__"
  Start-Sleep -Milliseconds 100
  Send-Keys "^(c)"
  $text = Get-Clipboard -Raw
  if ([string]::IsNullOrWhiteSpace($text) -or $text -eq "__codex_empty__") {
    throw "Failed to export editor text. Open $ScriptName in the VB editor first."
  }
  return $text
}

function Get-VbBodyInfo {
  param([string]$Text)
  $normalized = $Text -replace "`r`n", "`n"
  $lines = $normalized -split "`n", -1
  $subIndex = -1
  $endIndex = -1
  for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($subIndex -lt 0 -and $lines[$i] -match '^\s*Sub\s+\S+\s*\(') {
      $subIndex = $i
    }
    if ($lines[$i] -match '^\s*End\s+Sub\s*$') {
      $endIndex = $i
    }
  }
  if ($subIndex -lt 0) { throw "Cannot find generated Sub line." }
  if ($endIndex -lt 0 -or $endIndex -le $subIndex) { throw "Cannot find generated End Sub line." }
  $bodyLines = @()
  if ($endIndex -gt ($subIndex + 1)) {
    $bodyLines = $lines[($subIndex + 1)..($endIndex - 1)]
  }
  [pscustomobject]@{
    SubLine = $lines[$subIndex]
    EndLine = $lines[$endIndex]
    BodyText = (($bodyLines -join "`r`n") + "`r`n")
  }
}

function Patch-Body {
  param([string]$BodyText)
  $patched = $BodyText
  if ($patched -match [regex]::Escape($OldDim)) {
    $patched = [regex]::Replace($patched, [regex]::Escape($OldDim), [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $NewDim }, 1)
  }
  elseif ($patched -notmatch [regex]::Escape($NewDim)) {
    throw "Cannot find old or new Dim line."
  }
  if ($patched -notmatch [regex]::Escape($InsertLine)) {
    if ($patched -notmatch [regex]::Escape($AfterLine)) {
      throw "Cannot find insertion anchor line."
    }
    $patched = [regex]::Replace($patched, [regex]::Escape($AfterLine), [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $AfterLine + "`r`n" + $InsertLine }, 1)
  }
  return $patched
}

$root = Resolve-Path -LiteralPath $OutputRoot -ErrorAction SilentlyContinue
if (-not $root) {
  New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null
  $root = Resolve-Path -LiteralPath $OutputRoot
}
$exportDir = Join-Path $root "exports\rtpro_vb_regex"
$importDir = Join-Path $root "imports\rtpro_vb_regex"
$verifyDir = Join-Path $root "verify"
New-Item -ItemType Directory -Force -Path $exportDir, $importDir, $verifyDir | Out-Null

$process = Get-PortalProcess
if (-not $process) { throw "No Siemens.Automation.Portal window was found." }
$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$exportPath = Join-Path $exportDir "$($ScriptName)_export_full_$stamp.vbs"
$bodyPath = Join-Path $importDir "$($ScriptName)_patched_body_$stamp.vbs"
$readbackPath = Join-Path $verifyDir "$($ScriptName)_regex_readback_$stamp.vbs"
$logPath = Join-Path $verifyDir "$($ScriptName)_regex_body_replace_$stamp.txt"

$original = Export-EditorText -Process $process
[IO.File]::WriteAllText($exportPath, $original, [Text.Encoding]::UTF8)
$info = Get-VbBodyInfo -Text $original
$patchedBody = Patch-Body -BodyText $info.BodyText
[IO.File]::WriteAllText($bodyPath, $patchedBody, [Text.Encoding]::UTF8)

# TIA's Find/Replace panel can preserve the fixed generated Sub/End Sub lines by
# matching the body as group 2 and replacing the whole match with group 1 + body + group 3.
$findRegex = "(?s)(Sub\s+" + [regex]::Escape($ScriptName) + "\(\)\s*\r?\n)(.*?)(\r?\nEnd\s+Sub)"
$replaceText = '$1' + $patchedBody.TrimEnd("`r", "`n") + '$3'

Activate-Portal $process
Click-Relative -Process $process -X 520 -Y 230
Send-Keys "{ESC}"
Send-Keys "^(f)"

# Coordinates are relative to the current full-screen TIA layout. They target the
# right Find/Replace task card shown by V17 RT Professional.
Set-FieldByClick -Process $process -X 2320 -Y 230 -Text $findRegex
Set-FieldByClick -Process $process -X 2320 -Y 515 -Text $replaceText

# Enable regular expression if the checkbox is not already enabled. The exact
# state cannot be read reliably from this custom control, so click near the
# regex checkbox only when the user has opened the same task card layout.
Click-Relative -Process $process -X 2286 -Y 376

# Replace from current position. If the editor supports multiline regex, this
# should update exactly one function body.
Click-Relative -Process $process -X 2335 -Y 614
Start-Sleep -Seconds 1
Send-Keys "^(s)"

$readback = Export-EditorText -Process $process
[IO.File]::WriteAllText($readbackPath, $readback, [Text.Encoding]::UTF8)

$dimOk = $readback.Contains($NewDim)
$insertOk = $readback.Contains($InsertLine)
$subOk = $readback.Contains($info.SubLine)
$endOk = $readback -match '(?m)^\s*End\s+Sub\s*$'

$log = @(
  "ProcessId=$($process.Id)",
  "ScriptName=$ScriptName",
  "ExportPath=$exportPath",
  "BodyImportPath=$bodyPath",
  "ReadbackPath=$readbackPath",
  "FindRegex=$findRegex",
  "DimOk=$dimOk",
  "InsertOk=$insertOk",
  "SubOk=$subOk",
  "EndOk=$endOk"
)
[IO.File]::WriteAllLines($logPath, $log, [Text.Encoding]::UTF8)
Write-Output $logPath
if (-not ($dimOk -and $insertOk -and $subOk -and $endOk)) {
  throw "Regex replace readback failed. See $logPath"
}

