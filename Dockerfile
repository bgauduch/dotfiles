# Full isolated installation test (ADR-0009 / PLAN Phase 8).
# Building this image performs a clean `chezmoi init --apply` exactly as on a
# fresh Linux machine (apt bricks + mise bootstrap + dev tools + configs + zsh
# plugins), then asserts the core binaries and runs doctor.sh. A successful build
# == the install works end to end. Reproduce locally with `make integration-test`.
FROM debian:bookworm-slim

ARG USER=dev
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      git curl ca-certificates sudo unzip build-essential \
 && rm -rf /var/lib/apt/lists/* \
 && useradd -m -s /bin/bash "${USER}" \
 && echo "${USER} ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/${USER}"

USER ${USER}
WORKDIR /home/${USER}
ENV PATH="/home/${USER}/.local/bin:/home/${USER}/.local/share/mise/shims:${PATH}"

# Bring the dotfiles in as the chezmoi source state.
COPY --chown=${USER}:${USER} . /home/${USER}/.local/share/chezmoi

# Install chezmoi, then init + apply non-interactively (prompts via env vars).
ENV CHEZMOI_NAME="CI User" \
    CHEZMOI_EMAIL="ci@example.com"
RUN sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "${HOME}/.local/bin" \
 && chezmoi init --apply --source="${HOME}/.local/share/chezmoi"

# Assert the core stack is installed, then run the smoke-test (informational).
RUN for b in zsh mise zellij hx yazi lazygit starship; do \
      command -v "$b" >/dev/null || { echo "MISSING binary: $b"; exit 1; }; \
    done \
 && doctor.sh || true
