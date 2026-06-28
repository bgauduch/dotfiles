---
status: accepted
date: 2026-06-28
decision-makers: [Baptiste]
security-relevant: false
review-by: trigger:adoption-nix
supersedes: []
---

# ADR-0001 — chezmoi as the cross-OS dotfiles manager

## Context and problem statement
Need for an identical environment on macOS (main machine) and WSL2/Debian, from a single
versioned source of truth. The differences between operating systems (Homebrew paths, clipboard,
WSL) must be handled without duplicating files per machine.

## Decision drivers
- Single versioned source (consistent with the existing GitLab workflow).
- Handling OS differences through templating, not duplication.
- No heavy runtime; minimal dependencies.
- One-liner bootstrap on a fresh machine.

## Considered options
- Option A — **chezmoi**: 1:1 source→home mapping, Go templating, native OS detection.
- Option B — **GNU Stow**: pure symlinks, simple, but no templating (OS differences = separate files).
- Option C — **yadm**: git wrapper, more limited templating than chezmoi.
- Option D — **Nix/home-manager**: maximum reproducibility (see ADR-0006).

## Decision
**chezmoi.** It offers OS templating (`{{ if eq .chezmoi.os "darwin" }}`, WSL detection via
`.chezmoi.kernel.osrelease`) that allows a single file per config, lifecycle scripts
(`run_once_`, `run_onchange_`) for idempotent installs, and a one-liner bootstrap. Stow is
ruled out because the absence of templating would force duplicated macOS/Linux files — the
anti-goal.

## Consequences
- Good: a single file per config, OS differences readable inline, reproducible install.
- Bad: a learning curve on the Go template syntax; the source state is not editable "in place"
  (you have to go through `chezmoi edit` / `chezmoi add`). Accepted.

## Comparison
| Criterion | chezmoi | Stow | yadm | Nix/HM |
|---|---|---|---|---|
| OS templating | ✅ native | ❌ | ~ | ✅ |
| Runtime dependency | 1 binary | perl | git | Nix toolchain |
| Learning curve | medium | low | low | high |
| Reproducibility | configs | configs | configs | full system |
