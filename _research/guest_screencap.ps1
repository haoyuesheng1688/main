param(
    [string]$OutPath = 'C:\Users\Administrator\Desktop\CodexOut\screen.png',
    [string]$ErrorPath = 'C:\Users\Administrator\Desktop\CodexOut\screen-error.txt'
)

$ErrorActionPreference = 'Stop'

try {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $bounds = [System.Windows.Forms.SystemInformation]::VirtualScreen
    $bitmap = New-Object System.Drawing.Bitmap $bounds.Width, $bounds.Height
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.CopyFromScreen($bounds.Location, [System.Drawing.Point]::Empty, $bounds.Size)

    $directory = Split-Path -Path $OutPath -Parent
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
    $bitmap.Save($OutPath, [System.Drawing.Imaging.ImageFormat]::Png)

    $graphics.Dispose()
    $bitmap.Dispose()
}
catch {
    $directory = Split-Path -Path $ErrorPath -Parent
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
    $_ | Out-String | Set-Content -LiteralPath $ErrorPath -Encoding UTF8
    throw
}
