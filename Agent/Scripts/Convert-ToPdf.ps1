[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$PaperPath,
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

Import-Module (Join-Path $PSScriptRoot 'LaTeXCopilot.psm1') -Force
$workspace = Resolve-PaperWorkspace -PaperPath $PaperPath
$configuration = Get-PaperConfiguration -PaperPath $workspace
$paperRoot = Join-Path $workspace 'Paper'
$mainFile = Join-Path $paperRoot ([string]$configuration.paper.mainFile)
$mainName = Split-Path -Leaf $mainFile
$generatedPdf = [System.IO.Path]::ChangeExtension($mainFile, '.pdf')
$projectName = Split-Path -Leaf $workspace
$finalPdf = Join-Path $paperRoot ($projectName + '.pdf')

if (-not [string]::IsNullOrWhiteSpace($OutputPath)) {
    $finalPdf = if ([System.IO.Path]::IsPathRooted($OutputPath)) {
        [System.IO.Path]::GetFullPath($OutputPath)
    }
    else {
        [System.IO.Path]::GetFullPath((Join-Path $paperRoot $OutputPath))
    }
}
$paperPrefix = [System.IO.Path]::GetFullPath($paperRoot).TrimEnd('\') + '\'
if (-not $finalPdf.StartsWith($paperPrefix, [System.StringComparison]::OrdinalIgnoreCase) -or
    [System.IO.Path]::GetExtension($finalPdf) -ine '.pdf') {
    throw 'The output must be a PDF inside the selected Paper directory.'
}
if (-not (Get-Command latexmk -ErrorAction SilentlyContinue)) {
    throw 'latexmk is required.'
}

Push-Location $paperRoot
try {
    & latexmk -g -pdf -bibtex -interaction=nonstopmode -halt-on-error -file-line-error $mainName
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $generatedPdf -PathType Leaf)) {
        throw 'LaTeX PDF conversion failed.'
    }
    if (-not $finalPdf.Equals($generatedPdf, [System.StringComparison]::OrdinalIgnoreCase)) {
        Move-Item -LiteralPath $generatedPdf -Destination $finalPdf -Force
    }
}
finally {
    & latexmk -c $mainName | Out-Null
    $base = Join-Path $paperRoot ([System.IO.Path]::GetFileNameWithoutExtension($mainName))
    foreach ($extension in @('.bbl', '.blg')) {
        $artifact = $base + $extension
        if (Test-Path -LiteralPath $artifact -PathType Leaf) {
            Remove-Item -LiteralPath $artifact -Force
        }
    }
    Pop-Location
}

$pages = ''
if (Get-Command pdfinfo -ErrorAction SilentlyContinue) {
    $info = & pdfinfo $finalPdf
    $pageLine = $info | Where-Object { $_ -match '^Pages:\s+(\d+)' } | Select-Object -First 1
    if ($pageLine -match '^Pages:\s+(\d+)') {
        $pages = ", $($Matches[1]) pages"
    }
}
Write-Host "PDF created: $finalPdf$pages"
Write-Output $finalPdf
