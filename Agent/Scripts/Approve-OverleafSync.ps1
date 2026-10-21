[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$PaperPath,
    [string]$RequestId
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

Import-Module (Join-Path $PSScriptRoot 'LaTeXCopilot.psm1') -Force
$workspace = Resolve-PaperWorkspace -PaperPath $PaperPath
$requestRoot = Join-Path $workspace 'Authoring\.run-state\sync-requests'
if (-not (Test-Path -LiteralPath $requestRoot -PathType Container)) {
    throw 'No synchronization requests exist.'
}

if ([string]::IsNullOrWhiteSpace($RequestId)) {
    $requestPath = Get-ChildItem -LiteralPath $requestRoot -Filter '*.request.json' -File |
        Sort-Object LastWriteTimeUtc -Descending |
        Where-Object {
            $id = $_.BaseName -replace '\.request$', ''
            -not (Test-Path -LiteralPath (Join-Path $requestRoot ($id + '.approval.json')))
        } |
        Select-Object -First 1 -ExpandProperty FullName
}
else {
    if ($RequestId -notmatch '^[a-f0-9]{32}$') { throw 'Invalid RequestId.' }
    $requestPath = Join-Path $requestRoot ($RequestId + '.request.json')
}
if (-not $requestPath -or -not (Test-Path -LiteralPath $requestPath -PathType Leaf)) {
    throw 'No pending synchronization request was found.'
}

$request = Get-Content -LiteralPath $requestPath -Raw | ConvertFrom-Json
if ([DateTime]::UtcNow -gt [DateTime]::Parse($request.expiresAtUtc).ToUniversalTime()) {
    throw 'Synchronization request has expired.'
}
$approvalPath = Join-Path $requestRoot ($request.requestId + '.approval.json')
Write-JsonAtomic -Path $approvalPath -Value ([ordered]@{
    requestId = [string]$request.requestId
    direction = [string]$request.direction
    browserId = [string]$request.browserId
    decision = 'approved'
    actor = 'LaTeX-CoPilot'
    approvedAtUtc = [DateTime]::UtcNow.ToString('o')
})
Write-Host "Approved sync '$($request.direction)' request $($request.requestId)."
