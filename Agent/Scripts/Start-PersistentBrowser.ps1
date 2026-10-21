[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$PaperPath,
    [string]$BrowserId
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

Import-Module (Join-Path $PSScriptRoot 'LaTeXCopilot.psm1') -Force
$workspace = Resolve-PaperWorkspace -PaperPath $PaperPath
$configuration = Get-PaperConfiguration -PaperPath $workspace
if ([string]::IsNullOrWhiteSpace($configuration.overleaf.projectUrl)) {
    throw 'Configure Authoring\config.json overleaf.projectUrl before starting the browser.'
}
if ([string]::IsNullOrWhiteSpace($BrowserId)) {
    $BrowserId = [string]$configuration.browser.browserId
}
if ($BrowserId -notmatch '^[A-Za-z0-9._-]+$' -or $BrowserId -cne [string]$configuration.browser.browserId) {
    throw "Invalid or unconfigured BrowserId: $BrowserId"
}

$address = [string]$configuration.browser.debuggingAddress
$port = [int]$configuration.browser.debuggingPort
if ($address -notin @('127.0.0.1', 'localhost')) {
    throw 'The debugging address must remain loopback-only.'
}

$profilePath = [Environment]::ExpandEnvironmentVariables(
    [string]$configuration.browser.profilePath
).Replace('{browserId}', $BrowserId)
$profilePath = [System.IO.Path]::GetFullPath($profilePath)
$markerPath = Join-Path $profilePath 'latex-copilot-browser.json'
$endpoint = "http://${address}:$port/json/version"

try {
    $version = Invoke-RestMethod -Uri $endpoint -TimeoutSec 2
    if ($version.webSocketDebuggerUrl) {
        if (-not (Test-Path -LiteralPath $markerPath -PathType Leaf)) {
            throw 'Active browser has no durable identity marker.'
        }
        $marker = Get-Content -LiteralPath $markerPath -Raw | ConvertFrom-Json
        if ($marker.browserId -cne $BrowserId) {
            throw 'Active browser identity does not match the requested BrowserId.'
        }
        Write-Host "Reusing persistent browser '$BrowserId'."
        exit 0
    }
}
catch {
    if ($_.Exception.Message -match 'identity|marker') {
        throw
    }
}

$edgePaths = @(
    "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe",
    "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe",
    "$env:LOCALAPPDATA\Microsoft\Edge\Application\msedge.exe"
) | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf }
$edge = $edgePaths | Select-Object -First 1
if (-not $edge) {
    throw 'Microsoft Edge was not found.'
}

New-Item -ItemType Directory -Path $profilePath -Force | Out-Null
Write-JsonAtomic -Path $markerPath -Value ([ordered]@{
    browserId = $BrowserId
    debuggingAddress = $address
    debuggingPort = $port
    createdAtUtc = [DateTime]::UtcNow.ToString('o')
})

$process = Start-Process -FilePath $edge -ArgumentList @(
    "--remote-debugging-address=$address",
    "--remote-debugging-port=$port",
    "--user-data-dir=$profilePath",
    '--no-first-run',
    '--no-default-browser-check',
    '--start-maximized',
    [string]$configuration.overleaf.projectUrl
) -PassThru

$deadline = [DateTime]::UtcNow.AddSeconds(30)
while ([DateTime]::UtcNow -lt $deadline -and -not $process.HasExited) {
    Start-Sleep -Milliseconds 500
    try {
        $version = Invoke-RestMethod -Uri $endpoint -TimeoutSec 2
        if ($version.webSocketDebuggerUrl) {
            Write-Host "Started persistent browser '$BrowserId'."
            exit 0
        }
    }
    catch {}
}
throw "Persistent browser '$BrowserId' did not become ready."
