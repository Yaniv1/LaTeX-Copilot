[CmdletBinding()]
param(
    [string]$Title,
    [string[]]$Authors,
    [string]$Destination,
    [string]$StartingMaterial,
    [switch]$NoStartingMaterial,
    [string]$Focus,
    [string]$SpecificInstructions,
    [switch]$InitializeGit,
    [switch]$SkipGitSetup,
    [string]$GitHubProfile
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

Import-Module (Join-Path $PSScriptRoot 'LaTeXCopilot.psm1') -Force
$agentRoot = Get-LaTeXCopilotRoot
$templateRoot = Join-Path $agentRoot 'Templates\DemoPaper'

if ([string]::IsNullOrWhiteSpace($Title)) {
    $Title = Read-Host 'Paper title'
}
if ([string]::IsNullOrWhiteSpace($Title)) {
    throw 'Paper title is required.'
}
if ($null -eq $Authors -or $Authors.Count -eq 0) {
    $authorInput = Read-Host 'Authors, separated by semicolons'
    $Authors = @($authorInput -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
}
if ($Authors.Count -eq 0) {
    throw 'At least one author is required.'
}

$defaultName = ($Title -replace '[^A-Za-z0-9]+', '-').Trim('-')
if ([string]::IsNullOrWhiteSpace($Destination)) {
    $defaultRoot = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'Papers'
    $destinationInput = Read-Host "Paper workspace path [$defaultRoot\$defaultName]"
    $Destination = if ([string]::IsNullOrWhiteSpace($destinationInput)) {
        Join-Path $defaultRoot $defaultName
    }
    else {
        $destinationInput
    }
}
$Destination = [System.IO.Path]::GetFullPath($Destination)
if (Test-Path -LiteralPath $Destination) {
    throw "Destination already exists: $Destination"
}

if (-not $NoStartingMaterial -and [string]::IsNullOrWhiteSpace($StartingMaterial)) {
    $StartingMaterial = Read-Host 'Existing draft path, Word/LaTeX/document, or leave blank'
}
if ([string]::IsNullOrWhiteSpace($Focus)) {
    $Focus = Read-Host 'What should the paper focus on?'
}
if ([string]::IsNullOrWhiteSpace($SpecificInstructions)) {
    $SpecificInstructions = Read-Host 'Paper-specific instructions or constraints'
}

Copy-Item -LiteralPath $templateRoot -Destination $Destination -Recurse

$configPath = Join-Path $Destination 'Authoring\config.json'
$configuration = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
$configuration.paper.title = $Title
$configuration.paper.authors = @($Authors)
$configuration.paper.workspaceName = Split-Path -Leaf $Destination
$slug = ($configuration.paper.workspaceName.ToLowerInvariant() -replace '[^a-z0-9]+', '-').Trim('-')
$configuration.browser.browserId = "latex-copilot-$slug"
$hashBytes = [System.Security.Cryptography.SHA256]::Create().ComputeHash(
    [System.Text.Encoding]::UTF8.GetBytes($configuration.browser.browserId)
)
$configuration.browser.debuggingPort = 9300 + ([BitConverter]::ToUInt16($hashBytes, 0) % 500)
$configuration.createdAtUtc = [DateTime]::UtcNow.ToString('o')
Write-JsonAtomic -Path $configPath -Value $configuration

$authorsLatex = ($Authors -join ' \and ')
$mainPath = Join-Path $Destination 'Paper\main.tex'
$main = Get-Content -LiteralPath $mainPath -Raw
$main = $main.Replace('{{TITLE}}', $Title).Replace('{{AUTHORS_LATEX}}', $authorsLatex)
Set-Content -LiteralPath $mainPath -Value $main -Encoding UTF8 -NoNewline

$instructionPath = Join-Path $Destination 'Authoring\instructions\paper-specific.md'
$instruction = @"
# Paper-Specific Instructions

## Objective

$Focus

## Author Requirements

$SpecificInstructions

## Starting Material

$(if ($NoStartingMaterial -or [string]::IsNullOrWhiteSpace($StartingMaterial)) { 'Start from the deployed LaTeX template.' } else { "Use the registered starting material: $([System.IO.Path]::GetFileName($StartingMaterial))." })
"@
Set-Content -LiteralPath $instructionPath -Value $instruction -Encoding UTF8

if (-not $NoStartingMaterial -and -not [string]::IsNullOrWhiteSpace($StartingMaterial)) {
    if (-not (Test-Path -LiteralPath $StartingMaterial -PathType Leaf)) {
        throw "Starting material not found: $StartingMaterial"
    }
    $intakeDirectory = Join-Path $Destination 'Authoring\intake\source'
    New-Item -ItemType Directory -Path $intakeDirectory -Force | Out-Null
    Copy-Item -LiteralPath $StartingMaterial -Destination (Join-Path $intakeDirectory ([System.IO.Path]::GetFileName($StartingMaterial)))
}

Set-ActivePaperPath -PaperPath $Destination
Write-Host "Created paper workspace: $Destination"
Write-Host 'Edit paper-specific instructions under Authoring\instructions\paper-specific.md.'

if (-not $InitializeGit -and -not $SkipGitSetup) {
    $InitializeGit = (Read-Host 'Initialize local Git and create a private GitHub repository now? [y/N]') -match '^(?i)y(?:es)?$'
}
if ($InitializeGit) {
    & (Join-Path $PSScriptRoot 'Initialize-PaperGit.ps1') `
        -PaperPath $Destination `
        -ProfileName $GitHubProfile `
        -Visibility private
}
