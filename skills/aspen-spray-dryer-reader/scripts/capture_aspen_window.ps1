[CmdletBinding()]
param(
    [int]$ProcessId,
    [string]$OutputPath = (Join-Path (Get-Location) 'aspen_window.png')
)

Add-Type -AssemblyName System.Drawing
Add-Type @'
using System;
using System.Runtime.InteropServices;

public class CodexWin32 {
    [StructLayout(LayoutKind.Sequential)]
    public struct RECT {
        public int Left;
        public int Top;
        public int Right;
        public int Bottom;
    }

    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);
}
'@

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
$rect = New-Object CodexWin32+RECT
[CodexWin32]::GetWindowRect($process.MainWindowHandle, [ref]$rect) | Out-Null

$width = $rect.Right - $rect.Left
$height = $rect.Bottom - $rect.Top

if ($width -le 0 -or $height -le 0) {
    throw "Aspen window for process $ProcessId has an invalid size."
}

$directory = Split-Path -Path $OutputPath -Parent
if ($directory) {
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
}

$bitmap = New-Object System.Drawing.Bitmap $width, $height
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$graphics.CopyFromScreen($rect.Left, $rect.Top, 0, 0, $bitmap.Size)
$bitmap.Save($OutputPath, [System.Drawing.Imaging.ImageFormat]::Png)
$graphics.Dispose()
$bitmap.Dispose()

[pscustomobject]@{
    ProcessId       = $process.Id
    MainWindowTitle = $process.MainWindowTitle
    OutputPath      = (Resolve-Path -LiteralPath $OutputPath).Path
    Width           = $width
    Height          = $height
} | Format-List
