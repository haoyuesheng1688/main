param(
    [Parameter(Mandatory = $true)]
    [string]$SourcePath,

    [Parameter(Mandatory = $true)]
    [string]$TargetPath,

    [string]$ScriptText,

    [string]$ScriptFile
)

$ErrorActionPreference = 'Stop'

$provided = @($PSBoundParameters.ContainsKey('ScriptText'), $PSBoundParameters.ContainsKey('ScriptFile')) |
    Where-Object { $_ } |
    Measure-Object |
    Select-Object -ExpandProperty Count

if ($provided -ne 1) {
    throw 'Specify exactly one of -ScriptText or -ScriptFile.'
}

$resolvedScriptText = if ($PSBoundParameters.ContainsKey('ScriptFile')) {
    [System.IO.File]::ReadAllText($ScriptFile, [System.Text.Encoding]::UTF8)
} else {
    $ScriptText
}

$bytes = [System.IO.File]::ReadAllBytes($SourcePath)
if ($bytes.Length -lt 24) {
    throw "Unexpected BAC file size: $($bytes.Length)"
}

$textLength = [BitConverter]::ToInt64($bytes, 8)
$textOffset = 24
$trailerOffset = $textOffset + $textLength

if ($trailerOffset -gt $bytes.Length) {
    throw "Invalid text length $textLength for file size $($bytes.Length)"
}

$header = New-Object byte[] 24
[Array]::Copy($bytes, 0, $header, 0, 24)

$scriptBytes = [System.Text.Encoding]::Unicode.GetBytes($resolvedScriptText)
if ($scriptBytes.Length -lt 2 -or $scriptBytes[-2] -ne 0 -or $scriptBytes[-1] -ne 0) {
    $terminated = New-Object byte[] ($scriptBytes.Length + 2)
    [Array]::Copy($scriptBytes, 0, $terminated, 0, $scriptBytes.Length)
    $scriptBytes = $terminated
}
$lengthBytes = [BitConverter]::GetBytes([Int64]$scriptBytes.Length)
[Array]::Copy($lengthBytes, 0, $header, 8, 8)

$trailerLength = $bytes.Length - $trailerOffset
$trailer = New-Object byte[] $trailerLength
if ($trailerLength -gt 0) {
    [Array]::Copy($bytes, $trailerOffset, $trailer, 0, $trailerLength)
}

$output = New-Object byte[] ($header.Length + $scriptBytes.Length + $trailer.Length)
$cursor = 0
[Array]::Copy($header, 0, $output, $cursor, $header.Length)
$cursor += $header.Length
[Array]::Copy($scriptBytes, 0, $output, $cursor, $scriptBytes.Length)
$cursor += $scriptBytes.Length
if ($trailer.Length -gt 0) {
    [Array]::Copy($trailer, 0, $output, $cursor, $trailer.Length)
}

[System.IO.File]::WriteAllBytes($TargetPath, $output)
