---
status: proposed
date: YYYY-MM-DD
decision-makers: [Baptiste]
security-relevant: false        # true => the 4 security fields at the bottom are mandatory
review-by: YYYY-MM-DD           # or trigger:<event>
supersedes: []
---

# ADR-NNNN — <short title of the decision>

## Context and problem statement
<What problem, what constraints (cross-OS macOS/WSL2, supply-chain, etc.).>

## Decision drivers
- <criterion 1, e.g. portability>
- <criterion 2, e.g. minimal attack surface>
- <criterion 3, e.g. ease of maintenance>

## Considered options
- Option A — <name>
- Option B — <name>
- Option C — <name>

## Decision
<Chosen option + rationale in 2-4 sentences.>

## Consequences
- Good: <...>
- Bad / accepted costs: <...>

## Comparison (optional)
| Criterion | Option A | Option B | Option C |
|---|---|---|---|

---
<!-- The fields below are MANDATORY if security-relevant: true -->

## Threats addressed
<IDs from docs/THREAT-MODEL.md, e.g. T-SC-01 (compromised plugin), T-AG-01 (agent exfiltration).>

## Residual attack surface
<What this decision does NOT protect against. Honesty > false comfort.>

## Review / expiry
<Date or trigger for re-review. Why this decision may become outdated.>

## Verification
<Concrete command(s) proving the decision is in effect on the machine.>
