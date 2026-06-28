# THREAT MODEL — Shell environment + tooling + AI agents

> Referenced by the `security-relevant` ADRs. Each threat has a stable ID used in the
> "Threats addressed" field of the ADRs. Scope: the 3 layers (shell, tools, AI agents).
> Asset profile: freelance Cloud/IaC workstation holding AWS credentials (multi-account), SSH,
> Terraform state, GitLab/GitHub tokens, AI agent configs. A named target of the 2026 campaigns.

## Adversary model
- **Opportunistic supply-chain**: compromises a popular upstream dependency (the most likely,
  cf. the 2026 axios/node-ipc/Shai-Hulud campaigns). Has not targeted Baptiste personally.
- **Targeted**: knows the profile (freelance Cloud), goes after the credentials. Less likely, high impact.
- **Injection via AI agent**: drives an agent through malicious content (prompt injection) to
  exfiltrate or destroy.

## Layer 1 — Shell & plugins

| ID | Threat | Vector | Covering ADR |
|---|---|---|---|
| T-SC-01 | Shell plugin compromised upstream | Update of a plugin sourced at startup | 0003, 0007 |
| T-SC-02 | Fresh poisoned release, short window | Bump onto a recently booby-trapped HEAD | 0003 |
| T-SC-03 | Maintainer account compromised, publishing outside CI | Malicious manual release | 0003 |
| T-SC-04 | Unvalidated / dormant dependency awakened | Dynamic version resolution | 0003, 0006 |
| T-SC-05 | Trojanized build with valid provenance (Miasma type) | Compromised maintainer CI, SLSA valid but malicious | 0003 |
| T-CR-01 | Credential exfiltration via preexec/precmd hook | Plugin hooks the shell, reads $AWS_*/$*_TOKEN | 0003, 0004 |

## Layer 2 — Tools & package management

| ID | Threat | Vector | Covering ADR |
|---|---|---|---|
| T-SC-06 | apt verification bypass via global key | Third-party repo added to the global keyring | 0002 |
| T-SC-07 | Outdated package with unpatched CVE | Version too old for lack of an up-to-date source | 0002 |
| T-CR-02 | Secret committed in cleartext in the dotfiles repo | Human error, .env added | 0007 |
| T-CR-03 | Provisioning: cleartext secret by mistake or forgotten implicit secret step | Badly rendered template / untracked bootstrap | 0005 |
| T-SC-08 | mise/LSP binary tampered with at download | Compromised GitHub release, partial provenance check | 0003 |

> Note: the LSP servers installed by mise belong to this layer (tools) and to the
> ADR-0003 trust cycle — not to a separate layer.

## Layer 3 — AI agents

| ID | Threat | Vector | Covering ADR |
|---|---|---|---|
| T-AG-01 | Prompt injection → credential exfiltration | Booby-trapped content read by the agent | 0004 |
| T-AG-02 | Malicious or compromised MCP server | Adding/updating an unvalidated MCP | 0004 |
| T-AG-03 | Hook executing model-derived content | Hook that evals an LLM output | 0004 |
| T-AG-04 | Infrastructure destruction by an agent | Agent-driven terraform destroy / git push --force | 0004 |

> **Reading the "Covering ADR" column**: it lists the **primary preventive control(s)**.
> **Drift detection** (the recurring ADR-0007 audit) applies *in addition* to
> T-SC-01..07, T-CR-02 and T-AG-02; not repeated row by row to keep the table readable.

## Assumptions & out of scope
- **Out of scope**: physical compromise of the machine, OS malware outside the dev ecosystem,
  network MITM attack on TLS (assumed sound), upstream compromise of the Anthropic/GitLab/Bitwarden account.
- **Assumption**: the machine is clean at the time of the initial bootstrap.
- **Accepted limit** (cf. ADR-0003): no static scan proves a script is harmless;
  the defense is in depth (pin + soak + sandbox), not a guarantee.

## Prioritization (risk = likelihood × impact)
1. **T-SC-01 / T-CR-01** (compromised plugin → credential exfil): medium-to-high likelihood (active
   campaigns), critical impact. → ADR-0003 (pin) + ADR-0004 (sandbox).
2. **T-SC-08 / T-AG-01 / T-AG-02** (mise/LSP binaries + AI agents): broad and active surface, medium
   likelihood (2026 campaign pattern = compromised release), critical impact. → ADR-0003 + ADR-0004.
   Note: the binaries/LSPs via mise are more exposed than the 2 zsh plugins; effort realigned.
3. **T-SC-06 / T-CR-02 / T-CR-03** (config & secrets): medium likelihood, high impact. → ADR-0002/0007/0005.
4. The rest: low likelihood or contained impact.
