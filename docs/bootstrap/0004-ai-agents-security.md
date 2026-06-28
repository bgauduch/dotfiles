---
status: accepted
date: 2026-06-28
decision-makers: [Baptiste]
security-relevant: true
review-by: 2027-01-28
supersedes: []
---

# ADR-0004 — Sécurité des agents IA (Claude Code, MCP, hooks)

## Contexte et énoncé du problème
L'environnement héberge des agents IA (Claude Code, multi-instances via Zellij/worktrees, MCP
servers, hooks shell), dans le même shell que mes credentials Cloud/IaC, avec capacité d'exécuter
des commandes. Risques propres : prompt injection → exfiltration, MCP server malveillant/compromis,
hooks exécutant du code arbitraire, lecture de `.env`/secrets. Le payload node-ipc 2026 ciblait les
configs Claude/Kiro — les agents IA sont une cible nommée.

## Drivers de décision
- Limiter ce qu'un agent (ou une injection le pilotant) peut faire à mes credentials.
- Garder l'autonomie utile sans ouvrir une RCE.
- Traçabilité des actions, **sans créer de passif de confidentialité** sur le code client.

## Options considérées
- Option A — Confiance totale (`--dangerously-skip-permissions`) : rejeté.
- Option B — Permissions allow/deny/ask, sans isolation OS.
- Option C — **Permissions calibrées + sandbox OS + MCP allowlistés/épinglés + hooks audités.**

## Décision
**Option C**, en couches (commandes/profils opératoires → RUNBOOK) :
1. **Permissions Claude Code** (`~/.claude/settings.json`, géré par chezmoi) : `deny` sur
   l'irréversible et les secrets (`Read(.env*)`, `Read(secrets/**)`, `rm -rf`, `git push --force`,
   `terraform destroy`) ; `ask` sur `git push`, `terraform apply`, `aws` ; `allow` sur lecture/lint/
   test. Premier match : deny > ask > allow.
2. **Sandbox OS** : Seatbelt (macOS) / bubblewrap+socat (Linux/WSL2) — filet si une injection passe.
   **Viabilité à prouver au démarrage** (cf surface résiduelle), pas à asserter.
3. **MCP servers** : allowlist explicite, épinglés, traités comme une **dépendance** (cycle de
   confiance ADR-0003). Pas de MCP arbitraire sans entrée lockfile.
4. **Hooks** : hooks Claude Code → Zellij n'exécutent que des commandes locales **fixes**
   (rename-tab), jamais de contenu dérivé du modèle. Audités en revue de config.
5. **Isolation par worktree** : 1 agent = 1 worktree = 1 branche.
6. **Traçabilité + rétention scindée perso/client.** On s'appuie sur les transcripts natifs
   (`~/.claude/projects/`) — pas de logging custom. **MAIS** ces transcripts contiennent le code
   client lu par l'agent : politique de rétention **scindée** — contexte **client = purge** (jamais
   archivé hors machine), contexte **perso = conservable**. Évite de transformer la traçabilité en
   passif de confidentialité.
7. **Usage agent sur code client = sous réserve contractuelle.** Faire transiter du code client par
   un agent IA (→ fournisseur tiers) n'est lancé **que si le contrat/DPA l'autorise**. À défaut :
   cloisonnement (pas d'agent sur le code client). Décision business hors corpus, tranchée par moi.

## Conséquences
- Bonnes : blast radius limité ; secrets hors de portée par défaut ; sandbox comme filet ; pas de
  passif transcripts côté client.
- Mauvaises : sandbox Linux nécessite bubblewrap+socat (install) ; quelques `ask` subsistent ;
  cloisonnement client = autonomie réduite sur ces contextes (assumé).

## Menaces adressées
- **T-CR-01** (exfil credentials via hook plugin) : deny `Read(.env*)`/`secrets/**` + sandbox (conjoint ADR-0003).
- **T-AG-01** (prompt injection → exfil) : deny secrets + sandbox.
- **T-AG-02** (MCP malveillant/compromis) : allowlist + épinglage + revue (ADR-0003).
- **T-AG-03** (hook exécutant du contenu modèle) : hooks à commandes fixes.
- **T-AG-04** (destruction d'infra : terraform destroy / push force) : deny + ask.

## Surface d'attaque résiduelle
- Une injection agit dans le périmètre **autorisé** (modifier du code du worktree courant) — la
  sandbox limite l'OS, pas la logique permise.
- **Sandbox à prouver** : bubblewrap/WSL2 (user namespaces) et Seatbelt (`sandbox-exec` déprécié)
  fragiles ; `doctor.sh` confirme qu'elle tourne, sinon le filet est aspirationnel.
- Binaires/MCP appelés par l'agent partagent la confiance d'**ADR-0003**.
- Exfiltration via un canal **autorisé** (un `git push` approuvé) non éliminée.

## Revue / expiration
Revue semestrielle (écosystème très mouvant) ; revue immédiate à chaque ajout de MCP server.

## Vérification
```sh
grep -q 'Read(.env' ~/.claude/settings.json && echo OK || echo "MANQUE deny secrets"
command -v bwrap >/dev/null 2>&1 || [ "$(uname)" = Darwin ] || echo "sandbox Linux indispo"
```
