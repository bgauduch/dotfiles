---
status: accepted
date: 2026-06-28
decision-makers: [Baptiste]
security-relevant: true
review-by: 2027-06-28
supersedes: []
---

# ADR-0009 — CI integration test: full isolated install on every commit

> Amends the **forge & CI platform** part of [ADR-0007](0007-recurring-audit-ci-precommit.md)
> (which assumed GitLab): the repo is hosted on **GitHub**, so CI runs on
> **GitHub Actions**. The ADR-0007 audit matrix remains the target; ADR-0009 only decides the
> platform and the **integration test** (isolated install), not the level-2 gates.

## Context and problem statement
The chezmoi source state is entirely static until it is *applied* to a machine.
A template that fails to render, a non-idempotent install script, a wrong mise tool name, or a
broken `.zshrc` only show up at `apply` time. We need a safety net that **replays a clean
end-to-end installation** on every change, before merge — without depending on a human machine.

## Decision drivers
- Validate the real install (apt + mise + chezmoi apply + doctor), not just syntax.
- Test **every branch commit** and **every PR** (the requested repo strategy).
- Local reproducibility identical to CI (no "works on my machine" drift).
- Platform = the repo's platform (GitHub), without rewriting ADR-0007.

## Considered options
- Option A — Static lint only (shellcheck/render): fast but does not prove the install works.
- Option B — CI job installing directly on the runner: polluted by the runner's pre-installed
  tools, not a "fresh machine".
- Option C — **Build a Docker image (`Dockerfile`) that runs `chezmoi init --apply` then
  `doctor.sh` in a clean Debian; the build IS the test.** Reproducible locally via
  `make integration-test`. Complemented by a gitleaks job (blocking) and shellcheck (advisory).

## Decision
**Option C.**
- `.github/workflows/integration-test.yml` on `push` (all branches) + `pull_request`:
  - `isolated-install` (blocking): `docker build` of the `Dockerfile` → full isolated install.
  - `secrets` (blocking): gitleaks (ADR-0007 level 1).
  - `lint` (advisory): shellcheck.
- `Dockerfile` + `make integration-test`: same isolated install locally.
- **Repo strategy**: conventional commits; one `main` branch + feature branches;
  integration tested on every commit; merge to `main` via a green PR.

## Consequences
- Good: install regressions caught before merge; reproducible locally; no human machine
  required; the PR carries the install proof (green job).
- Bad: the full build (mise install) takes a few minutes per run; the macOS/brew path
  is not covered by a Linux runner (a `macos-latest` extension is documented, kept optional).

## Threats addressed
- **T-CR-02** (secret committed by mistake): blocking gitleaks in CI.
- **T-SC-04/08** (tampered dependency/binary that breaks the install): an isolated install that
  fails blocks the merge — the dangerous change does not pass silently.

## Residual attack surface
- CI proves the install **succeeds**, not that it is **innocent** (a binary with valid provenance
  but malicious behavior still passes — see ADR-0003 T-SC-05).
- macOS coverage is not automated (Linux runner); tested manually on a real machine.
- The deterministic level-2 gates (cross-witness, soak) remain deferred (ADR-0007 / ADR-0006).

## Review / expiry
Annual review, or immediate review if the forge changes or if the level-2 switch criterion
(ADR-0006) is reached (adding the deterministic gates to the pipeline).

## Verification
```sh
make integration-test   # docker build: full isolated install, non-zero exit code on failure
make secrets            # gitleaks detect
```
