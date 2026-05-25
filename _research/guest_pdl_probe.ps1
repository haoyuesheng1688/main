$ErrorActionPreference = 'Stop'

$outDir = 'C:\Users\Administrator\Desktop\CodexOut'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

Get-ChildItem -LiteralPath 'C:\Users\Public\Documents\Siemens\WinCCProjects\1' -Recurse -Filter *.pdl -ErrorAction SilentlyContinue |
    Select-Object FullName, Name, Length, LastWriteTime |
    Format-Table -AutoSize |
    Out-String -Width 320 |
    Set-Content -LiteralPath (Join-Path $outDir 'pdl_only.txt') -Encoding UTF8

'ok' | Set-Content -LiteralPath (Join-Path $outDir 'done_pdl.txt') -Encoding ASCII
