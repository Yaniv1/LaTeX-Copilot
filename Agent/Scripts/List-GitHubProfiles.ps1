[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

Import-Module (Join-Path $PSScriptRoot 'LaTeXCopilot.psm1') -Force
$profiles = @(Get-GitHubProfiles)
if ($profiles.Count -eq 0) {
    Write-Host 'No isolated GitHub profiles are configured.'
    Write-Host 'Create one with:'
    Write-Host '  Agent\Scripts\Configure-GitHubProfile.ps1 -ExpectedUser <github-user>'
    Write-Host 'The authenticated GitHub username becomes the default profile name.'
    exit 0
}

Write-Host 'Configured LaTeX-CoPilot GitHub profiles:'
$profiles | Format-Table ProfileName, GitHubUser, ConfiguredAtUtc -AutoSize
