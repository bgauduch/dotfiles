---
status: accepted
date: 2026-06-28
decision-makers: [Baptiste]
security-relevant: true
review-by: 2027-06-28
supersedes: []
---

# ADR-0005 — Secrets & credentials (stockage, provisioning machine neuve)

## Contexte et énoncé du problème
chezmoi gère les *configs* ; rien ne décidait où vivent les **secrets** et **accès** : clés SSH,
credentials AWS multi-comptes, tokens GitLab/GitHub. C'est l'actif central du threat model (poste
freelance Cloud/IaC). "Pas de secret en clair dans le repo" est nécessaire mais insuffisant : il
faut une source de vérité *positive* et un flux de bootstrap explicite. Deux natures distinctes :
secrets **statiques** (à stocker/récupérer) et **accès AWS** (où le bon réflexe est de ne RIEN
stocker).

## Drivers de décision
- Source unique, jamais de secret en clair dans git.
- Bootstrap machine neuve déterministe et tracé.
- Réutiliser l'outillage en place ; découpler config / secret.
- Minimiser les secrets longue-durée matérialisés sur disque.

## Options considérées
- **Bitwarden CLI + templates chezmoi** (statiques) : déjà en place ; injection au `apply`.
- SOPS + age : chiffré dans le repo, autonome, mais déplace le problème vers la clé age.
- Manuel/RUNBOOK seul : zéro dépendance mais MTTR élevé et faillible.
- Pour AWS : clés statiques (Bitwarden→`~/.aws/credentials`) **vs** SSO/granted (creds temporaires).

## Décision
1. **Secrets statiques → Bitwarden CLI**, injectés par template chezmoi : fichiers `*.tmpl`
   appelant `{{ (bitwarden "item" "<id>").<champ> }}`, rendus seulement au `chezmoi apply`, jamais
   committés. Le repo ne contient que des **IDs d'items**, jamais des valeurs.
2. **Accès AWS → SSO / `granted` (creds temporaires), ZÉRO clé statique** par défaut. Login
   interactif par profil/compte ; fallback `aws-vault` (backend keychain OS) **uniquement** pour un
   compte sans SSO. Aucune clé long-terme sur disque ; Bitwarden ne sert qu'au *transport* d'un
   secret long-terme inévitable, pas à remplacer un SSO.
3. **Bootstrap & ordre cold-start** : `bw unlock` AVANT le premier `chezmoi apply` ; clone du repo
   privé en **HTTPS + token** (issu du vault) pour éviter le deadlock clé-SSH ⇄ repo. Procédure :
   RUNBOOK.

## Conséquences
- Bonnes : source unique, rien en clair, bootstrap tracé, pas de clé AWS statique ; repo publiable
  sans fuite.
- Mauvaises : dépendance à `bw`/réseau au `apply` (échec lisible si vault verrouillé) ; login SSO
  interactif par session (friction mineure assumée).

## Menaces adressées
- **T-CR-03** (secret en clair par erreur / geste secret implicite oublié) : références-only +
  bootstrap documenté + zéro clé statique AWS.

## Surface d'attaque résiduelle
- **Vault Bitwarden compromis** (compte/master password) : hors périmètre (hypothèse "compte amont
  sain"), mitigé par 2FA.
- Secrets **matérialisés sur disque** après apply : minimiser ; préférer agents/SSO en mémoire.
- `bw` est un binaire à provenance vérifiée (ADR-0003).

## Revue / expiration
Revue annuelle ; immédiate à l'ajout d'un type de credential ou d'un changement de gestionnaire.

## Vérification
```sh
grep -rIl --exclude='*.tmpl' -E 'AKIA|BEGIN [A-Z ]*PRIVATE KEY|glpat-|ghp_' ~/.local/share/chezmoi \
  && echo "SECRET EN CLAIR" || echo OK
test -f ~/.aws/credentials && echo "ATTENTION clé statique AWS présente" || echo "AWS sans clé statique OK"
```
