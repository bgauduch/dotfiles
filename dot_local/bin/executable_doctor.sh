#!/usr/bin/env bash
# doctor.sh — non-destructive smoke-test that the environment is actually wired
# (PLAN Phase 8 / RUNBOOK). It's the "it really works" net, not the eye.
# Exits non-zero if a hard check (FAIL) fails; WARN is advisory.
set -uo pipefail

fail=0
ok()   { printf '  \033[32mOK\033[0m   %s\n' "$1"; }
warn() { printf '  \033[33mWARN\033[0m %s\n' "$1"; }
bad()  { printf '  \033[31mFAIL\033[0m %s\n' "$1"; fail=1; }
have() { command -v "$1" >/dev/null 2>&1; }

echo "== binaries =="
for b in zsh git mise zellij helix yazi lazygit starship; do
  have "$b" && ok "$b" || bad "$b missing"
done
if [ "$(uname)" = Darwin ]; then
  have wezterm && ok wezterm || warn "wezterm missing (brew cask)"
fi

echo "== mise provenance verification (ADR-0003) =="
if have mise; then
  mise settings 2>/dev/null | grep -q 'lockfile = true' \
    && ok "mise lockfile=true (checksums verified)" \
    || bad "mise lockfile verification OFF"
fi

echo "== zsh plugins pinned (ADR-0003) =="
lock=""; have chezmoi && lock="$(chezmoi source-path)/zsh-plugins.lock"
dir="$HOME/.local/share/zsh/plugins"
if [ -n "$lock" ] && [ -f "$lock" ]; then
  while read -r name _url sha _tag _; do
    case "$name" in ""|\#*) continue ;; esac
    if [ -d "$dir/$name/.git" ]; then
      head="$(git -C "$dir/$name" rev-parse HEAD)"
      if   [ "$sha" = PIN_ME ];   then warn "$name not pinned (PIN_ME -> $head)"
      elif [ "$head" = "$sha" ];  then ok "$name @ $sha"
      else bad "$name drift ($head != $sha)"; fi
    else warn "$name not installed"; fi
  done < "$lock"
else
  warn "zsh-plugins.lock not found"
fi

echo "== Claude Code deny rules (ADR-0004) =="
grep -q 'Read(.env' "$HOME/.claude/settings.json" 2>/dev/null \
  && ok "deny secrets present" || bad "deny secrets missing"

echo "== agent sandbox (ADR-0004) =="
if [ "$(uname)" = Darwin ]; then
  have sandbox-exec && ok "Seatbelt available" || warn "sandbox-exec missing"
else
  have bwrap && ok "bubblewrap available" \
    || warn "bubblewrap (bwrap) missing — agent sandbox is aspirational until installed"
fi

echo "== no committed secrets (ADR-0007 level 1) =="
if have gitleaks && have chezmoi; then
  ( cd "$(chezmoi source-path)" && gitleaks detect --no-banner -q ) \
    && ok "gitleaks clean" || bad "gitleaks found potential secrets"
else
  warn "gitleaks not installed — skipping secret scan"
fi

echo
[ "$fail" -eq 0 ] && echo "doctor: PASS" || echo "doctor: FAIL"
exit "$fail"
