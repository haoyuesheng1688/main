$ErrorActionPreference = 'Stop'

$outDir = 'C:\Users\Administrator\Desktop\CodexOut'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

$paths = @(
    'C:\Program Files (x86)\Siemens\WinCC',
    'C:\Program Files\Siemens\WinCC'
) | Where-Object { Test-Path $_ }

foreach ($path in $paths) {
    $safeName = ($path -replace '[:\\ ]', '_').Trim('_')
    Get-ChildItem -LiteralPath $path -Recurse -Include *tag*,*script*,*import*,*export*,*.exe -ErrorAction SilentlyContinue |
        Sort-Object FullName |
        Select-Object FullName, Name, Extension |
        Format-Table -AutoSize |
        Out-String -Width 320 |
        Set-Content -LiteralPath (Join-Path $outDir ("tools_" + $safeName + ".txt")) -Encoding UTF8
}

'ok' | Set-Content -LiteralPath (Join-Path $outDir 'done_tools.txt') -Encoding ASCII
