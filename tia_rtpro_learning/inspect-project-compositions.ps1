param([string]$OutputRoot = ".\tia_rtpro_learning")

$ErrorActionPreference = "Stop"
$OutputRoot = [System.IO.Path]::GetFullPath($OutputRoot)
$logDir = Join-Path $OutputRoot "logs"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$logPath = Join-Path $logDir "inspect_project_compositions.txt"
if (Test-Path -LiteralPath $logPath) { Remove-Item -LiteralPath $logPath -Force }
function LogLine([string]$s) { Add-Content -LiteralPath $logPath -Value $s -Encoding UTF8 }

[System.Reflection.Assembly]::LoadFrom("C:\Program Files\Siemens\Automation\Portal V17\PublicAPI\V17\Siemens.Engineering.dll") | Out-Null
[System.Reflection.Assembly]::LoadFrom("C:\Program Files\Siemens\Automation\Portal V17\PublicAPI\V17\Siemens.Engineering.Hmi.dll") | Out-Null

$process = [Siemens.Engineering.TiaPortal]::GetProcesses() |
    Where-Object { $_.Mode.ToString() -eq "WithUserInterface" -and $_.ProjectPath } |
    Select-Object -First 1
if (-not $process) { throw "No open TIA Portal UI process with a project path was found." }

$tia = $process.Attach()
try {
    $project = $tia.Projects | Select-Object -First 1
    LogLine "PROJECT_TYPE=$($project.GetType().FullName)"
    foreach ($prop in $project.GetType().GetProperties()) {
        try {
            $value = $prop.GetValue($project, $null)
            $valueType = if ($value) { $value.GetType().FullName } else { "<null>" }
            LogLine "PROJECT_PROP=$($prop.Name)|PROP_TYPE=$($prop.PropertyType.FullName)|VALUE_TYPE=$valueType"
            if ($value -and ($prop.Name -match "Hmi|Screen|Script|Runtime|Device|Group|Folder|Composition|Items|Devices")) {
                $countProp = $value.GetType().GetProperty("Count")
                if ($countProp) {
                    try { LogLine "PROJECT_PROP_COUNT=$($prop.Name)|$($countProp.GetValue($value,$null))" } catch {}
                }
            }
        }
        catch {
            LogLine "PROJECT_PROP_ERR=$($prop.Name)|$($_.Exception.Message)"
        }
    }

    foreach ($method in $project.GetType().GetMethods()) {
        if ($method.Name -match "Hmi|Screen|Script|Runtime|Find|Get|Service|Composition|Device") {
            LogLine "PROJECT_METHOD=$($method.Name)|GENERIC=$($method.IsGenericMethod)|PARAMS=$($method.GetParameters().Count)|RET=$($method.ReturnType.FullName)"
        }
    }
}
finally {
    if ($tia) { $tia.Dispose() }
}

$logPath

