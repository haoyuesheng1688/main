param(
    [string]$OutputRoot = ".\tia_popup_touch_sim",
    [string]$TagTableName = "Codex_Popup_Sim_Int_Tags",
    [string]$TagName = "Sim_SelectedCompID"
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

$OutputRoot = [System.IO.Path]::GetFullPath($OutputRoot)
$importDir = Join-Path $OutputRoot "import"
$exportDir = Join-Path $OutputRoot "exports"
$logDir = Join-Path $OutputRoot "logs"
New-Item -ItemType Directory -Force -Path $importDir, $exportDir, $logDir | Out-Null

$xml = @"
<?xml version="1.0" encoding="utf-8"?>
<Document>
  <Engineering version="V17" />
  <Hmi.Tag.TagTable ID="0">
    <AttributeList>
      <Name>$TagTableName</Name>
    </AttributeList>
    <ObjectList>
      <Hmi.Tag.Tag ID="1" CompositionName="Tags">
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
          <Name>$TagName</Name>
          <Persistency>false</Persistency>
          <QualityCode>false</QualityCode>
          <ScalingHmiHigh>100</ScalingHmiHigh>
          <ScalingHmiLow>0</ScalingHmiLow>
          <ScalingPlcHigh>10</ScalingPlcHigh>
          <ScalingPlcLow>0</ScalingPlcLow>
          <StartValue>1</StartValue>
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
          <MultilingualText ID="2" CompositionName="Comment">
            <ObjectList>
              <MultilingualTextItem ID="3" CompositionName="Items">
                <AttributeList>
                  <Culture>zh-CN</Culture>
                  <Text><body><p>Popup simulation selected component ID.</p></body></Text>
                </AttributeList>
              </MultilingualTextItem>
            </ObjectList>
          </MultilingualText>
          <MultilingualText ID="4" CompositionName="DisplayName">
            <ObjectList>
              <MultilingualTextItem ID="5" CompositionName="Items">
                <AttributeList>
                  <Culture>zh-CN</Culture>
                  <Text />
                </AttributeList>
              </MultilingualTextItem>
            </ObjectList>
          </MultilingualText>
          <MultilingualText ID="6" CompositionName="TagValue">
            <ObjectList>
              <MultilingualTextItem ID="7" CompositionName="Items">
                <AttributeList>
                  <Culture>zh-CN</Culture>
                  <Text />
                </AttributeList>
              </MultilingualTextItem>
            </ObjectList>
          </MultilingualText>
        </ObjectList>
      </Hmi.Tag.Tag>
    </ObjectList>
  </Hmi.Tag.TagTable>
</Document>
"@

$xmlPath = Join-Path $importDir "$TagTableName.xml"
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

    $exportPath = Join-Path $exportDir "$($TagTableName)_export.xml"
    if (Test-Path -LiteralPath $exportPath) { Remove-Item -LiteralPath $exportPath -Force }
    $table.Export([System.IO.FileInfo]$exportPath, [Siemens.Engineering.ExportOptions]::WithDefaults)
    $project.Save()
    $log.Add("OK_IMPORT_INT_TAGTABLE=$TagTableName")
    $log.Add("OK_EXPORT_INT_TAGTABLE=$exportPath")
    $log.Add("ProjectSaved=True")
}
finally {
    if ($tia) { $tia.Dispose() }
}

$logPath = Join-Path $logDir "popup_sim_int_tag_loop.txt"
$log | Set-Content -LiteralPath $logPath -Encoding UTF8
$log
