[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$PaperPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

Import-Module (Join-Path $PSScriptRoot 'LaTeXCopilot.psm1') -Force
$workspace = Resolve-PaperWorkspace -PaperPath $PaperPath
$configuration = Get-PaperConfiguration -PaperPath $workspace
$mainFile = Join-Path (Join-Path $workspace 'Paper') ([string]$configuration.paper.mainFile)
$source = Get-Content -LiteralPath $mainFile -Raw
$marker = '\authornote{'
$start = $source.IndexOf($marker, [System.StringComparison]::Ordinal)
if ($start -lt 0) {
    throw 'The manuscript does not contain an \authornote{...} command.'
}

$contentStart = $start + $marker.Length
$depth = 1
$end = -1
for ($index = $contentStart; $index -lt $source.Length; $index++) {
    if ($source[$index] -eq '{') {
        $depth++
    }
    elseif ($source[$index] -eq '}') {
        $depth--
        if ($depth -eq 0) {
            $end = $index
            break
        }
    }
}
if ($end -lt 0) {
    throw 'The manuscript author note has unbalanced braces.'
}

$content = $source.Substring($contentStart, $end - $contentStart)
$content = [regex]::Replace(
    $content,
    '\s*Last updated:\s*\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}\s+PST\.\s*$',
    '',
    [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
).TrimEnd()
$timestamp = [DateTime]::UtcNow.AddHours(-8).ToString('yyyy-MM-dd HH:mm')
$separator = if ([string]::IsNullOrWhiteSpace($content)) { '' } else { ' ' }
$updatedContent = "$content$separator" + "Last updated: $timestamp PST."
$updatedSource = $source.Substring(0, $contentStart) + $updatedContent + $source.Substring($end)
Set-Content -LiteralPath $mainFile -Value $updatedSource -Encoding UTF8 -NoNewline
Write-Host "Author note timestamp: $timestamp PST"
