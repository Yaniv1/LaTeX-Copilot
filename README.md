# LaTeX-CoPilot

LaTeX-CoPilot is a reusable GitHub Copilot CLI agent for scientific-paper
authoring, LaTeX rendering, structured review, and optional bidirectional
Overleaf synchronization.

The agent runs from this repository, while paper data lives in separate
workspaces. Every paper workspace has an `Authoring` directory for
paper-specific configuration and instructions and a `Paper` directory for
the manuscript, references, figures, and a dedicated template copy.

## Create a paper

```powershell
.\Agent\Scripts\New-Paper.ps1
```

The script asks for the paper title, authors, destination, starting material,
research focus, and paper-specific instructions. It deploys a fresh workspace
from `Templates\DemoPaper` and records it as the active paper without adding
the workspace to this Git repository. It can also initialize the paper's own
local Git repository and private-by-default GitHub remote.

## Private GitHub profile

Keep personal paper repositories isolated from work GitHub credentials:

```powershell
.\Agent\Scripts\Configure-GitHubProfile.ps1 `
  -ProfileName private `
  -ExpectedUser your-private-github-user `
  -Browser chrome
```

Authentication is stored by GitHub CLI under the user's application-data
directory, not in this repository. Paper Git commands select that isolated
profile explicitly.

Create or synchronize a paper repository with:

```powershell
.\Agent\Scripts\Initialize-PaperGit.ps1 `
  -PaperPath C:\path\to\paper `
  -ProfileName private

.\Agent\Scripts\Sync-PaperGit.ps1 `
  -PaperPath C:\path\to\paper `
  -Sync out `
  -CommitMessage "Revise methodology" `
  -Approved
```

`-Approved` may be supplied only after the author reviews every staged change
and explicitly authorizes the commit and push.

## Start the agent

```powershell
.\Agent\Scripts\Start-LaTeXCopilot.ps1
```

Pass `-PaperPath C:\path\to\paper` to select a workspace explicitly. The
launcher starts Copilot CLI with the `LaTeX-CoPilot` custom agent, grants
access only to that workspace, and keeps the current directory at the agent
repository root.

## Overleaf synchronization

After a paper's `Authoring\config.json` contains its own Overleaf URL,
download URL, account name, browser ID, and loopback port, synchronize with:

```powershell
.\Agent\Scripts\Sync-Overleaf.ps1 `
  -PaperPath C:\path\to\paper `
  -Sync inout `
  -Wait manual `
  -WaitTime 30
```

Directions are `in`, `out`, `inout`, and `outin`. Authorization modes are
`manual`, `auto`, and approval-file-based `agentic`. Browser profiles are
stored outside both the agent repository and paper workspace.

## Demo template

`Templates\DemoPaper` demonstrates the separation between generic writing
guidance and paper-specific instructions. Its small sample manuscript
describes how to conduct a critical reading of a scientific paper. It does
not contain content from any private manuscript.
