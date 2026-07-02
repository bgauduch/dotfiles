# Architecture Decision Records (ADR)

Structural decisions for the portable development environment (chezmoi + shell + tools +
AI agents). Format: **extended MADR** (4 custom security fields), defined in
[ADR-0000](0000-adr-process-and-repo-conventions.md). Template: [`_template.md`](_template.md).

Every new or changed technical decision ⇒ an ADR (or a superseding one). The
`security-relevant` ADRs reference [`THREAT-MODEL.md`](../THREAT-MODEL.md). The **how**
(procedures, commands, steps) lives in [`RUNBOOK.md`](../RUNBOOK.md), not in the ADRs.

## Index

| ADR | Title | Type | Sec | Status |
|---|---|---|---|---|
| [0000](0000-adr-process-and-repo-conventions.md) | ADR process and format | meta | – | accepted |
| [0001](0001-chezmoi-dotfiles-manager.md) | chezmoi as the dotfiles manager | granular | no | accepted |
| [0002](0002-tooling-and-packages-doctrine.md) | Tooling & packages doctrine (apt/mise/brew, inventory) | **doctrine** | **yes** | accepted |
| [0003](0003-dependencies-trust-supply-chain.md) | Dependency trust & supply-chain (pin/lock/soak) | **doctrine** | **yes** | accepted |
| [0004](0004-ai-agents-security.md) | AI agent security (Claude Code, MCP, hooks) | granular | **yes** | accepted |
| [0005](0005-secrets-and-credentials.md) | Secrets & credentials (Bitwarden / SSO AWS) | granular | **yes** | accepted |
| [0006](0006-immutability-level-pragmatic.md) | Pragmatic, evolving immutability level | granular | **yes** | accepted |
| [0007](0007-recurring-audit-ci-precommit.md) | Recurring CI audit + pre-commit | granular | **yes** | **proposed** (level 2 deferred) |
| [0008](0008-tui-stack.md) | TUI stack (WezTerm/Zellij/Helix/Yazi/Lazygit) | **grouped** | no | accepted (Helix under validation) |
| [0009](0009-ci-integration-test.md) | CI integration test (isolated install, GitHub Actions) | granular | **yes** | accepted (amends ADR-0007 forge) |
| [0010](0010-auto-commit-push-deferred.md) | chezmoi auto-commit/push — deferred | granular | **yes** | **proposed** (deferred) |

## See also
- **ADR format & process** (granularity, numbering, immutability): [ADR-0000](0000-adr-process-and-repo-conventions.md).
- **Repository conventions** (language, commits, branching, secrets, structure):
  [`../conventions.md`](../conventions.md).
