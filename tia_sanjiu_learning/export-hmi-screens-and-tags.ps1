param(
    [string]$OutputRoot = ".\tia_sanjiu_learning",
    [string[]]$ScreenNameLike = @("C1", "C2", "数据记录", "操作日志")
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

function Export-ScreenFolder {
    param($Folder, [string]$BaseDir, [string[]]$NameLike, $Log)
    foreach ($screen in $Folder.Screens) {
        $matched = $false
        foreach ($pattern in $NameLike) {
            if ($screen.Name -like "*$pattern*") { $matched = $true; break }
        }
        if ($matched) {
            $safeName = ($screen.Name -replace '[\\/:*?"<>|]', '_')
            $path = Join-Path $BaseDir ("screen_{0}.xml" -f $safeName)
            if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Force }
            $screen.Export([System.IO.FileInfo]$path, [Siemens.Engineering.ExportOptions]::WithDefaults)
            $Log.Add("EXPORT_SCREEN=$($screen.Name)|$path")
        }
    }
    foreach ($sub in $Folder.Folders) {
        Export-ScreenFolder -Folder $sub -BaseDir $BaseDir -NameLike $NameLike -Log $Log
    }
}

$OutputRoot = [System.IO.Path]::GetFullPath($OutputRoot)
$screenDir = Join-Path $OutputRoot "exports\screens"
$tagDir = Join-Path $OutputRoot "exports\tag_tables"
$logDir = Join-Path $OutputRoot "logs"
New-Item -ItemType Directory -Force -Path $screenDir, $tagDir, $logDir | Out-Null

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
    $log.Add("ProjectPath=$($project.Path)")
    $log.Add("HmiTarget=$($hmi.Name)")

    foreach ($table in $hmi.TagFolder.TagTables) {
        $safeName = ($table.Name -replace '[\\/:*?"<>|]', '_')
        $path = Join-Path $tagDir ("tagtable_{0}.xml" -f $safeName)
        if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Force }
        $table.Export([System.IO.FileInfo]$path, [Siemens.Engineering.ExportOptions]::WithDefaults)
        $log.Add("EXPORT_TAG_TABLE=$($table.Name)|$path")
    }

    Export-ScreenFolder -Folder $hmi.ScreenFolder -BaseDir $screenDir -NameLike $ScreenNameLike -Log $log
}
finally {
    if ($tia) { $tia.Dispose() }
}

$logPath = Join-Path $logDir "export_hmi_screens_and_tags.txt"
$log | Set-Content -LiteralPath $logPath -Encoding UTF8
$log
