$ErrorActionPreference = 'Stop'

$processes = Get-Process -Name 'EPLAN' -ErrorAction SilentlyContinue |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_.MainWindowTitle) }

if (-not $processes) {
    throw 'No open EPLAN process with a window title was found.'
}

foreach ($process in $processes) {
    $title = $process.MainWindowTitle
    if ($title -notmatch ' - (?<path>[A-Z]:\\.+)$') {
        continue
    }

    $basePath = $matches.path.Trim()
    $candidates = New-Object System.Collections.Generic.List[string]
    $candidates.Add($basePath)

    if (-not [IO.Path]::HasExtension($basePath)) {
        $candidates.Add($basePath + '.elk')
        $directory = Split-Path -Parent $basePath
        $leaf = Split-Path -Leaf $basePath
        if (Test-Path -LiteralPath $directory) {
            Get-ChildItem -LiteralPath $directory -Filter '*.elk' -File -ErrorAction SilentlyContinue |
                Where-Object { $_.BaseName -eq $leaf } |
                ForEach-Object { $candidates.Add($_.FullName) }
        }
    }

    foreach ($candidate in $candidates) {
        if ([string]::IsNullOrWhiteSpace($candidate)) {
            continue
        }
        if (Test-Path -LiteralPath $candidate) {
            Write-Output $candidate
            exit 0
        }
    }
}

throw 'Could not resolve an .elk path from the open EPLAN window title.'
