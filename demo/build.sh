#!/usr/bin/env bash
# Build the demo sandbox = the project's integration-test image (clean chezmoi
# init --apply at build). Run from anywhere; uses the repo root. Extra args are
# passed to docker build (e.g. --no-cache).
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
exec docker build -t dotfiles-demo -f "${repo_root}/Dockerfile" "$@" "${repo_root}"
