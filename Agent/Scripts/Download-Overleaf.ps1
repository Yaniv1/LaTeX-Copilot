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
if ([string]::IsNullOrWhiteSpace($BrowserId)) {
    $BrowserId = [string]$configuration.browser.browserId
}
foreach ($field in @('projectUrl', 'downloadUrl')) {
    if ([string]::IsNullOrWhiteSpace($configuration.overleaf.$field)) {
        throw "Configure overleaf.$field before synchronizing in."
    }
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

$work = Join-Path $workspace ('Authoring\.sync-work\' + [guid]::NewGuid().ToString('N'))
$download = Join-Path $work 'download'
$extract = Join-Path $work 'extract'
$result = Join-Path $work 'result.json'
$status = Join-Path $workspace 'Authoring\.run-state\download.json'
New-Item -ItemType Directory -Path $download,$extract -Force | Out-Null

& $python (Join-Path $PSScriptRoot 'download_overleaf.py') `
    --config (Join-Path $workspace 'Authoring\config.json') `
    --browser-id $BrowserId `
    --download-directory $download `
    --result-file $result `
    --status-file $status
if ($LASTEXITCODE -ne 0) { throw 'Overleaf download failed.' }

$archivePath = [System.IO.Path]::GetFullPath(
    [string](Get-Content -LiteralPath $result -Raw | ConvertFrom-Json).archivePath
)
$downloadPrefix = [System.IO.Path]::GetFullPath($download).TrimEnd('\') + '\'
if (-not $archivePath.StartsWith($downloadPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw 'Downloaded archive is outside the synchronization workspace.'
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [System.IO.Compression.ZipFile]::OpenRead($archivePath)
try {
    $extractPrefix = [System.IO.Path]::GetFullPath($extract).TrimEnd('\') + '\'
    foreach ($entry in $archive.Entries) {
        $target = [System.IO.Path]::GetFullPath((Join-Path $extract $entry.FullName))
        if (-not $target.StartsWith($extractPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "Unsafe ZIP path: $($entry.FullName)"
        }
        if (-not $entry.Name) {
            New-Item -ItemType Directory -Path $target -Force | Out-Null
        }
        else {
            New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
            [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $target, $true)
        }
    }
}
finally { $archive.Dispose() }

$source = $extract
if (-not (Test-Path -LiteralPath (Join-Path $source $configuration.paper.mainFile))) {
    $directories = @(Get-ChildItem -LiteralPath $extract -Directory)
    $files = @(Get-ChildItem -LiteralPath $extract -File)
    if ($directories.Count -eq 1 -and $files.Count -eq 0 -and
        (Test-Path -LiteralPath (Join-Path $directories[0].FullName $configuration.paper.mainFile))) {
        $source = $directories[0].FullName
    }
    else { throw 'Downloaded project has no configured main file at its root.' }
}

$paper = Join-Path $workspace 'Paper'
$backup = Join-Path $workspace (
    'Authoring\.sync-backups\' + [DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss-fff') + '\Paper'
)
New-Item -ItemType Directory -Path (Split-Path -Parent $backup) -Force | Out-Null
Move-Item -LiteralPath $paper -Destination $backup
try {
    Move-Item -LiteralPath $source -Destination $paper
}
catch {
    if (-not (Test-Path -LiteralPath $paper)) {
        Move-Item -LiteralPath $backup -Destination $paper -ErrorAction SilentlyContinue
    }
    throw
}
Remove-Item -LiteralPath $work -Recurse -Force
Write-Host "Synchronized in. Backup: $backup"
& (Join-Path $PSScriptRoot 'Test-Paper.ps1') -PaperPath $workspace
