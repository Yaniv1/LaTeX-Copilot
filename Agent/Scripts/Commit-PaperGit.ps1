[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$PaperPath,
    [Parameter(Mandatory = $true)]
    [string]$CommitMessage,
    [switch]$Approved
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

Import-Module (Join-Path $PSScriptRoot 'LaTeXCopilot.psm1') -Force
$workspace = Resolve-PaperWorkspace -PaperPath $PaperPath
$gitRoot = (& git -C $workspace rev-parse --show-toplevel 2>$null)
if ($LASTEXITCODE -ne 0 -or
    -not [System.IO.Path]::GetFullPath(($gitRoot -replace '/', '\')).TrimEnd('\').Equals(
        $workspace.TrimEnd('\'),
        [System.StringComparison]::OrdinalIgnoreCase
    )) {
    throw 'The paper workspace is not its own local Git repository.'
}

& (Join-Path $PSScriptRoot 'Update-AuthorNoteTimestamp.ps1') -PaperPath $workspace
& (Join-Path $PSScriptRoot 'Test-Paper.ps1') -PaperPath $workspace
& git -C $workspace add --all
if ($LASTEXITCODE -ne 0) { throw 'Unable to stage paper changes.' }
$staged = @(& git -C $workspace diff --cached --name-status)
if ($staged.Count -eq 0) {
    Write-Host 'There are no local paper changes to commit.'
    return
}

Write-Host 'Staged local paper changes:'
$staged | ForEach-Object { Write-Host $_ }
& git -C $workspace --no-pager diff --cached --stat
& git -C $workspace --no-pager diff --cached --binary
if (-not $Approved) {
    & git -C $workspace reset --quiet
    throw 'Local commit requires explicit approval. Re-run with -Approved after review.'
}

& git -C $workspace commit -m $CommitMessage
if ($LASTEXITCODE -ne 0) { throw 'Unable to commit local paper changes.' }
Write-Host 'Created the approved local paper commit. Nothing was pushed.'
