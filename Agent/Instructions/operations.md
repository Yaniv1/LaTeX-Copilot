# Agent Operations

The agent runs from the LaTeX-CoPilot repository root and receives a separate
paper workspace path. Never change the working directory permanently to the
paper workspace and never move paper content into the agent repository.

Read the selected workspace's `Authoring/config.json`,
`Authoring/instructions/paper-specific.md`, `Authoring/AUTHOR_REQUEST.md`, and
registered intake material before substantive edits. Publication content is
restricted to `Paper/`; paper-specific metadata and instructions remain under
`Authoring/`.

As the first action of every newly started agent instance, run:

```powershell
Agent\Scripts\Record-AgentSession.ps1 -PaperPath <workspace>
```

This records `COPILOT_AGENT_SESSION_ID` in `Authoring\config.json` and writes
`Authoring\instructions\agent-session.md` with the exact `/resume <session-id>`
recovery command. Run it directly from the parent agent instance; do not
delegate it to a worker whose environment contains a different session ID.
Do not inspect or edit the manuscript until this succeeds.

Before implementing any durable paper-specific author request, rewrite
`Authoring\instructions\paper-specific.md` to integrate it into the relevant
semantic location. Section-specific requests belong under the corresponding
paper section, such as `Introduction`, `Method`, `Results`, or `Discussion`;
cross-cutting requests belong under objective, audience, contribution,
evidence, sources, figures, style, or venue constraints. Create a named
section when necessary. Merge related guidance, remove duplication, and
replace superseded instructions so the file describes the current intended
paper rather than the order in which requests arrived. Do not append raw
requests, timestamps, session IDs, or chronological request logs. Re-read the
complete updated instruction file before changing the manuscript. Ignore
transient compile, sync, Git, approval, and status commands unless they
establish a durable paper requirement.

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
non-work GitHub CLI profile outside the repository. When no profile name is
provided, use the authenticated GitHub username. Never replace an existing
profile unless the author explicitly authorizes `-ReplaceExisting`. Local and
remote Git are separate resources with separate permissions:

- `Initialize-LocalPaperGit.ps1` creates only the local repository.
- `Commit-PaperGit.ps1` reviews and commits local changes without pushing.
- `Create-PaperGitHubRemote.ps1` creates only the GitHub repository and remote.
- `Sync-PaperGit.ps1` pulls or pushes already committed history.

Show every staged change and obtain explicit author approval before passing
`-Approved` to a local commit. Separately show outgoing commits and obtain
explicit approval before passing `-Approved` to a remote push.
