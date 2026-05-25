param(
  [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
)

$ErrorActionPreference = 'Stop'
$rootPath = (Resolve-Path -LiteralPath $Root).Path

$rootFiles = Get-ChildItem -LiteralPath $rootPath -File -Force
$skills = Get-ChildItem -LiteralPath $rootPath -Recurse -Filter SKILL.md -File -ErrorAction SilentlyContinue |
  Where-Object { $_.FullName -notmatch '\\_archive\\' }

[pscustomobject]@{
  Root = $rootPath
  RootFileCount = $rootFiles.Count
  RootFilesByExtension = ($rootFiles | Group-Object Extension | Sort-Object Count -Descending | ForEach-Object { "$($_.Name):$($_.Count)" }) -join '; '
  SkillCount = $skills.Count
  ArchiveExists = Test-Path -LiteralPath (Join-Path $rootPath '_archive')
}

Write-Host ''
Write-Host 'Root files:'
$rootFiles | Select-Object Name,Length,LastWriteTime | Format-Table -AutoSize

Write-Host ''
Write-Host 'Skills outside archive:'
$skills | ForEach-Object { $_.FullName.Substring($rootPath.Length + 1) } | Sort-Object
