param(
    [string]$OutputRoot = ".\tia_rtpro_learning"
)

$ErrorActionPreference = "Stop"

$OutputRoot = [System.IO.Path]::GetFullPath($OutputRoot)
$logDir = Join-Path $OutputRoot "logs"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$logPath = Join-Path $logDir "inspect_rtpro_tree.txt"
if (Test-Path -LiteralPath $logPath) { Remove-Item -LiteralPath $logPath -Force }

function LogLine {
    param([string]$Text)
    Add-Content -LiteralPath $logPath -Value $Text -Encoding UTF8
}

function Load-TiaV17Assemblies {
    [System.Reflection.Assembly]::LoadFrom("C:\Program Files\Siemens\Automation\Portal V17\PublicAPI\V17\Siemens.Engineering.dll") | Out-Null
    [System.Reflection.Assembly]::LoadFrom("C:\Program Files\Siemens\Automation\Portal V17\PublicAPI\V17\Siemens.Engineering.Hmi.dll") | Out-Null
}

function Get-GenericService {
    param($Object, [Type]$ServiceType)
    $method = $Object.GetType().GetMethods() |
        Where-Object { $_.Name -eq "GetService" -and $_.IsGenericMethod -and $_.GetParameters().Count -eq 0 } |
        Select-Object -First 1
    if (-not $method) { return $null }
    try {
        return $method.MakeGenericMethod($ServiceType).Invoke($Object, @())
    }
    catch {
        return $null
    }
}

function Log-Properties {
    param($Object, [string]$Prefix)
    $props = $Object.GetType().GetProperties() | Select-Object -ExpandProperty Name
    LogLine "$Prefix PROPERTIES=$($props -join ',')"
}

function Walk-DeviceItems {
    param($Items, [string]$Prefix, [Type]$SoftwareContainerType)
    foreach ($item in $Items) {
        LogLine "ITEM=$Prefix/$($item.Name)|TYPE=$($item.GetType().FullName)|CHILDREN=$($item.DeviceItems.Count)"
        Log-Properties -Object $item -Prefix "ITEM_PROPS=$Prefix/$($item.Name)"
        $svc = Get-GenericService -Object $item -ServiceType $SoftwareContainerType
        if ($svc) {
            LogLine "ITEM_SERVICE_SOFTWARE_CONTAINER=$Prefix/$($item.Name)|TYPE=$($svc.GetType().FullName)"
            if ($svc.Software) {
                $sw = $svc.Software
                LogLine "SOFTWARE=$Prefix/$($item.Name)|NAME=$($sw.Name)|TYPE=$($sw.GetType().FullName)"
                Log-Properties -Object $sw -Prefix "SOFTWARE_PROPS=$($sw.Name)"
            }
        }
        if ($item.DeviceItems.Count -gt 0) {
            Walk-DeviceItems -Items $item.DeviceItems -Prefix "$Prefix/$($item.Name)" -SoftwareContainerType $SoftwareContainerType
        }
    }
}

Load-TiaV17Assemblies
LogLine "START=$(Get-Date -Format s)"
$processes = [Siemens.Engineering.TiaPortal]::GetProcesses()
foreach ($p in $processes) {
    LogLine "TIA_PROCESS=Id:$($p.Id)|Mode:$($p.Mode)|ProjectPath:$($p.ProjectPath)"
}
$process = $processes | Where-Object { $_.Mode.ToString() -eq "WithUserInterface" -and $_.ProjectPath } | Select-Object -First 1
if (-not $process) { throw "No open TIA Portal UI process with a project path was found." }

$tia = $process.Attach()
try {
    $project = $tia.Projects | Select-Object -First 1
    if (-not $project) { throw "No open project in selected TIA process." }
    LogLine "PROJECT=$($project.Name)|PATH=$($project.Path)|DEVICES=$($project.Devices.Count)"
    $softwareContainerType = [type]"Siemens.Engineering.HW.Features.SoftwareContainer"

    foreach ($device in $project.Devices) {
        LogLine "DEVICE=$($device.Name)|TYPE=$($device.GetType().FullName)|ITEMS=$($device.DeviceItems.Count)"
        Log-Properties -Object $device -Prefix "DEVICE_PROPS=$($device.Name)"
        $svc = Get-GenericService -Object $device -ServiceType $softwareContainerType
        if ($svc) {
            LogLine "DEVICE_SERVICE_SOFTWARE_CONTAINER=$($device.Name)|TYPE=$($svc.GetType().FullName)"
            if ($svc.Software) {
                $sw = $svc.Software
                LogLine "DEVICE_SOFTWARE=$($device.Name)|NAME=$($sw.Name)|TYPE=$($sw.GetType().FullName)"
                Log-Properties -Object $sw -Prefix "DEVICE_SOFTWARE_PROPS=$($sw.Name)"
            }
        }
        Walk-DeviceItems -Items $device.DeviceItems -Prefix $device.Name -SoftwareContainerType $softwareContainerType
    }
}
finally {
    if ($tia) { $tia.Dispose() }
}
LogLine "END=$(Get-Date -Format s)"
$logPath

