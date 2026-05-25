param(
    [string]$ProjectPath,
    [string]$OutputDir = (Get-Location).Path
)

$ErrorActionPreference = 'Stop'

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$findScript = Join-Path $scriptRoot 'find-open-eplan-project.ps1'
$exportScript = Join-Path $scriptRoot 'export-eplan-io.ps1'

if ([string]::IsNullOrWhiteSpace($ProjectPath)) {
    $ProjectPath = & $findScript
}

if ([string]::IsNullOrWhiteSpace($ProjectPath)) {
    throw 'Could not determine the EPLAN project path.'
}

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

$env:EPLAN_PROJECT_PATH = $ProjectPath
$env:EPLAN_OUTPUT_DIR = $OutputDir

$args = '-STA -NoProfile -ExecutionPolicy Bypass -File "{0}"' -f $exportScript
$proc = Start-Process -FilePath 'powershell.exe' -ArgumentList $args -PassThru -Wait

$summaryPath = Join-Path $OutputDir 'eplan_io_summary.txt'
$csvPath = Join-Path $OutputDir 'eplan_io_points.csv'
$errorPath = Join-Path $OutputDir 'eplan_io_error.txt'

if ((Test-Path -LiteralPath $summaryPath) -and (Test-Path -LiteralPath $csvPath)) {
    [pscustomobject]@{
        ProjectPath = $ProjectPath
        OutputDir = $OutputDir
        SummaryPath = $summaryPath
        CsvPath = $csvPath
        ChildExitCode = $proc.ExitCode
    }
    exit 0
}

if (Test-Path -LiteralPath $errorPath) {
    throw (Get-Content -LiteralPath $errorPath -Raw)
}

throw "EPLAN IO export did not produce output files. ChildExitCode=$($proc.ExitCode)"
