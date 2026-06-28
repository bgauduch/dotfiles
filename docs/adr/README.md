# Architecture Decision Records (ADR)

Décisions structurantes de l'environnement de développement portable (chezmoi + shell + outils +
agents IA). Format : **MADR étendu** (4 champs sécu custom), défini dans
[ADR-0000](0000-adr-process-and-repo-conventions.md). Gabarit : [`_template.md`](_template.md).

Toute décision technique nouvelle ou modifiée ⇒ un ADR (ou un superseding). Les ADR
`security-relevant` référencent [`THREAT-MODEL.md`](../THREAT-MODEL.md). Le **comment** (procédures,
commandes, étapes) vit dans [`RUNBOOK.md`](../RUNBOOK.md), pas dans les ADR.

## Index

| ADR | Titre | Type | Sécu | Statut |
|---|---|---|---|---|
| [0000](0000-adr-process-and-repo-conventions.md) | Processus ADR & conventions du dépôt | méta | – | accepted |
| [0001](0001-chezmoi-dotfiles-manager.md) | chezmoi comme gestionnaire de dotfiles | granulaire | non | accepted |
| [0002](0002-tooling-and-packages-doctrine.md) | Doctrine d'outillage & paquets (apt/mise/brew, inventaire) | **doctrine** | **oui** | accepted |
| [0003](0003-dependencies-trust-supply-chain.md) | Confiance & supply-chain des dépendances (pin/lock/soak) | **doctrine** | **oui** | accepted |
| [0004](0004-ai-agents-security.md) | Sécurité agents IA (Claude Code, MCP, hooks) | granulaire | **oui** | accepted |
| [0005](0005-secrets-and-credentials.md) | Secrets & credentials (Bitwarden / SSO AWS) | granulaire | **oui** | accepted |
| [0006](0006-immutability-level-pragmatic.md) | Niveau d'immutabilité pragmatique évolutif | granulaire | **oui** | accepted |
| [0007](0007-recurring-audit-ci-precommit.md) | Audit récurrent CI + pre-commit | granulaire | **oui** | **proposed** (niveau 2 différé) |
| [0008](0008-tui-stack.md) | Stack TUI (WezTerm/Zellij/Helix/Yazi/Lazygit) | **groupé** | non | accepted (Helix sous validation) |

## Conventions rapides
- Numérotation incrémentale, jamais réutilisée. Un ADR déprécié reste (superseding, pas suppression).
- Granulaire pour les choix structurants ; doctrine pour les règles transverses ; groupé pour les
  familles (stack).
- ADR = décision durable (quoi + pourquoi). État mouvant (liste d'outils, versions) → fichier de
  conf. Procédure (comment) → `RUNBOOK.md`.
