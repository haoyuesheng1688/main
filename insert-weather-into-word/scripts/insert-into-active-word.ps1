param(
    [Parameter(Mandatory = $true)]
    [string]$Text,

    [switch]$NewParagraph
)

$ErrorActionPreference = 'Stop'

try {
    $word = [Runtime.InteropServices.Marshal]::GetActiveObject('Word.Application')
} catch {
    throw 'Microsoft Word is not open or is not accessible through COM.'
}

if ($NewParagraph) {
    $word.Selection.TypeParagraph()
}

$word.Selection.TypeText($Text)
