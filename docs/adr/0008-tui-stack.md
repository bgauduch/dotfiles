---
status: accepted
date: 2026-06-28
decision-makers: [Baptiste]
security-relevant: false
review-by: trigger:major-stack-change
supersedes: []
---

# ADR-0008 — TUI stack: WezTerm + Zellij + Helix + Yazi + Lazygit [grouped]

> **Grouped** ADR: these five tools form a single coherent decision (replace VS Code + cmux
> with a portable native terminal stack). The "why" is shared; we trace them together.

## Context
Replace VS Code + cmux with a native terminal stack, identical on macOS/WSL2, keyboard-navigable,
lightweight, mouse as backup, able to orchestrate multiple AI agents. Layers: emulator,
multiplexer, editor, file-tree, git diff.

## Decision drivers
- Simple keyboard navigation + mouse possible.
- Lightweight, cross-OS portable, open formats (anti vendor lock-in).
- Multi-agent (replace cmux) + Claude Code hooks integration.

## Decision (by layer)
| Layer | Tool chosen | Alternative rejected | Reason |
|---|---|---|---|
| GPU emulator | **WezTerm** | iTerm2/Alacritty | single cross-OS Lua config, target detection, launches Zellij; under WSL2 runs on the **Windows** side (replaces Remote-WSL) — *seam* below |
| Multiplexer | **Zellij** | tmux | visible hints (no muscle memory), native floating panes (file-tree), declarative KDL config; tmux kept for SSH/remote |
| Editor | **Helix** *(under validation, see below)* | Neovim / Zed | simple keyboard model (selection→action), lightweight, mouse by default, integrated LSP without heavy Lua config; Zed = no multiplexer + imperfect WSL2 |
| File-tree | **Yazi** (floating pane) | nnn/ranger | fills Helix's lack of a file-tree, opens in the editor instance |
| Git diff | **Lazygit** | tig/gitui | visual diff + delta integration |

## Helix validation (the biggest functional risk — replacing VS Code for IaC/Python load)
Helix is a **target**, not a given: adoption is only confirmed after a **timebox on a real
task** in Crossplane/Terraform/Python (2-3 weeks), with VS Code kept in parallel during the trial.
**Rollback criterion** (documented rollback to VS Code/hybrid, without superseding) if any is true:
- IaC/Python editing significantly slower than VS Code day to day;
- Crossplane/YAML LSP/refactor/diagnostics insufficient for real work;
- absence of a debugger (DAP) blocking for Python.
The final decision is traced (an amendment to this ADR) after the trial, not on paper.

## WezTerm / Windows seam (critical WSL2 portability)
On the WSL2 side, WezTerm runs **on Windows**, outside the Linux `$HOME` managed by chezmoi: its config
(`wezterm.lua` on Windows) is **outside the chezmoi-WSL context**. Decision so as not to falsely
claim "identical config across 2 OSes" on the emulator side:
- **Chosen**: WezTerm Windows config **out of scope for chezmoi-WSL**, documented in the RUNBOOK
  (`winget install wez.wezterm` + storing the Windows `.lua`); chezmoi manages WezTerm **macOS** only;
  the `.lua` is factored out (a shared template copied manually to the Windows side).
- **Rejected**: a 2nd Windows chezmoi context (doubles the machinery for one file; cost > benefit).
WezTerm is **never** installed inside WSL.

## Consequences
- Good: a coherent, portable, lightweight, multi-agent stack; the same config on 2 OSes via chezmoi.
- Bad: loss of cmux's scriptable browser (replaced by `glab mr`/`glab ci` — the GitLab
  forge, ADR-0007) and of native macOS/iOS notifications (→ Zellij rename-tab hooks). Helix without
  a native file-tree (Yazi workaround). Editor productivity risk covered by the timebox. Accepted.

## Review / expiry
Review if one of these tools changes its major model (e.g. Helix plugin system stable, or Zed fixes
WSL2 + multiplexing).

## Living detail (outside the ADR)
Configs and binds: see RUNBOOK § TUI Stack.
