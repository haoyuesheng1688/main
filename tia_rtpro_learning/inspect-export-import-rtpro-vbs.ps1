param(
    [string]$OutputRoot = ".\tia_rtpro_learning",
    [switch]$SkipImport
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
    param($Items, [Type]$SoftwareContainerType, [string]$Prefix = "")
    foreach ($item in $Items) {
        $software = Get-SoftwareFromDeviceItem -DeviceItem $item -SoftwareContainerType $SoftwareContainerType
        if ($software) {
            [pscustomobject]@{
                DeviceItemName = $item.Name
                Path = "$Prefix/$($item.Name)"
                Software = $software
            }
        }
        if ($item.DeviceItems.Count -gt 0) {
            Walk-DeviceItems -Items $item.DeviceItems -SoftwareContainerType $SoftwareContainerType -Prefix "$Prefix/$($item.Name)"
        }
    }
}

function Safe-FileName {
    param([string]$Name)
    return ($Name -replace '[\\/:*?"<>|]', '_')
}

function Get-PropertyValue {
    param($Object, [string]$Name)
    $prop = $Object.GetType().GetProperty($Name)
    if (-not $prop) { return $null }
    return $prop.GetValue($Object, $null)
}

function Export-VBScriptsFromFolder {
    param($Folder, [string]$ExportDir, [string]$Prefix, $Log)

    $scripts = Get-PropertyValue -Object $Folder -Name "VBScripts"
    if ($scripts) {
        foreach ($script in $scripts) {
            $safe = Safe-FileName -Name ($Prefix + $script.Name)
            $path = Join-Path $ExportDir ("vbscript_{0}.xml" -f $safe)
            if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Force }
            $script.Export([System.IO.FileInfo]$path, [Siemens.Engineering.ExportOptions]::WithDefaults)
            $Log.Add("EXPORT_VBSCRIPT=$($script.Name)|$path")
        }
    }

    $folders = Get-PropertyValue -Object $Folder -Name "Folders"
    if ($folders) {
        foreach ($sub in $folders) {
            Export-VBScriptsFromFolder -Folder $sub -ExportDir $ExportDir -Prefix ($Prefix + (Safe-FileName -Name $sub.Name) + "_") -Log $Log
        }
    }
}

function New-TestVBScriptXml {
    param([string]$Path)
    $content = @'
<?xml version="1.0" encoding="utf-8"?>
<Document>
  <Engineering version="V17" />
  <Hmi.VBScript.Script ID="0">
    <AttributeList>
      <Code>' Codex RT Professional import/export probe.
Dim codex_probe_result
codex_probe_result = "RTPro_VB_OK"</Code>
      <Name>Codex_RTPro_VB_IO_Loop</Name>
      <PreCode>

</PreCode>
      <Type>Sub</Type>
    </AttributeList>
    <ObjectList />
  </Hmi.VBScript.Script>
</Document>
'@
    Set-Content -LiteralPath $Path -Value $content -Encoding UTF8
}

$OutputRoot = [System.IO.Path]::GetFullPath($OutputRoot)
$exportDir = Join-Path $OutputRoot "exports"
$scriptDir = Join-Path $exportDir "vbscripts"
$importDir = Join-Path $OutputRoot "imports"
$verifyDir = Join-Path $OutputRoot "verify"
$logDir = Join-Path $OutputRoot "logs"
New-Item -ItemType Directory -Force -Path $scriptDir, $importDir, $verifyDir, $logDir | Out-Null

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

    $log.Add("ProjectName=$($project.Name)")
    $log.Add("ProjectPath=$($project.Path)")

    $softwareContainerType = [type]"Siemens.Engineering.HW.Features.SoftwareContainer"
    $softwareInfos = foreach ($device in $project.Devices) {
        Walk-DeviceItems -Items $device.DeviceItems -SoftwareContainerType $softwareContainerType -Prefix $device.Name
    }

    foreach ($info in $softwareInfos) {
        $sw = $info.Software
        $log.Add("SOFTWARE=$($info.Path)|$($sw.Name)|$($sw.GetType().FullName)")
    }

    $hmiInfos = $softwareInfos | Where-Object {
        $_.Software.GetType().FullName -like "*Hmi*" -or (Get-PropertyValue -Object $_.Software -Name "VBScriptFolder")
    }
    if (-not $hmiInfos) { throw "No HMI-like software object was found." }

    foreach ($info in $hmiInfos) {
        $hmi = $info.Software
        $log.Add("HMI_TARGET=$($hmi.Name)|$($hmi.GetType().FullName)|$($info.Path)")
        $props = $hmi.GetType().GetProperties() | Select-Object -ExpandProperty Name
        $log.Add("HMI_PROPERTIES=$($props -join ',')")

        $vbFolder = Get-PropertyValue -Object $hmi -Name "VBScriptFolder"
        if (-not $vbFolder) {
            $log.Add("NO_VBSCRIPTFOLDER=$($hmi.Name)")
            continue
        }
        $log.Add("VBSCRIPTFOLDER_TYPE=$($vbFolder.GetType().FullName)")
        Export-VBScriptsFromFolder -Folder $vbFolder -ExportDir $scriptDir -Prefix "" -Log $log

        if (-not $SkipImport) {
            $testImport = Join-Path $importDir "Codex_RTPro_VB_IO_Loop.xml"
            New-TestVBScriptXml -Path $testImport
            $scripts = Get-PropertyValue -Object $vbFolder -Name "VBScripts"
            if (-not $scripts) { throw "VBScriptFolder does not expose VBScripts import collection." }
            $scripts.Import([System.IO.FileInfo]$testImport, [Siemens.Engineering.ImportOptions]::Override)
            $log.Add("IMPORT_TEST_VBSCRIPT=Codex_RTPro_VB_IO_Loop")

            $imported = $scripts.Find("Codex_RTPro_VB_IO_Loop")
            if (-not $imported) { throw "Imported VB script was not found by name." }
            $verifyPath = Join-Path $verifyDir "vbscript_Codex_RTPro_VB_IO_Loop_export.xml"
            if (Test-Path -LiteralPath $verifyPath) { Remove-Item -LiteralPath $verifyPath -Force }
            $imported.Export([System.IO.FileInfo]$verifyPath, [Siemens.Engineering.ExportOptions]::WithDefaults)
            $log.Add("EXPORT_TEST_VBSCRIPT=Codex_RTPro_VB_IO_Loop|$verifyPath")

            $project.Save()
            $log.Add("ProjectSaved=True")
        }
    }
}
finally {
    if ($tia) { $tia.Dispose() }
}

$logPath = Join-Path $logDir "inspect_export_import_rtpro_vbs.txt"
$log | Set-Content -LiteralPath $logPath -Encoding UTF8
$log

