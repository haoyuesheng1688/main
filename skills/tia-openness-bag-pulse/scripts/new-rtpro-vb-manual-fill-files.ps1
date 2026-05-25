param(
  [Parameter(Mandatory = $true)]
  [string]$SourcePath,
  [string]$OutputRoot = ".\tia_rtpro_learning",
  [string]$ScriptName = "DATA_Auto_CSV",
  [switch]$AddEnvironmentField
)

$ErrorActionPreference = "Stop"

function Get-EnvFieldName {
  # Avoid PowerShell 5 UTF-8-without-BOM decoding issues for the default
  # Chinese field name: 环境检测.
  return (-join ([char[]](0x73AF, 0x5883, 0x68C0, 0x6D4B)))
}

function Get-VbParts {
  param([string]$Text, [string]$Name)

  $normalized = $Text -replace "`r`n", "`n"
  $lines = $normalized -split "`n", -1
  $subIndex = -1
  $endIndex = -1

  for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($subIndex -lt 0 -and $lines[$i] -match ("^\s*Sub\s+" + [regex]::Escape($Name) + "\(\)\s*$")) {
      $subIndex = $i
    }
    if ($lines[$i] -match '^\s*End\s+Sub\s*$') {
      $endIndex = $i
    }
  }

  if ($subIndex -lt 0) { throw "Cannot find Sub $Name() line." }
  if ($endIndex -le $subIndex) { throw "Cannot find matching End Sub after Sub $Name()." }

  $bodyLines = @()
  if ($endIndex -gt ($subIndex + 1)) {
    $bodyLines = $lines[($subIndex + 1)..($endIndex - 1)]
  }

  [pscustomobject]@{
    FullText = $Text
    BodyText = ($bodyLines -join "`r`n")
    SubLine = $subIndex + 1
    EndLine = $endIndex + 1
  }
}

function Add-EnvFieldIfNeeded {
  param([string]$Body)

  $envName = Get-EnvFieldName
  $envLine = 'TagName(9) = "DATA1\' + $envName + '"'
  $updated = $Body

  if ($updated.Contains("Dim TagName(8),iLen")) {
    $updated = [regex]::Replace($updated, [regex]::Escape("Dim TagName(8),iLen"), "Dim TagName(9),iLen", 1)
  }

  if (-not $updated.Contains($envLine)) {
    $updated = [regex]::Replace($updated, '(?m)^(\s*TagName\(8\)\s*=\s*"DATA1\\[^"]*"\s*)$', {
      param($match)
      $match.Groups[1].Value + "`r`n" + $envLine
    }, 1)
  }

  return $updated
}

$resolvedSource = Resolve-Path -LiteralPath $SourcePath
$sourceText = [IO.File]::ReadAllText($resolvedSource, [Text.Encoding]::UTF8)
$parts = Get-VbParts -Text $sourceText -Name $ScriptName
$bodyText = $parts.BodyText

if ($AddEnvironmentField) {
  $bodyText = Add-EnvFieldIfNeeded -Body $bodyText
}

$root = Resolve-Path -LiteralPath $OutputRoot -ErrorAction SilentlyContinue
if (-not $root) {
  New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null
  $root = Resolve-Path -LiteralPath $OutputRoot
}

$outDir = Join-Path $root "manual_fill"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$suffix = if ($AddEnvironmentField) { "with_env" } else { "body_copy" }
$fullPath = Join-Path $outDir "$($ScriptName)_full_$($suffix)_$stamp.vbs"
$bodyPath = Join-Path $outDir "$($ScriptName)_body_only_$($suffix)_$stamp.vbs"

$fullText = $sourceText
if ($AddEnvironmentField) {
  $normalized = $sourceText -replace "`r`n", "`n"
  $lines = $normalized -split "`n", -1
  $before = @()
  if ($parts.SubLine -gt 1) { $before = $lines[0..($parts.SubLine - 1)] }
  $after = @()
  if ($parts.EndLine -le $lines.Count) { $after = $lines[($parts.EndLine - 1)..($lines.Count - 1)] }
  $fullText = (($before + ($bodyText -split "`r`n", -1) + $after) -join "`r`n")
}

[IO.File]::WriteAllText($fullPath, $fullText, [Text.Encoding]::UTF8)
[IO.File]::WriteAllText($bodyPath, $bodyText, [Text.Encoding]::UTF8)

$bodyHasSub = $bodyText -match '(?m)^\s*Sub\s+'
$bodyHasEnd = $bodyText -match '(?m)^\s*End\s+Sub\s*$'

Write-Output "FULL=$fullPath"
Write-Output "BODY=$bodyPath"
Write-Output "SUB_LINE=$($parts.SubLine)"
Write-Output "END_LINE=$($parts.EndLine)"
Write-Output "BODY_HAS_SUB=$bodyHasSub"
Write-Output "BODY_HAS_END=$bodyHasEnd"
Write-Output "ADD_ENV=$AddEnvironmentField"
