---
status: accepted
date: 2026-06-28
decision-makers: [Baptiste]
security-relevant: false
review-by: trigger:adoption-nix
supersedes: []
---

# ADR-0001 — chezmoi comme gestionnaire de dotfiles cross-OS

## Contexte et énoncé du problème
Besoin d'un environnement identique sur macOS (poste principal) et WSL2/Debian, à partir d'une
source de vérité unique versionnée. Les différences entre OS (paths Homebrew, clipboard, WSL)
doivent être gérées sans dupliquer des fichiers par machine.

## Drivers de décision
- Source unique versionnée (cohérent avec workflow GitLab existant).
- Gestion des différences OS par templating, pas par duplication.
- Pas de runtime lourd ; dépendances minimales.
- Bootstrap one-liner sur une machine neuve.

## Options considérées
- Option A — **chezmoi** : mapping 1:1 source→home, templating Go, détection OS native.
- Option B — **GNU Stow** : symlinks purs, simple, mais aucun templating (différences OS = fichiers séparés).
- Option C — **yadm** : git wrapper, templating plus limité que chezmoi.
- Option D — **Nix/home-manager** : reproductibilité maximale (voir ADR-0006).

## Décision
**chezmoi.** Il offre le templating OS (`{{ if eq .chezmoi.os "darwin" }}`, détection WSL via
`.chezmoi.kernel.osrelease`) qui permet un fichier unique par config, des scripts de cycle de vie
(`run_once_`, `run_onchange_`) pour l'install idempotente, et un bootstrap one-liner. Stow est
écarté car l'absence de templating forcerait des fichiers dupliqués macOS/Linux — l'anti-objectif.

## Conséquences
- Bonnes : un seul fichier par config, différences OS lisibles inline, install reproductible.
- Mauvaises : courbe sur la syntaxe template Go ; le source state n'est pas éditable "en place"
  (il faut passer par `chezmoi edit` / `chezmoi add`). Accepté.

## Comparatif
| Critère | chezmoi | Stow | yadm | Nix/HM |
|---|---|---|---|---|
| Templating OS | ✅ natif | ❌ | ~ | ✅ |
| Dépendance runtime | 1 binaire | perl | git | toolchain Nix |
| Courbe | moyenne | faible | faible | élevée |
| Reproductibilité | configs | configs | configs | système complet |
