---
status: accepted
date: 2026-06-28
decision-makers: [Baptiste]
security-relevant: true
review-by: trigger:doctrine-change
supersedes: []
---

# ADR-0002 — Tooling & packages doctrine (where things go, inventory)

> **Doctrine** ADR: it does NOT record the list of tools (moving state, cf ADR-0000), but the
> **durable rules** that decide *which manager installs what* and *what gets reinstalled on a
> fresh machine*. The trust/provenance of dependencies (pin, lock, soak) belongs to ADR-0003;
> this ADR only covers routing and inventory. The list lives in the versioned config files
> (`Brewfile.tmpl`, `mise.toml`, `zsh-plugins.lock`).

## Context and problem statement
Without a stable rule, the inventory drifts: one-off trials reinstalled "by default", the same
tool duplicated across two managers, dependencies executed at startup added without control. We
need a doctrine that survives changes to the list, on macOS + WSL2/Debian.

## Decision drivers
- Minimal attack surface and a clean inventory.
- Single source per tool (no duplicate across managers).
- Aligned cross-OS versioning for runtimes.
- Separate "durable decision" (this ADR) from "list" (config files).

## Decision: doctrine

1. **Single source per tool.** A tool = a single manager, never two. Per-project pinnable runtimes
   → **mise**; system building blocks → the OS's native manager (**apt** on Linux, **brew** on
   macOS, including casks for GUI apps).

2. **Routing a new tool:**
   - Pinnable dev runtime/tool (including LSP servers) → **mise** + a `mise.lock` entry.
   - Linux system tool → **apt**; third-party repo only if necessary, and then an **individual
     keyring + `Signed-By:`** (never a global key, cf safeguard below).
   - macOS tool / app → **brew** (formula or cask), declared in `Brewfile.tmpl`.

3. **Intentional inventory.** The tools that are declared (and therefore auto-reinstalled on a
   fresh machine) are those of **recurring** use (daily core, infra, CI/lint actually used).
   Tools **tried occasionally** are NOT declared: installable on demand. Goal: not a graveyard
   of trials.

4. **Passive tools** (prompt, completions, libs, build deps): judged **by role, not by usage
   count**; not removed solely on the criterion of a low number of occurrences.

5. **Shell security boundary.** Any dependency **executed at shell startup** (plugin, hook)
   belongs to ADR-0003 (trust/pin/soak), not to this doctrine. Likewise for the provenance of
   binaries.

6. **GUIs outside the shell scope**: not covered on the shell side; those exposing a CLI already
   on the PATH have nothing to carry.

### Third-party apt repository safeguard (mandatory)
A third-party repo adds its key as an **individual keyring** `/etc/apt/keyrings/<vendor>.gpg` +
`Signed-By:` in the `.sources`. **Never** `apt-key` nor the global `/etc/apt/trusted.gpg.d/`
(deprecated since Ubuntu 22.04, breaks isolation: a third-party key would sign for the whole
system).

## Consequences
- Good: a stable doctrine that does not expire when the list changes; minimal inventory;
  duplicates excluded by construction; a clean boundary with dependency security (ADR-0003).
- Bad: an "on demand" tool will have to be reinstalled when needed again (minor accepted cost).

## Threats addressed
- **T-SC-06** (bypass of apt verification via a global key): individual keyring + `Signed-By:`.
- **T-SC-07** (outdated package with a CVE): up-to-date source via the native manager, reviewed
  inventory.

## Residual attack surface
- The *trust* in the installed binaries (provenance, tampering on download) is NOT handled here
  → ADR-0003.

## Review / expiry
`trigger:doctrine-change` — review only if the doctrine evolves (a 3rd manager, a switch to Nix).
Changing the tool *list* does NOT trigger a review.

## Governed state files (outside ADR)
- `Brewfile.tmpl` — macOS inventory. `mise.toml` — runtimes + LSP + versions.
- `zsh-plugins.lock` — plugins (trust governed by ADR-0003).

## Verification
```sh
# apt safeguard (Linux): third-party repos in an individual keyring + Signed-By, never a global key
if [ -d /etc/apt ]; then
  test -d /etc/apt/keyrings && echo "OK: individual keyrings" || echo "CHECK: /etc/apt/keyrings missing"
  ! ls /etc/apt/trusted.gpg.d/*.asc /etc/apt/trusted.gpg.d/*.gpg >/dev/null 2>&1 \
    && echo "OK: no global third-party key" || echo "CHECK: key in global trusted.gpg.d"
else
  echo "macOS: apt N/A (brew routing, cf doctrine)"
fi
```
