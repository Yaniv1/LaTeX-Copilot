[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$PaperPath,
    [Parameter(Mandatory = $true)]
    [ValidateSet('in', 'out', 'inout', 'outin')]
    [string]$Sync,
    [switch]$Approved
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

Import-Module (Join-Path $PSScriptRoot 'LaTeXCopilot.psm1') -Force
$workspace = Resolve-PaperWorkspace -PaperPath $PaperPath
$configuration = Get-PaperConfiguration -PaperPath $workspace
$profileName = [string]$configuration.git.profileName
$remoteName = [string]$configuration.git.remoteName
$branch = [string]$configuration.git.defaultBranch
if (-not [bool]$configuration.git.remoteConfigured -or [string]::IsNullOrWhiteSpace($profileName)) {
    throw 'The paper remote is not configured. Run Create-PaperGitHubRemote.ps1 first.'
}

function Assert-CleanPaperGit {
    $changes = @(& git -C $workspace status --porcelain)
    if ($changes.Count -gt 0) {
        throw 'Remote synchronization requires a clean paper working tree. Commit local changes separately first.'
    }
}

function Sync-In {
    Assert-CleanPaperGit
    Invoke-GitWithProfile -ProfileName $profileName -RepositoryRoot $workspace -Arguments @(
        'fetch', '--prune', $remoteName
    ) | Out-Null
    & git -C $workspace show-ref --verify --quiet "refs/remotes/$remoteName/$branch"
    if ($LASTEXITCODE -eq 0) {
        & git -C $workspace merge --ff-only "$remoteName/$branch"
        if ($LASTEXITCODE -ne 0) { throw 'Paper pull is not a fast-forward.' }
    }
}

function Sync-Out {
    Assert-CleanPaperGit
    & git -C $workspace show-ref --verify --quiet "refs/remotes/$remoteName/$branch"
    if ($LASTEXITCODE -eq 0) {
        Write-Host 'Outgoing paper commits:'
        & git -C $workspace --no-pager log --oneline "$remoteName/$branch..HEAD"
    }
    else {
        Write-Host 'The remote branch is empty; the complete local history will be pushed.'
    }
    if (-not $Approved) {
        throw 'Remote push requires explicit approval. Re-run with -Approved after reviewing outgoing commits.'
    }
    Invoke-GitWithProfile -ProfileName $profileName -RepositoryRoot $workspace -Arguments @(
        'push', '-u', $remoteName, "HEAD:$branch"
    ) | Out-Null
}

$directions = @(switch ($Sync) {
    'in' { @('in') }
    'out' { @('out') }
    'inout' { @('in', 'out') }
    'outin' { @('out', 'in') }
})
foreach ($direction in $directions) {
    if ($direction -eq 'in') { Sync-In } else { Sync-Out }
}
Write-Host "Remote paper Git synchronization '$Sync' completed."
