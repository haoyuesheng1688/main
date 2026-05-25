param(
    [string]$OutputRoot = "C:\Users\QF100\Documents\New project\tia_rtpro_learning",
    [string]$ScriptName = "DATA_Auto_CSV",
    [string]$ArchiveName = ""
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($ArchiveName)) {
    $ArchiveName = "DATA1\" + (-join ([char[]](0x79F0, 0x91CD, 0x4EEA)))
}

function Load-TiaV17Assemblies {
    $mainDll = "C:\Program Files\Siemens\Automation\Portal V17\PublicAPI\V17\Siemens.Engineering.dll"
    $hmiDll = "C:\Program Files\Siemens\Automation\Portal V17\PublicAPI\V17\Siemens.Engineering.Hmi.dll"
    [System.Reflection.Assembly]::LoadFrom($mainDll) | Out-Null
    [System.Reflection.Assembly]::LoadFrom($hmiDll) | Out-Null
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

function Patch-Code {
    param([string]$Code, [string]$ArchiveName)

    if ($Code.Contains(('TagName(9) = "' + $ArchiveName + '"'))) {
        return $Code
    }

    $patched = [regex]::Replace($Code, 'Dim\s+TagName\(8\),iLen', 'Dim TagName(9),iLen', 1)
    if ($patched -eq $Code) {
        throw "Did not find expected 'Dim TagName(8),iLen' in $ScriptName."
    }

    $escapedArchive = [regex]::Escape($ArchiveName)
    if ($patched -match $escapedArchive) {
        return $patched
    }

    $patched = [regex]::Replace(
        $patched,
        '(?m)^(\s*TagName\(8\)\s*=\s*"DATA1\\[^"]*"\s*)$',
        {
            param($match)
            $match.Groups[1].Value + "`r`nTagName(9) = `"$ArchiveName`""
        },
        1
    )

    if (-not $patched.Contains(('TagName(9) = "' + $ArchiveName + '"'))) {
        throw "Failed to insert TagName(9) for $ArchiveName."
    }
    return $patched
}

function Get-CodeNode {
    param([xml]$Xml)
    $node = $Xml.SelectSingleNode("//Code")
    if (-not $node) { throw "No Code node found in exported script XML." }
    return $node
}

$OutputRoot = [System.IO.Path]::GetFullPath($OutputRoot)
$exportDir = Join-Path $OutputRoot "exports\weighing_patch"
$importDir = Join-Path $OutputRoot "imports\weighing_patch"
$verifyDir = Join-Path $OutputRoot "verify"
$logDir = Join-Path $OutputRoot "logs"
New-Item -ItemType Directory -Force -Path $exportDir, $importDir, $verifyDir, $logDir | Out-Null

Load-TiaV17Assemblies

$process = [Siemens.Engineering.TiaPortal]::GetProcesses() |
    Where-Object { $_.Mode.ToString() -eq "WithUserInterface" -and $_.ProjectPath } |
    Select-Object -First 1
if (-not $process) { throw "No open TIA Portal UI process with a project path was found." }

$tia = $process.Attach()
try {
    $project = $tia.Projects | Select-Object -First 1
    if (-not $project) { throw "No open project found." }

    $softwareContainerType = [type]"Siemens.Engineering.HW.Features.SoftwareContainer"
    $allSoftware = foreach ($device in $project.Devices) {
        Walk-DeviceItems -Items $device.DeviceItems -SoftwareContainerType $softwareContainerType
    }

    $hmiTargets = $allSoftware | Where-Object {
        $_.GetType().GetProperty("VBScriptFolder") -ne $null
    }
    if (-not $hmiTargets) { throw "No HMI target exposing VBScriptFolder was found." }

    $hmi = $hmiTargets | Where-Object { $_.Name -eq "HMI_RT_4" } | Select-Object -First 1
    if (-not $hmi) { $hmi = $hmiTargets | Select-Object -First 1 }

    $scripts = $hmi.VBScriptFolder.VBScripts
    $script = $scripts.Find($ScriptName)
    if (-not $script) { throw "VB script '$ScriptName' was not found under HMI '$($hmi.Name)'." }

    $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $beforePath = Join-Path $exportDir "$($ScriptName)_before_weighing_$stamp.xml"
    $importPath = Join-Path $importDir "$($ScriptName)_with_weighing_$stamp.xml"
    $afterPath = Join-Path $verifyDir "$($ScriptName)_after_weighing_$stamp.xml"
    $logPath = Join-Path $logDir "patch_data_auto_csv_weighing_$stamp.txt"

    $script.Export([System.IO.FileInfo]$beforePath, [Siemens.Engineering.ExportOptions]::WithDefaults)
    [xml]$xml = Get-Content -LiteralPath $beforePath -Raw
    $codeNode = Get-CodeNode -Xml $xml
    $beforeCode = $codeNode.InnerText
    $afterCode = Patch-Code -Code $beforeCode -ArchiveName $ArchiveName
    $codeNode.InnerText = $afterCode
    $xml.Save($importPath)

    $scripts.Import([System.IO.FileInfo]$importPath, [Siemens.Engineering.ImportOptions]::Override)
    $project.Save()

    $scriptAfter = $scripts.Find($ScriptName)
    $scriptAfter.Export([System.IO.FileInfo]$afterPath, [Siemens.Engineering.ExportOptions]::WithDefaults)
    [xml]$afterXml = Get-Content -LiteralPath $afterPath -Raw
    $readbackCode = (Get-CodeNode -Xml $afterXml).InnerText

    $ok = $readbackCode.Contains("Dim TagName(9),iLen") -and
        $readbackCode.Contains(('TagName(9) = "' + $ArchiveName + '"')) -and
        -not $readbackCode.Contains("Dim TagName(8),iLen")

    $log = @(
        "ProjectName=$($project.Name)",
        "ProjectPath=$($project.Path)",
        "HmiTarget=$($hmi.Name)",
        "ScriptName=$ScriptName",
        "ArchiveName=$ArchiveName",
        "BeforePath=$beforePath",
        "ImportPath=$importPath",
        "AfterPath=$afterPath",
        "Ok=$ok",
        "HasDim9=$($readbackCode.Contains('Dim TagName(9),iLen'))",
        "HasArchive=$($readbackCode.Contains(('TagName(9) = ""' + $ArchiveName + '""')))",
        "HasDim8=$($readbackCode.Contains('Dim TagName(8),iLen'))"
    )
    $log | Set-Content -LiteralPath $logPath -Encoding UTF8
    Write-Output $logPath
    $log

    if (-not $ok) {
        throw "Readback verification failed. See $logPath"
    }
}
finally {
    if ($tia) { $tia.Dispose() }
}
