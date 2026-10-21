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
$paperRoot = Join-Path $workspace 'Paper'
$mainFile = Join-Path $paperRoot ([string]$configuration.paper.mainFile)
$logFile = [System.IO.Path]::ChangeExtension($mainFile, '.log')

& (Join-Path $PSScriptRoot 'Convert-ToPdf.ps1') -PaperPath $workspace | Out-Null
$projectPdf = Join-Path $paperRoot ((Split-Path -Leaf $workspace) + '.pdf')
if (-not (Test-Path -LiteralPath $projectPdf -PathType Leaf)) {
    throw 'Expected project-named PDF was not produced.'
}

if (Get-Command pdfinfo -ErrorAction SilentlyContinue) {
    $info = & pdfinfo $projectPdf
    $pageLine = $info | Where-Object { $_ -match '^Pages:\s+(\d+)' } | Select-Object -First 1
    if ($pageLine -notmatch '^Pages:\s+(\d+)') {
        throw 'Unable to determine PDF page count.'
    }
    $pageCount = [int]$Matches[1]
    if ($pageCount -gt [int]$configuration.paper.maximumPages) {
        throw "Paper is $pageCount pages; maximum is $($configuration.paper.maximumPages)."
    }
}

$source = Get-Content -LiteralPath $mainFile -Raw
if ($source -notmatch 'Last updated:\s*\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}\s+PST\.') {
    Write-Warning 'The author note does not yet contain a PST last-update timestamp.'
}
Write-Host "Paper validation passed: $projectPdf"
