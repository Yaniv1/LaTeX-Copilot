[CmdletBinding()]
param(
    [string]$Title,
    [string[]]$Authors,
    [string]$Destination,
    [string]$StartingMaterial,
    [switch]$NoStartingMaterial,
    [string]$Focus,
    [string]$SpecificInstructions,

    [switch]$InitializeLocalGit,
    [switch]$SkipLocalGitSetup,
    [switch]$CreateRemoteGit,
    [switch]$SkipRemoteGitSetup,

    [switch]$InitializeGit,
    [switch]$SkipGitSetup,

    [string]$GitHubProfile,
    [string]$GitOwner,
    [string]$GitRepository,
    [ValidateSet('private', 'public')]
    [string]$GitVisibility = 'private',

    [switch]$ApprovePaperCreation,
    [switch]$ApproveLocalGitCreation,
    [switch]$ApproveRemoteGitCreation
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

Import-Module (Join-Path $PSScriptRoot 'LaTeXCopilot.psm1') -Force
$agentRoot = Get-LaTeXCopilotRoot
$templateRoot = Join-Path $agentRoot 'Templates\DemoPaper'

if (-not (Test-Path -LiteralPath $templateRoot -PathType Container)) {
    throw "Paper template not found: $templateRoot"
}
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
if (-not $NoStartingMaterial -and -not [string]::IsNullOrWhiteSpace($StartingMaterial)) {
    if (-not (Test-Path -LiteralPath $StartingMaterial -PathType Leaf)) {
        throw "Starting material not found: $StartingMaterial"
    }
    $StartingMaterial = (Resolve-Path -LiteralPath $StartingMaterial).Path
}
if ([string]::IsNullOrWhiteSpace($Focus)) {
    $Focus = Read-Host 'What should the paper focus on?'
}
if ([string]::IsNullOrWhiteSpace($SpecificInstructions)) {
    $SpecificInstructions = Read-Host 'Paper-specific instructions or constraints'
}

if ($InitializeGit) {
    $InitializeLocalGit = $true
    $CreateRemoteGit = $true
}
if ($SkipGitSetup) {
    $SkipLocalGitSetup = $true
    $SkipRemoteGitSetup = $true
}

$wantsLocalGit = if ($InitializeLocalGit) {
    $true
}
elseif ($SkipLocalGitSetup) {
    $false
}
else {
    (Read-Host 'Initialize a local Git repository for this paper? [y/N]') -match '^(?i)y(?:es)?$'
}

$wantsRemoteGit = $false
if ($wantsLocalGit) {
    $wantsRemoteGit = if ($CreateRemoteGit) {
        $true
    }
    elseif ($SkipRemoteGitSetup) {
        $false
    }
    else {
        (Read-Host 'Create a GitHub remote repository for this paper? [y/N]') -match '^(?i)y(?:es)?$'
    }
}
elseif ($CreateRemoteGit) {
    throw 'A GitHub remote requires local Git initialization.'
}

if ($wantsRemoteGit) {
    $profiles = @(Get-GitHubProfiles)
    if ($profiles.Count -eq 0) {
        throw 'No GitHub profiles are configured. Run Configure-GitHubProfile.ps1 first.'
    }
    Write-Host 'Available LaTeX-CoPilot GitHub profiles:'
    $profiles | Format-Table ProfileName, GitHubUser -AutoSize

    if ([string]::IsNullOrWhiteSpace($GitHubProfile)) {
        $defaultProfile = if ($profiles.Count -eq 1) { $profiles[0].ProfileName } else { '' }
        $prompt = if ($defaultProfile) { "GitHub profile name [$defaultProfile]" } else { 'GitHub profile name' }
        $GitHubProfile = Read-Host $prompt
        if ([string]::IsNullOrWhiteSpace($GitHubProfile)) { $GitHubProfile = $defaultProfile }
    }
    $selectedProfile = Get-GitHubProfile -ProfileName $GitHubProfile
    if ([string]::IsNullOrWhiteSpace($GitOwner)) { $GitOwner = [string]$selectedProfile.githubUser }
    if ([string]::IsNullOrWhiteSpace($GitRepository)) { $GitRepository = Split-Path -Leaf $Destination }
}

$startingMaterialSummary = if ($NoStartingMaterial -or [string]::IsNullOrWhiteSpace($StartingMaterial)) {
    'Start from the deployed LaTeX template'
}
else {
    $StartingMaterial
}

Write-Host ''
Write-Host 'NEW PAPER SETTINGS'
Write-Host '=================='
Write-Host "Title:                 $Title"
Write-Host "Authors:               $($Authors -join '; ')"
Write-Host "Destination:           $Destination"
Write-Host "Starting material:     $startingMaterialSummary"
Write-Host "Focus:                 $Focus"
Write-Host "Specific instructions: $SpecificInstructions"
Write-Host "Create local Git:      $wantsLocalGit"
Write-Host "Create GitHub remote:  $wantsRemoteGit"
if ($wantsRemoteGit) {
    Write-Host "GitHub profile:        $GitHubProfile"
    Write-Host "GitHub repository:     $GitOwner/$GitRepository"
    Write-Host "Remote visibility:     $GitVisibility"
}
Write-Host ''

$paperAuthorized = $ApprovePaperCreation
if (-not $paperAuthorized) {
    $paperAuthorized = (Read-Host "Type exactly 'CREATE PAPER' to create the paper workspace") -ceq 'CREATE PAPER'
}
if (-not $paperAuthorized) {
    throw 'Paper creation was not approved. No resources were created.'
}

$localGitAuthorized = $false
if ($wantsLocalGit) {
    $localGitAuthorized = $ApproveLocalGitCreation
    if (-not $localGitAuthorized) {
        $localGitAuthorized = (Read-Host "Type exactly 'CREATE LOCAL GIT' to initialize local Git") -ceq 'CREATE LOCAL GIT'
    }
}

$remoteGitAuthorized = $false
if ($wantsRemoteGit -and $localGitAuthorized) {
    $remoteGitAuthorized = $ApproveRemoteGitCreation
    if (-not $remoteGitAuthorized) {
        $remoteGitAuthorized = (Read-Host "Type exactly 'CREATE REMOTE GIT' to create the GitHub repository") -ceq 'CREATE REMOTE GIT'
    }
}

Copy-Item -LiteralPath $templateRoot -Destination $Destination -Recurse

$configPath = Join-Path $Destination 'Authoring\config.json'
$configuration = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
$configuration.paper.title = $Title
$configuration.paper.authors = @($Authors)
$configuration.paper.workspaceName = Split-Path -Leaf $Destination
$slug = ($configuration.paper.workspaceName.ToLowerInvariant() -replace '[^a-z0-9]+', '-').Trim('-')
$configuration.browser.browserId = "latex-copilot-$slug"
$sha256 = [System.Security.Cryptography.SHA256]::Create()
try {
    $hashBytes = $sha256.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($configuration.browser.browserId))
}
finally {
    $sha256.Dispose()
}
$configuration.browser.debuggingPort = 9300 + ([BitConverter]::ToUInt16($hashBytes, 0) % 500)
$configuration.createdAtUtc = [DateTime]::UtcNow.ToString('o')
Write-JsonAtomic -Path $configPath -Value $configuration

