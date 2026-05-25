param(
    [string]$OutputRoot = ".\tia_rtpro_learning",
    [string]$DeviceName = "HMI-5X"
)

$ErrorActionPreference = "Stop"
$OutputRoot = [System.IO.Path]::GetFullPath($OutputRoot)
$logDir = Join-Path $OutputRoot "logs"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$logPath = Join-Path $logDir "compile_rtpro_hmi_device.txt"
if (Test-Path -LiteralPath $logPath) { Remove-Item -LiteralPath $logPath -Force }
function LogLine([string]$s) { Add-Content -LiteralPath $logPath -Value $s -Encoding UTF8 }

[System.Reflection.Assembly]::LoadFrom("C:\Program Files\Siemens\Automation\Portal V17\PublicAPI\V17\Siemens.Engineering.dll") | Out-Null

function Get-GenericService {
    param($Object, [Type]$ServiceType)
    $method = $Object.GetType().GetMethods() |
        Where-Object { $_.Name -eq "GetService" -and $_.IsGenericMethod -and $_.GetParameters().Count -eq 0 } |
        Select-Object -First 1
    if (-not $method) { return $null }
    return $method.MakeGenericMethod($ServiceType).Invoke($Object, @())
}

$process = [Siemens.Engineering.TiaPortal]::GetProcesses() |
    Where-Object { $_.Mode.ToString() -eq "WithUserInterface" -and $_.ProjectPath } |
    Select-Object -First 1
if (-not $process) { throw "No open TIA Portal UI process with a project path was found." }

$tia = $process.Attach()
try {
    $project = $tia.Projects | Select-Object -First 1
    if (-not $project) { throw "No open project in selected TIA process." }
    LogLine "ProjectName=$($project.Name)"
    LogLine "ProjectPath=$($project.Path)"

    $device = $project.Devices | Where-Object { $_.Name -eq $DeviceName } | Select-Object -First 1
    if (-not $device) { throw "Device not found: $DeviceName" }
    LogLine "CompileDevice=$($device.Name)|$($device.GetType().FullName)"

    $compiler = Get-GenericService -Object $device -ServiceType ([type]"Siemens.Engineering.Compiler.ICompilable")
    if (-not $compiler) { throw "Device does not expose ICompilable: $DeviceName" }
    $result = $compiler.Compile()
    LogLine "CompileState=$($result.State)"
    try {
        foreach ($message in $result.Messages) {
            try {
                LogLine "CompileMessage=$($message.State)|$($message.Path)|$($message.Description)"
            }
            catch {
                LogLine "CompileMessageReadWarning=$($_.Exception.Message)"
            }
        }
    }
    catch {
        LogLine "CompileMessagesReadWarning=$($_.Exception.Message)"
    }
    LogLine "ProjectModified=$($project.IsModified)"
}
finally {
    if ($tia) { $tia.Dispose() }
}

$logPath


