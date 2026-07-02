---
status: accepted
date: 2026-06-28
decision-makers: [Baptiste]
security-relevant: true
review-by: 2027-06-28
supersedes: []
---

# ADR-0003 — Trust & supply-chain of external dependencies

> **Cross-cutting** doctrine: a single trust cycle for EVERY external dependency (shell plugin,
> tool/LSP via mise, MCP server, package with verifiable provenance). Avoids duplicating a
> "pin/soak ritual" scattered per topic. The *routing* (which manager) is in ADR-0002; the
> *operational steps* of a bump are in the RUNBOOK. Here: the principle and the levels.

## Context and problem statement
A profile targeted by the 2026 supply-chain campaigns (axios/node-ipc/Shai-Hulud): a freelance
Cloud/IaC workstation holding AWS/SSH/tfstate credentials. The most likely vector is a
**dependency compromised upstream** (shell plugin sourced at startup, binary/LSP installed by
mise, MCP server). We need a single rule: what establishes trust before executing third-party
code.

## Decision drivers
- Proportionate supply-chain security, without reinventing Nix (cf ADR-0006).
- Effort aligned with the real surface: binaries/LSP via mise are **more** exposed than the 2
  zsh plugins (campaign pattern = compromised release artifacts). Do not over-armor the plugins
  while subcontracting the binaries.
- macOS/WSL2 portability, reversibility (a step up in requirements is possible).

## Decision: single trust cycle
Every external dependency follows: **declare → pin/lock → verify provenance → soak before
adopting a bump**. Application per class:

| Class | Pin / lock | Provenance | Particularity |
|---|---|---|---|
| zsh plugins (vendored) | clone + **SHA** pinned in `zsh-plugins.lock` | diff review at bump + signature if available | sourced at startup = the most direct risk (T-CR-01); no plugin manager (OMZ/antidote ruled out, cf Decision) |
| Tools & **LSP** via mise | `mise.lock` (versions + **checksums** + URLs) | `mise settings lockfile=true` ⇒ checksums **verified at install** for supported backends; cosign/SLSA if upstream publishes | a lockfile without active verification is decorative; an LSP = a mise tool like any other |
| MCP servers | server version pinned (ADR-0004) | review at add/update | transitive dependency tree (npm/pip) not pinned = residual |
| apt packages (third-party repo) | version managed by apt | signature via `Signed-By:` keyring (ADR-0002) | — |

**Soak time**: do not pin a fresh release immediately; let a waiting period pass (≈ that of an
upstream alert window) before adopting a bump. Steps: RUNBOOK.

### Level 2 (deferred) — scripted gates
The *automated* gates (cross-witness tree-hash against nixpkgs/brew/Debian, scripted heuristic
scan, lint) are the **level-2 target** (ADR-0006), **not built** as long as the switchover
criterion is not met. We keep the decision and the trigger, not a piece of machinery that rots.
At level 1: pin + lock + manual review at bump + `gitleaks` (ADR-0007).

## Consequences
- Good: a single source of truth for the trust cycle; effort realigned to the real surface; no
  duplication; the level-2 path is tracked and triggered by a fact, not a whim.
- Bad: the diff review at bump remains **manual** at level 1 (fallible); accepted as long as the
  number of dependencies stays low (switchover criterion ADR-0006).

## Threats addressed
- **T-SC-01** (plugin compromised upstream), **T-SC-02/03** (compromised release/maintainer),
  **T-SC-04** (unvalidated/dormant dependency), **T-SC-05** (trojanized build with valid
  provenance), **T-CR-01** (credential exfil via a plugin hook), **T-SC-08** (mise/LSP binary
  tampered with on download).

## Residual attack surface
- **T-SC-05** (valid but malicious provenance): no pin proves harmlessness; defense in depth
  (pin + soak + agent sandboxing ADR-0004), not a guarantee.
- **Transitive** dependencies of MCP servers and mise binaries not pinned byte-for-byte (→ Nix,
  ADR-0006 level 3).
- Manual bump review: an obfuscated payload can slip through (accepted limit of level 1).
- **Checksum-less backends (TOFU)**: some upstreams publish no per-artifact hash (e.g. AWS CLI v2,
  shipped as `.pkg`/`.zip` installers). `mise.lock` cannot pre-seed a checksum for these; mise
  records a trust-on-first-use one at install, so the *first* download is unverified against
  upstream. Accepted: the brew/apt alternatives are no stronger, and version+URL stay pinned.

## Review / expiry
Annual review, or immediate upon adding a dependency class or crossing the level-2 switchover
criterion (ADR-0006).

## Verification
```sh
test -f zsh-plugins.lock && test -f mise.lock && echo "locks OK" || echo "missing lockfile"
mise settings 2>/dev/null | grep -q 'lockfile = true' && echo "mise verification active" || echo "ENABLE lockfile"
```
