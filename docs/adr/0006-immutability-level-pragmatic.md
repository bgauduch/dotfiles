---
status: accepted
date: 2026-06-28
decision-makers: [Baptiste]
security-relevant: true
review-by: trigger:switchover-criterion-met
supersedes: []
---

# ADR-0006 — Immutability level: pragmatic and evolving (and when to switch to Nix)

## Context and problem statement
Stated goal: "move toward an immutable system that runs only on validated dependencies".
A legitimate question was raised: is this over-engineering? are we reinventing an existing
system? The honest answer: yes, pushing immutability all the way **reinvents Nix**, which is the
existing solution for byte-for-byte reproducibility. So we must decide on a level, and above all
on an **explicit criterion** for moving up to the next level — so that it is a traced decision,
not a feeling.

## Decision drivers
- Supply-chain security (validated dependencies) without disproportionate complexity.
- macOS + WSL2 portability without breaking productivity.
- Reversibility: be able to raise the bar later without rewriting everything.

## Considered options
- **Level 1 — Pragmatic**: SHA pinning (plugins) + lockfiles (mise, Brewfile) + recurring scripted
  audit + ADR. Reproducibility of the *configs* and *declared versions*, not the whole system.
- **Level 2 — High**: Level 1 + lockfiles everywhere + blocking CI gates + checksums/cosign
  on the mise binaries when available. Still without a new heavyweight manager. **Concretely =
  ADR-0003 (scripted bump gates) + ADR-0007 (full CI audit), both in `proposed` status as
  long as we stay at level 1.**
- **Level 3 — Maximal (Nix/home-manager + flakes)**: byte-for-byte reproducibility, `flake.lock`
  pins everything (system + tools + configs), instant rollback.

## Decision
**Start at Level 1 (pragmatic) as a durable FOUNDATION, move up to Level 2 only if an
objective criterion requires it (not "by default once stabilized" — avoid building an audit
harness for 2 machines before the need), and switch to Level 3 (Nix) ONLY if the criterion is met.**

The Level 1 foundation actually implemented: SHA-pinned plugins + lockfiles (`zsh-plugins.lock`,
`mise.lock` with **active provenance verification**, ADR-0003) + gitleaks pre-commit/CI + ADR.
The scripted gates (ADR-0003) and the full blocking CI (ADR-0007) are the **Level 2 target**,
not built as long as the criterion below is < met: we keep the decision, not the machinery.

### Criterion for switching to Level 2 (build the ADR-0003/0007 gates)
Build the scripted audit harness if **≥ 1** becomes true:
- a bump introduced (or nearly introduced) a security regression not caught by eye;
- the number of vendored/MCP dependencies exceeds ~5 (manual audit no longer scales);
- an external requirement (client audit/compliance) demands an automated trace.

This is not over-engineering at Levels 1–2: pin + lockfiles + audit cover the bulk of the
supply-chain risk for an individual workstation. Level 3 (Nix) brings byte-for-byte repro but
at a real cost: learning curve (functional language), configs not editable in place,
macOS friction (missing launcher entries), and tension with the "git+zsh everywhere, zero
package manager" principle of ADR-0003. Adopting Nix "to be immutable" without a triggering need =
the definition of over-engineering.

### Objective criterion for switching to Nix (Level 3)
Switch if **≥ 2** of the following conditions become true:
1. More than 2 machines to keep strictly in sync (adding a desktop, VM, server).
2. A proven need for instant system rollback (a bump has already broken the environment ≥ 1 time).
3. A need for reproducible per-project environments shared with third parties (`nix develop`).
4. The time spent debugging macOS/WSL2 divergences exceeds ~1 day/quarter.
As long as < 2 conditions: stay at Levels 1–2. The decision to switch will be the subject of an ADR
superseding this one.

## Consequences
- Good: complexity aligned with the real need; an evolution path that is traced and triggered by
  facts, not by desire; no premature reinvention of Nix.
- Bad: Levels 1–2 do not guarantee byte-for-byte repro (two installs on different
  dates may differ on unpinned transitive deps). Accepted as long as the criterion is < 2.

## Threats addressed
- **T-SC-04** (unvalidated deps): lockfiles + pin cover the declared dependencies.
- Does NOT claim to address full transitive repro (that is the role of Level 3).

## Recovery / rollback (Levels 1–2, without Nix)
**Decision**: Levels 1–2 do **not** offer transactional rollback (that is the Level
3/Nix argument); we accept recovery via `git revert` of the source state + idempotent scripts +
snapshot of critical configs before a bump. **Detailed procedure: RUNBOOK § Rollback.**

## Residual attack surface
- **Transitive** dependencies of the mise/brew binaries not pinned byte-for-byte at Levels 1–2.
- Possible drift between two machines on unlocked versions (e.g. system apt/brew libs).
  Mitigated by the recurring audit that detects drift, not by construction.

## Review / expiry
On each run of the recurring audit: evaluate the switchover criterion (condition counter).
Explicit trigger if ≥ 2.

## Verification
```sh
# presence of the expected lockfiles (Level 1)
test -f zsh-plugins.lock && test -f mise.lock && echo OK || echo "lockfile missing"
```

## Note: are we reinventing an existing system?
Yes, partly, and that is accepted. Levels 1–2 = a pragmatic subset of what Nix does
(pin + lock + validation), implemented in git+zsh to stay portable and simple. We do NOT rewrite
the Nix store or dependency resolution — we just borrow the lockfile idea. The day we
want the strong guarantee, we adopt Nix instead of continuing to reimplement it worse: that is
exactly what the switchover criterion prevents.
