---
status: accepted
date: 2026-06-28
decision-makers: [Baptiste]
security-relevant: true
review-by: 2027-01-28
supersedes: []
---

# ADR-0004 — AI agent security (Claude Code, MCP, hooks)

## Context and problem statement
The environment hosts AI agents (Claude Code, multiple instances via Zellij/worktrees, MCP
servers, shell hooks), in the same shell as my Cloud/IaC credentials, with the ability to run
commands. Specific risks: prompt injection → exfiltration, malicious/compromised MCP server,
hooks running arbitrary code, reading `.env`/secrets. The 2026 node-ipc payload targeted the
Claude/Kiro configs — AI agents are a named target.

## Decision drivers
- Limit what an agent (or an injection driving it) can do to my credentials.
- Keep useful autonomy without opening an RCE.
- Traceability of actions, **without creating a confidentiality liability** on client code.

## Considered options
- Option A — Full trust (`--dangerously-skip-permissions`): rejected.
- Option B — allow/deny/ask permissions, without OS isolation.
- Option C — **Calibrated permissions + OS sandbox + allowlisted/pinned MCP + audited hooks.**

## Decision
**Option C**, in layers (operational commands/profiles → RUNBOOK):
1. **Claude Code permissions** (`~/.claude/settings.json`, managed by chezmoi): `deny` on the
   irreversible and on secrets (`Read(.env*)`, `Read(secrets/**)`, `rm -rf`, `git push --force`,
   `terraform destroy`); `ask` on `git push`, `terraform apply`, `aws`; `allow` on read/lint/
   test. First match wins: deny > ask > allow.
2. **OS sandbox**: Seatbelt (macOS) / bubblewrap+socat (Linux/WSL2) — a safety net if an injection gets through.
   **Viability must be proven at startup** (see residual surface), not asserted.
3. **MCP servers**: explicit allowlist, pinned, treated as a **dependency** (the trust
   cycle of ADR-0003). No arbitrary MCP without a lockfile entry.
4. **Hooks**: Claude Code → Zellij hooks only run **fixed** local commands
   (rename-tab), never content derived from the model. Audited in config review.
5. **Per-worktree isolation**: 1 agent = 1 worktree = 1 branch.
6. **Traceability + split personal/client retention.** We rely on native transcripts
   (`~/.claude/projects/`) — no custom logging. **BUT** these transcripts contain the client
   code read by the agent: a **split** retention policy — client context = **purge** (never
   archived off-machine), personal context = **may be kept**. This avoids turning traceability into
   a confidentiality liability.
7. **Agent use on client code = subject to contract.** Sending client code through
   an AI agent (→ a third-party provider) is only started **if the contract/DPA allows it**. Otherwise:
   partitioning (no agent on client code). A business decision outside this corpus, decided by me.

## Consequences
- Good: limited blast radius; secrets out of reach by default; sandbox as a safety net; no
  transcript liability on the client side.
- Bad: the Linux sandbox needs bubblewrap+socat (install); a few `ask` prompts remain;
  client partitioning = reduced autonomy on those contexts (accepted).

## Threats addressed
- **T-CR-01** (credential exfiltration via hook plugin): deny `Read(.env*)`/`secrets/**` + sandbox (jointly with ADR-0003).
- **T-AG-01** (prompt injection → exfiltration): deny secrets + sandbox.
- **T-AG-02** (malicious/compromised MCP): allowlist + pinning + review (ADR-0003).
- **T-AG-03** (hook running model content): fixed-command hooks.
- **T-AG-04** (infra destruction: terraform destroy / push force): deny + ask.

## Residual attack surface
- An injection acts within the **permitted** scope (modifying code in the current worktree) — the
  sandbox limits the OS, not the permitted logic.
- **Sandbox to be proven**: bubblewrap/WSL2 (user namespaces) and Seatbelt (`sandbox-exec` deprecated)
  are fragile; `doctor.sh` confirms it is running, otherwise the safety net is aspirational.
- Binaries/MCP called by the agent share the trust of **ADR-0003**.
- Exfiltration through an **authorized** channel (an approved `git push`) is not eliminated.

## Review / expiry
Reviewed every six months (the ecosystem moves fast); immediate review on each MCP server addition.

## Verification
```sh
grep -q 'Read(.env' ~/.claude/settings.json && echo OK || echo "MISSING deny secrets"
command -v bwrap >/dev/null 2>&1 || [ "$(uname)" = Darwin ] || echo "Linux sandbox unavailable"
```
