# TODO - work tracker

Durable backlog for this repo, kept in-repo (not GitHub issues) so it travels with the code and
is resumable locally or from Claude Code Web. Cold-start: read this, pick the next unchecked item.
Demo-prep + fixes land on branch `demo/live`.

## Done - branch `demo/live` (2026-07-02)
- [x] `terraform` + `awscli` declared as transverse mise tools (checksummed lock; awscli is TOFU,
  documented ADR-0003 residual). `2a9382d`
- [x] Repo aligned to that change: `doctor.sh` smoke-checks terraform/aws + warns on a brew/mise
  duplicate (ADR-0002); RUNBOOK/README bootstrap reordered (`aws sso login` after `chezmoi apply`,
  since the CLI is installed by apply); ADR-0003 TOFU residual note. `f43416a`
- [x] `demo/README.md` translated to English (repo is English-only). `f3ee419`
- [x] zsh set as default login shell post-install - idempotent, non-blocking chezmoi script. `d8692a5`
- [x] `chezmoi` declared as a managed mise tool - fixes `command not found` post-bootstrap, which
  broke the demo edit -> commit loop. `9977a5d`
- [x] Contextual editor in zsh: `code --wait` when a real `code` binary is on PATH inside a
  VS Code terminal (`$TERM_PROGRAM=vscode` + `whence -p code`), Helix otherwise. Guard uses
  `whence -p` because bare code-server injects `code` as a shell FUNCTION that chezmoi's execve
  can't run. The demo container symlinks the bundled VS Code remote CLI onto PATH as `code`
  (`demo/Dockerfile.vscode`), so `chezmoi edit`/`git commit` open in the running browser window.

## Backlog

### security
- [ ] **AWS profile generation (SSO, profile-gated, recon-safe).** `~/.aws/config` is unmanaged, so
  the `sso-sandbox`/`sso-billing-ro` aliases dangle after a fresh init, and the aliases are not gated
  to `.profile`. Plan: template `home/private_dot_aws/config.tmpl`; keep identifiers (account IDs,
  SSO start URL) out of the public repo via chezmoi prompt (preferred, machine-local) or Bitwarden;
  gate the personal profiles + aliases behind `{{ if eq .profile "personal" }}`; emit SSO blocks
  only, zero static key. Track as a short amendment to ADR-0005. Refs: ADR-0005, ADR-0002,
  THREAT-MODEL #10.
- [ ] **`mise.lock` two-writer / multi-machine / multi-OS / multi-profile lifecycle.** The lock is
  both a committed reproducibility artifact and a file `mise` mutates at runtime (`lockfile=true`:
  canonical re-sort + trust-on-first-use checksums, e.g. awscli `blake3:`, computed per install
  platform). Today chezmoi also manages/deploys it, so the two writers collide and `chezmoi diff`
  shows churn unrelated to the edit. Note `mise.lock` IS cross-platform by design (one file, all 7
  platforms) - per-platform lock files are NOT the answer; what actually diverges is the TOFU
  checksums (per install OS) and, under profile gating, the tool set.

  Root sub-defect: `.chezmoiignore` tries to exclude the lock with a bare `mise.lock`, but bare
  patterns match only the target root; the real target is nested (`.config/mise/mise.lock`), so the
  ignore never fires (confirmed: `chezmoi managed` lists it, `chezmoi ignored` does not). Needs
  `**/mise.lock` or the full path - OR the deploy strategy below.

  **Decision (leaning: Solution A).**
  - **A - committed checksummed lock, `create_` seed + deterministic regen (preferred).** Source
    file becomes `create_mise.lock`: chezmoi seeds it on a fresh machine (reproducible first install,
    checksums verified, ADR-0003), then never touches it again -> `mise` owns the runtime copy, zero
    chezmoi churn. The committed lock is regenerated **deterministically** with `mise lock -p <all
    platforms>` (machine-agnostic: checksums come from registries, no install needed), NOT captured
    from a machine's mutated home lock. Commit a **superset** lock (render config with
    `profile=work` if work is a superset of personal) so one lock covers both profiles.
  - **B - versions-only (simpler, weaker doctrine).** Do not commit/deploy the lock (fix the ignore
    to `**/mise.lock`). Versions stay pinned in `config.toml` (committed) so version reproducibility
    holds, but no shared committed checksums -> ADR-0003 weakens to "verified on each machine after
    first TOFU".
  - The arbitrage is repro-of-shared-checksums (A) vs operational simplicity (B). For a security
    portfolio repo, A is the fit and mirrors the existing `zsh-plugins.lock` drift-stop pattern.

  **Lifecycle under A (adding e.g. `rust`):** (1) `chezmoi edit ~/.config/mise/config.toml` -> pin
  an explicit version; (2) `chezmoi cd`; (3) `mise run lock` (repo task to build: renders the
  superset config + `mise lock -p <all>` -> writes `create_mise.lock`) = the sync step; (4) commit
  `config.toml.tmpl` + `create_mise.lock` together, push; (5) back home, `chezmoi apply` +
  `mise install` (local only; home lock mutates but `create_` makes chezmoi ignore it). Install is
  **local**; the committed lock is **regenerated**, never scraped from the local install.

  **Enforcement:** a CI check `mise run lock --check` (regenerate, diff, fail if the committed lock
  is stale vs config) - same mechanic as the zsh-plugins drift-stop (ADR-0007), turning "keep in
  sync" from manual discipline into a gate.

  Implementation deferred: (a) rename source lock to `create_mise.lock`; (b) add the `mise run lock`
  task + superset render; (c) add the CI drift-check; (d) fix/repurpose the `.chezmoiignore` entry.
  Refs: ADR-0003 (supply-chain), ADR-0007 (recurring audit CI).

### tech-debt
- [ ] **`.gitignore` `bin/` -> `/bin/`.** The unanchored `bin/` also matches `home/dot_local/bin/`,
  so a new untracked script there is silently ignored (tracked files unaffected). Anchor to repo root.

### enhancement
- [ ] **Em-dash sweep, repo-wide.** Replace `—` with `-` or rephrase across docs/ADRs/README/comments
  (owner convention: no em dashes). Add the rule to `docs/conventions.md`. Verify:
  `git ls-files | xargs grep -nP '\x{2014}'` returns nothing.
- [ ] **LSP batch via mise.** terraform-ls, gopls, bash-language-server, yaml-language-server,
  marksman (DEFERRED block in the mise config; helix already references terraform-ls). Confirm
  registry names on a real machine, keep the integration-test build green.
- [ ] **Profile-specific configs, work vs personal.** `.profile` currently gates only commented
  lines (personal == work functionally). Wire real per-profile config and give `.profile` an
  observable effect for the demo. Relates to the AWS profile item.

## Demo cold-start (web VS Code)
- One-liner: `sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply bgauduch/dotfiles --branch demo/live`
- Deterministic (skip prompts): prefix with
  `CHEZMOI_PROFILE=personal CHEZMOI_NAME="..." CHEZMOI_EMAIL="..."`.
- After apply: `exec zsh` for the current shell (new logins default to zsh). `chezmoi`, `terraform`,
  `aws` are on PATH via mise shims.
- Verify the loaded profile: `chezmoi execute-template '{{ .profile }}'`.
- The web demo clones the REMOTE branch: push `demo/live` for any fix to take effect there.
