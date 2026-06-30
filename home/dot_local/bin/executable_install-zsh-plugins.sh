#!/usr/bin/env bash
# Clone/verify vendored zsh plugins at the SHAs pinned in zsh-plugins.lock
# (ADR-0003). Idempotent & re-runnable; the bump ritual lives in the RUNBOOK.
#
# SHA == "PIN_ME": first-time TOFU — checkout the tag, print the resolved SHA to
# pin (does NOT fail), so a fresh machine bootstraps and you commit the SHA.
# SHA set: checkout it; any drift between HEAD and the pin hard-stops.
set -euo pipefail

have() { command -v "$1" >/dev/null 2>&1; }
dest="${HOME}/.local/share/zsh/plugins"
mkdir -p "${dest}"

# The lockfile lives in the chezmoi source (not deployed into $HOME).
if [ -n "${ZSH_PLUGINS_LOCK:-}" ]; then
  lock="${ZSH_PLUGINS_LOCK}"
elif have chezmoi; then
  lock="$(chezmoi source-path)/zsh-plugins.lock"
else
  lock=""
fi
if [ -z "${lock}" ] || [ ! -f "${lock}" ]; then
  echo "zsh-plugins.lock not found (set ZSH_PLUGINS_LOCK or install chezmoi)" >&2
  exit 1
fi

while read -r name url sha tag _rest; do
  case "${name}" in ""|\#*) continue ;; esac
  repo="${dest}/${name}"
  if [ ! -d "${repo}/.git" ]; then
    echo "==> cloning ${name}"
    git clone --quiet "${url}" "${repo}"
  fi
  git -C "${repo}" fetch --quiet --tags origin
  if [ "${sha}" = "PIN_ME" ]; then
    git -C "${repo}" checkout --quiet "${tag}"
    resolved="$(git -C "${repo}" rev-parse HEAD)"
    echo "WARN: ${name} not pinned. Resolved ${tag} -> ${resolved}"
    echo "      Pin it: replace PIN_ME with this SHA in zsh-plugins.lock (RUNBOOK)."
  else
    git -C "${repo}" checkout --quiet "${sha}"
    head="$(git -C "${repo}" rev-parse HEAD)"
    if [ "${head}" != "${sha}" ]; then
      echo "DRIFT: ${name} HEAD ${head} != pinned ${sha} — STOP" >&2
      exit 1
    fi
    echo "OK: ${name} @ ${sha}"
  fi
done < "${lock}"
