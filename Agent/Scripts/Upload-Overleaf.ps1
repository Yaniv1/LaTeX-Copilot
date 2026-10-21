[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$PaperPath,
    [string]$BrowserId,
    [switch]$PreAuthorized,
    [switch]$NonInteractive
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

Import-Module (Join-Path $PSScriptRoot 'LaTeXCopilot.psm1') -Force
$workspace = Resolve-PaperWorkspace -PaperPath $PaperPath
$configuration = Get-PaperConfiguration -PaperPath $workspace
if ([string]::IsNullOrWhiteSpace($BrowserId)) {
    $BrowserId = [string]$configuration.browser.browserId
}
if ([string]::IsNullOrWhiteSpace($configuration.overleaf.projectUrl)) {
    throw 'Configure overleaf.projectUrl before synchronizing out.'
}

& (Join-Path $PSScriptRoot 'Update-AuthorNoteTimestamp.ps1') -PaperPath $workspace
& (Join-Path $PSScriptRoot 'Test-Paper.ps1') -PaperPath $workspace
$paperDirectory = Join-Path $workspace 'Paper'
$files = Get-ChildItem -LiteralPath $paperDirectory -File -Recurse | Sort-Object FullName

Write-Host 'Complete upload manifest:'
foreach ($file in $files) {
    $relative = $file.FullName.Substring($paperDirectory.TrimEnd('\').Length + 1)
    $hash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
    Write-Host ("{0}`t{1}`t{2}" -f $relative, $file.Length, $hash)
}
if (-not $PreAuthorized) {
    $phrase = 'APPROVE OVERLEAF UPLOAD'
    $approval = Read-Host "Type exactly '$phrase'"
    if ($approval -cne $phrase) { throw 'Upload was not approved.' }
}

& (Join-Path $PSScriptRoot 'Start-PersistentBrowser.ps1') -PaperPath $workspace -BrowserId $BrowserId
$agentRoot = Get-LaTeXCopilotRoot
$python = Join-Path $agentRoot 'Agent\.venv\Scripts\python.exe'
if (-not (Test-Path -LiteralPath $python -PathType Leaf)) {
    $launcher = Get-Command py -ErrorAction SilentlyContinue
    if (-not $launcher) { $launcher = Get-Command python -ErrorAction Stop }
    $prefix = if ($launcher.Name -eq 'py.exe') { @('-3') } else { @() }
    & $launcher.Source @prefix -m venv (Join-Path $agentRoot 'Agent\.venv')
}
& $python -m pip install --disable-pip-version-check --quiet -r (Join-Path $PSScriptRoot 'requirements.txt')
if ($LASTEXITCODE -ne 0) { throw 'Unable to install Selenium.' }

$arguments = @(
    (Join-Path $PSScriptRoot 'upload_overleaf.py'),
    '--config', (Join-Path $workspace 'Authoring\config.json'),
    '--browser-id', $BrowserId,
    '--paper-directory', $paperDirectory,
    '--status-file', (Join-Path $workspace 'Authoring\.run-state\upload.json')
)
if ($NonInteractive) { $arguments += '--non-interactive' }
& $python @arguments
if ($LASTEXITCODE -ne 0) { throw 'Overleaf upload failed.' }
