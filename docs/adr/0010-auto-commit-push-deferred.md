---
status: proposed
date: 2026-06-30
decision-makers: [Baptiste]
security-relevant: true
review-by: trigger:daily-friction
supersedes: []
---

# ADR-0010 — chezmoi auto-commit / auto-push — deferred

> **Status `proposed` / deferred.** No `[git]` auto setting is configured. This ADR records the
> decision to defer and the trigger to revisit, so the choice is traced rather than implicit.

## Context and problem statement
chezmoi can auto-commit (and auto-push) source-state changes on `apply` via `[git] autoCommit` /
`autoPush`. It is convenient for one-off dotfile tweaks across machines. But the repo enforces
"merge to `main` only via a PR with green CI" (ADR-0009 / ADR-0007): the integration test +
gitleaks are the gate. `autoPush` would push straight to the tracked branch and **bypass that
gate**, and the local gitleaks pre-commit is warn-only by design (ADR-0007). So auto-push is in
direct tension with the branch model.

## Decision drivers
- Daily ergonomics (small dotfile edits should not require ceremony).
- Keep the PR + CI gate on `main` (no unreviewed/unscanned push to the trunk).
- Reversibility — adopt later if the friction proves real.

## Considered options
- Option A — Nothing (status quo): edits committed/pushed manually via the daily flow (RUNBOOK).
- Option B — `autoCommit = true` only: local commits auto-created, push stays manual/PR.
- Option C — `autoCommit + autoPush`: full automation; bypasses the PR/CI gate on the tracked branch.

## Decision
**Deferred — keep Option A for now.** No `[git]` auto setting. Revisit (likely Option B) if daily
friction proves real. Option C only if the branch model itself moves to trunk + non-blocking CI
(which would supersede part of ADR-0007 / ADR-0009).

## Consequences
- Good: the trunk stays gated; nothing reaches `main` unscanned/unreviewed.
- Bad: small cross-machine tweaks need a manual commit/PR (assumed; that is the daily flow).

## Threats addressed
- **T-CR-02** (secret committed/pushed by mistake): deferring auto-push keeps gitleaks-in-CI (on
  the PR) as a mandatory gate before anything lands on `main`.

## Residual attack surface
- The warn-only pre-commit (ADR-0007) does not block locally; the real gate stays in CI. Unchanged
  by this ADR.

## Review / expiry
`trigger:daily-friction` — revisit when manual commit/push friction is repeatedly felt, or when the
branch model switches to trunk (ADR-0007 escape hatch).

## Verification
```sh
# No chezmoi git automation is configured (expected while deferred):
chezmoi cat-config 2>/dev/null | grep -A2 '\[git\]' || echo "no [git] autoCommit/autoPush (expected)"
```
