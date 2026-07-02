---
status: proposed
date: 2026-06-28
decision-makers: [Baptiste]
security-relevant: true
review-by: 2027-06-28
supersedes: []
---

# ADR-0007 — Recurring security audit: blocking CI + pre-commit warning

> **Status `proposed` (level 2, implementation deferred).** At **level 1** (foundation, ADR-0006),
> only **gitleaks** (secrets) runs in pre-commit (warn) + CI (blocking); the deterministic gates
> for plugins/cross-witness/ADR lint relate to ADR-0003 and are only built when moving to level 2.
> The full matrix below is the **target**, not the current state.

## Context and problem statement
The shell audit was run once by hand. For it to have value over time, it must
re-run automatically and detect any drift (unpinned plugin, global key added, plaintext
secret, missing deny). Stated choice: blocking CI + pre-commit warning.

## Decision drivers
- Detect configuration drift on each change.
- Don't block the local flow (friction), but block integration (guarantee).
- Reuse the deterministic gate logic from ADR-0003.

## Considered options
- Option A — One-off manual audit: insufficient (forgetting).
- Option B — Blocking pre-commit: too much local friction, pushes toward `--no-verify`.
- Option C — **Blocking CI (source of truth) + non-blocking pre-commit (fast feedback).**

## Decision
**Option C.**
- **Pre-commit (warning)**: a fast hook that runs the "cheap" checks (plaintext secrets,
  plugin drift vs lockfile, presence of the Claude Code deny rules) and **warns** without blocking the
  commit. Goal: immediate feedback, zero incentive to bypass.
- **CI (blocking)**: a dotfiles pipeline (GitLab CI, consistent with the existing forge) that re-runs
  the full audit and **fails** if a gate is red. Source of truth: nothing is merged to `main`
  with a red gate.

### Forge & branch model
> **Amended by [ADR-0009](0009-ci-integration-test.md)**: the repository lives on **GitHub**, so the CI
> runs on **GitHub Actions** (not GitLab CI), with an "isolated install" integration test
> on each commit. The branch model below remains valid (PR + blocking CI on `main`).
- **Forge**: GitLab (aligns with the existing ecosystem). The PR/run review CLI is `glab`, not `gh`
  (aligned with ADR-0008).
- **Model**: mandatory MR + blocking CI on `main` (no direct push).
- **Accepted escape hatch (anti-erosion, solo)**: switch to **trunk + non-blocking CI** enacted
  *without superseding* if the solo friction outweighs the benefit. **Explicit trigger**: the first
  `--no-verify` or the first MR bypass. The guarantee depends on discipline; this trigger
  avoids denial (we switch officially instead of bypassing silently).

### Audit content (reuses audit/gates/ + audit/scan/)
| Check | Layer | Pre-commit | CI |
|---|---|---|---|
| Plaintext secrets (gitleaks/regex) | all | warn | blocking |
| Plugin SHA == lockfile | shell | warn | blocking |
| Soak time of proposed bumps | shell | – | blocking |
| `git tag -v` GPG of plugins | shell | – | blocking |
| Cross-witness tree-hash | shell | – | warn (degraded if no witness) |
| Heuristic scan of plugin diff | shell | warn | blocking if strong signals |
| Brewfile/mise vs lockfile (version drift) | tools | warn | blocking |
| No apt key in the global keyring | tools | – | blocking (Linux) |
| Deny secrets present (Claude settings) | agents | warn | blocking |
| MCP servers ∈ allowlist | agents | – | blocking |
| Active mise provenance check (not just lockfile present) | tools | warn | blocking (level 1) |
| Auto-launched LSPs ∈ declared languages.toml | continuous exec | – | blocking |
| No plaintext secret rendered outside *.tmpl | secrets | warn | blocking |
| security-relevant ADRs have the 4 fields | meta | warn | blocking (lint) |

## Consequences
- Good: drift detected early (local) and blocked late (CI); logic shared with the bump ritual.
- Bad: dual pre-commit/CI maintenance (mitigated by calling the same script from both).

## Threats addressed
- **T-SC-01..07** (drift toward an unvalidated dependency): drift blocked in CI.
- **T-CR-02** (secret committed by mistake): gitleaks pre-commit + CI.
- **T-AG-02** (MCP outside the allowlist added quietly): blocking CI check.

## Residual attack surface
- Pre-commit is bypassable (`--no-verify`) **by design** → that is why the guarantee is
  in CI, not locally.
- The audit only detects the drifts we have coded as a gate; a new, unmodeled attack
  class gets through (mitigated by the annual review of signals, ADR-0003).
- The heuristic scan has the limits of ADR-0003 (not a proof).

## Review / expiry
Annual review of the check matrix; add a gate for each newly identified threat class.

## Verification
```sh
audit/run.sh --mode ci      # return code ≠ 0 if a blocking gate fails
audit/run.sh --mode pre-commit   # never fails, prints warnings
```
