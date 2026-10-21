[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$PaperPath,
    [string]$ProfileName,
    [string]$Owner,
    [string]$Repository,
    [ValidateSet('private', 'public')]
    [string]$Visibility = 'private',
    [string]$DefaultBranch = 'main'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

Import-Module (Join-Path $PSScriptRoot 'LaTeXCopilot.psm1') -Force
$workspace = Resolve-PaperWorkspace -PaperPath $PaperPath
$configuration = Get-PaperConfiguration -PaperPath $workspace
if ([string]::IsNullOrWhiteSpace($ProfileName)) {
    $ProfileName = Read-Host 'LaTeX-CoPilot GitHub profile name [private]'
    if ([string]::IsNullOrWhiteSpace($ProfileName)) { $ProfileName = 'private' }
}
$profile = Get-GitHubProfile -ProfileName $ProfileName
if ([string]::IsNullOrWhiteSpace($Owner)) { $Owner = [string]$profile.githubUser }
if ([string]::IsNullOrWhiteSpace($Repository)) { $Repository = Split-Path -Leaf $workspace }

$existingRoot = (& git -C $workspace rev-parse --show-toplevel 2>$null)
if ($LASTEXITCODE -eq 0) {
    $existingRoot = [System.IO.Path]::GetFullPath(($existingRoot -replace '/', '\')).TrimEnd('\')
    if (-not $existingRoot.Equals($workspace.TrimEnd('\'), [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Paper workspace is nested inside another Git repository: $existingRoot"
    }
}
else {
    & git -C $workspace init -b $DefaultBranch
    if ($LASTEXITCODE -ne 0) { throw 'Unable to initialize the paper Git repository.' }
}

$ignorePath = Join-Path $workspace '.gitignore'
if (-not (Test-Path -LiteralPath $ignorePath)) {
    @'
Authoring/.run-state/
Authoring/.sync-work/
Authoring/.sync-backups/
*.aux
*.bbl
*.blg
*.fdb_latexmk
*.fls
*.log
*.out
*.synctex.gz
*.toc
'@ | Set-Content -LiteralPath $ignorePath -Encoding ASCII
}

try {
    Invoke-GhWithProfile -ProfileName $ProfileName -Arguments @('repo', 'view', "$Owner/$Repository", '--json', 'nameWithOwner') | Out-Null
    throw "GitHub repository already exists: $Owner/$Repository"
}
catch {
    if ($_.Exception.Message -notmatch 'Could not resolve|not found|HTTP 404') {
        throw
    }
}

$visibilityFlag = if ($Visibility -eq 'public') { '--public' } else { '--private' }
Invoke-GhWithProfile -ProfileName $ProfileName -Arguments @(
    'repo', 'create', "$Owner/$Repository", $visibilityFlag,
    '--description', "LaTeX paper workspace: $($configuration.paper.title)"
) | Out-Null

$remoteUrl = "https://github.com/$Owner/$Repository.git"
& git -C $workspace remote add origin $remoteUrl
if ($LASTEXITCODE -ne 0) { throw 'Unable to add the paper Git remote.' }

$configuration.git.profileName = $ProfileName
$configuration.git.owner = $Owner
$configuration.git.repository = $Repository
$configuration.git.visibility = $Visibility
$configuration.git.remoteName = 'origin'
$configuration.git.defaultBranch = $DefaultBranch
Write-JsonAtomic -Path (Join-Path $workspace 'Authoring\config.json') -Value $configuration

Write-Host "Initialized paper Git repository and created $Visibility remote: https://github.com/$Owner/$Repository"
Write-Host 'No files were staged, committed, or pushed.'
