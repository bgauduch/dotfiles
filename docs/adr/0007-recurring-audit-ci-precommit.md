---
status: proposed
date: 2026-06-28
decision-makers: [Baptiste]
security-relevant: true
review-by: 2027-06-28
supersedes: []
---

# ADR-0007 — Audit de sécurité récurrent : CI bloquant + pre-commit avertissement

> **Statut `proposed` (niveau 2, implémentation différée).** Au **niveau 1** (socle, ADR-0006),
> seul **gitleaks** (secrets) tourne en pre-commit (warn) + CI (bloquant) ; les gates déterministes
> de plugins/cross-witness/lint ADR relient ADR-0003 et ne sont construits qu'au passage niveau 2.
> La matrice complète ci-dessous est la **cible**, pas l'état courant.

## Contexte et énoncé du problème
L'audit shell a été joué une fois à la main. Pour qu'il ait de la valeur dans le temps, il doit se
rejouer automatiquement et détecter toute dérive (plugin dépinglé, clé globale ajoutée, secret en
clair, deny manquant). Choix exprimé : CI bloquant + pre-commit avertissement.

## Drivers de décision
- Détecter la dérive de configuration à chaque modification.
- Ne pas bloquer le flow local (friction), mais bloquer l'intégration (garantie).
- Réutiliser la logique de gates déterministes d'ADR-0003.

## Options considérées
- Option A — Audit manuel ponctuel : insuffisant (oubli).
- Option B — Pre-commit bloquant : trop de friction locale, pousse au `--no-verify`.
- Option C — **CI bloquant (source de vérité) + pre-commit non-bloquant (feedback rapide).**

## Décision
**Option C.**
- **Pre-commit (avertissement)** : hook rapide qui lance les checks "cheap" (secrets en clair,
  plugin drift vs lockfile, présence des deny Claude Code) et **avertit** sans bloquer le commit.
  But : feedback immédiat, zéro incitation au contournement.
- **CI (bloquant)** : pipeline dotfiles (GitLab CI, cohérent avec la forge existante) qui rejoue
  l'audit complet et **échoue** si un gate rouge. Source de vérité : rien n'est mergé sur `main`
  avec un gate rouge.

### Forge & modèle de branches
- **Forge** : GitLab (aligne l'écosystème existant). Le CLI de revue PR/run est `glab`, pas `gh`
  (aligné sur ADR-0008).
- **Modèle** : MR obligatoire + CI bloquante sur `main` (pas de push direct).
- **Porte de sortie assumée (anti-érosion solo)** : bascule **trunk + CI non-bloquante** actée
  *sans superseding* si la friction solo dépasse le bénéfice. **Déclencheur explicite** : 1er
  `--no-verify` ou 1er contournement de la MR. La garantie dépend de la discipline ; ce déclencheur
  évite le déni (on bascule officiellement au lieu de contourner en silence).

### Contenu de l'audit (réutilise audit/gates/ + audit/scan/)
| Check | Couche | Pre-commit | CI |
|---|---|---|---|
| Secrets en clair (gitleaks/regex) | toutes | warn | bloquant |
| Plugin SHA == lockfile | shell | warn | bloquant |
| Soak time des bumps proposés | shell | – | bloquant |
| `git tag -v` GPG des plugins | shell | – | bloquant |
| Cross-witness tree-hash | shell | – | warn (dégradé si pas de témoin) |
| Scan heuristique diff plugins | shell | warn | bloquant si signaux forts |
| Brewfile/mise vs lockfile (drift versions) | outils | warn | bloquant |
| Pas de clé apt en keyring global | outils | – | bloquant (Linux) |
| Deny secrets présents (Claude settings) | agents | warn | bloquant |
| MCP servers ∈ allowlist | agents | – | bloquant |
| Vérif provenance mise active (pas juste lockfile présent) | outils | warn | bloquant (niveau 1) |
| LSP auto-lancés ∈ languages.toml déclarés | exec continu | – | bloquant |
| Aucun secret en clair rendu hors *.tmpl | secrets | warn | bloquant |
| ADR security-relevant ont les 4 champs | méta | warn | bloquant (lint) |

## Conséquences
- Bonnes : dérive détectée tôt (local) et barrée tard (CI) ; logique partagée avec le rituel de bump.
- Mauvaises : double maintenance pre-commit/CI (mitigée en appelant le même script depuis les deux).

## Menaces adressées
- **T-SC-01..07** (dérive vers une dépendance non validée) : drift bloqué en CI.
- **T-CR-02** (secret commité par erreur) : gitleaks pre-commit + CI.
- **T-AG-02** (MCP hors allowlist ajouté discrètement) : check CI bloquant.

## Surface d'attaque résiduelle
- Pre-commit est contournable (`--no-verify`) **par conception** → c'est pourquoi la garantie est
  en CI, pas en local.
- L'audit ne détecte que les dérives qu'on a codées en gate ; une classe d'attaque nouvelle non
  modélisée passe (mitigé par la revue annuelle des signaux, ADR-0003).
- Le scan heuristique a les limites d'ADR-0003 (pas une preuve).

## Revue / expiration
Revue annuelle de la matrice de checks ; ajout d'un gate à chaque nouvelle classe de menace
identifiée.

## Vérification
```sh
audit/run.sh --mode ci      # code retour ≠ 0 si un gate bloquant échoue
audit/run.sh --mode pre-commit   # n'échoue jamais, imprime des warnings
```
