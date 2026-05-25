param([string]$OutputRoot = ".\tia_rtpro_learning")

$ErrorActionPreference = "Stop"
$OutputRoot = [System.IO.Path]::GetFullPath($OutputRoot)
$logDir = Join-Path $OutputRoot "logs"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$logPath = Join-Path $logDir "probe_hmi_services.txt"
if (Test-Path -LiteralPath $logPath) { Remove-Item -LiteralPath $logPath -Force }
function LogLine([string]$s) { Add-Content -LiteralPath $logPath -Value $s -Encoding UTF8 }

[System.Reflection.Assembly]::LoadFrom("C:\Program Files\Siemens\Automation\Portal V17\PublicAPI\V17\Siemens.Engineering.dll") | Out-Null
[System.Reflection.Assembly]::LoadFrom("C:\Program Files\Siemens\Automation\Portal V17\PublicAPI\V17\Siemens.Engineering.Hmi.dll") | Out-Null

function Get-AllTypes {
    $types = @()
    foreach ($asm in [AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.GetName().Name -like "Siemens.Engineering*" }) {
        try { $asmTypes = $asm.GetTypes() }
        catch [System.Reflection.ReflectionTypeLoadException] { $asmTypes = $_.Exception.Types | Where-Object { $_ } }
        $types += $asmTypes
    }
    return $types
}

function Try-ServiceTypes {
    param($Object, [string]$ObjectLabel, [Type[]]$Types)
    $method = $Object.GetType().GetMethods() |
        Where-Object { $_.Name -eq "GetService" -and $_.IsGenericMethod -and $_.GetParameters().Count -eq 0 } |
        Select-Object -First 1
    if (-not $method) {
        LogLine "NO_GETSERVICE=$ObjectLabel|$($Object.GetType().FullName)"
        return
    }
    foreach ($type in $Types) {
        try {
            $result = $method.MakeGenericMethod($type).Invoke($Object, @())
            if ($result) {
                LogLine "SERVICE_HIT=$ObjectLabel|TYPE=$($type.FullName)|RESULT=$($result.GetType().FullName)"
                $props = $result.GetType().GetProperties() | Select-Object -ExpandProperty Name
                LogLine "SERVICE_HIT_PROPS=$ObjectLabel|TYPE=$($type.FullName)|$($props -join ',')"
            }
        }
        catch {
            # Too many service types fail by design; only log hits.
        }
    }
}

function Walk-Items {
    param($Items, [string]$Prefix, [Type[]]$Types)
    foreach ($item in $Items) {
        Try-ServiceTypes -Object $item -ObjectLabel "$Prefix/$($item.Name)" -Types $Types
        if ($item.DeviceItems.Count -gt 0) {
            Walk-Items -Items $item.DeviceItems -Prefix "$Prefix/$($item.Name)" -Types $Types
        }
    }
}

$allTypes = Get-AllTypes
$candidateTypes = $allTypes | Where-Object {
    $_.FullName -match 'Hmi|RuntimeScripting|VBScript|Screen|Tag|Communication|Logging|Recipe|Report|Umac|Compiler|Download|Upload|SoftwareContainer'
} | Sort-Object FullName -Unique
LogLine "CANDIDATE_TYPES=$($candidateTypes.Count)"
foreach ($t in $candidateTypes) { LogLine "CANDIDATE=$($t.FullName)" }

$process = [Siemens.Engineering.TiaPortal]::GetProcesses() |
    Where-Object { $_.Mode.ToString() -eq "WithUserInterface" -and $_.ProjectPath } |
    Select-Object -First 1
$tia = $process.Attach()
try {
    $project = $tia.Projects | Select-Object -First 1
    LogLine "PROJECT=$($project.Name)|$($project.Path)"
    Try-ServiceTypes -Object $project -ObjectLabel "PROJECT:$($project.Name)" -Types $candidateTypes
    foreach ($device in $project.Devices) {
        Try-ServiceTypes -Object $device -ObjectLabel "DEVICE:$($device.Name)" -Types $candidateTypes
        Walk-Items -Items $device.DeviceItems -Prefix "DEVICE:$($device.Name)" -Types $candidateTypes
    }
}
finally {
    if ($tia) { $tia.Dispose() }
}

$logPath

