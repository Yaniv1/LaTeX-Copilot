Set-StrictMode -Version Latest

function Get-LaTeXCopilotRoot {
    return (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
}

function Resolve-PaperWorkspace {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PaperPath
    )

    $resolved = (Resolve-Path -LiteralPath $PaperPath).Path
    foreach ($required in @(
        'Authoring\config.json',
        'Authoring\instructions\paper-specific.md',
        'Paper\main.tex'
    )) {
        if (-not (Test-Path -LiteralPath (Join-Path $resolved $required) -PathType Leaf)) {
            throw "Invalid paper workspace; missing $required under $resolved"
        }
    }
    return $resolved
}

function Get-PaperConfiguration {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PaperPath
    )

    $workspace = Resolve-PaperWorkspace -PaperPath $PaperPath
    return Get-Content -LiteralPath (Join-Path $workspace 'Authoring\config.json') -Raw | ConvertFrom-Json
}

function Write-JsonAtomic {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [object]$Value
    )

    $parent = Split-Path -Parent $Path
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
    $temporary = $Path + '.tmp'
    $Value | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $temporary -Encoding UTF8
    Move-Item -LiteralPath $temporary -Destination $Path -Force
}

function Get-ActivePaperPath {
    $statePath = Join-Path (Get-LaTeXCopilotRoot) 'Agent\.state\active-paper.json'
    if (-not (Test-Path -LiteralPath $statePath -PathType Leaf)) {
        return $null
    }
    $state = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
    return [string]$state.paperPath
}

function Set-ActivePaperPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PaperPath
    )

    $workspace = Resolve-PaperWorkspace -PaperPath $PaperPath
    $statePath = Join-Path (Get-LaTeXCopilotRoot) 'Agent\.state\active-paper.json'
    Write-JsonAtomic -Path $statePath -Value ([ordered]@{
        paperPath = $workspace
        selectedAtUtc = [DateTime]::UtcNow.ToString('o')
    })
}

function Get-GitHubProfile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProfileName
    )

    if ($ProfileName -notmatch '^[A-Za-z0-9._-]+$') {
        throw 'GitHub profile names may contain only letters, numbers, periods, underscores, and hyphens.'
    }
    $profilePath = Join-Path (Get-LaTeXCopilotRoot) "Agent\.state\github-profiles\$ProfileName.json"
    if (-not (Test-Path -LiteralPath $profilePath -PathType Leaf)) {
        throw "GitHub profile '$ProfileName' is not configured. Run Configure-GitHubProfile.ps1."
    }
    return Get-Content -LiteralPath $profilePath -Raw | ConvertFrom-Json
}

function Invoke-GhWithProfile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProfileName,
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    $profile = Get-GitHubProfile -ProfileName $ProfileName
    $oldConfig = $env:GH_CONFIG_DIR
    try {
        $env:GH_CONFIG_DIR = [string]$profile.ghConfigDir
        $output = & gh @Arguments 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "GitHub CLI failed: gh $($Arguments -join ' ')`n$($output -join [Environment]::NewLine)"
        }
        return $output
    }
    finally {
        if ($null -eq $oldConfig) {
            Remove-Item Env:GH_CONFIG_DIR -ErrorAction SilentlyContinue
        }
        else {
            $env:GH_CONFIG_DIR = $oldConfig
        }
    }
}

function Invoke-GitWithProfile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProfileName,
        [Parameter(Mandatory = $true)]
        [string]$RepositoryRoot,
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    $profile = Get-GitHubProfile -ProfileName $ProfileName
    $oldConfig = $env:GH_CONFIG_DIR

    try {
        $env:GH_CONFIG_DIR = [string]$profile.ghConfigDir
        & gh auth setup-git --hostname github.com
        if ($LASTEXITCODE -ne 0) {
            throw "Unable to configure Git credentials for GitHub profile '$ProfileName'."
        }
        $output = & git -C $RepositoryRoot @Arguments 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "Git failed: git $($Arguments -join ' ')`n$($output -join [Environment]::NewLine)"
        }
        return $output
    }
    finally {
        if ($null -eq $oldConfig) { Remove-Item Env:GH_CONFIG_DIR -ErrorAction SilentlyContinue } else { $env:GH_CONFIG_DIR = $oldConfig }
    }
}

Export-ModuleMember -Function `
    Get-LaTeXCopilotRoot, `
    Resolve-PaperWorkspace, `
    Get-PaperConfiguration, `
    Write-JsonAtomic, `
    Get-ActivePaperPath, `
    Set-ActivePaperPath, `
    Get-GitHubProfile, `
    Invoke-GhWithProfile, `
    Invoke-GitWithProfile
