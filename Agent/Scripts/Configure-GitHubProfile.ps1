[CmdletBinding()]
param(
    [string]$ProfileName,
    [string]$ExpectedUser,
    [ValidateSet('default', 'chrome', 'edge')]
    [string]$Browser = 'default',
    [switch]$ReplaceExisting
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

Import-Module (Join-Path $PSScriptRoot 'LaTeXCopilot.psm1') -Force
if (-not [string]::IsNullOrWhiteSpace($ProfileName) -and
    $ProfileName -notmatch '^[A-Za-z0-9._-]+$') {
    throw 'ProfileName contains unsupported characters.'
}
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    throw 'GitHub CLI is required.'
}

$profilesRoot = Join-Path $env:APPDATA 'LaTeX-CoPilot\GitHubProfiles'
New-Item -ItemType Directory -Path $profilesRoot -Force | Out-Null
$pendingConfigDirectory = Join-Path $profilesRoot ('.pending-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $pendingConfigDirectory | Out-Null
$oldConfig = $env:GH_CONFIG_DIR
$oldBrowser = $env:GH_BROWSER
$profileCreated = $false
try {
    $env:GH_CONFIG_DIR = $pendingConfigDirectory
    if ($Browser -eq 'chrome') {
        $chromePaths = @(
            "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
            "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
            "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe"
        ) | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf }
        $chrome = $chromePaths | Select-Object -First 1
        if (-not $chrome) { throw 'Google Chrome was not found.' }
        $env:GH_BROWSER = $chrome
    }
    elseif ($Browser -eq 'edge') {
        $edgePaths = @(
            "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe",
            "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe",
            "$env:LOCALAPPDATA\Microsoft\Edge\Application\msedge.exe"
        ) | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf }
        $edge = $edgePaths | Select-Object -First 1
        if (-not $edge) { throw 'Microsoft Edge was not found.' }
        $env:GH_BROWSER = $edge
    }
    & gh auth login --hostname github.com --git-protocol https --web
    if ($LASTEXITCODE -ne 0) { throw 'GitHub authentication did not complete.' }
    $actualUser = (& gh api user --jq .login).Trim()
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($actualUser)) {
        throw 'Unable to identify the authenticated GitHub user.'
    }
    if (-not [string]::IsNullOrWhiteSpace($ExpectedUser) -and $actualUser -cne $ExpectedUser) {
        throw "Authenticated user '$actualUser' does not match expected user '$ExpectedUser'."
    }

    $resolvedProfileName = if ([string]::IsNullOrWhiteSpace($ProfileName)) {
        $actualUser
    }
    else {
        $ProfileName
    }
    if ($resolvedProfileName -notmatch '^[A-Za-z0-9._-]+$') {
        throw "The resolved profile name '$resolvedProfileName' contains unsupported characters."
    }

    $profilePath = Join-Path (Get-LaTeXCopilotRoot) "Agent\.state\github-profiles\$resolvedProfileName.json"
    $ghConfigDirectory = Join-Path $profilesRoot $resolvedProfileName
    $profileExists = (Test-Path -LiteralPath $profilePath) -or
        (Test-Path -LiteralPath $ghConfigDirectory)
    if ($profileExists -and -not $ReplaceExisting) {
        throw "GitHub profile '$resolvedProfileName' already exists. Choose another name or use -ReplaceExisting."
    }
    if ($profileExists) {
        if (Test-Path -LiteralPath $profilePath -PathType Leaf) {
            Remove-Item -LiteralPath $profilePath -Force
        }
        if (Test-Path -LiteralPath $ghConfigDirectory -PathType Container) {
            Remove-Item -LiteralPath $ghConfigDirectory -Recurse -Force
        }
    }

    Move-Item -LiteralPath $pendingConfigDirectory -Destination $ghConfigDirectory
    Write-JsonAtomic -Path $profilePath -Value ([ordered]@{
        profileName = $resolvedProfileName
        githubUser = $actualUser
        ghConfigDir = $ghConfigDirectory
        configuredAtUtc = [DateTime]::UtcNow.ToString('o')
    })
    $profileCreated = $true
}
finally {
    if ($null -eq $oldConfig) { Remove-Item Env:GH_CONFIG_DIR -ErrorAction SilentlyContinue } else { $env:GH_CONFIG_DIR = $oldConfig }
    if ($null -eq $oldBrowser) { Remove-Item Env:GH_BROWSER -ErrorAction SilentlyContinue } else { $env:GH_BROWSER = $oldBrowser }
    if (-not $profileCreated -and (Test-Path -LiteralPath $pendingConfigDirectory -PathType Container)) {
        Remove-Item -LiteralPath $pendingConfigDirectory -Recurse -Force
    }
}

Write-Host "Configured isolated GitHub profile '$resolvedProfileName' for $actualUser."
