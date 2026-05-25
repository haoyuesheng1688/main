param(
    [string]$OutputRoot,
    [string]$TemplateRoot,
    [switch]$SkipImport,
    [switch]$SkipCompile
)

$ErrorActionPreference = "Stop"

function Resolve-DefaultPath {
    param(
        [string]$Value,
        [string]$Default
    )
    if ([string]::IsNullOrWhiteSpace($Value)) {
        return [System.IO.Path]::GetFullPath($Default)
    }
    return [System.IO.Path]::GetFullPath($Value)
}

function Load-TiaV17Assemblies {
    $mainDll = "C:\Program Files\Siemens\Automation\Portal V17\PublicAPI\V17\Siemens.Engineering.dll"
    $hmiDll = "C:\Program Files\Siemens\Automation\Portal V17\PublicAPI\V17\Siemens.Engineering.Hmi.dll"
    if (-not (Test-Path -LiteralPath $mainDll)) {
        throw "Missing TIA V17 Openness assembly: $mainDll"
    }
    [System.Reflection.Assembly]::LoadFrom($mainDll) | Out-Null
    if (Test-Path -LiteralPath $hmiDll) {
        [System.Reflection.Assembly]::LoadFrom($hmiDll) | Out-Null
    }
}

function Get-SoftwareFromDeviceItem {
    param(
        $DeviceItem,
        [Type]$SoftwareContainerType
    )

    $method = $DeviceItem.GetType().GetMethods() |
        Where-Object { $_.Name -eq "GetService" -and $_.IsGenericMethod -and $_.GetParameters().Count -eq 0 } |
        Select-Object -First 1

    if (-not $method) { return $null }

    $service = $method.MakeGenericMethod($SoftwareContainerType).Invoke($DeviceItem, @())
    if ($service) { return $service.Software }
    return $null
}

function Walk-DeviceItems {
    param(
        $Items,
        [Type]$SoftwareContainerType
    )

    foreach ($item in $Items) {
        $software = Get-SoftwareFromDeviceItem -DeviceItem $item -SoftwareContainerType $SoftwareContainerType
        if ($software) { $software }
        if ($item.DeviceItems.Count -gt 0) {
            Walk-DeviceItems -Items $item.DeviceItems -SoftwareContainerType $SoftwareContainerType
        }
    }
}

function Export-Object {
    param(
        $Object,
        [string]$Path,
        [string]$Label,
        [System.Collections.Generic.List[string]]$Log
    )

    try {
        $Object.Export([System.IO.FileInfo]$Path, [Siemens.Engineering.ExportOptions]::WithDefaults)
        $Log.Add("OK_EXPORT=$Label|$Path")
    }
    catch {
        $Log.Add("FAIL_EXPORT=$Label|$($_.Exception.Message)")
    }
}

function Import-Export-Object {
    param(
        $Collection,
        [string]$Name,
        [string]$ImportPath,
        [string]$ExportPath,
        [string]$Label,
        [System.Collections.Generic.List[string]]$Log
    )

    try {
        $existing = $Collection.Find($Name)
        $action = if ($existing) { "OverrideExisting" } else { "CreateNew" }
        $Collection.Import([System.IO.FileInfo]$ImportPath, [Siemens.Engineering.ImportOptions]::Override) | Out-Null
        $object = $Collection.Find($Name)
        if (-not $object) {
            throw "Imported object not found: $Name"
        }
        if (Test-Path -LiteralPath $ExportPath) {
            Remove-Item -LiteralPath $ExportPath -Force
        }
        $object.Export([System.IO.FileInfo]$ExportPath, [Siemens.Engineering.ExportOptions]::WithDefaults)
        $Log.Add("OK_LOOP=$Label|$Name|$action|$ExportPath")
    }
    catch {
        $Log.Add("FAIL_LOOP=$Label|$Name|$($_.Exception.Message)")
    }
}

function Compile-HmiTarget {
    param($Hmi)

    $method = $Hmi.GetType().GetMethods() |
        Where-Object { $_.Name -eq "GetService" -and $_.IsGenericMethod -and $_.GetParameters().Count -eq 0 } |
        Select-Object -First 1
    if (-not $method) {
        throw "HMI target does not expose generic GetService."
    }

    $provider = $method.MakeGenericMethod([Siemens.Engineering.Compiler.ICompilable]).Invoke($Hmi, @())
    if (-not $provider) {
        throw "HMI target did not return an ICompilable service."
    }

    return $provider.Compile()
}

$OutputRoot = Resolve-DefaultPath -Value $OutputRoot -Default ".\tia_hmi_knowledge"
$TemplateRoot = Resolve-DefaultPath -Value $TemplateRoot -Default (Join-Path (Split-Path -Parent $PSScriptRoot) "assets\hmi-advanced-templates")
$exportDir = Join-Path $OutputRoot "exports"
$logDir = Join-Path $OutputRoot "logs"
New-Item -ItemType Directory -Force -Path $exportDir, $logDir | Out-Null

