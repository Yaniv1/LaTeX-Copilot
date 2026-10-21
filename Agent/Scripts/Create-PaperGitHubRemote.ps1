[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$PaperPath,
    [Parameter(Mandatory = $true)]
    [string]$ProfileName,
    [string]$Owner,
    [string]$Repository,
    [ValidateSet('private', 'public')]
    [string]$Visibility = 'private',
    [string]$RemoteName = 'origin'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

Import-Module (Join-Path $PSScriptRoot 'LaTeXCopilot.psm1') -Force
$workspace = Resolve-PaperWorkspace -PaperPath $PaperPath
$configuration = Get-PaperConfiguration -PaperPath $workspace
$gitRoot = (& git -C $workspace rev-parse --show-toplevel 2>$null)
if ($LASTEXITCODE -ne 0 -or
    -not [System.IO.Path]::GetFullPath(($gitRoot -replace '/', '\')).TrimEnd('\').Equals(
        $workspace.TrimEnd('\'),
        [System.StringComparison]::OrdinalIgnoreCase
    )) {
    throw 'Initialize the local paper Git repository before creating a remote.'
}

$profile = Get-GitHubProfile -ProfileName $ProfileName
if ([string]::IsNullOrWhiteSpace($Owner)) { $Owner = [string]$profile.githubUser }
if ([string]::IsNullOrWhiteSpace($Repository)) { $Repository = Split-Path -Leaf $workspace }

try {
    Invoke-GhWithProfile -ProfileName $ProfileName -Arguments @('repo', 'view', "$Owner/$Repository", '--json', 'nameWithOwner') | Out-Null
    throw "GitHub repository already exists: $Owner/$Repository"
}
catch {
    if ($_.Exception.Message -notmatch 'Could not resolve|not found|HTTP 404') { throw }
}

$visibilityFlag = if ($Visibility -eq 'public') { '--public' } else { '--private' }
Invoke-GhWithProfile -ProfileName $ProfileName -Arguments @(
    'repo', 'create', "$Owner/$Repository", $visibilityFlag,
    '--description', "LaTeX paper workspace: $($configuration.paper.title)"
) | Out-Null

$remoteUrl = "https://github.com/$Owner/$Repository.git"
& git -C $workspace remote add $RemoteName $remoteUrl
if ($LASTEXITCODE -ne 0) { throw 'Unable to add the paper Git remote.' }

$configuration.git.remoteConfigured = $true
$configuration.git.profileName = $ProfileName
$configuration.git.owner = $Owner
$configuration.git.repository = $Repository
$configuration.git.visibility = $Visibility
$configuration.git.remoteName = $RemoteName
Write-JsonAtomic -Path (Join-Path $workspace 'Authoring\config.json') -Value $configuration

Write-Host "Created $Visibility paper remote: https://github.com/$Owner/$Repository"
Write-Host 'No files were committed or pushed.'
