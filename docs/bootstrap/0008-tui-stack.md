---
status: accepted
date: 2026-06-28
decision-makers: [Baptiste]
security-relevant: false
review-by: trigger:changement-majeur-stack
supersedes: []
---

# ADR-0008 — Stack TUI : WezTerm + Zellij + Helix + Yazi + Lazygit [groupé]

> ADR **groupé** : ces cinq outils forment une seule décision cohérente (remplacer VS Code + cmux
> par une pile terminal native portable). Le "pourquoi" est partagé ; on les trace ensemble.

## Contexte
Remplacer VS Code + cmux par une stack terminal native, identique macOS/WSL2, navigable au clavier,
légère, souris en backup, capable d'orchestrer plusieurs agents IA. Couches : émulateur,
multiplexer, éditeur, file-tree, diff git.

## Drivers de décision
- Navigation clavier simple + souris possible.
- Léger, portable cross-OS, formats ouverts (anti vendor-lock-in).
- Multi-agent (remplacer cmux) + intégration hooks Claude Code.

## Décision (par couche)
| Couche | Outil retenu | Alternative écartée | Raison |
|---|---|---|---|
| Émulateur GPU | **WezTerm** | iTerm2/Alacritty | config Lua unique cross-OS, détection target, lance Zellij ; sous WSL2 tourne côté **Windows** (remplace Remote-WSL) — *seam* ci-dessous |
| Multiplexer | **Zellij** | tmux | hints visibles (pas de muscle memory), panes flottants natifs (file-tree), config KDL déclarative ; tmux gardé pour SSH/remote |
| Éditeur | **Helix** *(sous validation, cf infra)* | Neovim / Zed | clavier simple (selection→action), léger, souris par défaut, LSP intégré sans config Lua lourde ; Zed = pas multiplexer + WSL2 imparfait |
| File-tree | **Yazi** (pane flottant) | nnn/ranger | comble l'absence de file-tree Helix, ouvre dans l'instance éditeur |
| Diff git | **Lazygit** | tig/gitui | diff visuel + intégration delta |

## Validation Helix (le plus gros risque fonctionnel — remplacer VS Code pour charge IaC/Python)
Helix est **cible**, pas acquis : adoption confirmée seulement après un **timebox sur une vraie
tâche** Crossplane/Terraform/Python (2-3 semaines), VS Code gardé en parallèle pendant l'essai.
**Critère de retour** (rollback documenté vers VS Code/hybride, sans superseding) si l'un est vrai :
- édition IaC/Python significativement ralentie vs VS Code au quotidien ;
- LSP/refactor/diagnostics Crossplane/YAML insuffisants pour le travail réel ;
- absence de debugger (DAP) bloquante pour Python.
Décision finale tracée (amendement de cet ADR) après l'essai, pas sur papier.

## Seam WezTerm / Windows (portabilité critique WSL2)
Côté WSL2, WezTerm tourne **sur Windows**, hors du `$HOME` Linux géré par chezmoi : sa config
(`wezterm.lua` Windows) est **hors du contexte chezmoi-WSL**. Décision pour ne pas prétendre
faussement "config identique 2 OS" côté émulateur :
- **Retenu** : config WezTerm Windows **hors-scope chezmoi-WSL**, documentée au RUNBOOK
  (`winget install wez.wezterm` + dépôt du `.lua` Windows) ; chezmoi gère WezTerm **macOS** seul ;
  le `.lua` est factorisé (modèle partagé copié manuellement côté Windows).
- **Écarté** : 2e contexte chezmoi Windows (double la machinerie pour un fichier ; coût > bénéfice).
WezTerm n'est **jamais** installé dans WSL.

## Conséquences
- Bonnes : pile cohérente, portable, légère, multi-agent ; même config sur 2 OS via chezmoi.
- Mauvaises : perte du navigateur scriptable de cmux (remplacé par `glab mr`/`glab ci` — forge
  GitLab, ADR-0007) et des notifications natives macOS/iOS (→ hooks rename-tab Zellij). Helix sans
  file-tree natif (workaround Yazi). Risque productivité éditeur couvert par le timebox. Accepté.

## Revue / expiration
Revoir si un de ces outils change de modèle majeur (ex. Helix plugin system stable, ou Zed corrige
WSL2 + multiplexing).

## Détail vivant (hors ADR)
Configs et binds : cf RUNBOOK § Stack TUI.
