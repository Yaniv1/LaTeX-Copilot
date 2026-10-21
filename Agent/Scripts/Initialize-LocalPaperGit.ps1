[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$PaperPath,
    [string]$DefaultBranch = 'main'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

Import-Module (Join-Path $PSScriptRoot 'LaTeXCopilot.psm1') -Force
$workspace = Resolve-PaperWorkspace -PaperPath $PaperPath
$configuration = Get-PaperConfiguration -PaperPath $workspace

$existingRoot = (& git -C $workspace rev-parse --show-toplevel 2>$null)
if ($LASTEXITCODE -eq 0) {
    $existingRoot = [System.IO.Path]::GetFullPath(($existingRoot -replace '/', '\')).TrimEnd('\')
    if (-not $existingRoot.Equals($workspace.TrimEnd('\'), [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Paper workspace is nested inside another Git repository: $existingRoot"
    }
}
else {
    & git -C $workspace init -b $DefaultBranch
    if ($LASTEXITCODE -ne 0) { throw 'Unable to initialize the local paper Git repository.' }
}

$ignorePath = Join-Path $workspace '.gitignore'
if (-not (Test-Path -LiteralPath $ignorePath)) {
    @'
Authoring/.run-state/
Authoring/.sync-work/
Authoring/.sync-backups/
*.aux
*.bbl
*.blg
*.fdb_latexmk
*.fls
*.log
*.out
*.synctex.gz
*.toc
'@ | Set-Content -LiteralPath $ignorePath -Encoding ASCII
}

$configuration.git.localInitialized = $true
$configuration.git.defaultBranch = $DefaultBranch
Write-JsonAtomic -Path (Join-Path $workspace 'Authoring\config.json') -Value $configuration

Write-Host "Initialized local paper Git repository: $workspace"
Write-Host 'No files were staged or committed.'
