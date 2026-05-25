[CmdletBinding()]
param(
    [int]$ProcessId,
    [string[]]$Terms = @('DRYER', '结果', '流股结果', '摘要', '出风温度', '汽相温度'),
    [switch]$Exact,
    [switch]$Json
)

Add-Type -AssemblyName UIAutomationClient

if (-not $ProcessId) {
    $ProcessId = (
        Get-Process |
        Where-Object {
            ($_.ProcessName -match 'Aspen|Apwn|Hysys' -or $_.MainWindowTitle -match 'Aspen') -and
            $_.MainWindowTitle
        } |
        Select-Object -First 1 -ExpandProperty Id
    )
}

if (-not $ProcessId) {
    throw 'No visible Aspen window was found.'
}

$process = Get-Process -Id $ProcessId -ErrorAction Stop
$root = [System.Windows.Automation.AutomationElement]::FromHandle($process.MainWindowHandle)
$all = $root.FindAll(
    [System.Windows.Automation.TreeScope]::Descendants,
    [System.Windows.Automation.Condition]::TrueCondition
)

$matches = New-Object System.Collections.Generic.List[object]

for ($i = 0; $i -lt $all.Count; $i++) {
    $element = $all.Item($i)
    $name = $element.Current.Name

    if ([string]::IsNullOrWhiteSpace($name)) {
        continue
    }

    foreach ($term in $Terms) {
        $isMatch = if ($Exact) {
            $name -eq $term
        } else {
            $name -like "*$term*"
        }

        if ($isMatch) {
            $rect = $element.Current.BoundingRectangle
            $matches.Add([pscustomobject]@{
                Term        = $term
                Name        = $name
                ClassName   = $element.Current.ClassName
                ControlType = $element.Current.ControlType.ProgrammaticName
                Left        = $rect.Left
                Top         = $rect.Top
                Width       = $rect.Width
                Height      = $rect.Height
            })
            break
        }
    }
}

if ($Json) {
    $matches | ConvertTo-Json -Depth 3
    exit 0
}

$matches | Sort-Object Term, Name | Format-Table -AutoSize
