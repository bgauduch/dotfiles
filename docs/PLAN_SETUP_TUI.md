# PLAN — Setup TUI portable (chezmoi + Zellij + Helix + WezTerm + Yazi + Lazygit)

> À exécuter par Claude Code. **Démarre en plan mode** (`Shift+Tab`). Présente le plan,
> attends validation, puis passe en `acceptEdits`. Ne touche JAMAIS à `~` directement :
> tout passe par le source state chezmoi (`chezmoi add` / édition dans `~/.local/share/chezmoi`).

## Objectif
Remplacer VS Code + cmux par une stack terminal native, **identique sur macOS et WSL2/Debian**,
gérée par un repo dotfiles chezmoi unique. Cibles : éditeur clavier léger (Helix), multiplexer
multi-agent (Zellij), émulateur GPU (WezTerm), file-tree souris (Yazi), diff git visuel (Lazygit).

## Contraintes
- **Source de vérité unique** : repo Git chezmoi. Aucune divergence de fichiers entre OS ;
  les différences OSX/WSL2 sont gérées par templates `.tmpl`, pas par fichiers séparés.
- **Toolchain via mise** (déjà utilisé) pour versionner les binaires à l'identique.
- **Idempotent** : ré-exécutable sans casse. Scripts `run_onchange_`/`run_once_`.
- **Pas de secret en clair** dans le repo (intégration Bitwarden CLI déjà en place, optionnelle ici).
- Préférence formats ouverts, pas de lock-in.

## Détection d'OS (à utiliser dans tous les templates)
- macOS : `{{ if eq .chezmoi.os "darwin" }}`
- Linux : `{{ else if eq .chezmoi.os "linux" }}`
- WSL2 (sous-cas Linux) : `{{ if (.chezmoi.kernel.osrelease | lower | contains "microsoft") }}`
- Debian (sous-cas Linux) : `{{ if eq .chezmoi.osRelease.id "debian" }}`
Définir une variable custom `osid` dans `.chezmoidata` ou en tête de template pour simplifier :
`darwin` / `linux-wsl` / `linux-debian`.

---

## PHASE 0 — Pré-vol (lecture seule, pas de modif)
1. Détecter l'OS courant (`uname -a`, lire `/proc/sys/kernel/osrelease` si Linux).
2. Vérifier présence de : `git`, `curl`, `mise`. Lister ce qui manque SANS installer encore.
3. Vérifier si chezmoi est déjà initialisé (`~/.local/share/chezmoi`). Si oui, faire un
   `chezmoi diff` et s'arrêter pour rapport avant toute écriture.
4. **STOP** — présenter l'état détecté + le plan d'install à l'utilisateur. Attendre go.

## PHASE 1 — Bootstrap chezmoi + structure repo
1. Installer chezmoi si absent (`sh -c "$(curl -fsLS get.chezmoi.io)"`), sinon utiliser l'existant.
2. `chezmoi init` (créer le repo source si nouveau). Configurer remote GitLab si l'utilisateur
   fournit l'URL (sinon laisser local, demander l'URL en une seule question).
3. Créer l'arborescence source state :
   ```
   ~/.local/share/chezmoi/
   ├── .chezmoi.toml.tmpl          # config + prompts (nom, email, remote)
   ├── .chezmoidata.toml           # données partagées (osid dérivé)
   ├── .chezmoiignore              # ignore par OS (ex: configs Mac sur WSL2)
   ├── .chezmoiscripts/
   │   ├── run_onchange_before_10-install-tools.sh.tmpl
   │   └── run_onchange_after_20-mise-install.sh.tmpl
   ├── dot_zshrc.tmpl              # shell : sections ordonnées, templaté OS (Phase 5bis)
   ├── dot_config/
   │   ├── starship.toml           # prompt, fichier unique sans variation OS
   │   ├── wezterm/wezterm.lua.tmpl
   │   ├── zellij/config.kdl
   │   ├── zellij/layouts/agent.kdl.tmpl
   │   ├── helix/config.toml
   │   ├── helix/languages.toml
   │   ├── yazi/                   # keymap + init
   │   └── lazygit/config.yml
   └── dot_config/mise/config.toml # versions des outils
   ```

## PHASE 2 — Installation de la toolchain (script chezmoi)
**Principe de gestion de paquets (arbitrage cyber tranché) : gestionnaire système NATIF par OS
pour les briques bas niveau, `mise` comme couche cross-OS pour les outils dev.**
PAS de Homebrew côté WSL2/Linux (couche Ruby + taps tiers = surface d'attaque élargie, et
Linuxbrew est un citoyen de seconde zone). Homebrew reste uniquement sur macOS, sa plateforme native.

