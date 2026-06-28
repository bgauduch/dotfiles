# PLAN — Shell audit (Oh-My-Zsh → native Zsh)

> **Prerequisite for Phase 5bis** (PLAN_SETUP_TUI). Run **on the real machine**
> before filling in sections 5 and 6 of `dot_zshrc.tmpl`. Cannot run in the
> cloud container (needs the user's `~/.zshrc`, `~/.oh-my-zsh` and history).

## Goal
Inventory what is actually used in the current Oh-My-Zsh setup, so we port **only** the useful
aliases/functions/plugins to the native `.zshrc` — not all of OMZ. The decision is already
made (ADR-0003): native Zsh + 2 vendored, pinned plugins, no plugin manager.

## Procedure

### 1. Snapshot of the current state
```sh
# Aliases and functions actually loaded in the current shell
alias | sort > ~/omz-snapshot-aliases.txt
print -l ${(k)functions} | sort > ~/omz-snapshot-functions.txt
# Enabled OMZ plugins
grep -E '^\s*plugins=' ~/.zshrc > ~/omz-plugins.txt || true
```

### 2. Cross-check against real usage (history)
```sh
# Most-typed commands — to learn which OMZ aliases are really used
fc -l 1 | awk '{print $2}' | sort | uniq -c | sort -rn | head -50 > ~/omz-usage.txt
```
Cross-reference `omz-usage.txt` with `omz-snapshot-aliases.txt`: keep only the OMZ aliases
(e.g. the git plugin: `gst`/`gco`/`gp`…) that actually appear in the history.

### 3. Separate "mine" vs "provided by OMZ"
- **"Mine"** block: aliases/functions defined by the user in `~/.zshrc`/`~/.zsh/` →
  copied **verbatim** into section 5 of `dot_zshrc.tmpl`.
- **OMZ-missed** block: only the OMZ aliases confirmed in step 2 → **redefined by hand**
  in section 6 (do NOT reintroduce OMZ).

### 4. Integration
Fill in sections 5 and 6 of `dot_zshrc.tmpl`, then `chezmoi apply`.

### 5. Safety net (post-migration check)
```sh
alias | sort > ~/native-aliases.txt
diff <(sort ~/omz-snapshot-aliases.txt) <(sort ~/native-aliases.txt)
```
The diff should only contain OMZ aliases that were **deliberately dropped**. Otherwise: STOP,
complete section 6, start over.

## Expected output
- Sections 5 and 6 of `dot_zshrc.tmpl` filled in.
- `~/omz-snapshot-*.txt` kept for the duration of the migration (disposable afterward).
