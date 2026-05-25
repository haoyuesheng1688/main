param(
  [int]$ProcessId = 0,
  [string]$OutputRoot = ".\tia_rtpro_learning",
  [string]$ScriptName = "DATA_Auto_CSV",
  [string]$OldDim = "Dim TagName(8),iLen",
  [string]$NewDim = "Dim TagName(9),iLen",
  [string]$AfterLine = 'TagName(8) = "DATA1\露点温度"',
  [string]$InsertLine = 'TagName(9) = "DATA1\环境检测"',
  [int]$EditorClickX = 520,
  [int]$EditorClickY = 230,
  [switch]$SelectOnly
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName Microsoft.VisualBasic

Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class CodexVbBodyImportWin32 {
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int X, int Y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint dwFlags, uint dx, uint dy, uint dwData, UIntPtr dwExtraInfo);
  [DllImport("user32.dll")] public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, UIntPtr dwExtraInfo);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
}
'@

function Get-TargetPortalProcess {
  if ($ProcessId -ne 0) {
    return Get-Process -Id $ProcessId -ErrorAction Stop
  }

  $candidates = Get-Process -Name "Siemens.Automation.Portal" -ErrorAction Stop |
    Where-Object { $_.MainWindowHandle -ne [IntPtr]::Zero -and $_.MainWindowTitle }

  $match = $candidates | Where-Object { $_.MainWindowTitle -like "*$ScriptName*" } | Select-Object -First 1
  if ($match) { return $match }

  return $candidates | Select-Object -First 1
}

function Activate-Portal {
  param([System.Diagnostics.Process]$Process)
  [Microsoft.VisualBasic.Interaction]::AppActivate($Process.Id) | Out-Null
  [CodexVbBodyImportWin32]::SetForegroundWindow($Process.MainWindowHandle) | Out-Null
  Start-Sleep -Milliseconds 700
}

function Click-Editor {
  param([System.Diagnostics.Process]$Process)
  [CodexVbBodyImportWin32+RECT]$rect = New-Object CodexVbBodyImportWin32+RECT
  [CodexVbBodyImportWin32]::GetWindowRect($Process.MainWindowHandle, [ref]$rect) | Out-Null
  [CodexVbBodyImportWin32]::SetCursorPos(($rect.Left + $EditorClickX), ($rect.Top + $EditorClickY)) | Out-Null
  [CodexVbBodyImportWin32]::mouse_event(0x0002, 0, 0, 0, [UIntPtr]::Zero)
  Start-Sleep -Milliseconds 80
  [CodexVbBodyImportWin32]::mouse_event(0x0004, 0, 0, 0, [UIntPtr]::Zero)
  Start-Sleep -Milliseconds 500
}

function Send-Keys {
  param([string]$Keys, [int]$DelayMs = 350)
  [System.Windows.Forms.SendKeys]::SendWait($Keys)
  Start-Sleep -Milliseconds $DelayMs
}

function Send-KeyDown {
  param([byte]$Vk)
  [CodexVbBodyImportWin32]::keybd_event($Vk, 0, 0, [UIntPtr]::Zero)
}

function Send-KeyUp {
  param([byte]$Vk)
  [CodexVbBodyImportWin32]::keybd_event($Vk, 0, 0x0002, [UIntPtr]::Zero)
}

function Tap-Key {
  param([byte]$Vk, [int]$DelayMs = 20)
  Send-KeyDown $Vk
  Start-Sleep -Milliseconds $DelayMs
  Send-KeyUp $Vk
  Start-Sleep -Milliseconds $DelayMs
}

function Send-CtrlKey {
  param([byte]$Vk)
  Send-KeyDown 0x11
  Tap-Key $Vk 30
  Send-KeyUp 0x11
  Start-Sleep -Milliseconds 250
}

function Send-CtrlShiftKey {
  param([byte]$Vk)
  Send-KeyDown 0x11
  Send-KeyDown 0x10
  Tap-Key $Vk 30
  Send-KeyUp 0x10
  Send-KeyUp 0x11
  Start-Sleep -Milliseconds 250
}

function Send-ShiftKey {
  param([byte]$Vk)
  Send-KeyDown 0x10
  Tap-Key $Vk 30
  Send-KeyUp 0x10
  Start-Sleep -Milliseconds 250
}

function GoTo-Line {
  param([int]$LineNumber)
  Send-CtrlKey 0x47
  Set-Clipboard -Value ([string]$LineNumber)
  Start-Sleep -Milliseconds 150
  Send-CtrlKey 0x41
  Send-CtrlKey 0x56
  Tap-Key 0x0D 30
  Start-Sleep -Milliseconds 400
}

function Move-CaretToLineStart {
  param([int]$LineNumber)
  if ($LineNumber -lt 1) { throw "Invalid line number: $LineNumber" }
  Send-CtrlKey 0x24
  $downCount = $LineNumber - 1
  for ($i = 0; $i -lt $downCount; $i++) {
    Tap-Key 0x28 5
  }
  Tap-Key 0x24 10
  Start-Sleep -Milliseconds 200
}

