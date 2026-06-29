# Repository conventions

The single source of truth for how this repo is developed. Each rule is stated **once** here; the
*why* lives in the linked ADR, and procedures live in [`RUNBOOK.md`](RUNBOOK.md). Other docs (the
root `README.md`, `AGENTS.md`, the [ADR index](adr/README.md)) link here instead of restating.

## Language
- **English only** — all docs, ADRs, code comments, commit messages and PR titles.

## Commits
- **Conventional Commits** (`feat:`, `fix:`, `docs:`, `ci:`, `chore:`, …), enforced by the
  `commit-lint` workflow on both PR titles and commits
  ([ADR-0009](adr/0009-ci-integration-test.md)).

## Branching & merge
- Single **`main`** branch + short-lived **feature branches**.
- Merge to `main` only via a **PR with green CI** — no direct push.
- Every commit is **integration-tested** (full isolated install) on push and PR
  ([ADR-0009](adr/0009-ci-integration-test.md) /
  [ADR-0007](adr/0007-recurring-audit-ci-precommit.md)).

## ADRs
- Every **durable decision** is recorded as an ADR; **moving state** (tool lists, versions,
  inventory) lives in a config file instead. Format, granularity and numbering:
  [ADR-0000](adr/0000-adr-process-and-repo-conventions.md).
- The *why* lives in the ADRs; the *how* (procedures) in [`RUNBOOK.md`](RUNBOOK.md).

## chezmoi source state
- This git repo **is** the chezmoi source state. Edit the **source state** — never `~` directly.
- OS differences via **templates** (`.tmpl` + `{{ if eq .chezmoi.os ... }}`), never duplicate
  files per OS. WSL detection: `.chezmoi.kernel.osrelease | lower | contains "microsoft"`
  ([ADR-0001](adr/0001-chezmoi-dotfiles-manager.md)).
- chezmoi naming prefixes: `dot_` (→ `.`), `executable_` (→ `+x`), and `run_once_` /
  `run_onchange_` scripts under `.chezmoiscripts/`.
- Repo-management files at the source root (README, LICENSE, docs, AGENTS.md, CLAUDE.md, …) are
  kept out of `$HOME` via [`.chezmoiignore`](../.chezmoiignore) — they are not dotfiles.

## Secrets
- **Never committed in plain text.** Static secrets via Bitwarden CLI templates; AWS via SSO
  ([ADR-0005](adr/0005-secrets-and-credentials.md)). Bootstrap order: [`RUNBOOK.md`](RUNBOOK.md).

## Packaging
- **One manager per tool**: apt (Linux) / brew (macOS) for system bricks, mise for dev tools
  cross-OS ([ADR-0002](adr/0002-tooling-and-packages-doctrine.md)).

## Repository structure
The git repo root is the chezmoi source state:

```
~/.local/share/chezmoi/                 # source state (= this git repo)
├── docs/
│   ├── conventions.md                  # this file — repository conventions
│   ├── adr/                            # ADRs + index (README.md) + _template.md
│   ├── THREAT-MODEL.md                 # 3-layer threat model (referenced by ADRs)
│   └── RUNBOOK.md                      # procedures (bootstrap, bumps, rollback)
├── AGENTS.md, CLAUDE.md                # agent entry points (not deployed to $HOME)
├── .chezmoi.toml.tmpl                  # init prompts (name, email) + derived osid
├── .chezmoidata.toml                   # shared data (theme, font)
├── .chezmoiignore                      # ignore per OS + repo-management files
├── .chezmoiscripts/                    # run_once_ / run_onchange_ install scripts
├── dot_config/                         # wezterm, zellij, helix, yazi, lazygit, starship, mise
├── dot_zshrc.tmpl                      # shell, templated per OS
├── dot_claude/                         # Claude Code settings (deployed to ~/.claude)
├── dot_local/bin/                      # newagent, delagent, doctor.sh, install-zsh-plugins.sh
├── zsh-plugins.lock                    # plugin lockfile (repo + SHA + tag + review date)
├── Brewfile.tmpl                       # macOS tool inventory
├── Dockerfile, Makefile                # local integration test (not deployed)
└── .github/                            # CI workflows, renovate, commitlint config
```
