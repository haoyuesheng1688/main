param(
    [string]$OutputRoot = ".\tia_popup_touch_sim",
    [string]$TagTableName = "Codex_Popup_Sim_Int_Tags",
    [switch]$UseStructuredTagNames,
    [string[]]$SkipTagNames = @()
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

$script:idValue = 0
function New-HmiId {
    $script:idValue += 1
    return $script:idValue.ToString("X")
}

function New-IntTagXml {
    param(
        [string]$Name,
        [int]$StartValue,
        [string]$Comment
    )
    $id = New-HmiId
    $commentNode = New-HmiId
    $commentItem = New-HmiId
    $displayNode = New-HmiId
    $displayItem = New-HmiId
    $valueNode = New-HmiId
    $valueItem = New-HmiId
@"
      <Hmi.Tag.Tag ID="$id" CompositionName="Tags">
        <AttributeList>
          <AcquisitionTriggerMode>Visible</AcquisitionTriggerMode>
          <AddressAccessMode>Symbolic</AddressAccessMode>
          <Coding>Binary</Coding>
          <ConfirmationType>None</ConfirmationType>
          <GmpRelevant>false</GmpRelevant>
          <JobNumber>0</JobNumber>
          <Length>2</Length>
          <LinearScaling>false</LinearScaling>
          <LogicalAddress />
          <MandatoryCommenting>false</MandatoryCommenting>
          <Name>$Name</Name>
          <Persistency>false</Persistency>
          <QualityCode>false</QualityCode>
          <ScalingHmiHigh>100</ScalingHmiHigh>
          <ScalingHmiLow>0</ScalingHmiLow>
          <ScalingPlcHigh>10</ScalingPlcHigh>
          <ScalingPlcLow>0</ScalingPlcLow>
          <StartValue>$StartValue</StartValue>
          <SubstituteValue />
          <SubstituteValueUsage>None</SubstituteValueUsage>
          <Synchronization>false</Synchronization>
          <UpdateMode>ProjectWide</UpdateMode>
          <UseMultiplexing>false</UseMultiplexing>
        </AttributeList>
        <LinkList>
          <AcquisitionCycle TargetID="@OpenLink">
            <Name>1 s</Name>
          </AcquisitionCycle>
          <DataType TargetID="@OpenLink">
            <Name>Int</Name>
          </DataType>
          <HmiDataType TargetID="@OpenLink">
            <Name>Int</Name>
          </HmiDataType>
        </LinkList>
        <ObjectList>
          <MultilingualText ID="$commentNode" CompositionName="Comment">
            <ObjectList>
              <MultilingualTextItem ID="$commentItem" CompositionName="Items">
                <AttributeList>
                  <Culture>zh-CN</Culture>
                  <Text><body><p>$Comment</p></body></Text>
                </AttributeList>
              </MultilingualTextItem>
            </ObjectList>
          </MultilingualText>
          <MultilingualText ID="$displayNode" CompositionName="DisplayName">
            <ObjectList>
              <MultilingualTextItem ID="$displayItem" CompositionName="Items">
                <AttributeList>
                  <Culture>zh-CN</Culture>
                  <Text />
                </AttributeList>
              </MultilingualTextItem>
            </ObjectList>
          </MultilingualText>
          <MultilingualText ID="$valueNode" CompositionName="TagValue">
            <ObjectList>
              <MultilingualTextItem ID="$valueItem" CompositionName="Items">
                <AttributeList>
                  <Culture>zh-CN</Culture>
                  <Text />
                </AttributeList>
              </MultilingualTextItem>
            </ObjectList>
          </MultilingualText>
        </ObjectList>
      </Hmi.Tag.Tag>
"@
}

$OutputRoot = [System.IO.Path]::GetFullPath($OutputRoot)
$tagTableNameWasPassed = $PSBoundParameters.ContainsKey("TagTableName")
if ($UseStructuredTagNames -and -not $tagTableNameWasPassed) {
    $TagTableName = "Codex_Popup_PLC_Named_Int_Tags"
}
$importDir = Join-Path $OutputRoot "import"
$exportDir = Join-Path $OutputRoot "exports"
$logDir = Join-Path $OutputRoot "logs"
New-Item -ItemType Directory -Force -Path $importDir, $exportDir, $logDir | Out-Null

if ($UseStructuredTagNames) {
    $components = @(
        @{ Name="Valve01"; ActiveID=1 },
        @{ Name="Heater01"; ActiveID=2 },
        @{ Name="Fan01"; ActiveID=3 }
    )
    $tagSpecs = foreach ($component in $components) {
        $name = $component.Name
        $id = $component.ActiveID
        @{ Name="DB_Components_${name}_ClickTrig"; StartValue=0; Comment="Maps to DB_Components.$name.ClickTrig." }
        @{ Name="DB_Components_${name}_DoubleClickTime"; StartValue=800; Comment="Maps to DB_Components.$name.DoubleClickTime." }
        @{ Name="DB_Components_${name}_Switch1"; StartValue=0; Comment="Maps to DB_Components.$name.Switch[1]." }
        @{ Name="DB_Components_${name}_RealValue1_Int"; StartValue=0; Comment="Integer placeholder for DB_Components.$name.RealValue[1]." }
        @{ Name="DB_ActivePopup_${name}_Visible"; StartValue=0; Comment="Maps to DB_ActivePopup.$name.Visible." }
        @{ Name="DB_ActivePopup_${name}_ActiveID"; StartValue=$id; Comment="Maps to DB_ActivePopup.$name.ActiveID." }
        @{ Name="DB_ActivePopup_${name}_Confirmed"; StartValue=0; Comment="Maps to DB_ActivePopup.$name.Confirmed." }
        @{ Name="DB_ActivePopup_${name}_ConfirmBtn"; StartValue=0; Comment="Maps to DB_ActivePopup.$name.ConfirmBtn." }
        @{ Name="DB_ActivePopup_${name}_CancelBtn"; StartValue=0; Comment="Maps to DB_ActivePopup.$name.CancelBtn." }
    }
}
else {
    $tagSpecs = @(
        @{ Name="Sim_SelectedCompID"; StartValue=1; Comment="Selected component ID. 1=Valve01, 2=Heater01, 3=Fan01." },
        @{ Name="Sim_ClickPulse"; StartValue=0; Comment="Component click trigger pulse." },
        @{ Name="Sim_DoubleClickTime_ms"; StartValue=800; Comment="Double-click time in milliseconds." },
        @{ Name="Sim_Switch1"; StartValue=0; Comment="Simulated Switch[1]." },
        @{ Name="Sim_RealValue1_Int"; StartValue=0; Comment="Integer placeholder for RealValue[1] simulation." },
        @{ Name="Sim_Visible"; StartValue=0; Comment="Popup visible state." },
        @{ Name="Sim_ActiveID"; StartValue=0; Comment="Current active popup ID." },
        @{ Name="Sim_Confirmed"; StartValue=0; Comment="Confirmed state." },
        @{ Name="Sim_ConfirmPulse"; StartValue=0; Comment="Confirm button pulse." },
        @{ Name="Sim_CancelPulse"; StartValue=0; Comment="Cancel button pulse." }
    )
}

if ($SkipTagNames.Count -gt 0) {
    $skipSet = @{}
    foreach ($tagName in $SkipTagNames) {
        if (-not [string]::IsNullOrWhiteSpace($tagName)) {
            $skipSet[$tagName] = $true
        }
    }
    $tagSpecs = @($tagSpecs | Where-Object { -not $skipSet.ContainsKey($_.Name) })
}

$script:idValue = 0
$tagXml = ($tagSpecs | ForEach-Object { New-IntTagXml -Name $_.Name -StartValue $_.StartValue -Comment $_.Comment }) -join "`r`n"
$xml = @"
<?xml version="1.0" encoding="utf-8"?>
<Document>
  <Engineering version="V17" />
  <Hmi.Tag.TagTable ID="0">
    <AttributeList>
      <Name>$TagTableName</Name>
    </AttributeList>
    <ObjectList>
$tagXml
    </ObjectList>
  </Hmi.Tag.TagTable>
</Document>
"@

$xmlPath = Join-Path $importDir "$TagTableName.full-int.xml"
$xml | Set-Content -LiteralPath $xmlPath -Encoding UTF8

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

    $hmi.TagFolder.TagTables.Import([System.IO.FileInfo]$xmlPath, [Siemens.Engineering.ImportOptions]::Override) | Out-Null
    $table = $hmi.TagFolder.TagTables.Find($TagTableName)
    if (-not $table) { throw "Imported tag table not found: $TagTableName" }

    $exportPath = Join-Path $exportDir "$($TagTableName)_full_int_export.xml"
    if (Test-Path -LiteralPath $exportPath) { Remove-Item -LiteralPath $exportPath -Force }
    $table.Export([System.IO.FileInfo]$exportPath, [Siemens.Engineering.ExportOptions]::WithDefaults)
    $project.Save()
    $log.Add("OK_IMPORT_FULL_INT_TAGTABLE=$TagTableName")
    $log.Add("OK_EXPORT_FULL_INT_TAGTABLE=$exportPath")
    $log.Add("TagCount=$($tagSpecs.Count)")
    $log.Add("ProjectSaved=True")
}
finally {
    if ($tia) { $tia.Dispose() }
}

$logPath = Join-Path $logDir "popup_sim_full_int_tag_loop.txt"
$log | Set-Content -LiteralPath $logPath -Encoding UTF8
$log
