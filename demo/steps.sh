#!/usr/bin/env bash
# Guided tour of chezmoi (source state → templates → profiles → bootstrap → secrets).
# Run INSIDE the sandbox container:
#   bash ~/.local/share/chezmoi/demo/steps.sh
# Press Enter to advance between steps. Each step prints the matching chezmoi doc page.
set -uo pipefail

src="$(chezmoi source-path)"
demo="$(dirname "$src")/demo"   # repo-root/demo, above .chezmoiroot (never deployed)
pause() { printf '\n\033[2m— Enter —\033[0m'; read -r _ || true; printf '\n'; }
say()   { printf '\n\033[1;36m# %s\033[0m\n' "$*"; }
run()   { printf '\033[2m$ %s\033[0m\n' "$*"; eval "$*"; }
doc()   { printf '\033[2m  ↳ doc: %s\033[0m\n' "$*"; }

say "Mental model: \$HOME = target, the repo = source. The source state path:"
run 'chezmoi source-path'
doc 'https://www.chezmoi.io/reference/target-types'; pause

say "A. dot_ entries in the source map to ~/. :"
run "ls -A '$src' | head"; pause

say "A. Capture a real dotfile into the source state:"
run 'git config --global user.name "Demo User"'
run 'git config --global user.email "demo@example.com"'
run 'chezmoi add ~/.gitconfig'
run 'chezmoi source-path ~/.gitconfig'
doc 'https://www.chezmoi.io/user-guide/manage-machine-to-machine-differences'; pause

say "B. Templates: ONE file, per-OS branches (WezTerm config):"
run "grep -n 'chezmoi.os' '$src/dot_config/wezterm/wezterm.lua.tmpl'"; pause
say "B. The data driving the render (this machine):"
run "chezmoi execute-template '{{ .chezmoi.os }} / {{ .osid }} / {{ .profile }}'; echo"; pause
say "B. Rendered output here (macOS would render the darwin branch):"
run 'chezmoi cat ~/.config/wezterm/wezterm.lua | head'
doc 'https://www.chezmoi.io/user-guide/templating'; pause

say "C. Profiles: a 'work' machine gets extra tools, gated in the mise template:"
run "grep -n -A5 'profile \"work\"' '$src/dot_config/mise/config.toml.tmpl'"
doc 'https://www.chezmoi.io/reference/special-files/chezmoidata-format'; pause

say "D. Bootstrap scripts ran at init --apply (apt + mise), idempotent:"
run "ls '$src/.chezmoiscripts'"; pause
say "D. Smoke test:"
run 'doctor.sh || true'
doc 'https://www.chezmoi.io/user-guide/use-scripts-to-perform-actions'; pause

say "E. Secrets: only the Bitwarden item reference is in git — never the value:"
run "sed -n '1,8p' '$demo/secret.env.tmpl'"; pause
say "E. Render it (sandbox injects a stub via \$DEMO_SECRET; prod resolves via Bitwarden):"
run "DEMO_SECRET='s4ndb0x-stub-token' chezmoi execute-template < '$demo/secret.env.tmpl'"
doc 'https://www.chezmoi.io/user-guide/password-managers/bitwarden'; pause
say "E. Proof no secret is committed:"
run "grep -rIn 's4ndb0x-stub-token' '$src' 2>/dev/null || echo 'stub lives only at render time — nothing in git'"; pause

say "Done. Env as code: source state → templates → profiles → bootstrap → secrets."
