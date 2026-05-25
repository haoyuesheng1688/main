param(
    [string]$OutputRoot = ".\tia_sanjiu_learning"
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

function Get-IdGenerator {
    param([xml]$Xml)
    $max = 0
    foreach ($node in $Xml.SelectNodes("//*[@ID]")) {
        $id = $node.GetAttribute("ID")
        if ($id -match "^[0-9A-Fa-f]+$") {
            $value = [Convert]::ToInt32($id, 16)
            if ($value -gt $max) { $max = $value }
        }
    }
    $counter = @{ Value = $max + 1 }
    return {
        $id = $counter.Value.ToString("X")
        $counter.Value++
        return $id
    }.GetNewClosure()
}

function Reset-Ids {
    param($Node, [scriptblock]$NextId)
    if ($Node.Attributes -and $Node.Attributes["ID"]) {
        $Node.Attributes["ID"].Value = & $NextId
    }
    foreach ($child in $Node.ChildNodes) {
        Reset-Ids -Node $child -NextId $NextId
    }
}

function Set-AttributeText {
    param($Node, [string]$Name, [string]$Value)
    $target = $Node.SelectSingleNode(".//*[local-name()='$Name']")
    if ($target) { $target.InnerText = $Value }
}

function Add-DisplayTags {
    param([string]$SourcePath, [string]$TargetPath)
    [xml]$xml = Get-Content -LiteralPath $SourcePath -Raw
    if ($xml.OuterXml -like "*data_进风温度P_1*") {
        $xml.Save($TargetPath)
        return
    }

    $nextId = Get-IdGenerator -Xml $xml
    $tableObjectList = $xml.SelectSingleNode("/*[local-name()='Document']/*[local-name()='Hmi.Tag.TagTable']/*[local-name()='ObjectList']")
    if (-not $tableObjectList) { throw "Cannot find tag table ObjectList in $SourcePath" }

    for ($i = 1; $i -le 15; $i++) {
        $sourceName = "data_进风温度_$i"
        $newName = "data_进风温度P_$i"
        $sourceNode = $xml.SelectSingleNode("//*[local-name()='Hmi.Tag.Tag'][*[local-name()='AttributeList']/*[local-name()='Name' and text()='$sourceName']]")
        if (-not $sourceNode) { throw "Cannot find source display tag: $sourceName" }
        $clone = $sourceNode.CloneNode($true)
        Reset-Ids -Node $clone -NextId $nextId
        $clone.SelectSingleNode("*[local-name()='AttributeList']/*[local-name()='Name']").InnerText = $newName
        [void]$tableObjectList.AppendChild($clone)
    }

    $xml.Save($TargetPath)
}

function Update-VbScript {
    param([string]$SourcePath, [string]$TargetPath)
    $text = Get-Content -LiteralPath $SourcePath -Raw
    if ($text -notlike "*PV_JF进风温度P*") {
        $text = [regex]::Replace(
            $text,
            '(?s)(\s*If field2\(0\) = "PV_YF引风反馈" Then\s*\r?\n\s*data_7\(Find1-1\) = field2\(2\)\s*\r?\n\s*End If)',
            "`$1`r`n`r`n`t`tIf field2(0) = `"PV_JF进风温度P`" Then`r`n`t`t`tdata_8(Find1-1) = field2(2)`r`n`t`tEnd If",
            1
        )
    }
    if ($text -notlike "*data_进风温度P_*") {
        $text = [regex]::Replace(
            $text,
            '(\s*SmartTags\("data_引风频率_" &amp; i\) =data_7\(startLines \+ i-1\))',
            "`$1`r`n`r`n`t`tSmartTags(`"data_进风温度P_`" &amp; i) =data_8(startLines + i-1)",
            1
        )
        $text = [regex]::Replace(
            $text,
            '(\s*SmartTags\("data_引风频率_" &amp; i\) = 0\.0)',
            "`$1`r`n`t`tSmartTags(`"data_进风温度P_`" &amp; i) = 0.0",
            1
        )
    }
    Set-Content -LiteralPath $TargetPath -Value $text -Encoding UTF8
}

function Add-ScreenColumn {
    param([string]$SourcePath, [string]$TargetPath)
    [xml]$xml = Get-Content -LiteralPath $SourcePath -Raw
    if ($xml.OuterXml -like "*data_进风温度P_1*") {
        $xml.Save($TargetPath)
        return
    }

    $nextId = Get-IdGenerator -Xml $xml
    $screenObjectList = $xml.SelectSingleNode("/*[local-name()='Document']/*[local-name()='Hmi.Screen.Screen']/*[local-name()='ObjectList']/*[local-name()='Hmi.Screen.ScreenLayer']/*[local-name()='ObjectList']")
    if (-not $screenObjectList) { throw "Cannot find screen layer ObjectList in $SourcePath" }

    foreach ($buttonName in @("按钮_10", "按钮_11")) {
        $button = $xml.SelectSingleNode("//*[local-name()='AttributeList'][*[local-name()='ObjectName' and text()='$buttonName']]")
        if ($button) {
            $left = $button.SelectSingleNode("*[local-name()='Left']")
            if ($left) { $left.InnerText = "1174" }
        }
    }

    $header = $xml.SelectSingleNode("//*[local-name()='Hmi.Screen.TextField'][.//*[local-name()='Text' and contains(., '引风频率')]]")
    if (-not $header) { throw "Cannot find 引风频率 header field." }
    $headerClone = $header.CloneNode($true)
    Reset-Ids -Node $headerClone -NextId $nextId
    Set-AttributeText -Node $headerClone -Name "Left" -Value "1084"
    Set-AttributeText -Node $headerClone -Name "Width" -Value "80"
    Set-AttributeText -Node $headerClone -Name "ObjectName" -Value "文本域_进风温度P"
    foreach ($textNode in $headerClone.SelectNodes(".//*[local-name()='Text']")) {
        if ($textNode.InnerXml -like "*引风频率*") {
            $textNode.InnerXml = "<body><p>进风温度P</p></body>"
        }
    }
    [void]$screenObjectList.AppendChild($headerClone)

    for ($i = 1; $i -le 15; $i++) {
        $sourceTag = "data_引风频率_$i"
        $newTag = "data_进风温度P_$i"
        $field = $xml.SelectSingleNode("//*[local-name()='Hmi.Screen.IOField'][.//*[local-name()='Tag']/*[local-name()='Name' and text()='$sourceTag']]")
        if (-not $field) { throw "Cannot find source IOField for $sourceTag" }
        $clone = $field.CloneNode($true)
        Reset-Ids -Node $clone -NextId $nextId
        Set-AttributeText -Node $clone -Name "Left" -Value "1084"
        Set-AttributeText -Node $clone -Name "Width" -Value "80"
        Set-AttributeText -Node $clone -Name "ObjectName" -Value ("IO Field_进风温度P_{0}" -f $i)
        $tagName = $clone.SelectSingleNode(".//*[local-name()='Tag']/*[local-name()='Name']")
        if ($tagName) { $tagName.InnerText = $newTag }
        [void]$screenObjectList.AppendChild($clone)
    }

    $xml.Save($TargetPath)
}

$OutputRoot = [System.IO.Path]::GetFullPath($OutputRoot)
$exportDir = Join-Path $OutputRoot "exports"
$importDir = Join-Path $OutputRoot "imports"
$verifyDir = Join-Path $OutputRoot "verify"
$logDir = Join-Path $OutputRoot "logs"
New-Item -ItemType Directory -Force -Path $importDir, $verifyDir, $logDir | Out-Null

$tagSource = Join-Path $exportDir "tag_tables\tagtable_变量归档.xml"
$scriptSource = Join-Path $exportDir "vbscript_ReadFile_DATA1.xml"
$screenSource = Join-Path $exportDir "screens\screen_C1_数据记录.xml"
$tagImport = Join-Path $importDir "tagtable_变量归档_with_进风温度P.xml"
$scriptImport = Join-Path $importDir "vbscript_ReadFile_DATA1_with_进风温度P.xml"
$screenImport = Join-Path $importDir "screen_C1_数据记录_with_进风温度P.xml"

Add-DisplayTags -SourcePath $tagSource -TargetPath $tagImport
Update-VbScript -SourcePath $scriptSource -TargetPath $scriptImport
Add-ScreenColumn -SourcePath $screenSource -TargetPath $screenImport

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

    $hmi.TagFolder.TagTables.Import([System.IO.FileInfo]$tagImport, [Siemens.Engineering.ImportOptions]::Override)
    $log.Add("IMPORTED_TAG_TABLE=变量归档")

    $hmi.VBScriptFolder.VBScripts.Import([System.IO.FileInfo]$scriptImport, [Siemens.Engineering.ImportOptions]::Override)
    $log.Add("IMPORTED_VBSCRIPT=ReadFile_DATA1")

    $hmi.ScreenFolder.Screens.Import([System.IO.FileInfo]$screenImport, [Siemens.Engineering.ImportOptions]::Override)
    $log.Add("IMPORTED_SCREEN=C1_数据记录")

    $compilerType = [type]"Siemens.Engineering.Compiler.ICompilable"
    $method = $hmi.GetType().GetMethods() |
        Where-Object { $_.Name -eq "GetService" -and $_.IsGenericMethod -and $_.GetParameters().Count -eq 0 } |
        Select-Object -First 1
    $compiler = $method.MakeGenericMethod($compilerType).Invoke($hmi, @())
    $result = $compiler.Compile()
    $log.Add("CompileState=$($result.State)")
    foreach ($message in $result.Messages) {
        $log.Add("CompileMessage=$($message.State)|$($message.Path)|$($message.Description)")
    }

    $tagVerify = Join-Path $verifyDir "tagtable_变量归档_after_进风温度P.xml"
    $scriptVerify = Join-Path $verifyDir "vbscript_ReadFile_DATA1_after_进风温度P.xml"
    $screenVerify = Join-Path $verifyDir "screen_C1_数据记录_after_进风温度P.xml"
    foreach ($path in @($tagVerify, $scriptVerify, $screenVerify)) {
        if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Force }
    }

    $table = $hmi.TagFolder.TagTables.Find("变量归档")
    $table.Export([System.IO.FileInfo]$tagVerify, [Siemens.Engineering.ExportOptions]::WithDefaults)
    $vb = $hmi.VBScriptFolder.VBScripts.Find("ReadFile_DATA1")
    $vb.Export([System.IO.FileInfo]$scriptVerify, [Siemens.Engineering.ExportOptions]::WithDefaults)
    $screen = $hmi.ScreenFolder.Screens.Find("C1_数据记录")
    $screen.Export([System.IO.FileInfo]$screenVerify, [Siemens.Engineering.ExportOptions]::WithDefaults)
    $project.Save()
    $log.Add("ProjectSaved=True")
}
finally {
    if ($tia) { $tia.Dispose() }
}

$logPath = Join-Path $logDir "add_data1_inlet_temp_p.txt"
$log | Set-Content -LiteralPath $logPath -Encoding UTF8
$log





