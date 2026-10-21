[CmdletBinding()]
param(
    [string]$PaperPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

Import-Module (Join-Path $PSScriptRoot 'LaTeXCopilot.psm1') -Force
$agentRoot = Get-LaTeXCopilotRoot
if ([string]::IsNullOrWhiteSpace($PaperPath)) {
    $PaperPath = Get-ActivePaperPath
}
if ([string]::IsNullOrWhiteSpace($PaperPath)) {
    $PaperPath = Read-Host 'Paper workspace path'
}
$PaperPath = Resolve-PaperWorkspace -PaperPath $PaperPath
Set-ActivePaperPath -PaperPath $PaperPath

$copilot = Get-Command copilot -ErrorAction SilentlyContinue
if ($null -eq $copilot) {
    throw 'GitHub Copilot CLI is required.'
}

$prompt = @"
Start an interactive LaTeX-CoPilot session.
Selected paper workspace: $PaperPath
Before inspecting the manuscript, run Record-AgentSession.ps1 for this paper
to persist this new instance's COPILOT_AGENT_SESSION_ID and recovery command.
Then read its Authoring configuration and paper-specific instructions,
inspect its current manuscript state, and ask the author what to do. Before
implementing any paper-content request, rewrite the appropriate semantic
section of paper-specific.md so it remains a cohesive current specification,
not a chronological request log. Keep the agent code and paper workspace
strictly separated.
"@

& $copilot.Source `
    -C $agentRoot `
    --add-dir $PaperPath `
    --agent LaTeX-CoPilot `
    -i $prompt

if ($LASTEXITCODE -ne 0) {
    throw "LaTeX-CoPilot exited with code $LASTEXITCODE."
}
