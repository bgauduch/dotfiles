#!/usr/bin/env bash
# From-zero live demo: a bare browser VS Code (code-server) in a throwaway container.
# Open http://localhost:8080, then in the integrated terminal run the chezmoi one-liner
# and watch the env build from an empty machine (see demo/README.md). Every run is --rm.
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
img="dotfiles-demo-vscode"

docker build -t "${img}" -f "${repo_root}/demo/Dockerfile.vscode" "${repo_root}/demo"
echo "code-server → http://localhost:8080  (Ctrl-C stops the --rm container)"
exec docker run --rm -it -p 127.0.0.1:8080:8080 "${img}"
