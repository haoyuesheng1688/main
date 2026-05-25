param(
    [string]$ProjectRoot = "H:\程序优化\S4-弹窗\A3-赛奥5-高手\8赛奥5-last16_20260507M2",
    [string]$OutputRoot = ".\tia_rtpro_learning"
)

$ErrorActionPreference = "Stop"
$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
$OutputRoot = [System.IO.Path]::GetFullPath($OutputRoot)
$exportRoot = Join-Path $OutputRoot "exports\rtpro_raw_scripts"
$logDir = Join-Path $OutputRoot "logs"
New-Item -ItemType Directory -Force -Path $exportRoot, $logDir | Out-Null
$logPath = Join-Path $logDir "export_rtpro_script_snapshot.txt"
if (Test-Path -LiteralPath $logPath) { Remove-Item -LiteralPath $logPath -Force }
function LogLine([string]$s) { Add-Content -LiteralPath $logPath -Value $s -Encoding UTF8 }

$hmiDirs = Get-ChildItem -LiteralPath (Join-Path $ProjectRoot "IM\HMI\R") -Directory -Recurse -ErrorAction SilentlyContinue |
    Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName "ScriptLib") -PathType Container }
if (-not $hmiDirs) { throw "No RT Pro HMI ScriptLib directory found under $ProjectRoot" }

foreach ($hmiDir in $hmiDirs) {
    $rel = $hmiDir.FullName.Substring($ProjectRoot.Length).TrimStart("\")
    $safeRel = ($rel -replace '[\\/:*?"<>|]', '_')
    $dest = Join-Path $exportRoot $safeRel
    New-Item -ItemType Directory -Force -Path $dest | Out-Null
    foreach ($name in @("ScriptLib", "ScriptAct", "Config")) {
        $src = Join-Path $hmiDir.FullName $name
        if (Test-Path -LiteralPath $src) {
            $dst = Join-Path $dest $name
            New-Item -ItemType Directory -Force -Path $dst | Out-Null
            Get-ChildItem -LiteralPath $src -File -Force | Copy-Item -Destination $dst -Force
            foreach ($file in Get-ChildItem -LiteralPath $dst -File -Force) {
                $hash = Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256
                LogLine "COPIED=$($file.FullName)|SIZE=$($file.Length)|SHA256=$($hash.Hash)"
            }
        }
    }
}

LogLine "ProjectRoot=$ProjectRoot"
LogLine "ExportRoot=$exportRoot"
$logPath

