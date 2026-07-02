# RUNBOOK — Operational procedures (the "how")

> The ADRs set the **what + why** (lasting decisions). This RUNBOOK carries the **how**
> (the moving parts: commands, steps, execution order). Separation rule: cf. ADR-0000.
> No decisions here; if a procedure reveals a structural choice, it gets promoted to an ADR.

## Bootstrapping a fresh machine (mandatory order)
1. **Secrets first** (ADR-0005): `bw login` + `bw unlock`, export the `BW_SESSION` session.
2. **AWS** (ADR-0005): `aws sso login` (or `granted`) per profile; no static key on disk.
3. **chezmoi**: `sh -c "$(curl -fsLS get.chezmoi.io)"` then `chezmoi init --apply <repo>`.
   - Root of trust: machine assumed clean at the initial bootstrap (TOFU assumed, cf.
     THREAT-MODEL § Assumptions). No checksum to compare here — the repo, the source of the pins, is
     not cloned yet. Pinning/checksums apply to **later bumps** (ADR-0003).
4. **Smoke test**: `doctor.sh` (see below).

## Daily flow (edit / update / sync / conflicts)
Source of truth = the git repo; every machine converges via chezmoi. Shell aliases: `dot_zshrc.tmpl`
(`cm*`). Editor = **Helix** (`$EDITOR=hx`).
- **Edit a config**: `chezmoi edit --apply ~/.config/<...>` (`cme`) — edits the *source* file under
  `home/` in Helix, then applies. (Never edit `~` directly.)
- **Capture an out-of-band change** made directly in `$HOME`: `chezmoi add <path>` (`cma`) /
  `chezmoi re-add` (`cmra`) for already-managed files.
- **Update from upstream**: `chezmoi diff` (`cmd`) to preview, then `chezmoi update` (`cmu`) =
  `git pull` + `apply`.
- **Push your changes** (multi-machine): `chezmoi cd` (`cmcd`) → branch `<type>/<kebab>` →
  commit → push → PR (green CI) → merge. Other machines then `chezmoi update`. (Direct push to
  `main` is gated; auto-commit/push is deferred — ADR-0010.)
- **Local vs upstream divergence / conflicts**: `chezmoi status` (`cms`); resolve with
  `chezmoi merge <target>` (opens a 3-way merge in `$EDITOR`).

## Dependency bump ritual (decision: ADR-0003)
To be run for any bump of a vendored plugin / mise tool / LSP / MCP server:
1. `git log --oneline <old>..<new>` on the upstream: review the commits introduced.
2. Targeted review diff: presence of `curl|wget|nc`, `base64 -d`, reads of `$AWS_*`/`$*_TOKEN`/
   `~/.ssh`, `precmd`/`preexec` hooks, `curl|sh`, `chmod`/`crontab`.
3. Verify the signature when available (`git tag -v`, maintainer GPG).
4. **Soak**: let the waiting period elapse (cf. ADR-0003) before pinning a fresh release.
5. Update the pin: SHA in `zsh-plugins.lock` (plugins) or `mise.lock` (tools/LSP).
6. Re-clone / reinstall at the pin, verify the SHA/checksum post-install; drift ⇒ STOP.

> *Scripted* gates (cross-witness tree-hash, etc.) = level 2, not built (ADR-0003/0006).

## AI agent sandbox (decision: ADR-0004)
- Launch an agent in a restricted scope: bubblewrap profile (Linux/WSL2) / `sandbox-exec` (macOS).
- Filtered outbound network proxy via socat per the profile.
- **Verify that the sandbox actually runs** (do not assume it): startup check in
  `doctor.sh`; if the profile does not apply (WSL2 user-namespaces, deprecated Seatbelt), the agent
  does NOT start in "assumed sandbox" mode.
- 1 agent = 1 worktree = 1 branch (bounded file scope).

## LSP schemas (Crossplane/K8s) — network trade-off (ADR-0003)
To validate/autocomplete CRDs without a live network call: drop the CRD+K8s JSON schemas
locally and point `yaml-language-server` at them. Otherwise, leave remote resolution in place (an
assumed devex trade-off, not a gate).

## doctor.sh — fresh-machine smoke test
Checks: binaries present; plugin SHAs == `zsh-plugins.lock`; `mise settings` shows
`lockfile=true` + `mise.lock` present; agent sandbox actually starts; Claude deny-rules
present; no secret rendered in cleartext outside `*.tmpl`.

## Rollback (level 1-2, without Nix — ADR-0006)
- Nominal state: `chezmoi cd && git revert <commit> && chezmoi apply`.
- Apply broken mid-course (a `run_onchange_` script failed ⇒ hybrid state): chezmoi is not
  atomic. Idempotent scripts (re-runnable); `chezmoi diff`/`--dry-run` mandatory before
  apply; snapshot the critical configs (`.zshrc`, `mise.toml`) before a bump. Never bump the
  main machine in the middle of work.

## TUI stack — living detail (ADR-0008)
Configs in `dot_config/{wezterm,zellij,helix,yazi,lazygit}/`. VS Code-like binds and Zellij agent
layout (`layouts/agent.kdl`). On the WSL2 side: WezTerm installed on Windows (`winget install wez.wezterm`),
its `wezterm.lua` config on Windows is outside chezmoi (cf. the ADR-0008 seam).
