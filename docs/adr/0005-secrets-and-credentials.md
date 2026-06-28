---
status: accepted
date: 2026-06-28
decision-makers: [Baptiste]
security-relevant: true
review-by: 2027-06-28
supersedes: []
---

# ADR-0005 — Secrets & credentials (storage, new-machine provisioning)

## Context and problem statement
chezmoi manages the *configs*; nothing decided where the **secrets** and **access** live: SSH
keys, multi-account AWS credentials, GitLab/GitHub tokens. This is the central asset of the threat model (a
freelance Cloud/IaC workstation). "No plaintext secret in the repo" is necessary but not sufficient: we
need a *positive* source of truth and an explicit bootstrap flow. Two distinct kinds:
**static** secrets (to store/retrieve) and **AWS access** (where the right reflex is to store NOTHING).

## Decision drivers
- Single source, never a plaintext secret in git.
- Deterministic and traced new-machine bootstrap.
- Reuse the tooling already in place; decouple config / secret.
- Minimize long-lived secrets materialized on disk.

## Considered options
- **Bitwarden CLI + chezmoi templates** (static): already in place; injected at `apply`.
- SOPS + age: encrypted in the repo, self-contained, but moves the problem to the age key.
- Manual/RUNBOOK only: zero dependencies but high MTTR and error-prone.
- For AWS: static keys (Bitwarden→`~/.aws/credentials`) **vs** SSO/granted (temporary credentials).

## Decision
1. **Static secrets → Bitwarden CLI**, injected by chezmoi template: `*.tmpl` files
   calling `{{ (bitwarden "item" "<id>").<field> }}`, rendered only at `chezmoi apply`, never
   committed. The repo only contains **item IDs**, never values.
2. **AWS access → SSO / `granted` (temporary credentials), ZERO static keys** by default. Interactive
   login per profile/account; fallback to `aws-vault` (OS keychain backend) **only** for an
   account without SSO. No long-term key on disk; Bitwarden is used only to *transport* an
   unavoidable long-term secret, not to replace an SSO.
3. **Bootstrap & cold-start order**: `bw unlock` BEFORE the first `chezmoi apply`; clone the
   private repo over **HTTPS + token** (from the vault) to avoid the SSH-key ⇄ repo deadlock. Procedure:
   RUNBOOK.

## Consequences
- Good: single source, nothing in plaintext, traced bootstrap, no static AWS key; the repo can be
  published without leaks.
- Bad: dependency on `bw`/network at `apply` (readable failure if the vault is locked); interactive SSO
  login per session (minor friction, accepted).

## Threats addressed
- **T-CR-03** (plaintext secret by mistake / implicit secret gesture forgotten): references-only +
  documented bootstrap + zero static AWS key.

## Residual attack surface
- **Bitwarden vault compromised** (account/master password): out of scope (assumes an "upstream
  account is healthy"), mitigated by 2FA.
- Secrets **materialized on disk** after apply: minimize; prefer in-memory agents/SSO.
- `bw` is a binary with verified provenance (ADR-0003).

## Review / expiry
Reviewed annually; immediately on adding a credential type or changing the manager.

## Verification
```sh
grep -rIl --exclude='*.tmpl' -E 'AKIA|BEGIN [A-Z ]*PRIVATE KEY|glpat-|ghp_' ~/.local/share/chezmoi \
  && echo "PLAINTEXT SECRET" || echo OK
test -f ~/.aws/credentials && echo "WARNING static AWS key present" || echo "AWS without static key OK"
```
