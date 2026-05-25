param(
    [string]$ProjectPath = $env:EPLAN_PROJECT_PATH,
    [string]$OutputDir = $env:EPLAN_OUTPUT_DIR
)

$ErrorActionPreference = 'Stop'

$platformBin = 'C:\Program Files\EPLAN\Platform\2.9.4\Bin'
$offlineBin = 'C:\Program Files\EPLAN\Electric P8\2.9.4\Bin'

if ([string]::IsNullOrWhiteSpace($ProjectPath)) {
    throw 'EPLAN_PROJECT_PATH is not set.'
}

if ([string]::IsNullOrWhiteSpace($OutputDir)) {
    throw 'EPLAN_OUTPUT_DIR is not set.'
}

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

$summaryPath = Join-Path $OutputDir 'eplan_io_summary.txt'
$csvPath = Join-Path $OutputDir 'eplan_io_points.csv'
$errorPath = Join-Path $OutputDir 'eplan_io_error.txt'

[System.Reflection.Assembly]::LoadFrom((Join-Path $platformBin 'Eplan.EplApi.Baseu.dll')) | Out-Null
[System.Reflection.Assembly]::LoadFrom((Join-Path $platformBin 'Eplan.EplApi.Systemu.dll')) | Out-Null
[System.Reflection.Assembly]::LoadFrom((Join-Path $platformBin 'Eplan.EplApi.DataModelu.dll')) | Out-Null

$app = New-Object Eplan.EplApi.System.EplApplication
$app.EplanBinFolder = $offlineBin
$app.QuietMode = [Eplan.EplApi.System.EplApplication+QuietModes]::ShowNoDialogs
$app.Init('')

