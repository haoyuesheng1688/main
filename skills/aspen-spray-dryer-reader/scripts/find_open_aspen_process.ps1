[CmdletBinding()]
param(
    [switch]$IncludeBackground,
    [switch]$Json
)

$processes = Get-Process | Where-Object {
    $_.ProcessName -match 'Aspen|Apwn|Hysys' -or $_.MainWindowTitle -match 'Aspen'
}

if (-not $IncludeBackground) {
    $processes = $processes | Where-Object { $_.MainWindowTitle }
}

$result = foreach ($process in $processes) {
    $cim = Get-CimInstance Win32_Process -Filter "ProcessId = $($process.Id)" -ErrorAction SilentlyContinue

    [pscustomobject]@{
        ProcessName     = $process.ProcessName
        Id              = $process.Id
        MainWindowTitle = $process.MainWindowTitle
        ExecutablePath  = $cim.ExecutablePath
        CommandLine     = $cim.CommandLine
    }
}

$result = $result | Sort-Object @{ Expression = { [string]::IsNullOrWhiteSpace($_.MainWindowTitle) } }, ProcessName, Id

if ($Json) {
    $result | ConvertTo-Json -Depth 3
    exit 0
}

$result | Format-Table -AutoSize
