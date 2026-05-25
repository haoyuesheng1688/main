$ErrorActionPreference = 'Stop'
$logPath = 'C:\Users\QF100\Documents\New project\tia_popup_touch_sim\logs\hmi_tag_table_inventory.txt'
$outDir = 'C:\Users\QF100\Documents\New project\tia_popup_touch_sim\exports\all_hmi_tag_tables'
New-Item -ItemType Directory -Force -Path (Split-Path $logPath), $outDir | Out-Null
$log = New-Object System.Collections.Generic.List[string]
[System.Reflection.Assembly]::LoadFrom('C:\Program Files\Siemens\Automation\Portal V17\PublicAPI\V17\Siemens.Engineering.dll') | Out-Null
[System.Reflection.Assembly]::LoadFrom('C:\Program Files\Siemens\Automation\Portal V17\PublicAPI\V17\Siemens.Engineering.Hmi.dll') | Out-Null
function Get-SoftwareFromDeviceItem { param($DeviceItem, [Type]$SoftwareContainerType)
  $method = $DeviceItem.GetType().GetMethods() | Where-Object { $_.Name -eq 'GetService' -and $_.IsGenericMethod -and $_.GetParameters().Count -eq 0 } | Select-Object -First 1
  if (-not $method) { return $null }
  $service = $method.MakeGenericMethod($SoftwareContainerType).Invoke($DeviceItem, @())
  if ($service) { return $service.Software }
}
function Walk-DeviceItems { param($Items, [Type]$SoftwareContainerType)
  foreach ($item in $Items) {
    $software = Get-SoftwareFromDeviceItem -DeviceItem $item -SoftwareContainerType $SoftwareContainerType
    if ($software) { $software }
    if ($item.DeviceItems.Count -gt 0) { Walk-DeviceItems -Items $item.DeviceItems -SoftwareContainerType $SoftwareContainerType }
  }
}
$p = [Siemens.Engineering.TiaPortal]::GetProcesses() | Where-Object { $_.Mode.ToString() -eq 'WithUserInterface' -and $_.ProjectPath } | Select-Object -First 1
$tia = $p.Attach()
try {
  $project = $tia.Projects | Select-Object -First 1
  $log.Add('Project=' + $project.Name)
  $softwareContainerType = [type]'Siemens.Engineering.HW.Features.SoftwareContainer'
  $software = foreach ($device in $project.Devices) { Walk-DeviceItems -Items $device.DeviceItems -SoftwareContainerType $softwareContainerType }
  $hmi = $software | Where-Object { $_.GetType().FullName -eq 'Siemens.Engineering.Hmi.HmiTarget' } | Select-Object -First 1
  $log.Add('Hmi=' + $hmi.Name)
  foreach($table in $hmi.TagFolder.TagTables){
    $safe = ($table.Name -replace '[\\/:*?"<>|]', '_')
    $path = Join-Path $outDir ($safe + '.xml')
    if(Test-Path -LiteralPath $path){ Remove-Item -LiteralPath $path -Force }
    try { $table.Export([System.IO.FileInfo]$path, [Siemens.Engineering.ExportOptions]::WithDefaults); $log.Add('Exported=' + $table.Name + '|' + $path) }
    catch { $log.Add('ExportFailed=' + $table.Name + '|' + $_.Exception.Message) }
  }
}
finally { if($tia){ $tia.Dispose() } }
$log | Set-Content -LiteralPath $logPath -Encoding UTF8
