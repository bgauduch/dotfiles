# PLAN — Portable TUI setup (chezmoi + Zellij + Helix + WezTerm + Yazi + Lazygit)

> To be executed by Claude Code. **Start in plan mode** (`Shift+Tab`). Present the plan,
> wait for approval, then switch to `acceptEdits`. NEVER touch `~` directly:
> everything goes through the chezmoi source state (`chezmoi add` / editing in `~/.local/share/chezmoi`).

## Goal
Replace VS Code + cmux with a native terminal stack, **identical on macOS and WSL2/Debian**,
managed by a single chezmoi dotfiles repo. Targets: lightweight keyboard editor (Helix), multi-agent
multiplexer (Zellij), GPU emulator (WezTerm), mouse-driven file tree (Yazi), visual git diff (Lazygit).

## Constraints
- **Single source of truth**: the chezmoi Git repo. No file divergence between OSes;
  OSX/WSL2 differences are handled by `.tmpl` templates, not by separate files.
- **Toolchain via mise** (already in use) to version the binaries identically.
- **Idempotent**: re-runnable without breakage. `run_onchange_`/`run_once_` scripts.
- **No cleartext secret** in the repo (Bitwarden CLI integration already in place, optional here).
- Preference for open formats, no lock-in.

## OS detection (to use in all templates)
- macOS: `{{ if eq .chezmoi.os "darwin" }}`
- Linux: `{{ else if eq .chezmoi.os "linux" }}`
- WSL2 (Linux sub-case): `{{ if (.chezmoi.kernel.osrelease | lower | contains "microsoft") }}`
- Debian (Linux sub-case): `{{ if eq .chezmoi.osRelease.id "debian" }}`
Define a custom `osid` variable in `.chezmoidata` or at the top of a template to simplify things:
`darwin` / `linux-wsl` / `linux-debian`.

---

## PHASE 0 — Pre-flight (read-only, no changes)
1. Detect the current OS (`uname -a`, read `/proc/sys/kernel/osrelease` if Linux).
2. Check for the presence of: `git`, `curl`, `mise`. List what is missing WITHOUT installing anything yet.
3. Check whether chezmoi is already initialized (`~/.local/share/chezmoi`). If so, run a
   `chezmoi diff` and stop to report before any write.
4. **STOP** — present the detected state + the install plan to the user. Wait for go-ahead.

## PHASE 1 — chezmoi bootstrap + repo structure
1. Install chezmoi if absent (`sh -c "$(curl -fsLS get.chezmoi.io)"`), otherwise use the existing one.
2. `chezmoi init` (create the source repo if new). Configure the GitLab remote if the user
   provides the URL (otherwise leave it local, ask for the URL in a single question).
3. Create the source state tree:
   ```
   ~/.local/share/chezmoi/
   ├── .chezmoi.toml.tmpl          # config + prompts (name, email, remote)
   ├── .chezmoidata.toml           # shared data (derived osid)
   ├── .chezmoiignore              # ignore by OS (e.g. Mac configs on WSL2)
   ├── .chezmoiscripts/
   │   ├── run_onchange_before_10-install-tools.sh.tmpl
   │   └── run_onchange_after_20-mise-install.sh.tmpl
   ├── dot_zshrc.tmpl              # shell: ordered sections, OS-templated (Phase 5bis)
   ├── dot_config/
   │   ├── starship.toml           # prompt, single file with no OS variation
   │   ├── wezterm/wezterm.lua.tmpl
   │   ├── zellij/config.kdl
   │   ├── zellij/layouts/agent.kdl.tmpl
   │   ├── helix/config.toml
   │   ├── helix/languages.toml
   │   ├── yazi/                   # keymap + init
   │   └── lazygit/config.yml
   └── dot_config/mise/config.toml # tool versions
   ```

## PHASE 2 — Toolchain installation (chezmoi script)
**Package management principle (settled cyber trade-off): NATIVE system manager per OS
for low-level building blocks, `mise` as the cross-OS layer for dev tools.**
NO Homebrew on the WSL2/Linux side (Ruby layer + third-party taps = enlarged attack surface, and
Linuxbrew is a second-class citizen). Homebrew stays only on macOS, its native platform.