Load-TiaV17Assemblies

$process = [Siemens.Engineering.TiaPortal]::GetProcesses() |
    Where-Object { $_.Mode.ToString() -eq "WithUserInterface" -and $_.ProjectPath } |
    Select-Object -First 1
if (-not $process) {
    throw "No open TIA Portal UI process with a project path was found."
}

$log = New-Object System.Collections.Generic.List[string]
$tia = $process.Attach()

try {
    $project = $tia.Projects | Select-Object -First 1
    if (-not $project) {
        throw "No open project in selected TIA process."
    }

    $softwareContainerType = [type]"Siemens.Engineering.HW.Features.SoftwareContainer"
    $software = foreach ($device in $project.Devices) {
        Walk-DeviceItems -Items $device.DeviceItems -SoftwareContainerType $softwareContainerType
    }
    $hmi = $software | Where-Object { $_.GetType().FullName -eq "Siemens.Engineering.Hmi.HmiTarget" } | Select-Object -First 1
    if (-not $hmi) {
        throw "No HMI target was found."
    }

    $log.Add("ProjectName=$($project.Name)")
    $log.Add("ProjectPath=$($process.ProjectPath)")
    $log.Add("HmiTarget=$($hmi.Name)")
    $log.Add("CyclesCount=$($hmi.Cycles.Count)")
    $log.Add("TextListsCount=$($hmi.TextLists.Count)")
    $log.Add("GraphicListsCount=$($hmi.GraphicLists.Count)")
    $log.Add("VBScriptsCount=$($hmi.VBScriptFolder.VBScripts.Count)")
    $log.Add("TagTablesCount=$($hmi.TagFolder.TagTables.Count)")

    foreach ($cycle in $hmi.Cycles) {
        Export-Object -Object $cycle -Path (Join-Path $exportDir ("cycle_" + $cycle.Name + ".xml")) -Label ("CYCLE|" + $cycle.Name) -Log $log
    }
    foreach ($list in $hmi.TextLists) {
        Export-Object -Object $list -Path (Join-Path $exportDir ("textlist_" + $list.Name + ".xml")) -Label ("TEXTLIST|" + $list.Name) -Log $log
    }
    foreach ($list in $hmi.GraphicLists) {
        Export-Object -Object $list -Path (Join-Path $exportDir ("graphiclist_" + $list.Name + ".xml")) -Label ("GRAPHICLIST|" + $list.Name) -Log $log
    }
    foreach ($vb in $hmi.VBScriptFolder.VBScripts) {
        Export-Object -Object $vb -Path (Join-Path $exportDir ("vbscript_" + $vb.Name + ".xml")) -Label ("VBS|" + $vb.Name) -Log $log
    }

    if (-not $SkipImport) {
        Import-Export-Object -Collection $hmi.Cycles -Name "Codex_Cycle_3s" `
            -ImportPath (Join-Path $TemplateRoot "Codex_Cycle_3s.xml") `
            -ExportPath (Join-Path $exportDir "Codex_Cycle_3s_export.xml") `
            -Label "CYCLE" -Log $log

        Import-Export-Object -Collection $hmi.TextLists -Name "Codex_TextList_Status" `
            -ImportPath (Join-Path $TemplateRoot "Codex_TextList_Status.xml") `
            -ExportPath (Join-Path $exportDir "Codex_TextList_Status_export.xml") `
            -Label "TEXTLIST" -Log $log

        Import-Export-Object -Collection $hmi.GraphicLists -Name "Codex_GraphicList_Empty" `
            -ImportPath (Join-Path $TemplateRoot "Codex_GraphicList_Empty.xml") `
            -ExportPath (Join-Path $exportDir "Codex_GraphicList_Empty_export.xml") `
            -Label "GRAPHICLIST" -Log $log

        $hmi.TagFolder.TagTables.Import([System.IO.FileInfo](Join-Path $TemplateRoot "Codex_VBS_Tags.xml"), [Siemens.Engineering.ImportOptions]::Override) | Out-Null
        $hmi.VBScriptFolder.VBScripts.Import([System.IO.FileInfo](Join-Path $TemplateRoot "Codex_VBFunction_Loop.xml"), [Siemens.Engineering.ImportOptions]::Override) | Out-Null
        $log.Add("OK_LOOP=VBS|Codex_VBFunction_Loop|tags and script imported")
    }

    if (-not $SkipCompile) {
        $result = Compile-HmiTarget -Hmi $hmi
        $log.Add("CompileState=$($result.State)")
        foreach ($message in $result.Messages) {
            $log.Add("CompileMessage=$($message.State)|$($message.Path)|$($message.Description)")
        }
    }

    $project.Save()
    $log.Add("ProjectSaved=True")
}
finally {
    if ($tia) { $tia.Dispose() }
}

$logPath = Join-Path $logDir "hmi_advanced_loop.txt"
$log | Set-Content -Path $logPath -Encoding UTF8
$log
