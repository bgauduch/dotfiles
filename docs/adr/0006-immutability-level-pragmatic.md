---
status: accepted
date: 2026-06-28
decision-makers: [Baptiste]
security-relevant: true
review-by: trigger:critere-bascule-atteint
supersedes: []
---

# ADR-0006 — Niveau d'immutabilité : pragmatique évolutif (et quand passer à Nix)

## Contexte et énoncé du problème
Objectif exprimé : "tendre vers un système immutable qui tourne uniquement avec des dépendances
validées". Question légitime posée : est-ce de l'over-engineering ? réinvente-t-on un système
existant ? La réponse honnête : oui, pousser l'immutabilité à fond **réinvente Nix**, qui est la
solution existante pour la reproductibilité byte-for-byte. Il faut donc décider d'un niveau, et
surtout d'un **critère explicite** de passage au niveau supérieur — pour que ce soit une décision
tracée, pas un ressenti.

## Drivers de décision
- Sécurité supply-chain (dépendances validées) sans complexité disproportionnée.
- Portabilité macOS + WSL2 sans casser la productivité.
- Réversibilité : pouvoir monter en exigence plus tard sans tout réécrire.

## Options considérées
- **Niveau 1 — Pragmatique** : pin SHA (plugins) + lockfiles (mise, Brewfile) + audit scripté
  récurrent + ADR. Reproductibilité des *configs* et *versions déclarées*, pas du système entier.
- **Niveau 2 — Élevé** : Niveau 1 + lockfiles partout + gates bloquants en CI + checksums/cosign
  sur les binaires mise quand dispo. Toujours sans nouveau gestionnaire lourd. **Concrètement =
  ADR-0003 (gates de bump scriptés) + ADR-0007 (audit CI complet), tous deux en statut `proposed`
  tant qu'on reste niveau 1.**
- **Niveau 3 — Maximal (Nix/home-manager + flakes)** : reproductibilité byte-for-byte, `flake.lock`
  épingle l'intégralité (système + outils + configs), rollback instantané.

## Décision
**Démarrer au Niveau 1 (pragmatique) comme SOCLE durable, montée au Niveau 2 seulement si un
critère objectif l'exige (pas "par défaut une fois stabilisé" — éviter de construire un harnais
d'audit pour 2 machines avant le besoin), et bascule Niveau 3 (Nix) UNIQUEMENT si critère atteint.**

Le socle niveau 1 effectivement implémenté : pin SHA plugins + lockfiles (`zsh-plugins.lock`,
`mise.lock` avec **vérification de provenance active**, ADR-0003) + gitleaks pre-commit/CI + ADR.
Les gates scriptés (ADR-0003) et la CI bloquante complète (ADR-0007) sont la **cible niveau 2**,
non construits tant que < critère ci-dessous : on garde la décision, pas la machinerie.

### Critère de bascule vers Niveau 2 (construire les gates ADR-0003/0007)
Construire le harnais d'audit scripté si **≥ 1** devient vrai :
- un bump a introduit (ou failli introduire) une régression de sécurité non détectée à l'œil ;
- le nombre de dépendances vendored/MCP dépasse ~5 (l'audit manuel ne passe plus à l'échelle) ;
- exigence externe (audit client/conformité) demande une trace automatisée.

Ce n'est pas de l'over-engineering au Niveau 1–2 : pin + lockfiles + audit couvrent l'essentiel du
risque supply-chain pour un poste individuel. Le Niveau 3 (Nix) apporte la repro byte-for-byte mais
à un coût réel : courbe d'apprentissage (langage fonctionnel), configs non éditables en place,
friction macOS (entrées launcher manquantes), et tension avec le principe "git+zsh partout, zéro
package manager" d'ADR-0003. Adopter Nix "pour faire immutable" sans besoin déclencheur = la
définition de l'over-engineering.

### Critère objectif de bascule vers Nix (Niveau 3)
Basculer si **≥ 2** des conditions suivantes deviennent vraies :
1. Plus de 2 machines à garder strictement synchronisées (ajout d'un poste fixe, VM, serveur).
2. Besoin de rollback système instantané prouvé (un bump a déjà cassé l'environnement ≥ 1 fois).
3. Besoin d'environnements par projet reproductibles partagés avec des tiers (`nix develop`).
4. Le temps passé à débugger des divergences macOS/WSL2 dépasse ~1 j/trimestre.
Tant que < 2 conditions : rester Niveau 1–2. La décision de bascule fera l'objet d'un ADR
superseding celui-ci.

## Conséquences
- Bonnes : complexité alignée sur le besoin réel ; chemin d'évolution tracé et déclenché par des
  faits, pas par une envie ; pas de réinvention prématurée de Nix.
- Mauvaises : Niveau 1–2 ne garantit pas la repro byte-for-byte (deux installs à des dates
  différentes peuvent différer sur des deps transitives non pinnées). Accepté tant que critère < 2.

## Menaces adressées
- **T-SC-04** (deps non validées) : lockfiles + pin couvrent les dépendances déclarées.
- Ne prétend PAS adresser la repro transitive complète (c'est le rôle du Niveau 3).

## Récupération / rollback (Niveau 1–2, sans Nix)
**Décision** : Niveau 1–2 n'offre **pas** de rollback transactionnel (c'est l'argument Niveau
3/Nix) ; on assume une récupération par `git revert` du source state + scripts idempotents +
snapshot des confs critiques avant bump. **Procédure détaillée : RUNBOOK § Rollback.**

## Surface d'attaque résiduelle
- Dépendances **transitives** des binaires mise/brew non épinglées byte-for-byte au Niveau 1–2.
- Dérive possible entre deux machines sur les versions non lockées (ex. libs système apt/brew).
  Mitigé par l'audit récurrent qui détecte la dérive, pas par la construction.

## Revue / expiration
À chaque exécution de l'audit récurrent : évaluer le critère de bascule (compteur de conditions).
Trigger explicite si ≥ 2.

## Vérification
```sh
# présence des lockfiles attendus (Niveau 1)
test -f zsh-plugins.lock && test -f mise.lock && echo OK || echo "lockfile manquant"
```

## Note : réinvente-t-on un système existant ?
Oui, partiellement, et c'est assumé. Niveau 1–2 = un sous-ensemble pragmatique de ce que Nix fait
(pin + lock + validation), implémenté en git+zsh pour rester portable et simple. On ne réécrit PAS
le store Nix ni la résolution de dépendances — on emprunte juste l'idée de lockfile. Le jour où on
veut la garantie forte, on adopte Nix au lieu de continuer à le réimplémenter en moins bien : c'est
précisément ce que prévient le critère de bascule.
