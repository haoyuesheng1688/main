param(
    [string]$ExportRoot,
    [string]$OutputDir = "C:\Users\QF100\Documents\New project\docs\appendices"
)

$ErrorActionPreference = "Stop"

function Ensure-Directory {
    param([string]$Path)
    New-Item -ItemType Directory -Force -Path $Path | Out-Null
}

function Normalize-Text {
    param([string]$Text)
    if ($null -eq $Text) { return "" }
    return ($Text -replace '^\s+|\s+$', '')
}

function Get-StLines {
    param([string]$XmlPath)

    [xml]$xml = Get-Content -Raw -LiteralPath $XmlPath
    $ns = New-Object System.Xml.XmlNamespaceManager($xml.NameTable)
    $ns.AddNamespace("st", "http://www.siemens.com/automation/Openness/SW/NetworkSource/StructuredText/v3")
    $st = $xml.SelectSingleNode("//st:StructuredText", $ns)
    if (-not $st) {
        throw "StructuredText not found in $XmlPath"
    }

    $lines = New-Object System.Collections.Generic.List[string]
    $current = ""

    foreach ($child in $st.ChildNodes) {
        switch ($child.LocalName) {
            "NewLine" {
                $num = [int]$child.GetAttribute("Num")
                for ($i = 0; $i -lt $num; $i++) {
                    $lines.Add($current)
                    $current = ""
                }
            }
            "LineComment" {
                $current += ("// " + $child.InnerText)
            }
            "Access" {
                $names = $child.SelectNodes('.//*[local-name()="Component"]') | ForEach-Object {
                    $_.GetAttribute("Name")
                }
                $current += ($names -join ".")
            }
            "Blank" {
                $current += (" " * [int]$child.GetAttribute("Num"))
            }
            "Token" {
                $current += $child.GetAttribute("Text")
            }
            default {
                $current += $child.InnerText
            }
        }
    }

    if ($current) {
        $lines.Add($current)
    }

    return $lines
}

function Export-TagTableCsv {
    param(
        [string]$XmlPath,
        [string]$CsvPath
    )

    [xml]$xml = Get-Content -Raw -LiteralPath $XmlPath
    $table = $xml.Document.'SW.Tags.PlcTagTable'
    $tableName = $table.AttributeList.Name
    $rows = foreach ($tag in $table.ObjectList.'SW.Tags.PlcTag') {
        [PSCustomObject]@{
            TableName       = $tableName
            Name            = $tag.AttributeList.Name
            DataType        = $tag.AttributeList.DataTypeName
            LogicalAddress  = $tag.AttributeList.LogicalAddress
            ExternalVisible = $tag.AttributeList.ExternalVisible
        }
    }

    $rows | Export-Csv -NoTypeInformation -Encoding UTF8 -LiteralPath $CsvPath
}

Ensure-Directory -Path $OutputDir

if (-not $ExportRoot) {
    $tiaExportsRoot = "C:\Users\QF100\Documents\New project\tia_exports"
    $candidate = Get-ChildItem -LiteralPath $tiaExportsRoot -Directory |
        Where-Object { $_.Name -like "*_review" } |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1

    if (-not $candidate) {
        throw "No *_review export directory was found under $tiaExportsRoot"
    }

    $ExportRoot = $candidate.FullName
}

$ioBlockPath = Join-Path $ExportRoot "plc_blocks\0- IO Configure.xml"
$lines = Get-StLines -XmlPath $ioBlockPath

$digitalInputs = foreach ($line in $lines) {
    if ($line -match '^(?<symbol>[^=]+?)\s*:=\s*(?<invert>NOT\s+)?(?<addr>I\d+\.\d+)\s*;$') {
        [PSCustomObject]@{
            SignalName     = (Normalize-Text $matches.symbol)
            PhysicalInput  = $matches.addr
            Inverted       = [bool]$matches.invert
        }
    }
}

$digitalOutputs = foreach ($line in $lines) {
    if ($line -match '^(?<addr>Q\d+\.\d+)\s*:=\s*(?<symbol>[^;]+?)\s*;\s*(?<comment>//.*)?$') {
        [PSCustomObject]@{
            PhysicalOutput = $matches.addr
            SignalName     = (Normalize-Text $matches.symbol)
            Comment        = (Normalize-Text $matches.comment)
        }
    }
}

$analogInputs = foreach ($line in $lines) {
    if ($line -match '^(?<symbol>[^=]+?)\s*:=\s*(?<addr>IW\d+)\s*;$') {
        [PSCustomObject]@{
            SignalName    = (Normalize-Text $matches.symbol)
            PhysicalInput = $matches.addr
        }
    }
}

$analogOutputs = foreach ($line in $lines) {
    if ($line -match '^(?<addr>QW\d+)\s*:=\s*(?<symbol>[^;]+?)\s*;$') {
        [PSCustomObject]@{
            PhysicalOutput = $matches.addr
            SignalName     = (Normalize-Text $matches.symbol)
        }
    }
}

$digitalInputs |
    Sort-Object PhysicalInput |
    Export-Csv -NoTypeInformation -Encoding UTF8 -LiteralPath (Join-Path $OutputDir "plc_digital_input_map.csv")

$digitalOutputs |
    Sort-Object PhysicalOutput |
    Export-Csv -NoTypeInformation -Encoding UTF8 -LiteralPath (Join-Path $OutputDir "plc_digital_output_map.csv")

$analogInputs |
    Sort-Object PhysicalInput |
    Export-Csv -NoTypeInformation -Encoding UTF8 -LiteralPath (Join-Path $OutputDir "plc_analog_input_map.csv")

$analogOutputs |
    Sort-Object PhysicalOutput |
    Export-Csv -NoTypeInformation -Encoding UTF8 -LiteralPath (Join-Path $OutputDir "plc_analog_output_map.csv")

Export-TagTableCsv -XmlPath (Join-Path $ExportRoot "plc_tag_tables\IOM.xml") -CsvPath (Join-Path $OutputDir "plc_iom_symbolic_points.csv")
Export-TagTableCsv -XmlPath (Join-Path $ExportRoot "plc_tag_tables\M.xml") -CsvPath (Join-Path $OutputDir "plc_m_command_points.csv")
Export-TagTableCsv -XmlPath (Join-Path $ExportRoot "plc_tag_tables\AIQM.xml") -CsvPath (Join-Path $OutputDir "plc_aiqm_scaled_points.csv")
Export-TagTableCsv -XmlPath (Join-Path $ExportRoot "plc_tag_tables\Alarm.xml") -CsvPath (Join-Path $OutputDir "plc_alarm_points.csv")

$summary = @(
    [PSCustomObject]@{ Item = "DigitalInputs"; Count = $digitalInputs.Count }
    [PSCustomObject]@{ Item = "DigitalOutputs"; Count = $digitalOutputs.Count }
    [PSCustomObject]@{ Item = "AnalogInputs"; Count = $analogInputs.Count }
    [PSCustomObject]@{ Item = "AnalogOutputs"; Count = $analogOutputs.Count }
)

$summary | Export-Csv -NoTypeInformation -Encoding UTF8 -LiteralPath (Join-Path $OutputDir "appendix_summary.csv")

Write-Output "Appendix files generated in $OutputDir"
