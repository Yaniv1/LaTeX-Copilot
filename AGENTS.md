# LaTeX-CoPilot Repository

This repository contains reusable agent code and paper templates. It must not
contain private paper drafts, author credentials, browser profiles, tokens,
cookies, or project-specific research data.

Run the agent from this repository root. Paper workspaces are separate
directories with two required children:

- `Authoring/` contains configuration, paper-specific instructions, intake
  material, and local workflow state.
- `Paper/` contains publication content such as `main.tex`, references,
  figures, and that paper's private copy of its LaTeX templates.

Never commit generated paper workspaces to this agent repository. Use
`Agent/Scripts/New-Paper.ps1` to deploy a workspace from a template.
