# Agent Operations

The agent runs from the LaTeX-CoPilot repository root and receives a separate
paper workspace path. Never change the working directory permanently to the
paper workspace and never move paper content into the agent repository.

Read the selected workspace's `Authoring/config.json`,
`Authoring/instructions/paper-specific.md`, `Authoring/AUTHOR_REQUEST.md`, and
registered intake material before substantive edits. Publication content is
restricted to `Paper/`; paper-specific metadata and instructions remain under
`Authoring/`.

After every completed manuscript-edit request, run:

```powershell
Agent\Scripts\Update-AuthorNoteTimestamp.ps1 -PaperPath <workspace>
Agent\Scripts\Test-Paper.ps1 -PaperPath <workspace>
```

Render a named PDF with:

```powershell
Agent\Scripts\Convert-ToPdf.ps1 -PaperPath <workspace>
```

Use `Agent\Scripts\Sync-Overleaf.ps1` only when the author requests Overleaf
synchronization. Respect its direction and authorization parameters exactly.
For `agentic`, run synchronization asynchronously, inspect its request under
the selected paper's `Authoring\.run-state\sync-requests`, and approve only a
verified request with `Agent\Scripts\Approve-OverleafSync.ps1`.

Use `Agent\Scripts\Configure-GitHubProfile.ps1` to create an isolated,
non-work GitHub CLI profile outside the repository. Initialize a paper's own
local and remote repository with `Initialize-PaperGit.ps1`. Synchronize paper
Git with `Sync-PaperGit.ps1`; show every staged change and obtain explicit
author approval before passing `-Approved` for a commit or push.
