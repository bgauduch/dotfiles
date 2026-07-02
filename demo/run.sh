#!/usr/bin/env bash
# Launch a fresh sandbox container and drop into the ready environment (login zsh).
# --rm => every run is a clean reset. Image name overridable as $1.
set -euo pipefail
img="${1:-dotfiles-demo}"
if ! docker image inspect "${img}" >/dev/null 2>&1; then
  echo "Image '${img}' not found — run ./demo/build.sh first." >&2
  exit 1
fi
exec docker run --rm -it "${img}" zsh -l
