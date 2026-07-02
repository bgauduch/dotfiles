---
status: accepted
date: 2026-06-28
decision-makers: [Baptiste]
consulted: []
informed: []
---

# ADR-0000 — ADR process and format

> "Meta" ADR: it does not describe a technical choice in the setup, but **how decisions are
> recorded** in this repository. Repository conventions (language, secrets, templating, structure)
> live in [`../conventions.md`](../conventions.md). Read this first.

## Context and problem statement

This repository manages a portable development environment (macOS + WSL2/Debian) via chezmoi:
shell (native Zsh), multiplexer (Zellij), editor (Helix), terminal emulator (WezTerm), tooling
(apt/brew + mise), and AI agents (Claude Code, MCP, hooks). The structural decisions touch on
supply-chain security and must stay traceable over time: why a plugin is pinned to a given SHA,
why apt rather than Homebrew on Linux, why a given level of immutability. Without traceability,
these choices become folklore and nobody (you included, six months from now) knows whether they
are still valid.

**Decision: adopt MADR (Markdown Any Decision Records) extended with 4 fields specific to our
shell/tooling/security context.**

## Decision: ADR format = extended MADR

Standard MADR covers: context, decision drivers, considered options, issue/decision,
consequences (good/bad), confirmation. That is enough for classic architecture decisions, but it
lacks slots for what is central in a supply-chain-oriented setup. So we add 4 custom fields
(optional for non-security ADRs, mandatory for ADRs marked `security-relevant: true` in the
front-matter):

| Added field | Role | Why standard MADR is not enough |
|---|---|---|
| **Threats addressed** | list the attack scenarios the decision counters (ref. threat model) | MADR has no explicit decision → threat link |
| **Residual attack surface** | what the decision does NOT protect against (honesty) | avoid a false sense of security |
| **Review / expiry** | date or trigger for a mandatory re-review | a security decision expires; MADR is timeless |
| **Verification** | concrete command/procedure that proves the decision is in force | make the decision testable, not declarative |

Extended front-matter for each ADR:
```yaml
---
status: proposed | accepted | rejected | deprecated | superseded by ADR-XXXX
date: YYYY-MM-DD
decision-makers: [...]
security-relevant: true | false     # if true, the 4 custom fields are mandatory
review-by: YYYY-MM-DD | trigger:<event>   # e.g. trigger:bump-plugin
supersedes: [ADR-XXXX]              # optional
---
```

### Why not plain Nygard
Nygard (context / decision / consequences) is lighter but has neither compared options nor
security fields. For decisions where the "why not the other option" is the core of the value
(apt vs brew, vendored vs package-manager, pin-SHA vs latest), losing the "considered options"
column impoverishes the record. Extended MADR is the right compromise.

## Decision: ADR granularity

Four types of ADR, marked in the *Type* column of the README:
- **meta**: does not record a technical choice in the setup but the decision *process* itself
  (this ADR-0000). Only one expected.
- **doctrine**: a durable cross-cutting rule that applies to several topics (e.g. package routing
  ADR-0002, trust cycle ADR-0003). Avoids repeating the same rule per topic.
- **granular**: one structural choice = one file (see below).
- **grouped**: a family of coherent choices = one file (see below).

- **Granular ADR (1 decision = 1 file)** for structural choices: package management, plugin
  model, immutability, AI agents, audit pipeline. These are the decisions with strong "why" and
  security consequences.
- **Grouped ADR (1 file = a family of choices)** for lists: tool inventory (Brewfile), mise
  runtimes, plugin list. The "why" is shared; detailing each tool in a separate ADR would be
  noise. The detail lives in the config file (Brewfile, mise.toml, zsh-plugins.lock); the grouped
  ADR carries the *policy* (inclusion/exclusion criteria).

## ADR conventions
- **A new or modified technical decision ⇒ an ADR** (or update of an existing one via
  `status: superseded by`). No untracked structural choice.
- **Durable decision vs moving state.** An ADR records a **durable structural decision** (a
  choice, a doctrine, a principle that survives over time). A **moving state** — tool list,
  versions, inventory, whatever changes from project to project — does NOT go in an ADR: it lives
  in a **versioned config file** (`Brewfile`, `mise.toml`, `zsh-plugins.lock`), self-documenting,
  and the ADR only references it. Discrimination rule: *choosing Helix = decision (ADR); listing
  the 40 installed tools = state (config file)*. Recording a state in an ADR makes it expire at
  the first modification and pollutes the decision history with maintenance noise.
- **Numbering**: `NNNN-title-kebab.md`, incremental, never reused (a deprecated ADR stays; we do
  not delete history).
- **Immutability of history**: an accepted ADR is not rewritten on its decision; it is
  *superseded* by a new one. The record of "why we thought that at the time" is the value.
- **ADR ↔ threat link**: every `security-relevant` ADR references the threat IDs in
  [`../THREAT-MODEL.md`](../THREAT-MODEL.md) in its "Threats addressed" field.

## Consequences
- Good: durable traceability, documented onboarding of a new machine, security decisions
  re-reviewed on schedule, standard format that can be tooled (MADR lint possible in CI).
- Bad: discipline required (each choice = an ADR); a slight writing overhead. Accepted: the cost
  of an untracked setup is higher over time.

## Review / expiry
`review-by: trigger:new-layer` — review the ADR process if a 4th layer is added (e.g. dedicated
secrets management, or a switch to Nix that would change the repo structure).

## Verification
- The [`README.md`](README.md) index is the source of truth for the list of ADRs (NO hard-coded
  counter here: the number of ADRs is a moving state, it is not tracked in an ADR).
- Every `security-relevant: true` ADR has the 4 custom fields non-empty (lint possible).
