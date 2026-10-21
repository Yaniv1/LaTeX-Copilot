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
    [string]$DefaultBranch = 'main'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

Write-Warning 'Initialize-PaperGit.ps1 is a convenience wrapper. Local and remote Git remain separate operations.'
& (Join-Path $PSScriptRoot 'Initialize-LocalPaperGit.ps1') `
    -PaperPath $PaperPath `
    -DefaultBranch $DefaultBranch
& (Join-Path $PSScriptRoot 'Create-PaperGitHubRemote.ps1') `
    -PaperPath $PaperPath `
    -ProfileName $ProfileName `
    -Owner $Owner `
    -Repository $Repository `
    -Visibility $Visibility
