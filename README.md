# dotfiles

[![integration-test](https://github.com/bgauduch/dotfiles/actions/workflows/integration-test.yml/badge.svg)](https://github.com/bgauduch/dotfiles/actions/workflows/integration-test.yml)
[![commit-lint](https://github.com/bgauduch/dotfiles/actions/workflows/commit-lint.yml/badge.svg)](https://github.com/bgauduch/dotfiles/actions/workflows/commit-lint.yml)
[![Renovate](https://img.shields.io/badge/renovate-enabled-brightgreen?logo=renovatebot)](https://docs.renovatebot.com)
[![managed with chezmoi](https://img.shields.io/badge/managed%20with-chezmoi-blueviolet)](https://chezmoi.io)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Portable, security-conscious TUI development environment — identical on **macOS** and
**WSL2/Debian** — managed by [chezmoi](https://chezmoi.io). Decisions are traced as ADRs in
[`docs/adr/`](docs/adr/); the threat model and operational runbook live in
[`docs/`](docs/).

## Stack

| Layer       | Tool     | Config |
|-------------|----------|--------|
| Emulator    | WezTerm  | `dot_config/wezterm/wezterm.lua.tmpl` (macOS / Windows-side on WSL2) |
| Multiplexer | Zellij   | `dot_config/zellij/` (+ multi-agent `layouts/agent.kdl.tmpl`) |
| Editor      | Helix    | `dot_config/helix/` |
| File-tree   | Yazi     | `dot_config/yazi/` |
| Git         | Lazygit  | `dot_config/lazygit/config.yml` |
| Shell       | Zsh + Starship | `dot_zshrc.tmpl`, `dot_config/starship.toml` |
| Toolchain   | mise (+ apt/brew) | `dot_config/mise/config.toml.tmpl`, `Brewfile.tmpl` |

## Install (new machine)

```sh
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply bgauduch/dotfiles
```

Cold-start order matters (secrets first) — see [`docs/RUNBOOK.md`](docs/RUNBOOK.md):
unlock Bitwarden → `aws sso login` → `chezmoi init --apply` → `doctor.sh`.

## Key bindings (Zellij, VS Code-like)

| Bind        | Action |
|-------------|--------|
| `Alt`+arrows | Move focus between panes |
| `Alt`+`n`   | New terminal pane in current cwd |
| `Alt`+`w`   | Toggle floating panes |
| `Alt`+`e`   | Toggle floating Yazi file-tree |

## Verify

```sh
doctor.sh   # binaries, plugin SHAs, mise verification, sandbox, deny rules, secret scan
```

## Security model

A supply-chain-conscious setup, traced in the ADRs and threat model:
[packages](docs/adr/0002-tooling-and-packages-doctrine.md) ·
[dependency trust](docs/adr/0003-dependencies-trust-supply-chain.md) ·
[AI agents](docs/adr/0004-ai-agents-security.md) ·
[secrets](docs/adr/0005-secrets-and-credentials.md) ·
[threat model](docs/THREAT-MODEL.md).

## Contributing

Conventions (commits, branching, language, chezmoi rules, secrets) live in
[`docs/conventions.md`](docs/conventions.md). Agents: see [`AGENTS.md`](AGENTS.md).