In `run_onchange_before_10-install-tools.sh.tmpl`, branch by OS:
- **darwin**: `brew install wezterm zellij helix yazi lazygit mise zsh` (Apple Silicon, `/opt/homebrew`).
  Homebrew on macOS is legitimate (signature rollout via Sigstore underway).
- **linux-debian / linux-wsl**:
  1. System building blocks via **apt**: `zsh git curl build-essential` (packages verified by the
     GPG signature of the repo metadata, native Debian trust model).
  2. Dev tools via **mise**: install mise first, then `mise use -g` for zellij, helix, yazi,
     lazygit. mise downloads the projects' official binaries → identical versioning between OSes,
     no Homebrew-Linux dependency, and avoids the apt packages that are too old for these recent tools.
  3. WezTerm on the **Windows** side under WSL2 (see Phase 6) — DO NOT install it inside WSL.
- Make the script idempotent (test `command -v` before each install).
In `run_onchange_after_20-mise-install.sh.tmpl`: `mise install` to materialize
`dot_config/mise/config.toml` (a list shared between the two OSes for all of dev).

**ACTIVE mise provenance verification (ADR-0003, mandatory — this is the real surface)**:
commit `mise.lock` AND `mise settings lockfile=true` ⇒ checksums verified at install time (a lockfile
without active verification = decorative). The level-1 gate on the tools side tests that verification is *on*, not that
the file exists. **LSPs** are mise tools like any other (same cycle), never an ad-hoc
`curl|sh`.

### Security guardrail for third-party repos (Docker, HashiCorp, GitLab…)
If a third-party apt repo must be added (e.g. for Terraform via apt rather than mise):
- **NEVER** a key in the global keyring (`/etc/apt/trusted.gpg.d/` or `apt-key`, deprecated
  since Ubuntu 22.04). A global key = root of trust for ALL sources → if the third party's
  private key leaks, the attacker can bypass apt verification.
- **Correct pattern (2026)**: key in an INDIVIDUAL keyring under `/etc/apt/keyrings/<vendor>.gpg`,
  referenced via the `Signed-By:` option in the `.sources` file of that source only.
- Prefer `mise` when the tool is available there: avoids adding a third-party repo at all.

## PHASE 3 — WezTerm (emulator, OS template)
`wezterm.lua.tmpl`:
- Detect the OS via `wezterm.target_triple` on the Lua side AND via chezmoi for the injected values.
- Font: Hack Nerd Font (already installed). Size adjustable per OS.
- **Clipboard**: native WezTerm (handles OSC52), no pbcopy/clip.exe hack needed for copy.
- Launch Zellij automatically: `default_prog` →
  - darwin: `zellij`
  - wsl: from Windows, `wsl.exe -d <distro> -- zsh -lc zellij` (Phase 6).
- Theme consistent with Helix (e.g. Catppuccin). Disable the tab-close confirmation.