function Find-TextInEditor {
  param([string]$Text)
  Set-Clipboard -Value $Text
  Start-Sleep -Milliseconds 200
  Send-CtrlKey 0x46
  Send-CtrlKey 0x41
  Send-CtrlKey 0x56
  Tap-Key 0x0D 30
  Start-Sleep -Milliseconds 500
  Tap-Key 0x1B 30
  Start-Sleep -Milliseconds 250
}

function Move-CaretToBodyStartAfterSub {
  param([string]$SubLineText)
  Find-TextInEditor -Text $SubLineText
  Tap-Key 0x23 20
  Tap-Key 0x28 20
  Tap-Key 0x24 20
  Start-Sleep -Milliseconds 250
}

function Select-LineRangeByKeyboard {
  param(
    [int]$StartLine,
    [int]$ExclusiveEndLine,
    [string]$SubLineText = ""
  )
  if ($ExclusiveEndLine -le $StartLine) {
    throw "Invalid selection: start $StartLine, exclusive end $ExclusiveEndLine"
  }

  GoTo-Line -LineNumber $StartLine
  Tap-Key 0x24 20
  Send-CtrlShiftKey 0x23
  Send-ShiftKey 0x26
  Start-Sleep -Milliseconds 300
}

function Select-VbFunctionBody {
  param(
    [System.Diagnostics.Process]$Process,
    [string]$SubLineText,
    [int]$BodyStartLine,
    [int]$EndSubLine
  )

  Activate-Portal $Process
  Click-Editor $Process
  Send-Keys "{ESC}"
  Select-LineRangeByKeyboard -StartLine $BodyStartLine -ExclusiveEndLine $EndSubLine -SubLineText $SubLineText
  $selected = Get-SelectedText
  if ($selected -match '^\s*Sub\s+\S+\s*\(' -or $selected -match '(?m)^\s*End\s+Sub\s*$') {
    $selectionPath = Join-Path $verifyDir "$($ScriptName)_bad_selection_$stamp.vbs"
    [IO.File]::WriteAllText($selectionPath, $selected, [Text.Encoding]::UTF8)
    throw "Selection included generated Sub/End Sub lines. Bad selection saved to $selectionPath"
  }
  if ([string]::IsNullOrWhiteSpace($selected)) {
    throw "Body selection was empty."
  }
  return $selected
}

function Get-SelectedText {
  Set-Clipboard -Value "__codex_no_selection__"
  Start-Sleep -Milliseconds 100
  Send-CtrlKey 0x43
  return (Get-Clipboard -Raw)
}

function Export-EditorText {
  param([System.Diagnostics.Process]$Process)
  Activate-Portal $Process
  Click-Editor $Process
  Send-Keys "{ESC}"
  Send-Keys "^(a)"
  Set-Clipboard -Value "__codex_empty__"
  Start-Sleep -Milliseconds 150
  Send-Keys "^(c)"
  $text = Get-Clipboard -Raw
  if ([string]::IsNullOrWhiteSpace($text) -or $text -eq "__codex_empty__") {
    throw "Failed to copy editor text. Open $ScriptName in the VB code editor first."
  }
  return $text
}

function Patch-SourceText {
  param([string]$Text)
  $patched = $Text
  if ($patched -match [regex]::Escape($OldDim)) {
    $patched = [regex]::Replace($patched, [regex]::Escape($OldDim), [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $NewDim }, 1)
  }
  elseif ($patched -notmatch [regex]::Escape($NewDim)) {
    throw "Cannot find array dimension line: $OldDim"
  }

  if ($patched -notmatch [regex]::Escape($InsertLine)) {
    if ($patched -notmatch [regex]::Escape($AfterLine)) {
      throw "Cannot find insertion anchor line: $AfterLine"
    }
    $newline = if ($patched -match "`r`n") { "`r`n" } else { "`n" }
    $patched = [regex]::Replace($patched, [regex]::Escape($AfterLine), [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $AfterLine + $newline + $InsertLine }, 1)
  }

  return $patched
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
    Lines = $lines
    SubLine = $subIndex + 1
    BodyStartLine = $subIndex + 2
    EndSubLine = $endIndex + 1
    BodyLineCount = [Math]::Max(0, $endIndex - $subIndex - 1)
    BodyText = (($bodyLines -join "`r`n") + "`r`n")
    SubLineText = $lines[$subIndex]
  }
}

function Import-BodyOnly {
  param(
    [System.Diagnostics.Process]$Process,
    [int]$BodyStartLine,
    [int]$EndSubLine,
    [string]$SubLineText,
    [string]$BodyText
  )

  if ($EndSubLine -le $BodyStartLine) {
    throw "Invalid line range: body starts at $BodyStartLine, End Sub at $EndSubLine"
  }

  [void](Select-VbFunctionBody -Process $Process -SubLineText $SubLineText -BodyStartLine $BodyStartLine -EndSubLine $EndSubLine)

  Set-Clipboard -Value $BodyText
  Start-Sleep -Milliseconds 250
  Tap-Key 0x2E 80
  Start-Sleep -Milliseconds 250
  Send-CtrlKey 0x56
  Send-Keys "^(s)" 700
}