Dans `run_onchange_before_10-install-tools.sh.tmpl`, brancher par OS :
- **darwin** : `brew install wezterm zellij helix yazi lazygit mise zsh` (Apple Silicon, `/opt/homebrew`).
  Homebrew sur macOS est légitime (déploiement de signatures via Sigstore en cours).
- **linux-debian / linux-wsl** :
  1. Briques système via **apt** : `zsh git curl build-essential` (paquets vérifiés par signature
     GPG des métadonnées de dépôt, modèle de confiance natif Debian).
  2. Outils dev via **mise** : installer mise d'abord, puis `mise use -g` pour zellij, helix, yazi,
     lazygit. mise télécharge les binaires officiels des projets → versioning identique entre OS,
     pas de dépendance Homebrew-Linux, et évite les paquets apt trop vieux pour ces outils récents.
  3. WezTerm côté **Windows** sous WSL2 (voir Phase 6) — NE PAS l'installer dans WSL.
- Rendre le script idempotent (tester `command -v` avant chaque install).
Dans `run_onchange_after_20-mise-install.sh.tmpl` : `mise install` pour matérialiser
`dot_config/mise/config.toml` (liste partagée entre les deux OS pour tout le dev).

**Vérification de provenance mise ACTIVE (ADR-0003, impératif — c'est la vraie surface)** :
commit `mise.lock` ET `mise settings lockfile=true` ⇒ checksums vérifiés à l'install (un lockfile
sans vérif active = décoratif). Le gate niveau 1 côté outils teste que la vérif est *on*, pas que
le fichier existe. Les **LSP** sont des outils mise comme les autres (même cycle), jamais
`curl|sh` ad hoc.

### Garde-fou sécurité dépôts tiers (Docker, HashiCorp, GitLab…)
Si un dépôt apt tiers doit être ajouté (ex. pour Terraform via apt plutôt que mise) :
- **JAMAIS** de clé dans le keyring global (`/etc/apt/trusted.gpg.d/` ou `apt-key`, déprécié
  depuis Ubuntu 22.04). Une clé globale = racine de confiance pour TOUTES les sources → si la clé
  privée du tiers fuite, l'attaquant peut contourner la vérification apt.
- **Pattern correct (2026)** : clé dans un keyring INDIVIDUEL sous `/etc/apt/keyrings/<vendor>.gpg`,
  référencée via l'option `Signed-By:` dans le fichier `.sources` de cette source uniquement.
- Préférer `mise` quand l'outil y est dispo : évite d'ajouter un dépôt tiers tout court.

## PHASE 3 — WezTerm (émulateur, template OS)
`wezterm.lua.tmpl` :
- Détecter OS via `wezterm.target_triple` côté Lua ET via chezmoi pour les valeurs injectées.
- Police : Hack Nerd Font (déjà installée). Taille adaptable par OS.
- **Clipboard** : natif WezTerm (gère OSC52), pas de hack pbcopy/clip.exe nécessaire pour la copie.
- Lancer Zellij automatiquement : `default_prog` →
  - darwin : `zellij`
  - wsl : depuis Windows, `wsl.exe -d <distro> -- zsh -lc zellij` (Phase 6).
- Thème cohérent avec Helix (ex. Catppuccin). Désactiver la confirmation de fermeture d'onglet.

## PHASE 4 — Zellij (multiplexer, cœur multi-agent + binds VS Code-like)
`config.kdl` :
- Garder la status bar de hints visible (argument clé du choix Zellij : pas de muscle memory).
- **Keybinds façon VS Code** (à remapper proprement, sans casser les défauts Zellij) :
  - Toggle terminal/pane : un bind dédié (équiv. `Ctrl+ù`).
  - Focus pane éditeur ↔ terminal : navigation Alt+flèches.
  - Toggle file-tree : ouvrir Yazi en **pane flottant** (équiv. toggle explorateur).
  - Nouveau pane dans le cwd courant (équiv. "ouvrir terminal ici").
- `layouts/agent.kdl.tmpl` : layout multi-agent reproduisant cmux :
  - pane principal : Helix
  - pane flottant : Yazi (file-tree souris)
  - pane bas : agent Claude Code
  - pane latéral optionnel : Lazygit
  - 1 tab = 1 tâche = 1 worktree = 1 agent.

