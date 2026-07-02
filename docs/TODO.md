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
- [x] Contextual editor in zsh: `code --wait` inside a VS Code/code-server terminal
  (`$TERM_PROGRAM=vscode`), Helix otherwise - `chezmoi edit`/`git commit` open in the browser
  editor during the demo, terminal Helix elsewhere.

## Backlog

### security
- [ ] **AWS profile generation (SSO, profile-gated, recon-safe).** `~/.aws/config` is unmanaged, so
  the `sso-sandbox`/`sso-billing-ro` aliases dangle after a fresh init, and the aliases are not gated
  to `.profile`. Plan: template `home/private_dot_aws/config.tmpl`; keep identifiers (account IDs,
  SSO start URL) out of the public repo via chezmoi prompt (preferred, machine-local) or Bitwarden;
  gate the personal profiles + aliases behind `{{ if eq .profile "personal" }}`; emit SSO blocks
  only, zero static key. Track as a short amendment to ADR-0005. Refs: ADR-0005, ADR-0002,
  THREAT-MODEL #10.

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
