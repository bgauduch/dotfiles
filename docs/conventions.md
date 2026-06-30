# Repository conventions

How this repo is developed. The rules below are the source of truth; the rest of the repo links here.

## Single source of truth
Every fact has exactly **one canonical home**; everywhere else **links** to it, never restates it.
The layering:
- **Rules / conventions** → this file (`docs/conventions.md`).
- **Why** (decisions + rationale) → the ADRs ([`adr/`](adr/)).
- **How** (procedures) → [`RUNBOOK.md`](RUNBOOK.md).
- **Entry points** (root `README.md`, `AGENTS.md`, `CLAUDE.md`, the [ADR index](adr/README.md)) →
  links only, no restated rules.

Operating rule: when you add or change a fact, update its single home and link from elsewhere. If
you find yourself about to restate something, link instead.

## Language
- **English only** — all docs, ADRs, code comments, commit messages and PR titles.

## Commits
- **Conventional Commits** (`feat:`, `fix:`, `docs:`, `ci:`, `chore:`, …), enforced by the
  `commit-lint` workflow on both PR titles and commits
  ([ADR-0009](adr/0009-ci-integration-test.md)).

## Branching & merge
- Single **`main`** branch + short-lived **feature branches**.
- Branch names follow **`<type>/<short-kebab-summary>`**, where `<type>` is a Conventional Commit
  type (`feat`, `fix`, `docs`, `chore`, `ci`, …) matching the PR's eventual squash subject —
  e.g. `feat/portable-tui-dotfiles`, `docs/conventions-ssot`.
- Merge to `main` only via a **PR with green CI** — no direct push.
- Every **PR** is **integration-tested** (full isolated install); `main` is re-verified on merge.
  CI triggers on `pull_request` + `push` to `main` only — no duplicate runs
  ([ADR-0009](adr/0009-ci-integration-test.md) /
  [ADR-0007](adr/0007-recurring-audit-ci-precommit.md)).
- Enable the local warn-level **gitleaks pre-commit** hook once per clone: `mise run hooks`
  (the blocking secret gate is CI — [ADR-0007](adr/0007-recurring-audit-ci-precommit.md)).

## ADRs
- Every **durable decision** is recorded as an ADR; **moving state** (tool lists, versions,
  inventory) lives in a config file instead. Format, granularity and numbering:
  [ADR-0000](adr/0000-adr-process-and-repo-conventions.md).
- The *why* lives in the ADRs; the *how* (procedures) in [`RUNBOOK.md`](RUNBOOK.md).

## chezmoi source state
- The **`home/`** subtree is the chezmoi source state (`.chezmoiroot` → `home`); repo-management
  files (README, docs, CI, Dockerfile, mise.toml …) live **above** it and are never seen by
  chezmoi. Edit the **source state** — never `~` directly.
- OS differences via **templates** (`.tmpl` + `{{ if eq .chezmoi.os ... }}`), never duplicate
  files per OS. WSL detection: `.chezmoi.kernel.osrelease | lower | contains "microsoft"`
  ([ADR-0001](adr/0001-chezmoi-dotfiles-manager.md)).
- chezmoi naming prefixes (under `home/`): `dot_` (→ `.`), `executable_` (→ `+x`), and
  `run_once_` / `run_onchange_` scripts under `.chezmoiscripts/`.
- Files inside `home/` that are not dotfiles (lockfiles; `Brewfile` off macOS; `.config/wezterm`
  on WSL) are excluded via [`home/.chezmoiignore`](../home/.chezmoiignore).
- Edit configs with `chezmoi edit --apply <target>` — editor is **Helix** (`$EDITOR=hx`).
  Daily edit/update/sync flow: [`RUNBOOK.md`](RUNBOOK.md#daily-flow-edit--update--sync--conflicts).

## Profiles
- `chezmoi init` asks for a **machine profile** (`personal` | `work`), stored as `.profile`
  (CI/override: `CHEZMOI_PROFILE`). Gate machine-specific config or tools with
  `{{ if eq .profile "work" }}…{{ end }}` — e.g. work-only mise tools in
  `home/dot_config/mise/config.toml.tmpl`.

## Secrets
- **Never committed in plain text.** Static secrets via Bitwarden CLI templates; AWS via SSO
  ([ADR-0005](adr/0005-secrets-and-credentials.md)). Bootstrap order: [`RUNBOOK.md`](RUNBOOK.md).

## Packaging & tasks
- **One manager per tool**: apt (Linux) / brew (macOS) for system bricks, mise for dev tools
  cross-OS ([ADR-0002](adr/0002-tooling-and-packages-doctrine.md)).
- **mise is also the task runner** — repo dev tasks run via `mise run <task>`
  (`integration-test`, `hooks`, `lint`, `secrets`), defined in `mise.toml`. No separate `make`.

## Repository structure
The git repo root holds repo-management files; the chezmoi **source state** lives in `home/`
(`.chezmoiroot` → `home`), so nothing above it is ever deployed to `$HOME`:

```
<repo root>                              # git repo
├── .chezmoiroot                        # → "home" (points chezmoi at the source state)
├── README.md, LICENSE, AGENTS.md, CLAUDE.md
├── docs/                               # conventions.md, adr/, THREAT-MODEL.md, RUNBOOK.md
├── Dockerfile, mise.toml               # local integration test + dev tasks (not deployed)
├── .github/, .githooks/                # CI workflows, renovate, commitlint; git hooks
└── home/                               # ← chezmoi SOURCE STATE (applied to $HOME)
    ├── .chezmoi.toml.tmpl              # init prompts (name, email) + derived osid
    ├── .chezmoidata.toml               # shared data (theme, font)
    ├── .chezmoiignore                  # OS-only exclusions + lockfiles
    ├── .chezmoiscripts/                # run_once_ / run_onchange_ install scripts
    ├── dot_config/                     # wezterm, zellij, helix, yazi, lazygit, starship, mise
    ├── dot_zshrc.tmpl                  # shell, templated per OS
    ├── dot_claude/                     # Claude Code settings (→ ~/.claude)
    ├── dot_local/bin/                  # newagent, delagent, doctor.sh, install-zsh-plugins.sh
    ├── zsh-plugins.lock                # plugin lockfile (ignored from $HOME)
    └── Brewfile.tmpl                   # macOS tool inventory (→ ~/Brewfile on darwin)
```
