[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$PaperPath,
    [Parameter(Mandatory = $true)]
    [ValidateSet('in', 'out', 'inout', 'outin')]
    [string]$Sync,
    [string]$CommitMessage,
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
if ([string]::IsNullOrWhiteSpace($profileName) -or [string]::IsNullOrWhiteSpace($configuration.git.repository)) {
    throw 'Paper Git is not configured. Run Initialize-PaperGit.ps1 first.'
}

$gitRoot = (& git -C $workspace rev-parse --show-toplevel).Trim()
if ($LASTEXITCODE -ne 0 -or
    -not [System.IO.Path]::GetFullPath(($gitRoot -replace '/', '\')).TrimEnd('\').Equals(
        $workspace.TrimEnd('\'),
        [System.StringComparison]::OrdinalIgnoreCase
    )) {
    throw 'The selected paper workspace is not its own Git repository.'
}

function Sync-In {
    $changes = @(& git -C $workspace status --porcelain)
    if ($changes.Count -gt 0) { throw 'Pull requires a clean paper working tree.' }
    Invoke-GitWithProfile -ProfileName $profileName -RepositoryRoot $workspace -Arguments @('fetch', '--prune', $remoteName) | Out-Null
    & git -C $workspace show-ref --verify --quiet "refs/remotes/$remoteName/$branch"
    if ($LASTEXITCODE -eq 0) {
        & git -C $workspace merge --ff-only "$remoteName/$branch"
        if ($LASTEXITCODE -ne 0) { throw 'Paper pull is not a fast-forward.' }
    }
}

function Sync-Out {
    & (Join-Path $PSScriptRoot 'Update-AuthorNoteTimestamp.ps1') -PaperPath $workspace
    & (Join-Path $PSScriptRoot 'Test-Paper.ps1') -PaperPath $workspace
    & git -C $workspace add --all
    if ($LASTEXITCODE -ne 0) { throw 'Unable to stage paper changes.' }
    $staged = @(& git -C $workspace diff --cached --name-status)
    if ($staged.Count -gt 0) {
        Write-Host 'Staged paper changes:'
        $staged | ForEach-Object { Write-Host $_ }
        & git -C $workspace --no-pager diff --cached --stat
        & git -C $workspace --no-pager diff --cached --binary
        if (-not $Approved) {
            & git -C $workspace reset --quiet
            throw 'Commit and push require explicit approval. Re-run with -Approved after author review.'
        }
        if ([string]::IsNullOrWhiteSpace($CommitMessage)) {
            & git -C $workspace reset --quiet
            throw 'CommitMessage is required when paper changes are present.'
        }
        & git -C $workspace commit -m $CommitMessage
        if ($LASTEXITCODE -ne 0) { throw 'Unable to commit paper changes.' }
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
Write-Host "Paper Git synchronization '$Sync' completed."
