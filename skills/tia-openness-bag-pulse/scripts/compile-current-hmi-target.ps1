param(
    [string]$OutputRoot = ".\tia_popup_touch_sim"
)

$ErrorActionPreference = "Stop"

function Load-TiaV17Assemblies {
    [System.Reflection.Assembly]::LoadFrom("C:\Program Files\Siemens\Automation\Portal V17\PublicAPI\V17\Siemens.Engineering.dll") | Out-Null
    [System.Reflection.Assembly]::LoadFrom("C:\Program Files\Siemens\Automation\Portal V17\PublicAPI\V17\Siemens.Engineering.Hmi.dll") | Out-Null
}

function Get-SoftwareFromDeviceItem {
    param($DeviceItem, [Type]$SoftwareContainerType)
    $method = $DeviceItem.GetType().GetMethods() |
        Where-Object { $_.Name -eq "GetService" -and $_.IsGenericMethod -and $_.GetParameters().Count -eq 0 } |
        Select-Object -First 1
    if (-not $method) { return $null }
    $service = $method.MakeGenericMethod($SoftwareContainerType).Invoke($DeviceItem, @())
    if ($service) { return $service.Software }
    return $null
}

function Walk-DeviceItems {
    param($Items, [Type]$SoftwareContainerType)
    foreach ($item in $Items) {
        $software = Get-SoftwareFromDeviceItem -DeviceItem $item -SoftwareContainerType $SoftwareContainerType
        if ($software) { $software }
        if ($item.DeviceItems.Count -gt 0) {
            Walk-DeviceItems -Items $item.DeviceItems -SoftwareContainerType $SoftwareContainerType
        }
    }
}

function Compile-HmiTarget {
    param($Hmi)
    $method = $Hmi.GetType().GetMethods() |
        Where-Object { $_.Name -eq "GetService" -and $_.IsGenericMethod -and $_.GetParameters().Count -eq 0 } |
        Select-Object -First 1
    if (-not $method) { throw "HMI target does not expose generic GetService." }
    $provider = $method.MakeGenericMethod([Siemens.Engineering.Compiler.ICompilable]).Invoke($Hmi, @())
    if (-not $provider) { throw "HMI target did not return an ICompilable service." }
    return $provider.Compile()
}

$OutputRoot = [System.IO.Path]::GetFullPath($OutputRoot)
$logDir = Join-Path $OutputRoot "logs"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null

Load-TiaV17Assemblies
$process = [Siemens.Engineering.TiaPortal]::GetProcesses() |
    Where-Object { $_.Mode.ToString() -eq "WithUserInterface" -and $_.ProjectPath } |
    Select-Object -First 1
if (-not $process) { throw "No open TIA Portal UI process with a project path was found." }

$log = New-Object System.Collections.Generic.List[string]
$tia = $process.Attach()
try {
    $project = $tia.Projects | Select-Object -First 1
    if (-not $project) { throw "No open project in selected TIA process." }

    $softwareContainerType = [type]"Siemens.Engineering.HW.Features.SoftwareContainer"
    $software = foreach ($device in $project.Devices) {
        Walk-DeviceItems -Items $device.DeviceItems -SoftwareContainerType $softwareContainerType
    }
    $hmi = $software | Where-Object { $_.GetType().FullName -eq "Siemens.Engineering.Hmi.HmiTarget" } | Select-Object -First 1
    if (-not $hmi) { throw "No HMI target was found." }

    $log.Add("ProjectName=$($project.Name)")
    $log.Add("HmiTarget=$($hmi.Name)")
    $result = Compile-HmiTarget -Hmi $hmi
    $log.Add("CompileState=$($result.State)")
    foreach ($message in $result.Messages) {
        $log.Add("CompileMessage=$($message.State)|$($message.Path)|$($message.Description)")
    }
    $project.Save()
    $log.Add("ProjectSaved=True")
}
finally {
    if ($tia) { $tia.Dispose() }
}

$logPath = Join-Path $logDir "hmi_compile_loop.txt"
$log | Set-Content -LiteralPath $logPath -Encoding UTF8
$log
