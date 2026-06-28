---
status: accepted
date: 2026-06-28
decision-makers: [Baptiste]
security-relevant: true
review-by: 2027-06-28
supersedes: []
---

# ADR-0003 — Confiance & supply-chain des dépendances externes

> Doctrine **transverse** : un seul cycle de confiance pour TOUTE dépendance externe (plugin shell,
> outil/LSP via mise, serveur MCP, paquet à provenance vérifiable). Évite la duplication d'un
> "rituel de pin/soak" éparpillé par sujet. Le *routage* (quel gestionnaire) est dans ADR-0002 ;
> les *étapes opératoires* du bump sont dans le RUNBOOK. Ici : le principe et les niveaux.

## Contexte et énoncé du problème
Profil ciblé par les campagnes supply-chain 2026 (axios/node-ipc/Shai-Hulud) : un poste freelance
Cloud/IaC détenant credentials AWS/SSH/tfstate. Le vecteur le plus probable est une **dépendance
compromise en amont** (plugin shell sourcé au démarrage, binaire/LSP installé par mise, serveur
MCP). Il faut une règle unique : qu'est-ce qui établit la confiance avant d'exécuter du code tiers.

## Drivers de décision
- Sécurité supply-chain proportionnée, sans réinventer Nix (cf ADR-0006).
- Effort aligné sur la surface réelle : les binaires/LSP via mise sont **plus** exposés que les 2
  plugins zsh (pattern campagnes = artefacts de release compromis). Ne pas sur-blinder les plugins
  en sous-traitant les binaires.
- Portabilité macOS/WSL2, réversibilité (montée en exigence possible).

## Décision : cycle de confiance unique
Toute dépendance externe suit : **déclarer → épingler/lock → vérifier la provenance → soak avant
d'adopter un bump**. Application par classe :

| Classe | Pin / lock | Provenance | Particularité |
|---|---|---|---|
| Plugins zsh (vendored) | clone + **SHA** épinglé dans `zsh-plugins.lock` | revue de diff au bump + signature si dispo | sourcés au démarrage = risque le plus direct (T-CR-01) ; pas de plugin-manager (OMZ/antidote écartés, cf Décision) |
| Outils & **LSP** via mise | `mise.lock` (versions + **checksums** + URLs) | `mise settings lockfile=true` ⇒ checksums **vérifiés à l'install** pour les backends supportés ; cosign/SLSA si l'upstream publie | un lockfile sans vérif active = décoratif ; LSP = outil mise comme un autre |
| Serveurs MCP | version du serveur épinglée (ADR-0004) | revue à l'ajout/MAJ | arbre de deps transitif (npm/pip) non épinglé = résiduel |
| Paquets apt (dépôt tiers) | version gérée par apt | signature via keyring `Signed-By:` (ADR-0002) | — |

**Soak time** : ne pas épingler une release fraîche immédiatement ; laisser passer un délai
d'attente (≈ celui d'une fenêtre d'alerte amont) avant d'adopter un bump. Étapes : RUNBOOK.

### Niveau 2 (différé) — gates scriptés
Les gates *automatisés* (cross-witness tree-hash contre nixpkgs/brew/Debian, scan heuristique
scripté, lint) sont la **cible niveau 2** (ADR-0006), **non construits** tant que le critère de
bascule n'est pas atteint. On garde la décision et le déclencheur, pas une machinerie qui rote.
Au niveau 1 : pin + lock + revue manuelle au bump + `gitleaks` (ADR-0007).

## Conséquences
- Bonnes : une seule source de vérité du cycle de confiance ; effort réaligné sur la vraie surface ;
  pas de duplication ; chemin niveau 2 tracé et déclenché par un fait, pas une envie.
- Mauvaises : la revue de diff au bump reste **manuelle** au niveau 1 (faillible) ; assumé tant que
  le nombre de dépendances reste faible (critère de bascule ADR-0006).

## Menaces adressées
- **T-SC-01** (plugin compromis en amont), **T-SC-02/03** (release/ mainteneur compromis),
  **T-SC-04** (dep non validée/dormante), **T-SC-05** (build trojanisé à provenance valide),
  **T-CR-01** (exfil credentials via hook plugin), **T-SC-08** (binaire mise/LSP altéré au DL).

## Surface d'attaque résiduelle
- **T-SC-05** (provenance valide mais malveillante) : aucun pin ne prouve l'innocuité ; défense en
  profondeur (pin + soak + sandbox agents ADR-0004), pas une garantie.
- Deps **transitives** des serveurs MCP et des binaires mise non épinglées byte-for-byte (→ Nix,
  ADR-0006 niveau 3).
- Revue de bump manuelle : un payload obfusqué peut passer (limite assumée du niveau 1).

## Revue / expiration
Revue annuelle, ou immédiate à l'ajout d'une classe de dépendance ou au franchissement du critère
de bascule niveau 2 (ADR-0006).

## Vérification
```sh
test -f zsh-plugins.lock && test -f mise.lock && echo "locks OK" || echo "lockfile manquant"
mise settings 2>/dev/null | grep -q 'lockfile = true' && echo "vérif mise active" || echo "ACTIVER lockfile"
```
