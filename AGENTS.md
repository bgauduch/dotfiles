# AGENTS.md

Guidance for AI agents (and humans) working in this repository.

**This repo is the [chezmoi](https://chezmoi.io) source state** for a portable,
security-conscious TUI dev environment (macOS + WSL2/Debian). The git repo root **is** the
source state.

## Start here
- **Conventions — authoritative: [`docs/conventions.md`](docs/conventions.md).** Language,
  commits, branching, chezmoi rules, secrets, packaging. Follow it.
- **Why** (decisions): [`docs/adr/`](docs/adr/). **How** (procedures):
  [`docs/RUNBOOK.md`](docs/RUNBOOK.md).

## Working rules for agents
- Edit the **chezmoi source state** (`dot_*`, `.chezmoiscripts/`, …), never `~` directly.
- Follow [`docs/conventions.md`](docs/conventions.md) for commits, language, branching,
  chezmoi rules and secrets.
- Before pushing, run **`make integration-test`** (the same clean isolated install CI runs).
- Agent security model — deny rules, sandbox, MCP allowlist:
  [ADR-0004](docs/adr/0004-ai-agents-security.md).
- Never commit secrets; Bitwarden CLI + AWS SSO:
  [ADR-0005](docs/adr/0005-secrets-and-credentials.md).
