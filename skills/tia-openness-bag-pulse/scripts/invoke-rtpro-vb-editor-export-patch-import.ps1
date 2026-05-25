param(
  [int]$ProcessId = 0,
  [string]$OutputRoot = ".\tia_rtpro_learning",
  [string]$ScriptName = "DATA_Auto_CSV",
  [string]$OldDim = "Dim TagName(8),iLen",
  [string]$NewDim = "Dim TagName(9),iLen",
  [string]$AfterLine = 'TagName(8) = "DATA1\露点温度"',
  [string]$InsertLine = 'TagName(9) = "DATA1\环境检测"',
  [int]$EditorClickX = 440,
  [int]$EditorClickY = 220
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName Microsoft.VisualBasic

Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class CodexWin32 {
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int X, int Y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint dwFlags, uint dx, uint dy, uint dwData, UIntPtr dwExtraInfo);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
}
'@

function Get-TargetPortalProcess {
  if ($ProcessId -ne 0) {
    return Get-Process -Id $ProcessId -ErrorAction Stop
  }

  $candidates = Get-Process -Name "Siemens.Automation.Portal" -ErrorAction Stop |
    Where-Object { $_.MainWindowHandle -ne [IntPtr]::Zero -and $_.MainWindowTitle }

  $withScript = $candidates | Where-Object { $_.MainWindowTitle -like "*$ScriptName*" } | Select-Object -First 1
  if ($withScript) { return $withScript }

  $withProject = $candidates | Where-Object { $_.MainWindowTitle -like "*WinCC RT Professional*" -or $_.MainWindowTitle -like "*赛奥*" } | Select-Object -First 1
  if ($withProject) { return $withProject }

  return $candidates | Select-Object -First 1
}

function Activate-Portal {
  param([System.Diagnostics.Process]$Process)
  [Microsoft.VisualBasic.Interaction]::AppActivate($Process.Id) | Out-Null
  [CodexWin32]::SetForegroundWindow($Process.MainWindowHandle) | Out-Null
  Start-Sleep -Milliseconds 700
}

function Click-Editor {
  param([System.Diagnostics.Process]$Process)
  [CodexWin32+RECT]$rect = New-Object CodexWin32+RECT
  [CodexWin32]::GetWindowRect($Process.MainWindowHandle, [ref]$rect) | Out-Null
  $x = $rect.Left + $EditorClickX
  $y = $rect.Top + $EditorClickY
  [CodexWin32]::SetCursorPos($x, $y) | Out-Null
  [CodexWin32]::mouse_event(0x0002, 0, 0, 0, [UIntPtr]::Zero)
  Start-Sleep -Milliseconds 80
  [CodexWin32]::mouse_event(0x0004, 0, 0, 0, [UIntPtr]::Zero)
  Start-Sleep -Milliseconds 500
}

function Send-Keys {
  param([string]$Keys)
  [System.Windows.Forms.SendKeys]::SendWait($Keys)
  Start-Sleep -Milliseconds 450
}

function Get-EditorText {
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
    throw "Failed to copy editor text. Open the VB script editor and place focus in the code pane."
  }
  return $text
}

function Set-EditorText {
  param(
    [System.Diagnostics.Process]$Process,
    [string]$Text
  )
  Activate-Portal $Process
  Click-Editor $Process
  Send-Keys "{ESC}"
  Set-Clipboard -Value $Text
  Start-Sleep -Milliseconds 250
  Send-Keys "^(a)"
  Send-Keys "^(v)"
  Send-Keys "^(s)"
}

function Patch-DataAutoCsvText {
  param([string]$Text)

  $patched = $Text
  if ($patched -notmatch [regex]::Escape($InsertLine)) {
    if ($patched -match [regex]::Escape($OldDim)) {
      $patched = [regex]::Replace($patched, [regex]::Escape($OldDim), [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $NewDim }, 1)
    }
    elseif ($patched -notmatch [regex]::Escape($NewDim)) {
      throw "Cannot find array dimension line: $OldDim"
    }

    $afterPattern = [regex]::Escape($AfterLine)
    if ($patched -notmatch $afterPattern) {
      throw "Cannot find insertion anchor line: $AfterLine"
    }

    $newline = if ($patched -match "`r`n") { "`r`n" } else { "`n" }
    $patched = $patched -replace $afterPattern, ($AfterLine + $newline + $InsertLine)
  }
  else {
    if ($patched -match [regex]::Escape($OldDim)) {
      $patched = [regex]::Replace($patched, [regex]::Escape($OldDim), [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $NewDim }, 1)
    }
  }

  return $patched
}

$root = Resolve-Path -LiteralPath $OutputRoot -ErrorAction SilentlyContinue
if (-not $root) {
  New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null
  $root = Resolve-Path -LiteralPath $OutputRoot
}
$exportDir = Join-Path $root "exports\rtpro_vb_editor"
$importDir = Join-Path $root "imports\rtpro_vb_editor"
$verifyDir = Join-Path $root "verify"
New-Item -ItemType Directory -Force -Path $exportDir, $importDir, $verifyDir | Out-Null

$process = Get-TargetPortalProcess
if (-not $process) { throw "No Siemens.Automation.Portal window was found." }

$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$exportPath = Join-Path $exportDir "$($ScriptName)_export_$stamp.vbs"
$patchedPath = Join-Path $importDir "$($ScriptName)_patched_$stamp.vbs"
$readbackPath = Join-Path $verifyDir "$($ScriptName)_readback_$stamp.vbs"
$logPath = Join-Path $verifyDir "$($ScriptName)_export_patch_import_$stamp.txt"

$originalText = Get-EditorText $process
[IO.File]::WriteAllText($exportPath, $originalText, [Text.Encoding]::UTF8)

$patchedText = Patch-DataAutoCsvText $originalText
[IO.File]::WriteAllText($patchedPath, $patchedText, [Text.Encoding]::UTF8)

Set-EditorText -Process $process -Text $patchedText

$readbackText = Get-EditorText $process
[IO.File]::WriteAllText($readbackPath, $readbackText, [Text.Encoding]::UTF8)

$dimOk = $readbackText.Contains($NewDim)
$insertOk = $readbackText.Contains($InsertLine)
$log = @(
  "ProcessId=$($process.Id)",
  "WindowTitle=$($process.MainWindowTitle)",
  "ScriptName=$ScriptName",
  "ExportPath=$exportPath",
  "PatchedPath=$patchedPath",
  "ReadbackPath=$readbackPath",
  "DimOk=$dimOk",
  "InsertOk=$insertOk",
  "OldLength=$($originalText.Length)",
  "PatchedLength=$($patchedText.Length)",
  "ReadbackLength=$($readbackText.Length)"
)
[IO.File]::WriteAllLines($logPath, $log, [Text.Encoding]::UTF8)

Write-Output $logPath
if (-not ($dimOk -and $insertOk)) {
  throw "Import readback did not contain expected lines. See $logPath"
}

