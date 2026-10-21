[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$scriptsRoot = Join-Path $PSScriptRoot 'Scripts'

Write-Host ''
Write-Host 'LaTeX-CoPilot'
Write-Host '=============='
Write-Host '1. Create a new paper workspace'
Write-Host '2. Start editing the active paper with LaTeX-CoPilot'
Write-Host '3. Start editing a specific paper workspace'
Write-Host '4. List configured GitHub profiles'
Write-Host '5. Configure an isolated GitHub profile'
Write-Host '6. Show available paper operations'
Write-Host '0. Exit'
Write-Host ''

$selection = Read-Host 'Select an action'
switch ($selection) {
    '1' {
        & (Join-Path $scriptsRoot 'New-Paper.ps1')
    }
    '2' {
        & (Join-Path $scriptsRoot 'Start-LaTeXCopilot.ps1')
    }
    '3' {
        $paperPath = Read-Host 'Paper workspace path'
        & (Join-Path $scriptsRoot 'Start-LaTeXCopilot.ps1') -PaperPath $paperPath
    }
    '4' {
        & (Join-Path $scriptsRoot 'List-GitHubProfiles.ps1')
    }
    '5' {
        $profileName = Read-Host 'Local profile name [authenticated GitHub username]'
        $githubUser = Read-Host 'Expected GitHub username (optional)'
        & (Join-Path $scriptsRoot 'Configure-GitHubProfile.ps1') `
            -ProfileName $profileName `
            -ExpectedUser $githubUser
    }
    '6' {
        Write-Host ''
        Write-Host 'Paper authoring:'
        Write-Host '  Start-LaTeXCopilot.ps1  Interactive editing and review'
        Write-Host '  Record-AgentSession.ps1 Record the active session for recovery'
        Write-Host '  Convert-ToPdf.ps1       Render a project-named PDF'
        Write-Host '  Test-Paper.ps1          Compile and validate a paper'
        Write-Host ''
        Write-Host 'Paper Git:'
        Write-Host '  Initialize-LocalPaperGit.ps1'
        Write-Host '                            Create only the local repository'
        Write-Host '  Commit-PaperGit.ps1     Review and commit local changes'
        Write-Host '  Create-PaperGitHubRemote.ps1'
        Write-Host '                            Create only the GitHub remote'
        Write-Host '  Sync-PaperGit.ps1       Pull or push committed history'
        Write-Host ''
        Write-Host 'Overleaf:'
        Write-Host '  Sync-Overleaf.ps1       Sync in, out, inout, or outin'
        Write-Host '  Start-PersistentBrowser.ps1'
        Write-Host '                            Reuse an authenticated browser'
    }
    '0' {
        return
    }
    default {
        throw "Unknown action: $selection"
    }
}