$authorsLatex = ($Authors -join ', ')
$mainPath = Join-Path $Destination 'Paper\main.tex'
$main = Get-Content -LiteralPath $mainPath -Raw
$main = $main.Replace('{{TITLE}}', $Title).Replace('{{AUTHORS_LATEX}}', $authorsLatex)
Set-Content -LiteralPath $mainPath -Value $main -Encoding UTF8 -NoNewline

$instructionPath = Join-Path $Destination 'Authoring\instructions\paper-specific.md'
$instruction = @"
# Paper-Specific Instructions

## Objective

$Focus

## Paper-Wide Requirements

$SpecificInstructions

## Section Instructions

Add and maintain named subsections here as the author provides requirements
for the Introduction, Method, Results, Discussion, Conclusion, or other paper
sections. Consolidate related guidance and replace superseded instructions.

## Starting Material

$startingMaterialSummary
"@
Set-Content -LiteralPath $instructionPath -Value $instruction -Encoding UTF8

if (-not $NoStartingMaterial -and -not [string]::IsNullOrWhiteSpace($StartingMaterial)) {
    $intakeDirectory = Join-Path $Destination 'Authoring\intake\source'
    New-Item -ItemType Directory -Path $intakeDirectory -Force | Out-Null
    Copy-Item -LiteralPath $StartingMaterial -Destination (Join-Path $intakeDirectory ([System.IO.Path]::GetFileName($StartingMaterial)))
}

Set-ActivePaperPath -PaperPath $Destination
Write-Host "Created paper workspace: $Destination"
Write-Host 'Edit paper-specific instructions under Authoring\instructions\paper-specific.md.'

if ($wantsLocalGit) {
    if ($localGitAuthorized) {
        & (Join-Path $PSScriptRoot 'Initialize-LocalPaperGit.ps1') -PaperPath $Destination
    }
    else {
        Write-Host 'Local Git creation was not approved and was skipped.'
    }
}
if ($wantsRemoteGit) {
    if ($remoteGitAuthorized) {
        & (Join-Path $PSScriptRoot 'Create-PaperGitHubRemote.ps1') `
            -PaperPath $Destination `
            -ProfileName $GitHubProfile `
            -Owner $GitOwner `
            -Repository $GitRepository `
            -Visibility $GitVisibility
    }
    else {
        Write-Host 'GitHub remote creation was not approved and was skipped.'
    }
}

$startScript = Join-Path $agentRoot 'Agent\Scripts\Start-LaTeXCopilot.ps1'
Write-Host ''
Write-Host 'Next, start editing with LaTeX-CoPilot:'
Write-Host "  & '$startScript' -PaperPath '$Destination'"