## PHASE 5 — Helix + Yazi + Lazygit (éditeur & navigation)
`helix/config.toml` :
```toml
[editor]
line-number = "relative"
mouse = true                 # souris en backup
true-color = true
color-modes = true
bufferline = "multiple"      # onglets de buffers facon VS Code
[editor.file-picker]
hidden = false
[editor.cursor-shape]
insert = "bar"
normal = "block"
select = "underline"
[editor.auto-save]
focus-lost = true
```
- `languages.toml` : LSP pour Terraform (terraform-ls), Go (gopls), Python, Bash, YAML, Markdown
  (cohérent avec le stack IaC de l'utilisateur).
- **Pont Yazi → Helix** : configurer Yazi pour ouvrir le fichier sélectionné dans l'instance
  Helix via Zellij (ENTER ouvre dans le pane éditeur). Documenter la limite connue (Yazi démarre
  dans le cwd de lancement).
- `lazygit/config.yml` : thème accordé, intégration delta pour les diffs.

## PHASE 5bis — Shell (Zsh + Starship, migration depuis Oh-My-Zsh)
> PRÉREQUIS : exécuter d'abord le plan d'audit shell séparé (`PLAN_AUDIT_SHELL.md`) qui produit
> l'inventaire alias/fonctions/plugins. Intégrer ses résultats ici avant d'écrire le `.zshrc`.

Couche shell = vit DANS chaque pane Zellij (n'interfère ni avec WezTerm ni Zellij ni Helix).

`dot_zshrc.tmpl` structuré en sections ordonnées :
1. **Exports / PATH** — templaté OS :
   - darwin : `eval "$(/opt/homebrew/bin/brew shellenv)"`
   - linux : pas de brew ; PATH mise + ~/.local/bin
2. **Init outils** : `eval "$(mise activate zsh)"`, complétions.
3. **Sourcing plugins** (repos indépendants, PAS besoin d'OMZ) — ordre important :
   - `zsh-autosuggestions`
   - `zsh-syntax-highlighting` **toujours en DERNIER** (sinon coloration cassée)
4. **Prompt** : `eval "$(starship init zsh)"` **en tout dernier** (écrase tout thème résiduel).
5. **Bloc alias/fonctions custom** : recopié VERBATIM depuis l'audit (section "à moi").
6. **Alias OMZ regrettés** : uniquement ceux confirmés utilisés par l'audit (croisement historique),
   redéfinis à la main (ex. ceux du plugin git OMZ : gst/gco/gp… si réellement tapés).

`dot_config/starship.toml` : fichier unique, pas de variation OS. Migrer la config Starship existante.

**Décision DÉJÀ TRANCHÉE par ADR-0003 (ne PAS reposer la question)** : Zsh natif + **plugins
vendored clonés et épinglés au SHA** (`zsh-plugins.lock`), zéro plugin-manager. OMZ **et** antidote
sont écartés (MAJ opaque / surface). Toute remise en cause = superseding d'ADR-0003, pas un prompt.

Install en script `run_once_` :
- cloner `zsh-autosuggestions` et `zsh-syntax-highlighting` aux SHA du lockfile (pas de `git pull`).
- vérifier le SHA après clone (cf bloc Vérification d'ADR-0003) ; drift → STOP.
- complétion sur abréviations via quelques `compdef` à la main.

**Vérification post-migration (filet de sécurité, dans le script ou en check manuel)** :
```sh
# comparer l'ancien monde OMZ au nouveau
diff <(sort ~/omz-snapshot-aliases.txt) <(sort ~/native-aliases.txt)
```
Le diff ne doit plus contenir que des alias OMZ volontairement abandonnés. STOP et rapport sinon.

## PHASE 6 — Spécifique WSL2 (le point de portabilité critique)
- WezTerm tourne **côté Windows** (installé via winget : `winget install wez.wezterm`), pas dans WSL.
  Il lance le shell WSL → Helix/Zellij s'exécutent dans le Linux. (Remplace Remote-WSL de VS Code.)
- **Seam explicite (ADR-0008)** : la config WezTerm Windows (`wezterm.lua` côté Windows) est
  **hors du contexte chezmoi-WSL** (chezmoi ne gère que le `$HOME` Linux). Retenu : config WezTerm
  Windows **hors-scope chezmoi**, documentée au RUNBOOK ; chezmoi gère WezTerm **macOS** seul ; le
  `.lua` est factorisé (modèle partagé copié manuellement côté Windows). Ne pas prétendre "config
  émulateur identique 2 OS".
- Vérifier l'accès clipboard Windows↔WSL (WezTerm OSC52 gère ; sinon fallback `clip.exe`/`win32yank`).
- Nerd Font : déjà résolue côté utilisateur (installation cross-WSL/Windows OK).
- `.chezmoiignore` : ignorer les fichiers Windows-only quand on applique côté Linux, et inversement.
- Détecter WSL dans les scripts via `.chezmoi.kernel.osrelease | lower | contains "microsoft"`.

## PHASE 7 — Intégration agents Claude Code (notifications Zellij)
- Configurer les hooks Claude Code (`~/.claude/settings.json`, lui-même géré par chezmoi en
  `dot_claude/settings.json.tmpl`) :
  - `Notification` → `zellij action rename-tab` avec marqueur "ATTEND" (équiv. anneau cmux).
  - `Stop` → renommer en "FINI".
- Fournir un script `newagent <tache>` (dans `dot_local/bin/`) : crée un git worktree + une tab
  Zellij chargée avec `layouts/agent.kdl`, lance `claude`. Et `delagent` pour cleanup
  (`git worktree remove`).

## PHASE 7bis — Documentation des décisions (ADR) & modèle de menace
> Les ADR et le modèle de menace sont FOURNIS (voir dossier `dotfiles/docs/`). Claude Code les
> copie dans le source state, ne les régénère pas, et les tient à jour si un choix change.
- Copier `docs/adr/*` (0000→0008 + `_template.md` + `README.md`), `docs/THREAT-MODEL.md` et
  `docs/RUNBOOK.md` dans le source state chezmoi sous `docs/`.
- Règle permanente : toute décision technique nouvelle/modifiée ⇒ un ADR (MADR étendu) ou un
  superseding. Les ADR `security-relevant` référencent les IDs du THREAT-MODEL.
- Lint ADR (intégré à l'audit) : chaque ADR `security-relevant: true` doit avoir les 4 champs
  custom non vides (Menaces / Surface résiduelle / Revue / Vérification).

## PHASE 7ter — Sécurité par couche (mise en œuvre du rapport cyber)
> Synthèse actionnable. Pour CHAQUE choix : risques → mitigations (complexité) → reco appliquée.
> Détail complet et justifications dans les ADR référencés.

### Couche 1 — Shell & plugins (ADR-0003 ; menaces T-SC-01..05, T-CR-01)
- **Risque** : plugin sourcé au démarrage = RCE-by-design ; exfiltration credentials AWS/SSH/TF.
- **Mitigations** :
  - Pin SHA + lockfile `zsh-plugins.lock` — complexité FAIBLE — **APPLIQUÉ** (bloque MAJ furtive).
  - Rituel de bump manuel (diff/soak/tag signé) — complexité MOYENNE — **APPLIQUÉ** (RUNBOOK).
  - Gates déterministes scriptés (cross-witness) — complexité MOYENNE — **DIFFÉRÉ niveau 2** (ADR-0006).
  - Signature GPG des tags — complexité FAIBLE — **APPLIQUÉ** (TOFU 1re fois).
- **Reco contexte** : surface minimale (2 plugins) ; ne jamais réintroduire OMZ/antidote (MAJ opaque).

### Couche 2 — Outils & paquets (ADR-0002 routage, ADR-0003 confiance ; menaces T-SC-06..08, T-CR-02)
- **Risque** : clé apt globale = bypass vérif toutes sources ; binaire mise/LSP altéré ; secret commité.
- **Mitigations** :
  - apt natif (Linux) + brew (macOS) + mise (dev+LSP), source unique par outil — FAIBLE — **APPLIQUÉ**.
  - Keyrings individuels `/etc/apt/keyrings/` + `Signed-By:` — FAIBLE — **APPLIQUÉ** (impératif).
  - `mise.lock` + `lockfile=true` ⇒ checksums vérifiés à l'install — MOYENNE — **APPLIQUÉ** (T-SC-08 résiduel sur release trojanisée).
  - gitleaks pre-commit + CI — FAIBLE — **APPLIQUÉ**.
- **Reco contexte** : LSP = outils mise comme les autres (même cycle ADR-0003) ; trancher doublons → mise unique.

### Couche 3 — Agents IA (ADR-0004 ; menaces T-AG-01..04)
- **Risque** : prompt injection → exfil ; MCP compromis ; hook eval de sortie LLM ; destruction infra.
- **Mitigations** :
  - Permissions Claude Code deny/ask/allow (secrets en deny) — FAIBLE — **APPLIQUÉ**.
  - Sandbox OS (Seatbelt macOS / bubblewrap+socat Linux) — MOYENNE — **APPLIQUÉ**.
  - MCP allowlistés + épinglés + revus comme dépendance — MOYENNE — **APPLIQUÉ**.
  - Hooks à commandes fixes uniquement (jamais d'eval de contenu modèle) — FAIBLE — **APPLIQUÉ**.
  - Isolation 1 agent = 1 worktree — FAIBLE — **APPLIQUÉ**.
- **Reco contexte** : revue immédiate à chaque ajout de MCP ; ne jamais activer
  `--dangerously-skip-permissions` hors conteneur jetable.

## PHASE 7quater — Pipeline d'audit récurrent (ADR-0007) — NIVEAU 2, DIFFÉRÉ
> **Niveau 1 (socle) = uniquement `gitleaks` pre-commit + CI.** Le pipeline complet ci-dessous
> (gates scriptés, cross-witness) est la **cible niveau 2**, construite seulement au franchissement
> du critère ADR-0006. Ne pas le bâtir d'emblée. Même script pre-commit (warn) et CI (bloquant).
- Créer `audit/run.sh --mode {pre-commit|ci}` qui orchestre :
  - `audit/scan/` : gitleaks/regex secrets, scan heuristique diff plugins.
  - `audit/gates/` : SHA==lockfile, soak time, `git tag -v`, cross-witness tree-hash,
    drift Brewfile/mise, pas de clé apt globale, deny secrets Claude, MCP ∈ allowlist, lint ADR.
- **pre-commit** (hook chezmoi `run_once_` installe le hook) : checks "cheap", **n'échoue jamais**,
  imprime des warnings. Contournable par conception (`--no-verify`).
- **CI** (`.gitlab-ci.yml` dans le repo dotfiles) : audit complet, **échoue** si gate bloquant rouge.
  Source de vérité : rien sur `main` avec un gate rouge.
- Matrice complète des checks (pre-commit vs CI, warn vs bloquant) : voir ADR-0007.
- À chaque exécution : évaluer le **critère de bascule Nix** (ADR-0006, compteur de conditions ≥ 2).

## PHASE 8 — Vérification & commit
1. `chezmoi diff` puis `chezmoi apply` (en plan : montrer le diff avant apply).
2. Test à blanc : lancer WezTerm → Zellij → layout agent → ouvrir Helix + Yazi + Lazygit.
2bis. **Smoke-test machine neuve scriptable** : un `doctor.sh` vérifie binaires présents, SHA
   plugins == lockfile, vérif provenance mise active, sandbox agent qui tourne réellement
   (ADR-0004), deny secrets Claude présents. C'est le filet "ça marche vraiment", pas l'œil.
   Détail `doctor.sh` : RUNBOOK.
2ter. **Rollback documenté (ADR-0006)** : RUNBOOK couvre `git revert` du source state + apply, et le
   cas apply cassé à mi-course (scripts idempotents, snapshot conf critiques avant bump).
3. Niveau 1 : `gitleaks` + checks cheap. (CI complète / gates scriptés = niveau 2 différé, ADR-0003/0007.)
4. Vérifier que les binds VS Code-like répondent.
5. `chezmoi cd && git add -A && git commit` — **STOP avant push** (push en `ask`, validation humaine).
   Forge = GitLab, modèle MR + CI avec porte de sortie trunk (ADR-0007).
6. Produire un README dans le repo : commande d'install one-liner pour une nouvelle machine
   (`sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply <user>/<repo>`), et la liste des binds.
7. Le `docs/adr/` et `docs/THREAT-MODEL.md` sont versionnés dans le repo (déjà fournis).

---

## Garde-fous pour Claude Code
- Tout fichier ciblant `~` doit être créé/édité **dans le source state chezmoi**, jamais en direct.
- Avant tout `apply`, montrer `chezmoi diff`. Ne pas appliquer sans validation en plan mode.
- `git push` et toute commande réseau d'install : en mode `ask`.
- Idempotence obligatoire : chaque script teste l'existant avant d'agir.
- Si un binaire n'est pas dispo sur un OS (ex. WezTerm dans WSL), ne pas l'installer côté Linux ;
  documenter la procédure Windows à la place.
- **Secrets & creds (ADR-0005)** : secrets statiques via **Bitwarden CLI** (templates `*.tmpl`
  `{{ (bitwarden ...) }}`, rendus au `apply`, jamais committés, IDs-only dans git) ; **accès AWS via
  SSO/granted, zéro clé statique**. Bootstrap : `bw unlock` AVANT le 1er apply (ordre cold-start :
  RUNBOOK). Ne JAMAIS committer un secret en clair.