try {
    $pm = New-Object Eplan.EplApi.DataModel.ProjectManager
    $pm.LockProjectByDefault = $false
    $project = $pm.OpenProject($ProjectPath, [Eplan.EplApi.DataModel.ProjectManager+OpenMode]::ReadOnly)
    if ($null -eq $project) {
        throw "OpenProject returned null for '$ProjectPath'."
    }

    $finder = New-Object Eplan.EplApi.DataModel.DMObjectsFinder($project)
    $plcs = @($finder.GetPLCs($null))
    $rows = New-Object System.Collections.Generic.List[object]

    foreach ($plc in $plcs) {
        $plcName = [string]$plc.VisibleName
        if ([string]::IsNullOrWhiteSpace($plcName)) {
            $plcName = [string]$plc.Name
        }

        $moduleKind = ''
        if ($plcName -match '^[A-Za-z]+') {
            $moduleKind = $matches[0].ToUpperInvariant()
        }

        $plcPage = ''
        if ($plc.Page -ne $null) {
            $plcPage = [string]$plc.Page.Name
        }

        foreach ($terminal in @($plc.PLCTerminals)) {
            $io = $terminal.PlcIOEntry
            if ($null -eq $io) {
                continue
            }

            $directionDisplay = ''
            $directionCode = ''
            try {
                $directionDisplay = [string]$io.Properties.PLCIOENTRY_DIRECTION.GetDisplayString()
            }
            catch {
            }
            try {
                $directionCode = [string]$io.Properties.PLCIOENTRY_DIRECTION.ToInt()
            }
            catch {
            }

            if ([string]::IsNullOrWhiteSpace($directionDisplay)) {
                switch ($moduleKind) {
                    'AI' { $directionDisplay = 'Input' }
                    'DI' { $directionDisplay = 'Input' }
                    'AQ' { $directionDisplay = 'Output' }
                    'DQ' { $directionDisplay = 'Output' }
                }
            }

            $terminalName = [string]$terminal.VisibleName
            if ([string]::IsNullOrWhiteSpace($terminalName)) {
                $terminalName = [string]$terminal.Name
            }

            $pageName = ''
            if ($terminal.Page -ne $null) {
                $pageName = [string]$terminal.Page.Name
            }

            $parentFunction = ''
            if ($terminal.ParentFunction -ne $null) {
                $parentFunction = [string]$terminal.ParentFunction.VisibleName
                if ([string]::IsNullOrWhiteSpace($parentFunction)) {
                    $parentFunction = [string]$terminal.ParentFunction.Name
                }
            }

            $functionText = [string]$io.FunctionText
            if ($functionText -match '@') {
                $functionText = $functionText.Substring($functionText.LastIndexOf('@') + 1)
            }
            $functionText = $functionText.TrimEnd(';')

            $externalConnections = @(
                $terminal.ExternalConnections | ForEach-Object {
                    $fn = [string]$_.FunctionName
                    $pin = [string]$_.FunctionPinName
                    $cn = [string]$_.ConnectionName
                    (@($fn, $pin, $cn) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) -join ':'
                }
            ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

            $connectionEndpoints = @(
                $terminal.Connections | ForEach-Object {
                    $src = ''
                    $dst = ''
                    try {
                        $src = [string]$_.Properties.CONNECTION_SOURCE.GetDisplayString()
                    }
                    catch {
                    }
                    try {
                        $dst = [string]$_.Properties.CONNECTION_DESTINATION.GetDisplayString()
                    }
                    catch {
                    }
                    (@($src, $dst) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) -join ' => '
                }
            ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

            $rows.Add([pscustomobject]@{
                PlcBox = $plcName
                ModuleKind = $moduleKind
                PlcPage = $plcPage
                Terminal = $terminalName
                Direction = $directionDisplay
                DirectionCode = $directionCode
                Address = [string]$io.Address
                SymbolicAddress = [string]$io.SymbolicAddress
                DataType = [string]$io.DataType
                Cpu = [string]$io.PlcCpu
                FunctionText = $functionText
                Page = $pageName
                ParentFunction = $parentFunction
                ExternalConnections = ($externalConnections -join ' | ')
                ConnectionEndpoints = ($connectionEndpoints -join ' | ')
                TerminalObjectId = [string]$terminal.ObjectIdentifier
                PlcIoObjectId = [string]$io.ObjectIdentifier
            })
        }
    }

    $rows | Sort-Object ModuleKind, PlcBox, Address, Terminal | Export-Csv -LiteralPath $csvPath -NoTypeInformation -Encoding UTF8

    $directionCounts = $rows | Group-Object Direction | Sort-Object Name
    $moduleCounts = $rows | Group-Object ModuleKind | Sort-Object Name
    $connectedCount = @(
        $rows | Where-Object {
            -not [string]::IsNullOrWhiteSpace($_.ExternalConnections) -or
            -not [string]::IsNullOrWhiteSpace($_.ConnectionEndpoints)
        }
    ).Count
    $unconnectedCount = $rows.Count - $connectedCount

    $summary = New-Object System.Collections.Generic.List[string]
    $summary.Add("Project=$($project.ProjectLinkFilePath)")
    $summary.Add("Csv=$csvPath")
    $summary.Add("PlcBoxCount=$($plcs.Count)")
    $summary.Add("IoPointCount=$($rows.Count)")
    $summary.Add("ConnectedIoPointCount=$connectedCount")
    $summary.Add("UnconnectedIoPointCount=$unconnectedCount")
    $summary.Add('')
    $summary.Add('[DirectionCounts]')
    foreach ($item in $directionCounts) {
        $name = $item.Name
        if ([string]::IsNullOrWhiteSpace($name)) {
            $name = '(empty)'
        }
        $summary.Add("$name=$($item.Count)")
    }
    $summary.Add('')
    $summary.Add('[ModuleKindCounts]')
    foreach ($item in $moduleCounts) {
        $name = $item.Name
        if ([string]::IsNullOrWhiteSpace($name)) {
            $name = '(empty)'
        }
        $summary.Add("$name=$($item.Count)")
    }

    Set-Content -LiteralPath $summaryPath -Value $summary -Encoding UTF8

    if (Test-Path $errorPath) {
        Remove-Item -LiteralPath $errorPath -Force
    }
}
catch {
    Set-Content -LiteralPath $errorPath -Value $_.Exception.ToString() -Encoding UTF8
    throw
}
