param(
    [string]$OutputRoot = ".\tia_popup_touch_sim",
    [string]$ScreenName = "Codex_Popup_Sim_800x800",
    [int]$ScreenNumber = 12,
    [int]$ScreenWidth = 800,
    [int]$ScreenHeight = 800,
    [switch]$AsNormalScreen,
    [switch]$UseStructuredTagNames,
    [ValidateSet("Valve01", "Heater01", "Fan01")]
    [string]$FocusComponent = "Heater01",
    [switch]$BindCompId,
    [switch]$BindIntSet,
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

function New-TextFieldXml {
    param(
        [string]$Name,
        [string]$Text,
        [int]$Left,
        [int]$Top,
        [int]$Width,
        [int]$Height = 28,
        [int]$FontSize = 14,
        [string]$FontStyle = "Regular",
        [string]$BackFillStyle = "Transparent",
        [string]$BackColor = "255, 255, 255",
        [string]$ForeColor = "0, 0, 0",
        [string]$HorizontalAlignment = "Left",
        [int]$BorderWidth = 0
    )
    $id = New-HmiId
    $font = New-HmiId
    $fontItem = New-HmiId
    $textNode = New-HmiId
    $textItem = New-HmiId
    $safe = Escape-Xml $Text
@"
          <Hmi.Screen.TextField ID="$id" CompositionName="ScreenItems">
            <AttributeList>
              <BackColor>$BackColor</BackColor>
              <BackFillStyle>$BackFillStyle</BackFillStyle>
              <BorderBackColor>226, 225, 225</BorderBackColor>
              <BorderColor>100, 100, 100</BorderColor>
              <BorderWidth>$BorderWidth</BorderWidth>
              <BottomMargin>2</BottomMargin>
              <CornerRadius>3</CornerRadius>
              <EdgeStyle>Double</EdgeStyle>
              <FitToLargest>false</FitToLargest>
              <Flashing>None</Flashing>
              <ForeColor>$ForeColor</ForeColor>
              <Height>$Height</Height>
              <HorizontalAlignment>$HorizontalAlignment</HorizontalAlignment>
              <Left>$Left</Left>
              <LeftMargin>3</LeftMargin>
              <ObjectName>$Name</ObjectName>
              <RightMargin>2</RightMargin>
              <TabIndex>-1</TabIndex>
              <TextOrientation>Horizontal</TextOrientation>
              <Top>$Top</Top>
              <TopMargin>2</TopMargin>
              <UseDesignColorSchema>false</UseDesignColorSchema>
              <VerticalAlignment>Middle</VerticalAlignment>
              <Width>$Width</Width>
            </AttributeList>
            <ObjectList>
              <Hmi.Globalization.MultiLingualFont ID="$font" CompositionName="Font">
                <ObjectList>
                  <Hmi.Globalization.FontItem ID="$fontItem" CompositionName="Items">
                    <AttributeList>
                      <Culture>zh-CN</Culture>
                      <FontFamily>Arial</FontFamily>
                      <FontSize>$FontSize</FontSize>
                      <FontStyle>$FontStyle</FontStyle>
                    </AttributeList>
                  </Hmi.Globalization.FontItem>
                </ObjectList>
              </Hmi.Globalization.MultiLingualFont>
              <MultilingualText ID="$textNode" CompositionName="Text">
                <ObjectList>
                  <MultilingualTextItem ID="$textItem" CompositionName="Items">
                    <AttributeList>
                      <Culture>zh-CN</Culture>
                      <Text><body><p>$safe</p></body></Text>
                    </AttributeList>
                  </MultilingualTextItem>
                </ObjectList>
              </MultilingualText>
            </ObjectList>
          </Hmi.Screen.TextField>
"@
}

function New-ButtonXml {
    param(
        [string]$Name,
        [string]$Text,
        [int]$Left,
        [int]$Top,
        [int]$Width = 150,
        [int]$Height = 46,
        [string]$BackColor = "230, 242, 255",
        [string]$BorderColor = "0, 102, 204",
        [array]$SetTags = @()
    )
    $id = New-HmiId
    $font = New-HmiId
    $fontItem = New-HmiId
    $help = New-HmiId
    $helpItem = New-HmiId
    $off = New-HmiId
    $offItem = New-HmiId
    $on = New-HmiId
    $onItem = New-HmiId
    $safe = Escape-Xml $Text
    $eventXml = ""
    if ($SetTags.Count -gt 0) {
        $event = New-HmiId
        $handler = New-HmiId
        $entries = ($SetTags | ForEach-Object {
            $entry = New-HmiId
            $tagParam = New-HmiId
            $valueParam = New-HmiId
            $tag = $_.Tag
            $value = $_.Value
@"
                      <Hmi.Event.FunctionListEntry ID="$entry" CompositionName="FunctionListEntries">
                        <AttributeList>
                          <Name>SetTag</Name>
                          <Type>SystemFunction</Type>
                        </AttributeList>
                        <ObjectList>
                          <Hmi.Event.FunctionListEntryParameter ID="$tagParam" CompositionName="Parameters">
                            <AttributeList>
                              <Name>Tag</Name>
                            </AttributeList>
                            <LinkList>
                              <Value TargetID="@OpenLink">
                                <Name>$tag</Name>
                              </Value>
                            </LinkList>
                          </Hmi.Event.FunctionListEntryParameter>
                          <Hmi.Event.FunctionListEntryParameter ID="$valueParam" CompositionName="Parameters">
                            <AttributeList>
                              <Name>Value</Name>
                              <Value Type="System.Double">$value</Value>
                            </AttributeList>
                          </Hmi.Event.FunctionListEntryParameter>
                        </ObjectList>
                      </Hmi.Event.FunctionListEntry>
"@
        }) -join "`r`n"
        $eventXml = @"
              <Hmi.Event.Event ID="$event" CompositionName="Events">
                <AttributeList>
                  <Name>Click</Name>
                </AttributeList>
                <ObjectList>
                  <Hmi.Event.FunctionListEventHandler ID="$handler" CompositionName="EventHandler">
                    <ObjectList>
$entries
                    </ObjectList>
                  </Hmi.Event.FunctionListEventHandler>
                </ObjectList>
              </Hmi.Event.Event>
"@
    }
@"
          <Hmi.Screen.Button ID="$id" CompositionName="ScreenItems">
            <AttributeList>
              <BackColor>$BackColor</BackColor>
              <BackFillStyle>Solid</BackFillStyle>
              <BitNumber>0</BitNumber>
              <BorderBackColor>255, 255, 255</BorderBackColor>
              <BorderColor>$BorderColor</BorderColor>
              <BorderWidth>1</BorderWidth>
              <CornerRadius>0</CornerRadius>
              <CornerStyle>Pointed</CornerStyle>
              <EdgeStyle>Style3D</EdgeStyle>
              <Enabled>true</Enabled>
              <FirstGradientColor>240, 248, 255</FirstGradientColor>
              <FirstGradientOffset>15</FirstGradientOffset>
              <FitToLargest>false</FitToLargest>
              <Flashing>None</Flashing>
              <FocusColor>51, 51, 51</FocusColor>
              <FocusWidth>0</FocusWidth>
              <ForeColor>0, 0, 0</ForeColor>
              <Height>$Height</Height>
              <HorizontalAlignment>Center</HorizontalAlignment>
              <HorizontalPictureAlignment>Center</HorizontalPictureAlignment>
              <HotKey>0</HotKey>
              <Left>$Left</Left>
              <MiddleGradientColor>210, 230, 250</MiddleGradientColor>
              <Mode>Text</Mode>
              <ObjectName>$Name</ObjectName>
              <PictureAreaBottomMargin>0</PictureAreaBottomMargin>
              <PictureAreaLeftMargin>0</PictureAreaLeftMargin>
              <PictureAreaRightMargin>0</PictureAreaRightMargin>
              <PictureAreaTopMargin>0</PictureAreaTopMargin>
              <PictureAutoSizing>StretchPicture</PictureAutoSizing>
              <SecondGradientColor>180, 210, 240</SecondGradientColor>
              <SecondGradientOffset>15</SecondGradientOffset>
              <TabIndex>1</TabIndex>
              <TextAreaBottomMargin>0</TextAreaBottomMargin>
              <TextAreaLeftMargin>0</TextAreaLeftMargin>
              <TextAreaRightMargin>0</TextAreaRightMargin>
              <TextAreaTopMargin>0</TextAreaTopMargin>
              <TextOrientation>Horizontal</TextOrientation>
              <Top>$Top</Top>
              <UseDesignColorSchema>false</UseDesignColorSchema>
              <UseFirstGradient>false</UseFirstGradient>
              <UseSecondGradient>false</UseSecondGradient>
              <UseTwoHandOperation>false</UseTwoHandOperation>
              <VerticalAlignment>Middle</VerticalAlignment>
              <VerticalPictureAlignment>Middle</VerticalPictureAlignment>
              <Width>$Width</Width>
            </AttributeList>
            <ObjectList>
$eventXml
              <Hmi.Globalization.MultiLingualFont ID="$font" CompositionName="Font">
                <ObjectList>
                  <Hmi.Globalization.FontItem ID="$fontItem" CompositionName="Items">
                    <AttributeList>
                      <Culture>zh-CN</Culture>
                      <FontFamily>Arial</FontFamily>
                      <FontSize>14</FontSize>
                      <FontStyle>Regular</FontStyle>
                    </AttributeList>
                  </Hmi.Globalization.FontItem>
                </ObjectList>
              </Hmi.Globalization.MultiLingualFont>
              <MultilingualText ID="$help" CompositionName="HelpText">
                <ObjectList>
                  <MultilingualTextItem ID="$helpItem" CompositionName="Items">
                    <AttributeList>
                      <Culture>zh-CN</Culture>
                      <Text />
                    </AttributeList>
                  </MultilingualTextItem>
                </ObjectList>
              </MultilingualText>
              <MultilingualText ID="$off" CompositionName="TextOff">
                <ObjectList>
                  <MultilingualTextItem ID="$offItem" CompositionName="Items">
                    <AttributeList>
                      <Culture>zh-CN</Culture>
                      <Text><body><p>$safe</p></body></Text>
                    </AttributeList>
                  </MultilingualTextItem>
                </ObjectList>
              </MultilingualText>
              <MultilingualText ID="$on" CompositionName="TextOn">
                <ObjectList>
                  <MultilingualTextItem ID="$onItem" CompositionName="Items">
                    <AttributeList>
                      <Culture>zh-CN</Culture>
                      <Text><body><p>$safe</p></body></Text>
                    </AttributeList>
                  </MultilingualTextItem>
                </ObjectList>
              </MultilingualText>
            </ObjectList>
          </Hmi.Screen.Button>
"@
}

function New-IoFieldXml {
    param(
        [string]$Name,
        [string]$TagName,
        [int]$Left,
        [int]$Top,
        [int]$Width,
        [int]$Height = 28,
        [string]$Mode = "InOutput",
        [string]$DataFormat = "Decimal",
        [int]$FieldLength = 3,
        [string]$Pattern = "999"
    )
    $id = New-HmiId
    $font = New-HmiId
    $fontItem = New-HmiId
    $help = New-HmiId
    $helpItem = New-HmiId
    $prop = New-HmiId
    $dynamic = New-HmiId
@"
          <Hmi.Screen.IOField ID="$id" CompositionName="ScreenItems">
            <AttributeList>
              <AboveUpperLimitColor>237, 88, 97</AboveUpperLimitColor>
              <BackColor>255, 255, 255</BackColor>
              <BackFillStyle>Solid</BackFillStyle>
              <BelowLowerLimitColor>241, 161, 44</BelowLowerLimitColor>
              <BorderBackColor>101, 103, 115</BorderBackColor>
              <BorderColor>71, 73, 87</BorderColor>
              <BorderWidth>1</BorderWidth>
              <BottomMargin>2</BottomMargin>
              <CornerRadius>3</CornerRadius>
              <DataFormat>$DataFormat</DataFormat>
              <EdgeStyle>Double</EdgeStyle>
              <Enabled>true</Enabled>
              <FieldLength>$FieldLength</FieldLength>
              <FitToLargest>false</FitToLargest>
              <Flashing>None</Flashing>
              <ForeColor>0, 0, 180</ForeColor>
              <FormatPattern>$Pattern</FormatPattern>
              <Height>$Height</Height>
              <HiddenInput>false</HiddenInput>
              <HorizontalAlignment>Left</HorizontalAlignment>
              <Left>$Left</Left>
              <LeftMargin>3</LeftMargin>
              <Mode>$Mode</Mode>
              <ObjectName>$Name</ObjectName>
              <RightMargin>2</RightMargin>
              <ShiftDecimalPoint>0</ShiftDecimalPoint>
              <ShowLeadingZeros>false</ShowLeadingZeros>
              <TabIndex>1</TabIndex>
              <TextOrientation>Horizontal</TextOrientation>
              <Top>$Top</Top>
              <TopMargin>2</TopMargin>
              <Unit />
              <UseDesignColorSchema>false</UseDesignColorSchema>
              <UseTwoHandOperation>false</UseTwoHandOperation>
              <VerticalAlignment>Middle</VerticalAlignment>
              <Width>$Width</Width>
            </AttributeList>
            <ObjectList>
              <Hmi.Globalization.MultiLingualFont ID="$font" CompositionName="Font">
                <ObjectList>
                  <Hmi.Globalization.FontItem ID="$fontItem" CompositionName="Items">
                    <AttributeList>
                      <Culture>zh-CN</Culture>
                      <FontFamily>Arial</FontFamily>
                      <FontSize>13</FontSize>
                      <FontStyle>Regular</FontStyle>
                    </AttributeList>
                  </Hmi.Globalization.FontItem>
                </ObjectList>
              </Hmi.Globalization.MultiLingualFont>
              <MultilingualText ID="$help" CompositionName="HelpText">
                <ObjectList>
                  <MultilingualTextItem ID="$helpItem" CompositionName="Items">
                    <AttributeList>
                      <Culture>zh-CN</Culture>
                      <Text />
                    </AttributeList>
                  </MultilingualTextItem>
                </ObjectList>
              </MultilingualText>
              <Hmi.Screen.Property ID="$prop" CompositionName="Properties">
                <AttributeList>
                  <Name>ProcessValue</Name>
                </AttributeList>
                <ObjectList>
                  <Hmi.Dynamic.TagConnectionDynamic ID="$dynamic" CompositionName="Dynamic">
                    <AttributeList>
                      <Indirect>false</Indirect>
                    </AttributeList>
                    <LinkList>
                      <Tag TargetID="@OpenLink">
                        <Name>$TagName</Name>
                      </Tag>
                    </LinkList>
                  </Hmi.Dynamic.TagConnectionDynamic>
                </ObjectList>
              </Hmi.Screen.Property>
            </ObjectList>
          </Hmi.Screen.IOField>
"@
}

function Get-ComponentActiveId {
    param([string]$Component)
    switch ($Component) {
        "Valve01" { return "1" }
        "Heater01" { return "2" }
        "Fan01" { return "3" }
        default { return "0" }
    }
}

function Get-InputTagName {
    param([string]$Field, [string]$Component = $FocusComponent)
    if ($UseStructuredTagNames) {
        if ($Field -eq "SelectedCompID") { return "DB_ActivePopup_${Component}_ActiveID" }
        if ($Field -eq "ClickPulse") { return "DB_Components_${Component}_ClickTrig" }
        if ($Field -eq "DoubleClickTime_ms") { return "DB_Components_${Component}_DoubleClickTime" }
        if ($Field -eq "Switch1") { return "DB_Components_${Component}_Switch1" }
        if ($Field -eq "RealValue1_Int") { return "DB_Components_${Component}_RealValue1_Int" }
    }
    switch ($Field) {
        "SelectedCompID" { return "Sim_SelectedCompID" }
        "ClickPulse" { return "Sim_ClickPulse" }
        "DoubleClickTime_ms" { return "Sim_DoubleClickTime_ms" }
        "Switch1" { return "Sim_Switch1" }
        "RealValue1_Int" { return "Sim_RealValue1_Int" }
        default { return $Field }
    }
}

function Get-OutputTagName {
    param([string]$Field, [string]$Component = $FocusComponent)
    if ($UseStructuredTagNames) {
        return "DB_ActivePopup_${Component}_${Field}"
    }
    switch ($Field) {
        "Visible" { return "Sim_Visible" }
        "ActiveID" { return "Sim_ActiveID" }
        "Confirmed" { return "Sim_Confirmed" }
        "ConfirmBtn" { return "Sim_ConfirmPulse" }
        "CancelBtn" { return "Sim_CancelPulse" }
        default { return $Field }
    }
}

$OutputRoot = [System.IO.Path]::GetFullPath($OutputRoot)
$importDir = Join-Path $OutputRoot "import"
$exportDir = Join-Path $OutputRoot "exports"
$logDir = Join-Path $OutputRoot "logs"
New-Item -ItemType Directory -Force -Path $importDir, $exportDir, $logDir | Out-Null

$help = New-HmiId
$helpItem = New-HmiId
$layer = New-HmiId
$items = New-Object System.Collections.Generic.List[string]
$usageText = if ($UseStructuredTagNames) {
    "Normal TP1200 runtime simulation: tag names mirror PLC data, for example DB_ActivePopup_${FocusComponent}_ActiveID."
}
elseif ($AsNormalScreen -and $BindIntSet) {
    "Normal TP1200 runtime simulation: Int IOFields are bound, and buttons write SetTag values without needing a popup open function."
}
elseif ($BindIntSet) {
    "IO2 simulation: Int IOFields are bound, and buttons write SetTag values for trigger/visible/confirm/cancel states."
}
elseif ($BindCompId) {
    "IO1 simulation: CompID is bound to Sim_SelectedCompID; the other boxes stay visual."
}
else {
    "Visual-only safe screen: no tag table, no ProcessValue binding. Use this first to verify TP1200 layout."
}

$titleText = if ($AsNormalScreen) { "HMI Popup Simulation Runtime Screen" } else { "HMI Popup Simulation 800x800" }
$items.Add((New-TextFieldXml -Name "Txt_Title" -Text $titleText -Left 25 -Top 18 -Width 750 -Height 42 -FontSize 22 -FontStyle "Bold" -HorizontalAlignment "Center" -BackFillStyle "Solid" -BackColor "226, 239, 255"))
$items.Add((New-TextFieldXml -Name "Txt_Usage" -Text $usageText -Left 30 -Top 72 -Width 735 -Height 32 -FontSize 13))
$items.Add((New-TextFieldXml -Name "Txt_InputHeader" -Text "Input / Trigger" -Left 38 -Top 122 -Width 320 -Height 32 -FontSize 16 -FontStyle "Bold" -BackFillStyle "Solid" -BackColor "235, 235, 235"))
$items.Add((New-TextFieldXml -Name "Txt_OutputHeader" -Text "Output / Popup State" -Left 420 -Top 122 -Width 320 -Height 32 -FontSize 16 -FontStyle "Bold" -BackFillStyle "Solid" -BackColor "235, 235, 235"))

if ($BindIntSet) {
    $valveId = Get-ComponentActiveId "Valve01"
    $heaterId = Get-ComponentActiveId "Heater01"
    $fanId = Get-ComponentActiveId "Fan01"
    $items.Add((New-ButtonXml -Name "Btn_Valve01_Trigger" -Text "Valve01 Trigger" -Left 38 -Top 168 -SetTags @(
        @{ Tag=(Get-InputTagName "SelectedCompID" "Valve01"); Value=$valveId }, @{ Tag=(Get-InputTagName "ClickPulse" "Valve01"); Value="1" }, @{ Tag=(Get-OutputTagName "Visible" "Valve01"); Value="1" },
        @{ Tag=(Get-OutputTagName "ActiveID" "Valve01"); Value=$valveId }, @{ Tag=(Get-OutputTagName "Confirmed" "Valve01"); Value="0" }, @{ Tag=(Get-OutputTagName "ConfirmBtn" "Valve01"); Value="0" },
        @{ Tag=(Get-OutputTagName "CancelBtn" "Valve01"); Value="0" }
    )))
    $items.Add((New-ButtonXml -Name "Btn_Heater01_Trigger" -Text "Heater01 Trigger" -Left 205 -Top 168 -SetTags @(
        @{ Tag=(Get-InputTagName "SelectedCompID" "Heater01"); Value=$heaterId }, @{ Tag=(Get-InputTagName "ClickPulse" "Heater01"); Value="1" }, @{ Tag=(Get-OutputTagName "Visible" "Heater01"); Value="1" },
        @{ Tag=(Get-OutputTagName "ActiveID" "Heater01"); Value=$heaterId }, @{ Tag=(Get-OutputTagName "Confirmed" "Heater01"); Value="0" }, @{ Tag=(Get-OutputTagName "ConfirmBtn" "Heater01"); Value="0" },
        @{ Tag=(Get-OutputTagName "CancelBtn" "Heater01"); Value="0" }
    )))
    $items.Add((New-ButtonXml -Name "Btn_Fan01_Trigger" -Text "Fan01 Trigger" -Left 38 -Top 225 -SetTags @(
        @{ Tag=(Get-InputTagName "SelectedCompID" "Fan01"); Value=$fanId }, @{ Tag=(Get-InputTagName "ClickPulse" "Fan01"); Value="1" }, @{ Tag=(Get-OutputTagName "Visible" "Fan01"); Value="1" },
        @{ Tag=(Get-OutputTagName "ActiveID" "Fan01"); Value=$fanId }, @{ Tag=(Get-OutputTagName "Confirmed" "Fan01"); Value="0" }, @{ Tag=(Get-OutputTagName "ConfirmBtn" "Fan01"); Value="0" },
        @{ Tag=(Get-OutputTagName "CancelBtn" "Fan01"); Value="0" }
    )))
    $items.Add((New-ButtonXml -Name "Btn_Reset_ClickPulse" -Text "Reset Pulse" -Left 205 -Top 225 -BackColor "245, 245, 245" -BorderColor "120, 120, 120" -SetTags @(
        @{ Tag=(Get-InputTagName "ClickPulse" "Valve01"); Value="0" }, @{ Tag=(Get-InputTagName "ClickPulse" "Heater01"); Value="0" }, @{ Tag=(Get-InputTagName "ClickPulse" "Fan01"); Value="0" },
        @{ Tag=(Get-OutputTagName "ConfirmBtn" "Valve01"); Value="0" }, @{ Tag=(Get-OutputTagName "ConfirmBtn" "Heater01"); Value="0" }, @{ Tag=(Get-OutputTagName "ConfirmBtn" "Fan01"); Value="0" },
        @{ Tag=(Get-OutputTagName "CancelBtn" "Valve01"); Value="0" }, @{ Tag=(Get-OutputTagName "CancelBtn" "Heater01"); Value="0" }, @{ Tag=(Get-OutputTagName "CancelBtn" "Fan01"); Value="0" }
    )))
    $items.Add((New-ButtonXml -Name "Btn_Confirm" -Text "Confirm" -Left 430 -Top 380 -BackColor "218, 245, 226" -BorderColor "0, 140, 70" -SetTags @(
        @{ Tag=(Get-OutputTagName "ConfirmBtn"); Value="1" }, @{ Tag=(Get-OutputTagName "CancelBtn"); Value="0" }, @{ Tag=(Get-OutputTagName "Confirmed"); Value="1" },
        @{ Tag=(Get-OutputTagName "Visible"); Value="0" }, @{ Tag=(Get-InputTagName "ClickPulse"); Value="0" }
    )))
    $items.Add((New-ButtonXml -Name "Btn_Cancel" -Text "Cancel" -Left 595 -Top 380 -BackColor "255, 235, 235" -BorderColor "180, 60, 60" -SetTags @(
        @{ Tag=(Get-OutputTagName "ConfirmBtn"); Value="0" }, @{ Tag=(Get-OutputTagName "CancelBtn"); Value="1" }, @{ Tag=(Get-OutputTagName "Confirmed"); Value="0" },
        @{ Tag=(Get-OutputTagName "Visible"); Value="0" }, @{ Tag=(Get-InputTagName "ClickPulse"); Value="0" }
    )))
}
else {
    $items.Add((New-ButtonXml -Name "Btn_Valve01_Trigger" -Text "Valve01 Trigger" -Left 38 -Top 168))
    $items.Add((New-ButtonXml -Name "Btn_Heater01_Trigger" -Text "Heater01 Trigger" -Left 205 -Top 168))
    $items.Add((New-ButtonXml -Name "Btn_Fan01_Trigger" -Text "Fan01 Trigger" -Left 38 -Top 225))
    $items.Add((New-ButtonXml -Name "Btn_Reset_ClickPulse" -Text "Reset Pulse" -Left 205 -Top 225 -BackColor "245, 245, 245" -BorderColor "120, 120, 120"))
    $items.Add((New-ButtonXml -Name "Btn_Confirm" -Text "Confirm" -Left 430 -Top 380 -BackColor "218, 245, 226" -BorderColor "0, 140, 70"))
    $items.Add((New-ButtonXml -Name "Btn_Cancel" -Text "Cancel" -Left 595 -Top 380 -BackColor "255, 235, 235" -BorderColor "180, 60, 60"))
}

$inputRows = @(
    @{ Label="CompID"; Value="1/2/3"; Top=300; Tag=(Get-InputTagName "SelectedCompID"); Obj="CompID"; Len=3; Pattern="999" },
    @{ Label="ClickTrig"; Value="0/1"; Top=340; Tag=(Get-InputTagName "ClickPulse"); Obj="ClickTrig"; Len=1; Pattern="9" },
    @{ Label="DoubleClickTime"; Value="800"; Top=380; Tag=(Get-InputTagName "DoubleClickTime_ms"); Obj="DoubleClickTime"; Len=4; Pattern="9999" },
    @{ Label="Switch[1]"; Value="0/1"; Top=420; Tag=(Get-InputTagName "Switch1"); Obj="Switch1"; Len=1; Pattern="9" },
    @{ Label="RealValue[1]"; Value="0"; Top=460; Tag=(Get-InputTagName "RealValue1_Int"); Obj="RealValue1"; Len=5; Pattern="99999" }
)
foreach ($row in $inputRows) {
    $items.Add((New-TextFieldXml -Name ("Lbl_Input_" + $row.Obj) -Text $row.Label -Left 45 -Top $row.Top -Width 155 -Height 28 -FontSize 13))
    if ($BindIntSet -or ($BindCompId -and $row.Label -eq "CompID")) {
        $items.Add((New-IoFieldXml -Name ("IO_Input_" + $row.Obj) -TagName $row.Tag -Left 210 -Top $row.Top -Width 125 -Height 28 -Mode "InOutput" -DataFormat "Decimal" -FieldLength $row.Len -Pattern $row.Pattern))
    }
    else {
        $items.Add((New-TextFieldXml -Name ("Box_Input_" + $row.Obj) -Text $row.Value -Left 210 -Top $row.Top -Width 125 -Height 28 -FontSize 13 -BackFillStyle "Solid" -BackColor "255, 255, 255" -ForeColor "0, 0, 180" -BorderWidth 1))
    }
}

$outputRows = @(
    @{ Label="Visible"; Value="0/1"; Top=168; Tag=(Get-OutputTagName "Visible"); Len=1; Pattern="9" },
    @{ Label="ActiveID"; Value="1/2/3"; Top=208; Tag=(Get-OutputTagName "ActiveID"); Len=3; Pattern="999" },
    @{ Label="Confirmed"; Value="0/1"; Top=248; Tag=(Get-OutputTagName "Confirmed"); Len=1; Pattern="9" },
    @{ Label="ConfirmBtn"; Value="0/1"; Top=288; Tag=(Get-OutputTagName "ConfirmBtn"); Len=1; Pattern="9" },
    @{ Label="CancelBtn"; Value="0/1"; Top=328; Tag=(Get-OutputTagName "CancelBtn"); Len=1; Pattern="9" }
)
foreach ($row in $outputRows) {
    $items.Add((New-TextFieldXml -Name ("Lbl_Output_" + $row.Label) -Text $row.Label -Left 430 -Top $row.Top -Width 120 -Height 28 -FontSize 13))
    if ($BindIntSet) {
        $items.Add((New-IoFieldXml -Name ("IO_Output_" + $row.Label) -TagName $row.Tag -Left 555 -Top $row.Top -Width 120 -Height 28 -Mode "Output" -DataFormat "Decimal" -FieldLength $row.Len -Pattern $row.Pattern))
    }
    else {
        $items.Add((New-TextFieldXml -Name ("Box_Output_" + $row.Label) -Text $row.Value -Left 555 -Top $row.Top -Width 120 -Height 28 -FontSize 13 -BackFillStyle "Solid" -BackColor "250, 250, 250" -ForeColor "0, 0, 180" -BorderWidth 1))
    }
}

$items.Add((New-TextFieldXml -Name "Lbl_InfoTitle" -Text "InfoTitle" -Left 45 -Top 530 -Width 110 -Height 28 -FontSize 13))
$items.Add((New-TextFieldXml -Name "Box_InfoTitle" -Text "Valve01 / Heater01 / Fan01" -Left 160 -Top 530 -Width 575 -Height 30 -FontSize 13 -BackFillStyle "Solid" -BackColor "255, 255, 255" -BorderWidth 1))
$items.Add((New-TextFieldXml -Name "Lbl_InfoMessage" -Text "InfoMessage" -Left 45 -Top 570 -Width 110 -Height 28 -FontSize 13))
$items.Add((New-TextFieldXml -Name "Box_InfoMessage" -Text "Confirm operation popup message here." -Left 160 -Top 570 -Width 575 -Height 60 -FontSize 13 -BackFillStyle "Solid" -BackColor "255, 255, 255" -BorderWidth 1))

$items.Add((New-TextFieldXml -Name "Txt_PlcMap1" -Text "PLC map: DB_Components.Valve01/Heater01/Fan01.ClickTrig -> HMI popup FB1 -> DB_ActivePopup.*" -Left 38 -Top 660 -Width 705 -Height 30 -FontSize 12 -ForeColor "70, 70, 70"))
$items.Add((New-TextFieldXml -Name "Txt_PlcMap2" -Text "Next step after stable import: replace visual boxes with IOFields and bind tags one by one." -Left 38 -Top 695 -Width 705 -Height 30 -FontSize 12 -ForeColor "70, 70, 70"))
$items.Add((New-TextFieldXml -Name "Txt_Note" -Text "No HMI tag table is imported by this safe version, so it should not trigger the previous tag import crash." -Left 38 -Top 730 -Width 705 -Height 30 -FontSize 12 -ForeColor "100, 80, 0"))

$screenItemsXml = ($items.ToArray()) -join "`r`n"
$screenKind = if ($AsNormalScreen) { "Hmi.Screen.Screen" } else { "Hmi.Screen.ScreenPopup" }
$normalOnlyAttributes = if ($AsNormalScreen) {
@"
      <Number>$ScreenNumber</Number>
      <Visible>true</Visible>
"@
}
else {
    ""
}
$normalHelpText = if ($AsNormalScreen) {
@"
      <MultilingualText ID="$help" CompositionName="HelpText">
        <ObjectList>
          <MultilingualTextItem ID="$helpItem" CompositionName="Items">
            <AttributeList>
              <Culture>zh-CN</Culture>
              <Text />
            </AttributeList>
          </MultilingualTextItem>
        </ObjectList>
      </MultilingualText>
"@
}
else {
    ""
}

$screenXml = @"
<?xml version="1.0" encoding="utf-8"?>
<Document>
  <Engineering version="V17" />
  <$screenKind ID="0">
    <AttributeList>
      <ActiveLayer>0</ActiveLayer>
      <BackColor>255, 255, 255</BackColor>
      <GridColor>0, 0, 0</GridColor>
      <Height>$ScreenHeight</Height>
      <Name>$ScreenName</Name>
$normalOnlyAttributes
      <Width>$ScreenWidth</Width>
    </AttributeList>
    <ObjectList>
$normalHelpText
      <Hmi.Screen.ScreenLayer ID="$layer" CompositionName="Layers">
        <AttributeList>
          <Index>0</Index>
          <Name />
          <VisibleES>true</VisibleES>
        </AttributeList>
        <ObjectList>
$screenItemsXml
        </ObjectList>
      </Hmi.Screen.ScreenLayer>
    </ObjectList>
  </$screenKind>
</Document>
"@

$screenXmlPath = Join-Path $importDir "$ScreenName.visual.xml"
$screenXml | Set-Content -LiteralPath $screenXmlPath -Encoding UTF8
$log = New-Object System.Collections.Generic.List[string]
$log.Add("GeneratedVisualScreenXml=$screenXmlPath")

if (-not $SkipImport) {
    Load-TiaV17Assemblies
    $process = [Siemens.Engineering.TiaPortal]::GetProcesses() |
        Where-Object { $_.Mode.ToString() -eq "WithUserInterface" -and $_.ProjectPath } |
        Select-Object -First 1
    if (-not $process) { throw "No open TIA Portal UI process with a project path was found." }

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
        if ($AsNormalScreen) {
            $hmi.ScreenFolder.Screens.Import([System.IO.FileInfo]$screenXmlPath, [Siemens.Engineering.ImportOptions]::Override) | Out-Null
            $screen = $hmi.ScreenFolder.Screens.Find($ScreenName)
            if (-not $screen) { throw "Imported normal screen not found: $ScreenName" }
        }
        else {
            $hmi.ScreenPopupFolder.ScreenPopups.Import([System.IO.FileInfo]$screenXmlPath, [Siemens.Engineering.ImportOptions]::Override) | Out-Null
            $screen = $hmi.ScreenPopupFolder.ScreenPopups.Find($ScreenName)
            if (-not $screen) { throw "Imported popup screen not found: $ScreenName" }
        }
        $exportPath = Join-Path $exportDir "$($ScreenName)_visual_export.xml"
        if (Test-Path -LiteralPath $exportPath) { Remove-Item -LiteralPath $exportPath -Force }
        $screen.Export([System.IO.FileInfo]$exportPath, [Siemens.Engineering.ExportOptions]::WithDefaults)
        $project.Save()
        if ($AsNormalScreen) {
            $log.Add("OK_IMPORT_VISUAL_SCREEN=$ScreenName")
            $log.Add("OK_EXPORT_VISUAL_SCREEN=$exportPath")
        }
        else {
            $log.Add("OK_IMPORT_VISUAL_POPUP=$ScreenName")
            $log.Add("OK_EXPORT_VISUAL_POPUP=$exportPath")
        }
        $log.Add("ProjectSaved=True")
    }
    finally {
        if ($tia) { $tia.Dispose() }
    }
}

$logPath = Join-Path $logDir "popup_sim_visual_screen_loop.txt"
$log | Set-Content -LiteralPath $logPath -Encoding UTF8
$log
