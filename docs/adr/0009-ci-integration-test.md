---
status: accepted
date: 2026-06-28
decision-makers: [Baptiste]
security-relevant: true
review-by: 2027-06-28
supersedes: []
---

# ADR-0009 — Test d'intégration CI : installation isolée complète à chaque commit

> Amende le volet **forge & plateforme CI** d'[ADR-0007](0007-recurring-audit-ci-precommit.md)
> (qui supposait GitLab) : le dépôt est hébergé sur **GitHub**, donc la CI est réalisée en
> **GitHub Actions**. La matrice d'audit d'ADR-0007 reste la cible ; ADR-0009 ne tranche que la
> plateforme et le **test d'intégration** (install isolée), pas les gates niveau 2.

## Contexte et énoncé du problème
Le source state chezmoi est entièrement statique tant qu'il n'est pas *appliqué* sur une machine.
Un template qui ne rend pas, un script d'install non idempotent, un nom d'outil mise erroné ou un
`.zshrc` cassé ne se voient qu'à l'`apply`. Il faut un filet qui **rejoue une installation propre
de bout en bout** à chaque changement, avant merge — sans dépendre d'une machine humaine.

## Drivers de décision
- Valider l'install réelle (apt + mise + chezmoi apply + doctor), pas seulement la syntaxe.
- Tester **chaque commit de branche** et **chaque PR** (stratégie dépôt demandée).
- Reproductibilité locale identique à la CI (pas de divergence "marche chez moi").
- Plateforme = celle du dépôt (GitHub), sans réécrire ADR-0007.

## Options considérées
- Option A — Lint statique seul (shellcheck/render) : rapide mais ne prouve pas que l'install marche.
- Option B — Job CI installant directement sur le runner : pollué par les outils pré-installés du
  runner, pas une "machine neuve".
- Option C — **Build d'une image Docker (`Dockerfile`) qui fait `chezmoi init --apply` puis
  `doctor.sh` dans un Debian vierge ; le build EST le test.** Reproductible en local via
  `make integration-test`. Complété par un job gitleaks (bloquant) et shellcheck (indicatif).

## Décision
**Option C.**
- `.github/workflows/integration-test.yml` sur `push` (toutes branches) + `pull_request` :
  - `isolated-install` (bloquant) : `docker build` du `Dockerfile` → install isolée complète.
  - `secrets` (bloquant) : gitleaks (ADR-0007 niveau 1).
  - `lint` (indicatif) : shellcheck.
- `Dockerfile` + `make integration-test` : même install isolée en local.
- **Stratégie dépôt** : conventional commits ; une branche `main` + branches de feature ;
  intégration testée à chaque commit ; merge sur `main` via PR verte.

## Conséquences
- Bonnes : régression d'install détectée avant merge ; reproductible localement ; aucune machine
  humaine requise ; la PR porte la preuve d'install (job vert).
- Mauvaises : le build complet (mise install) prend quelques minutes par run ; le chemin macOS/brew
  n'est pas couvert par un runner Linux (extension `macos-latest` documentée, gardée optionnelle).

## Menaces adressées
- **T-CR-02** (secret commité par erreur) : gitleaks bloquant en CI.
- **T-SC-04/08** (dépendance/binaire altéré ou cassant l'install) : une install isolée qui échoue
  bloque le merge — le changement dangereux ne passe pas silencieusement.

## Surface d'attaque résiduelle
- La CI prouve que l'install **réussit**, pas qu'elle est **innocente** (un binaire à provenance
  valide mais malveillant passe — cf ADR-0003 T-SC-05).
- Couverture macOS non automatisée (runner Linux) ; testée manuellement sur machine réelle.
- Les gates déterministes niveau 2 (cross-witness, soak) restent différés (ADR-0007 / ADR-0006).

## Revue / expiration
Revue annuelle, ou immédiate si la forge change ou si le critère de bascule niveau 2 (ADR-0006)
est atteint (ajout des gates déterministes au pipeline).

## Vérification
```sh
make integration-test   # docker build : install isolée complète, code retour ≠ 0 si échec
make secrets            # gitleaks detect
```
