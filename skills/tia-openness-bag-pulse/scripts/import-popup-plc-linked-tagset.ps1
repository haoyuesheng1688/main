param(
    [string]$OutputRoot = ".\tia_popup_touch_sim",
    [string]$TagTableName = "Codex_Popup_PLC_Named_Int_Tags",
    [string]$ConnectionName = "HMI_连接_1",
    [switch]$ReplaceExistingTable,
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

function Escape-Xml([string]$Text) {
    if ([string]::IsNullOrEmpty($Text)) { return "" }
    return [System.Security.SecurityElement]::Escape($Text)
}

$script:idValue = 0
function New-HmiId {
    $script:idValue += 1
    return $script:idValue.ToString("X")
}

function New-HmiTagXml {
    param(
        [string]$Name,
        [string]$DataType,
        [string]$ControllerTag,
        [string]$Comment,
        [string]$StartValue = "0"
    )

    $id = New-HmiId
    $commentNode = New-HmiId
    $commentItem = New-HmiId
    $displayNode = New-HmiId
    $displayItem = New-HmiId
    $valueNode = New-HmiId
    $valueItem = New-HmiId
    $length = switch ($DataType) {
        "Bool" { "1" }
        "Real" { "4" }
        default { "2" }
    }
    $coding = switch ($DataType) {
        "Real" { "IEEE754Float" }
        default { "Binary" }
    }
    $safeComment = Escape-Xml $Comment
    $startNode = if ($DataType -eq "Real") { "<StartValue />" } else { "<StartValue>$StartValue</StartValue>" }
    $connectionXml = ""
    if (-not [string]::IsNullOrWhiteSpace($ControllerTag)) {
        $safeControllerTag = Escape-Xml $ControllerTag
        $safeConnectionName = Escape-Xml $ConnectionName
        $connectionXml = @"
          <Connection TargetID="@OpenLink">
            <Name>$safeConnectionName</Name>
          </Connection>
          <ControllerTag TargetID="@OpenLink">
            <Name>$safeControllerTag</Name>
          </ControllerTag>
"@
    }

@"
      <Hmi.Tag.Tag ID="$id" CompositionName="Tags">
        <AttributeList>
          <AcquisitionTriggerMode>Visible</AcquisitionTriggerMode>
          <AddressAccessMode>Symbolic</AddressAccessMode>
          <Coding>$coding</Coding>
          <ConfirmationType>None</ConfirmationType>
          <GmpRelevant>false</GmpRelevant>
          <JobNumber>0</JobNumber>
          <Length>$length</Length>
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
          $startNode
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
$connectionXml
          <DataType TargetID="@OpenLink">
            <Name>$DataType</Name>
          </DataType>
          <HmiDataType TargetID="@OpenLink">
            <Name>$DataType</Name>
          </HmiDataType>
        </LinkList>
        <ObjectList>
          <MultilingualText ID="$commentNode" CompositionName="Comment">
            <ObjectList>
              <MultilingualTextItem ID="$commentItem" CompositionName="Items">
                <AttributeList>
                  <Culture>zh-CN</Culture>
                  <Text><body><p>$safeComment</p></body></Text>
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
$importDir = Join-Path $OutputRoot "import"
$exportDir = Join-Path $OutputRoot "exports"
$logDir = Join-Path $OutputRoot "logs"
New-Item -ItemType Directory -Force -Path $importDir, $exportDir, $logDir | Out-Null

$components = @("Valve01", "Heater01", "Fan01")
$tagSpecs = foreach ($component in $components) {
    @{ Name="DB_Components_${component}_ClickTrig"; DataType="Bool"; ControllerTag="DB_Components.$component.ClickTrig"; Comment="PLC linked: DB_Components.$component.ClickTrig." }
    @{ Name="DB_Components_${component}_DoubleClickTime"; DataType="Int"; ControllerTag=""; Comment="Internal helper only. DB_Components.$component has no DoubleClickTime member in the exported PLC DB." }
    @{ Name="DB_Components_${component}_Switch1"; DataType="Bool"; ControllerTag="DB_Components.$component.Switch[1]"; Comment="PLC linked: DB_Components.$component.Switch[1]." }
    @{ Name="DB_Components_${component}_RealValue1"; DataType="Real"; ControllerTag="DB_Components.$component.RealValue[1]"; Comment="PLC linked: DB_Components.$component.RealValue[1]." }
    @{ Name="DB_Components_${component}_RealValue1_Int"; DataType="Int"; ControllerTag=""; Comment="Legacy Int placeholder kept for screens that still use the Int simulation field." }
    @{ Name="DB_ActivePopup_${component}_Visible"; DataType="Bool"; ControllerTag="DB_ActivePopup.$component.Visible"; Comment="PLC linked: DB_ActivePopup.$component.Visible." }
    @{ Name="DB_ActivePopup_${component}_ActiveID"; DataType="Int"; ControllerTag="DB_ActivePopup.$component.ActiveID"; Comment="PLC linked: DB_ActivePopup.$component.ActiveID." }
    @{ Name="DB_ActivePopup_${component}_Confirmed"; DataType="Bool"; ControllerTag="DB_ActivePopup.$component.Confirmed"; Comment="PLC linked: DB_ActivePopup.$component.Confirmed." }
    @{ Name="DB_ActivePopup_${component}_ConfirmBtn"; DataType="Bool"; ControllerTag="DB_ActivePopup.$component.ConfirmBtn"; Comment="PLC linked: DB_ActivePopup.$component.ConfirmBtn." }
    @{ Name="DB_ActivePopup_${component}_CancelBtn"; DataType="Bool"; ControllerTag="DB_ActivePopup.$component.CancelBtn"; Comment="PLC linked: DB_ActivePopup.$component.CancelBtn." }
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
$tagXml = ($tagSpecs | ForEach-Object {
    New-HmiTagXml -Name $_.Name -DataType $_.DataType -ControllerTag $_.ControllerTag -Comment $_.Comment
}) -join "`r`n"
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

$xmlPath = Join-Path $importDir "$TagTableName.plc-linked.xml"
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

    if ($ReplaceExistingTable) {
        $existing = $hmi.TagFolder.TagTables.Find($TagTableName)
        if ($existing) {
            $backupPath = Join-Path $exportDir "$($TagTableName)_before_replace.xml"
            if (Test-Path -LiteralPath $backupPath) { Remove-Item -LiteralPath $backupPath -Force }
            $existing.Export([System.IO.FileInfo]$backupPath, [Siemens.Engineering.ExportOptions]::WithDefaults)
            $existing.Delete()
            $log.Add("OK_BACKUP_BEFORE_REPLACE=$backupPath")
            $log.Add("OK_DELETE_EXISTING_TAGTABLE=$TagTableName")
        }
    }

    $hmi.TagFolder.TagTables.Import([System.IO.FileInfo]$xmlPath, [Siemens.Engineering.ImportOptions]::Override) | Out-Null
    $table = $hmi.TagFolder.TagTables.Find($TagTableName)
    if (-not $table) { throw "Imported tag table not found: $TagTableName" }

    $exportPath = Join-Path $exportDir "$($TagTableName)_plc_linked_export.xml"
    if (Test-Path -LiteralPath $exportPath) { Remove-Item -LiteralPath $exportPath -Force }
    $table.Export([System.IO.FileInfo]$exportPath, [Siemens.Engineering.ExportOptions]::WithDefaults)
    $project.Save()
    $log.Add("OK_IMPORT_PLC_LINKED_TAGTABLE=$TagTableName")
    $log.Add("OK_EXPORT_PLC_LINKED_TAGTABLE=$exportPath")
    $log.Add("TagCount=$($tagSpecs.Count)")
    $log.Add("ProjectSaved=True")
}
finally {
    if ($tia) { $tia.Dispose() }
}

$logPath = Join-Path $logDir "popup_plc_linked_tag_loop.txt"
$log | Set-Content -LiteralPath $logPath -Encoding UTF8
$log