## PHASE 4 — Zellij (multiplexer, multi-agent core + VS Code-like binds)
`config.kdl`:
- Keep the hints status bar visible (a key argument for choosing Zellij: no muscle memory needed).
- **VS Code-style keybinds** (to be remapped cleanly, without breaking the Zellij defaults):
  - Toggle terminal/pane: a dedicated bind (equiv. VS Code's `Ctrl+` backtick).
  - Focus editor pane ↔ terminal: Alt+arrows navigation.
  - Toggle file tree: open Yazi in a **floating pane** (equiv. toggle explorer).
  - New pane in the current cwd (equiv. "open terminal here").
- `layouts/agent.kdl.tmpl`: multi-agent layout reproducing cmux:
  - main pane: Helix
  - floating pane: Yazi (mouse-driven file tree)
  - bottom pane: Claude Code agent
  - optional side pane: Lazygit
  - 1 tab = 1 task = 1 worktree = 1 agent.

## PHASE 5 — Helix + Yazi + Lazygit (editor & navigation)
`helix/config.toml`:
```toml
[editor]
line-number = "relative"
mouse = true                 # mouse as backup
true-color = true
color-modes = true
bufferline = "multiple"      # buffer tabs VS Code style
[editor.file-picker]
hidden = false
[editor.cursor-shape]
insert = "bar"
normal = "block"
select = "underline"
[editor.auto-save]
focus-lost = true
```
- `languages.toml`: LSP for Terraform (terraform-ls), Go (gopls), Python, Bash, YAML, Markdown
  (consistent with the user's IaC stack).
- **Yazi → Helix bridge**: configure Yazi to open the selected file in the Helix
  instance via Zellij (ENTER opens it in the editor pane). Document the known limit (Yazi starts
  in the launch cwd).
- `lazygit/config.yml`: matching theme, delta integration for diffs.

## PHASE 5bis — Shell (Zsh + Starship, migration from Oh-My-Zsh)
> PREREQUISITE: first run the separate shell audit plan (`PLAN_AUDIT_SHELL.md`) which produces
> the alias/function/plugin inventory. Integrate its results here before writing the `.zshrc`.

The shell layer = lives INSIDE each Zellij pane (does not interfere with WezTerm, Zellij or Helix).

`dot_zshrc.tmpl` structured into ordered sections:
1. **Exports / PATH** — OS-templated:
   - darwin: `eval "$(/opt/homebrew/bin/brew shellenv)"`
   - linux: no brew; mise PATH + ~/.local/bin
2. **Tool init**: `eval "$(mise activate zsh)"`, completions.
3. **Plugin sourcing** (independent repos, NO need for OMZ) — order matters:
   - `zsh-autosuggestions`
   - `zsh-syntax-highlighting` **always LAST** (otherwise highlighting breaks)
4. **Prompt**: `eval "$(starship init zsh)"` **dead last** (overwrites any residual theme).
5. **Custom alias/function block**: copied VERBATIM from the audit ("mine" section).
6. **Missed OMZ aliases**: only those confirmed used by the audit (history cross-check),
   redefined by hand (e.g. those of the OMZ git plugin: gst/gco/gp… if actually typed).

`dot_config/starship.toml`: single file, no OS variation. Migrate the existing Starship config.

**Decision ALREADY SETTLED by ADR-0003 (do NOT reopen the question)**: native Zsh + **vendored
plugins cloned and pinned to a SHA** (`zsh-plugins.lock`), zero plugin manager. OMZ **and** antidote
are ruled out (opaque updates / surface). Any reconsideration = superseding ADR-0003, not a prompt.

Install in a `run_once_` script:
- clone `zsh-autosuggestions` and `zsh-syntax-highlighting` at the lockfile SHAs (no `git pull`).
- verify the SHA after cloning (cf. the ADR-0003 Verification block); drift → STOP.
- abbreviation completion via a few hand-written `compdef`s.

**Post-migration verification (safety net, in the script or as a manual check)**:
```sh
# compare the old OMZ world to the new one
diff <(sort ~/omz-snapshot-aliases.txt) <(sort ~/native-aliases.txt)
```
The diff should contain only the OMZ aliases deliberately dropped. STOP and report otherwise.

## PHASE 6 — WSL2-specific (the critical portability point)
- WezTerm runs **on the Windows side** (installed via winget: `winget install wez.wezterm`), not in WSL.
  It launches the WSL shell → Helix/Zellij run inside the Linux. (Replaces VS Code's Remote-WSL.)
- **Explicit seam (ADR-0008)**: the Windows WezTerm config (`wezterm.lua` on the Windows side) is
  **outside the chezmoi-WSL context** (chezmoi only manages the Linux `$HOME`). Decided: the Windows
  WezTerm config is **out of chezmoi scope**, documented in the RUNBOOK; chezmoi manages WezTerm on
  **macOS** only; the `.lua` is factored out (a shared template copied manually on the Windows side). Do not
  claim "identical emulator config across 2 OSes".
- Verify Windows↔WSL clipboard access (WezTerm OSC52 handles it; otherwise fall back to `clip.exe`/`win32yank`).
- Nerd Font: already resolved on the user's side (cross-WSL/Windows installation OK).
- `.chezmoiignore`: ignore Windows-only files when applying on the Linux side, and vice versa.
- Detect WSL in scripts via `.chezmoi.kernel.osrelease | lower | contains "microsoft"`.

## PHASE 7 — Claude Code agent integration (Zellij notifications)
- Configure the Claude Code hooks (`~/.claude/settings.json`, itself managed by chezmoi as
  `dot_claude/settings.json.tmpl`):
  - `Notification` → `zellij action rename-tab` with a "WAITING" marker (equiv. the cmux ring).
  - `Stop` → rename to "DONE".
- Provide a `newagent <task>` script (in `dot_local/bin/`): creates a git worktree + a Zellij
  tab loaded with `layouts/agent.kdl`, launches `claude`. And `delagent` for cleanup
  (`git worktree remove`).

## PHASE 7bis — Decision documentation (ADR) & threat model
> The ADRs and the threat model are PROVIDED (see the `dotfiles/docs/` folder). Claude Code
> copies them into the source state, does not regenerate them, and keeps them up to date if a choice changes.
- Copy `docs/adr/*` (0000→0008 + `_template.md` + `README.md`), `docs/THREAT-MODEL.md` and
  `docs/RUNBOOK.md` into the chezmoi source state under `docs/`.
- Permanent rule: any new/modified technical decision ⇒ an ADR (extended MADR) or a
  superseding. The `security-relevant` ADRs reference the THREAT-MODEL IDs.
- ADR lint (integrated into the audit): every `security-relevant: true` ADR must have the 4 custom
  fields non-empty (Threats / Residual surface / Review / Verification).

## PHASE 7ter — Per-layer security (implementing the cyber report)
> Actionable summary. For EACH choice: risks → mitigations (complexity) → applied recommendation.
> Full detail and justifications in the referenced ADRs.

### Layer 1 — Shell & plugins (ADR-0003; threats T-SC-01..05, T-CR-01)
- **Risk**: a plugin sourced at startup = RCE-by-design; exfiltration of AWS/SSH/TF credentials.
- **Mitigations**:
  - SHA pin + `zsh-plugins.lock` lockfile — complexity LOW — **APPLIED** (blocks stealth updates).
  - Manual bump ritual (diff/soak/signed tag) — complexity MEDIUM — **APPLIED** (RUNBOOK).
  - Scripted deterministic gates (cross-witness) — complexity MEDIUM — **DEFERRED level 2** (ADR-0006).
  - GPG signature of tags — complexity LOW — **APPLIED** (TOFU first time).
- **Context recommendation**: minimal surface (2 plugins); never reintroduce OMZ/antidote (opaque updates).

### Layer 2 — Tools & packages (ADR-0002 routing, ADR-0003 trust; threats T-SC-06..08, T-CR-02)
- **Risk**: global apt key = verification bypass for all sources; tampered mise/LSP binary; committed secret.
- **Mitigations**:
  - native apt (Linux) + brew (macOS) + mise (dev+LSP), single source per tool — LOW — **APPLIED**.
  - individual keyrings `/etc/apt/keyrings/` + `Signed-By:` — LOW — **APPLIED** (mandatory).
  - `mise.lock` + `lockfile=true` ⇒ checksums verified at install — MEDIUM — **APPLIED** (T-SC-08 residual on trojanized release).
  - gitleaks pre-commit + CI — LOW — **APPLIED**.
- **Context recommendation**: LSP = mise tools like any other (same ADR-0003 cycle); settle duplicates → mise only.

### Layer 3 — AI agents (ADR-0004; threats T-AG-01..04)
- **Risk**: prompt injection → exfil; compromised MCP; hook eval of LLM output; infra destruction.
- **Mitigations**:
  - Claude Code deny/ask/allow permissions (secrets in deny) — LOW — **APPLIED**.
  - OS sandbox (Seatbelt macOS / bubblewrap+socat Linux) — MEDIUM — **APPLIED**.
  - MCPs allowlisted + pinned + reviewed like a dependency — MEDIUM — **APPLIED**.
  - Hooks with fixed commands only (never an eval of model content) — LOW — **APPLIED**.
  - Isolation 1 agent = 1 worktree — LOW — **APPLIED**.
- **Context recommendation**: immediate review on every MCP addition; never enable
  `--dangerously-skip-permissions` outside a disposable container.

## PHASE 7quater — Recurring audit pipeline (ADR-0007) — LEVEL 2, DEFERRED
> **Level 1 (baseline) = only `gitleaks` pre-commit + CI.** The full pipeline below
> (scripted gates, cross-witness) is the **level-2 target**, built only upon crossing
> the ADR-0006 criterion. Do not build it up front. Same script pre-commit (warn) and CI (blocking).
- Create `audit/run.sh --mode {pre-commit|ci}` which orchestrates:
  - `audit/scan/`: gitleaks/regex secrets, heuristic scan of plugin diffs.
  - `audit/gates/`: SHA==lockfile, soak time, `git tag -v`, cross-witness tree-hash,
    Brewfile/mise drift, no global apt key, Claude deny secrets, MCP ∈ allowlist, ADR lint.
- **pre-commit** (chezmoi `run_once_` hook installs the hook): "cheap" checks, **never fails**,
  prints warnings. Bypassable by design (`--no-verify`).
- **CI** (`.gitlab-ci.yml` in the dotfiles repo): full audit, **fails** if a blocking gate is red.
  Source of truth: nothing on `main` with a red gate.
- Full matrix of checks (pre-commit vs CI, warn vs blocking): see ADR-0007.
- On each run: evaluate the **Nix switch-over criterion** (ADR-0006, counter of conditions ≥ 2).

## PHASE 8 — Verification & commit
1. `chezmoi diff` then `chezmoi apply` (in plan mode: show the diff before apply).
2. Dry run: launch WezTerm → Zellij → agent layout → open Helix + Yazi + Lazygit.
2bis. **Scriptable fresh-machine smoke test**: a `doctor.sh` checks that binaries are present, plugin
   SHAs == lockfile, mise provenance verification is active, the agent sandbox actually runs
   (ADR-0004), Claude deny secrets are present. It is the "it really works" net, not the eyeball.
   `doctor.sh` detail: RUNBOOK.
2ter. **Documented rollback (ADR-0006)**: the RUNBOOK covers `git revert` of the source state + apply, and the
   case of an apply broken mid-course (idempotent scripts, snapshot of critical configs before a bump).
3. Level 1: `gitleaks` + cheap checks. (Full CI / scripted gates = deferred level 2, ADR-0003/0007.)
4. Verify that the VS Code-like binds respond.
5. `chezmoi cd && git add -A && git commit` — **STOP before push** (push set to `ask`, human approval).
   Forge = GitLab, MR + CI model with a trunk exit gate (ADR-0007).
6. Produce a README in the repo: one-liner install command for a new machine
   (`sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply <user>/<repo>`), and the list of binds.
7. The `docs/adr/` and `docs/THREAT-MODEL.md` are versioned in the repo (already provided).

---

## Guardrails for Claude Code
- Any file targeting `~` must be created/edited **in the chezmoi source state**, never directly.
- Before any `apply`, show `chezmoi diff`. Do not apply without approval in plan mode.
- `git push` and any network install command: in `ask` mode.
- Idempotence mandatory: each script tests the existing state before acting.
- If a binary is not available on an OS (e.g. WezTerm in WSL), do not install it on the Linux side;
  document the Windows procedure instead.
- **Secrets & creds (ADR-0005)**: static secrets via **Bitwarden CLI** (`*.tmpl` templates
  `{{ (bitwarden ...) }}`, rendered at `apply`, never committed, IDs-only in git); **AWS access via
  SSO/granted, zero static key**. Bootstrap: `bw unlock` BEFORE the first apply (cold-start order:
  RUNBOOK). NEVER commit a cleartext secret.
