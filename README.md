# LaTeX-CoPilot

LaTeX-CoPilot is a reusable GitHub Copilot CLI agent for scientific-paper
authoring, LaTeX rendering, structured review, and optional bidirectional
Overleaf synchronization.

The agent runs from this repository, while paper data lives in separate
workspaces. Every paper workspace has an `Authoring` directory for
paper-specific configuration and instructions and a `Paper` directory for
the manuscript, references, figures, and a dedicated template copy.

## Start here

Open the interactive capability menu:

```powershell
.\Agent\start.ps1
```

It can create or open a paper, list or configure isolated GitHub profiles,
and show the available PDF, validation, Git, and Overleaf operations.

## Create a paper

```powershell
.\Agent\Scripts\New-Paper.ps1
```

The script asks for the paper title, authors, destination, starting material,
research focus, and paper-specific instructions. It deploys a fresh workspace
from `Templates\DemoPaper` and records it as the active paper without adding
the workspace to this Git repository.

Before creating anything, it displays every selected setting and requires
final paper-workspace approval. Local Git initialization and GitHub remote
creation are separate choices with separate approval phrases.

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

List the available profile names and their GitHub users at any time:

```powershell
.\Agent\Scripts\List-GitHubProfiles.ps1
```

When new-paper Git setup asks for a profile, it displays this same list first.
If exactly one profile exists, it is offered as the default.

Create and use paper Git in independent stages:

```powershell
.\Agent\Scripts\Initialize-LocalPaperGit.ps1 `
  -PaperPath C:\path\to\paper

.\Agent\Scripts\Commit-PaperGit.ps1 `
  -PaperPath C:\path\to\paper `
  -CommitMessage "Revise methodology" `
  -Approved

.\Agent\Scripts\Create-PaperGitHubRemote.ps1 `
  -PaperPath C:\path\to\paper `
  -ProfileName private

.\Agent\Scripts\Sync-PaperGit.ps1 `
  -PaperPath C:\path\to\paper `
  -Sync out `
  -Approved
```

Local commit approval does not authorize remote creation or pushing. Remote
creation approval does not authorize a local commit. Push approval applies
only to already committed history after the author reviews outgoing commits.

## Start the agent

```powershell
.\Agent\Scripts\Start-LaTeXCopilot.ps1
```

Pass `-PaperPath C:\path\to\paper` to select a workspace explicitly. The
launcher starts Copilot CLI with the `LaTeX-CoPilot` custom agent, grants
access only to that workspace, and keeps the current directory at the agent
repository root.

Every launched agent instance first records its
`COPILOT_AGENT_SESSION_ID`. `Record-AgentSession.ps1` stores the active ID and
session history in `Authoring\config.json` and writes
`Authoring\instructions\agent-session.md`. If an instance crashes or
disappears, start Copilot CLI and run the recorded `/resume <session-id>`
command.

Whenever the author adds or changes a durable requirement about the paper,
the agent rewrites the appropriate semantic section of
`Authoring\instructions\paper-specific.md`. Introduction requests belong
under Introduction, methodology requests under Method, and cross-cutting
requirements under objective, audience, evidence, style, or venue sections.
Related guidance is consolidated and superseded guidance is replaced so the
file remains a cohesive current specification rather than a request log.

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
not contain content from any private manuscript. New papers use the IEEE Open
Journals class through `Paper\template\ieeetj.cls` and the default
`Paper\template\paper-template.sty` package. The package imports the dedicated
`Paper\template\ext.sty` extensions, including the compact `enumpar`
environment.
