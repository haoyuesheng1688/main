$ErrorActionPreference = 'Stop'

$outDir = 'C:\Users\Administrator\Desktop\CodexOut'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

Get-ChildItem -LiteralPath 'C:\Users\Public\Documents\Siemens\WinCCProjects\1' -Force |
    Select-Object Name, FullName, Mode |
    Format-Table -AutoSize |
    Out-String -Width 240 |
    Set-Content -LiteralPath (Join-Path $outDir 'project_root.txt') -Encoding UTF8

Get-Process |
    Where-Object { $_.ProcessName -match 'WinCC|SCRIPT|PASSDBRT|SDIAGRT' } |
    Select-Object ProcessName, Id, MainWindowTitle |
    Format-Table -AutoSize |
    Out-String -Width 240 |
    Set-Content -LiteralPath (Join-Path $outDir 'processes.txt') -Encoding UTF8

Get-ChildItem -LiteralPath 'C:\Users\Public\Documents\Siemens\WinCCProjects\1' -Recurse -Include *.bac,*.pdl,*.fct,*.pas,*.mcp -ErrorAction SilentlyContinue |
    Select-Object FullName, Extension |
    Format-Table -AutoSize |
    Out-String -Width 300 |
    Set-Content -LiteralPath (Join-Path $outDir 'script_files.txt') -Encoding UTF8

'ok' | Set-Content -LiteralPath (Join-Path $outDir 'done.txt') -Encoding ASCII
