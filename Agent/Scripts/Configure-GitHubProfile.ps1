[CmdletBinding()]
param(
    [string]$ProfileName = 'private',
    [string]$ExpectedUser,
    [ValidateSet('default', 'chrome', 'edge')]
    [string]$Browser = 'default'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

Import-Module (Join-Path $PSScriptRoot 'LaTeXCopilot.psm1') -Force
if ($ProfileName -notmatch '^[A-Za-z0-9._-]+$') {
    throw 'ProfileName contains unsupported characters.'
}
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    throw 'GitHub CLI is required.'
}

$ghConfigDirectory = Join-Path $env:APPDATA "LaTeX-CoPilot\GitHubProfiles\$ProfileName"
New-Item -ItemType Directory -Path $ghConfigDirectory -Force | Out-Null
$oldConfig = $env:GH_CONFIG_DIR
$oldBrowser = $env:GH_BROWSER
try {
    $env:GH_CONFIG_DIR = $ghConfigDirectory
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
}
finally {
    if ($null -eq $oldConfig) { Remove-Item Env:GH_CONFIG_DIR -ErrorAction SilentlyContinue } else { $env:GH_CONFIG_DIR = $oldConfig }
    if ($null -eq $oldBrowser) { Remove-Item Env:GH_BROWSER -ErrorAction SilentlyContinue } else { $env:GH_BROWSER = $oldBrowser }
}

$profilePath = Join-Path (Get-LaTeXCopilotRoot) "Agent\.state\github-profiles\$ProfileName.json"
Write-JsonAtomic -Path $profilePath -Value ([ordered]@{
    profileName = $ProfileName
    githubUser = $actualUser
    ghConfigDir = $ghConfigDirectory
    configuredAtUtc = [DateTime]::UtcNow.ToString('o')
})
Write-Host "Configured isolated GitHub profile '$ProfileName' for $actualUser."
