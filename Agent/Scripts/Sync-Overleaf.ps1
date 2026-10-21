[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$PaperPath,
    [Parameter(Mandatory = $true)]
    [ValidateSet('in', 'out', 'inout', 'outin')]
    [string]$Sync,
    [ValidateSet('auto', 'manual', 'agentic')]
    [string]$Wait = 'manual',
    [ValidateRange(1, 3600)]
    [int]$WaitTime = 30,
    [string]$BrowserId
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

Import-Module (Join-Path $PSScriptRoot 'LaTeXCopilot.psm1') -Force
$workspace = Resolve-PaperWorkspace -PaperPath $PaperPath
$configuration = Get-PaperConfiguration -PaperPath $workspace
if ([string]::IsNullOrWhiteSpace($BrowserId)) {
    $BrowserId = [string]$configuration.browser.browserId
}
if ($BrowserId -cne [string]$configuration.browser.browserId) {
    throw "BrowserId '$BrowserId' is not configured for this paper."
}
$requestRoot = Join-Path $workspace 'Authoring\.run-state\sync-requests'

function Wait-Authorization {
    param([string]$Direction, [int]$Stage, [int]$Total)
    if ($Wait -eq 'auto') {
        Write-Host "Stage $Stage/$Total sync '$Direction' starts in $WaitTime seconds."
        Start-Sleep -Seconds $WaitTime
        return
    }
    if ($Wait -eq 'manual') {
        $phrase = "APPROVE SYNC $($Direction.ToUpperInvariant())"
        if ((Read-Host "Type exactly '$phrase'") -cne $phrase) {
            throw "Sync '$Direction' was not approved."
        }
        return
    }

    $requestId = [guid]::NewGuid().ToString('N')
    $requestPath = Join-Path $requestRoot ($requestId + '.request.json')
    $approvalPath = Join-Path $requestRoot ($requestId + '.approval.json')
    $deadline = [DateTime]::UtcNow.AddSeconds($WaitTime)
    Write-JsonAtomic -Path $requestPath -Value ([ordered]@{
        requestId = $requestId
        direction = $Direction
        stage = $Stage
        stageCount = $Total
        browserId = $BrowserId
        requestedAtUtc = [DateTime]::UtcNow.ToString('o')
        expiresAtUtc = $deadline.ToString('o')
    })
    Write-Host "Agent approval request: $requestId"
    while ([DateTime]::UtcNow -lt $deadline) {
        if (Test-Path -LiteralPath $approvalPath -PathType Leaf) {
            $approval = Get-Content -LiteralPath $approvalPath -Raw | ConvertFrom-Json
            if ($approval.requestId -ne $requestId -or
                $approval.direction -ne $Direction -or
                $approval.browserId -ne $BrowserId -or
                $approval.decision -ne 'approved') {
                throw 'Agent approval does not match the sync request.'
            }
            return
        }
        Start-Sleep -Seconds 1
    }
    throw "Agent approval request $requestId expired."
}

$directions = @(switch ($Sync) {
    'in' { @('in') }
    'out' { @('out') }
    'inout' { @('in', 'out') }
    'outin' { @('out', 'in') }
})
for ($index = 0; $index -lt $directions.Count; $index++) {
    $direction = $directions[$index]
    Wait-Authorization -Direction $direction -Stage ($index + 1) -Total $directions.Count
    if ($direction -eq 'in') {
        & (Join-Path $PSScriptRoot 'Download-Overleaf.ps1') -PaperPath $workspace -BrowserId $BrowserId
    }
    else {
        & (Join-Path $PSScriptRoot 'Upload-Overleaf.ps1') `
            -PaperPath $workspace `
            -BrowserId $BrowserId `
            -PreAuthorized `
            -NonInteractive:($Wait -ne 'manual')
    }
}
Write-Host "Synchronization '$Sync' completed."
