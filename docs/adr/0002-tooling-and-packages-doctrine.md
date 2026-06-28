---
status: accepted
date: 2026-06-28
decision-makers: [Baptiste]
security-relevant: true
review-by: trigger:changement-doctrine
supersedes: []
---

# ADR-0002 — Doctrine d'outillage & paquets (où va quoi, inventaire)

> ADR **doctrine** : ne trace PAS la liste des outils (état mouvant, cf ADR-0000), mais les **règles
> durables** qui décident *quel gestionnaire installe quoi* et *ce qui est réinstallé sur une machine
> neuve*. La confiance/provenance des dépendances (pin, lock, soak) relève d'ADR-0003 ; cet ADR ne
> traite que le routage et l'inventaire. La liste vit dans les fichiers de conf versionnés
> (`Brewfile.tmpl`, `mise.toml`, `zsh-plugins.lock`).

## Contexte et énoncé du problème
Sans règle stable, l'inventaire dérive : essais ponctuels réinstallés "par défaut", même outil en
double via deux gestionnaires, dépendances exécutées au démarrage ajoutées sans contrôle. Il faut
une doctrine qui survive aux changements de liste, sur macOS + WSL2/Debian.

## Drivers de décision
- Surface d'attaque minimale et propreté de l'inventaire.
- Source unique par outil (pas de doublon entre gestionnaires).
- Versioning cross-OS aligné pour les runtimes.
- Séparer "décision durable" (cet ADR) de "liste" (fichiers de conf).

## Décision : doctrine

1. **Source unique par outil.** Un outil = un seul gestionnaire, jamais deux. Runtimes pinnables
   par projet → **mise** ; briques système → gestionnaire natif de l'OS (**apt** sur Linux,
   **brew** sur macOS, casks compris pour les apps GUI).

2. **Routage d'un nouvel outil :**
   - Runtime/outil dev pinnable (y compris serveurs LSP) → **mise** + entrée `mise.lock`.
   - Outil système Linux → **apt** ; dépôt tiers seulement si nécessaire, alors **keyring
     individuel + `Signed-By:`** (jamais de clé globale, cf garde-fou ci-dessous).
   - Outil / app macOS → **brew** (formule ou cask), déclaré dans `Brewfile.tmpl`.

3. **Inventaire intentionnel.** Sont déclarés (donc réinstallés auto sur machine neuve) les outils
   à usage **récurrent** (cœur quotidien, infra, CI/lint réellement utilisés). Les outils **essayés
   ponctuellement** ne sont PAS déclarés : installables à la demande. Objectif : pas un cimetière
   d'essais.

4. **Outils passifs** (prompt, complétions, libs, deps de build) : jugés **par rôle, pas par
   compteur d'usage** ; pas supprimés sur le seul critère d'un faible nombre d'occurrences.

5. **Frontière sécu shell.** Toute dépendance **exécutée au démarrage du shell** (plugin, hook)
   relève d'ADR-0003 (confiance/pin/soak), pas de cette doctrine. Idem provenance des binaires.

6. **GUI hors périmètre shell** : non couvertes côté shell ; celles exposant un CLI déjà dans le
   PATH n'ont rien à porter.

### Garde-fou dépôts tiers apt (impératif)
Un dépôt tiers ajoute sa clé en **keyring individuel** `/etc/apt/keyrings/<vendor>.gpg` + `Signed-By:`
dans le `.sources`. **Jamais** `apt-key` ni `/etc/apt/trusted.gpg.d/` global (obsolète depuis Ubuntu
22.04, casse l'isolation : une clé tierce signerait pour tout le système).

## Conséquences
- Bonnes : doctrine stable qui ne se périme pas quand la liste change ; inventaire minimal ;
  doublons exclus par construction ; frontière nette avec la sécurité des dépendances (ADR-0003).
- Mauvaises : un outil "à la demande" devra être réinstallé quand re-nécessaire (coût mineur assumé).

## Menaces adressées
- **T-SC-06** (bypass vérif apt via clé globale) : keyring individuel + `Signed-By:`.
- **T-SC-07** (paquet obsolète à CVE) : source à jour par gestionnaire natif, inventaire revu.

## Surface d'attaque résiduelle
- La *confiance* dans les binaires installés (provenance, altération au téléchargement) n'est PAS
  traitée ici → ADR-0003.

## Revue / expiration
`trigger:changement-doctrine` — revoir seulement si la doctrine évolue (3e gestionnaire, bascule
Nix). La modification de la *liste* d'outils ne déclenche PAS de revue.

## Fichiers d'état régis (hors ADR)
- `Brewfile.tmpl` — inventaire macOS. `mise.toml` — runtimes + LSP + versions.
- `zsh-plugins.lock` — plugins (confiance régie par ADR-0003).

## Vérification
```sh
# garde-fou apt (Linux) : dépôts tiers en keyring individuel + Signed-By, jamais de clé globale
if [ -d /etc/apt ]; then
  test -d /etc/apt/keyrings && echo "OK: keyrings individuels" || echo "VERIFIER: /etc/apt/keyrings absent"
  ! ls /etc/apt/trusted.gpg.d/*.asc /etc/apt/trusted.gpg.d/*.gpg >/dev/null 2>&1 \
    && echo "OK: pas de clé tierce globale" || echo "VERIFIER: clé en trusted.gpg.d global"
else
  echo "macOS: apt N/A (routage brew, cf doctrine)"
fi
```