$root = Resolve-Path -LiteralPath $OutputRoot -ErrorAction SilentlyContinue
if (-not $root) {
  New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null
  $root = Resolve-Path -LiteralPath $OutputRoot
}
$exportDir = Join-Path $root "exports\rtpro_vb_body"
$importDir = Join-Path $root "imports\rtpro_vb_body"
$verifyDir = Join-Path $root "verify"
New-Item -ItemType Directory -Force -Path $exportDir, $importDir, $verifyDir | Out-Null

$process = Get-TargetPortalProcess
if (-not $process) { throw "No Siemens.Automation.Portal window was found." }

$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$exportPath = Join-Path $exportDir "$($ScriptName)_export_full_$stamp.vbs"
$patchedPath = Join-Path $importDir "$($ScriptName)_patched_full_$stamp.vbs"
$bodyPath = Join-Path $importDir "$($ScriptName)_patched_body_$stamp.vbs"
$readbackPath = Join-Path $verifyDir "$($ScriptName)_readback_body_import_$stamp.vbs"
$logPath = Join-Path $verifyDir "$($ScriptName)_body_export_patch_import_$stamp.txt"

$original = Export-EditorText -Process $process
[IO.File]::WriteAllText($exportPath, $original, [Text.Encoding]::UTF8)

$originalInfo = Get-VbBodyInfo -Text $original
$patched = Patch-SourceText -Text $original
$patchedInfo = Get-VbBodyInfo -Text $patched
[IO.File]::WriteAllText($patchedPath, $patched, [Text.Encoding]::UTF8)
[IO.File]::WriteAllText($bodyPath, $patchedInfo.BodyText, [Text.Encoding]::UTF8)

if ($SelectOnly) {
  $selected = Select-VbFunctionBody -Process $process -SubLineText $originalInfo.SubLineText -BodyStartLine $originalInfo.BodyStartLine -EndSubLine $originalInfo.EndSubLine
  $selectionPath = Join-Path $verifyDir "$($ScriptName)_selected_body_$stamp.vbs"
  [IO.File]::WriteAllText($selectionPath, $selected, [Text.Encoding]::UTF8)
  $log = @(
    "ProcessId=$($process.Id)",
    "WindowTitle=$($process.MainWindowTitle)",
    "ScriptName=$ScriptName",
    "ExportPath=$exportPath",
    "PatchedPath=$patchedPath",
    "BodyImportPath=$bodyPath",
    "SelectedBodyPath=$selectionPath",
    "SubLine=$($originalInfo.SubLine)",
    "BodyStartLine=$($originalInfo.BodyStartLine)",
    "EndSubLine=$($originalInfo.EndSubLine)",
    "BodyLineCount=$($originalInfo.BodyLineCount)",
    "SelectOnly=True"
  )
  [IO.File]::WriteAllLines($logPath, $log, [Text.Encoding]::UTF8)
  Write-Output $logPath
  return
}

Import-BodyOnly -Process $process -BodyStartLine $originalInfo.BodyStartLine -EndSubLine $originalInfo.EndSubLine -SubLineText $originalInfo.SubLineText -BodyText $patchedInfo.BodyText

$readback = Export-EditorText -Process $process
[IO.File]::WriteAllText($readbackPath, $readback, [Text.Encoding]::UTF8)

$dimOk = $readback.Contains($NewDim)
$insertOk = $readback.Contains($InsertLine)
$subProtected = $readback -match '^\s*Sub\s+\S+\s*\('
$endProtected = $readback -match '(?m)^\s*End\s+Sub\s*$'

$log = @(
  "ProcessId=$($process.Id)",
  "WindowTitle=$($process.MainWindowTitle)",
  "ScriptName=$ScriptName",
  "ExportPath=$exportPath",
  "PatchedPath=$patchedPath",
  "BodyImportPath=$bodyPath",
  "ReadbackPath=$readbackPath",
  "SubLine=$($originalInfo.SubLine)",
  "BodyStartLine=$($originalInfo.BodyStartLine)",
  "EndSubLine=$($originalInfo.EndSubLine)",
  "BodyLineCount=$($originalInfo.BodyLineCount)",
  "DimOk=$dimOk",
  "InsertOk=$insertOk",
  "SubProtectedPresent=$subProtected",
  "EndSubProtectedPresent=$endProtected"
)
[IO.File]::WriteAllLines($logPath, $log, [Text.Encoding]::UTF8)

Write-Output $logPath
if (-not ($dimOk -and $insertOk -and $subProtected -and $endProtected)) {
  throw "Body-only import readback did not contain expected lines. See $logPath"
}





