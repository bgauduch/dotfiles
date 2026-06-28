# RUNBOOK — Procédures opérationnelles (le "comment")

> Les ADR fixent le **quoi + pourquoi** (décisions durables). Ce RUNBOOK porte le **comment**
> (état mouvant : commandes, étapes, ordres d'exécution). Règle de séparation : cf ADR-0000.
> Aucune décision ici ; si une procédure révèle un choix structurant, il remonte en ADR.

## Bootstrap machine neuve (ordre impératif)
1. **Secrets d'abord** (ADR-0005) : `bw login` + `bw unlock`, exporter la session `BW_SESSION`.
   - Cold-start : si le repo dotfiles est privé, le cloner en **HTTPS + token** (récupéré du vault
     via `bw`) AVANT d'avoir une clé SSH ; la clé SSH est ensuite rendue par chezmoi. Évite le
     deadlock clé-SSH ⇄ repo.
2. **AWS** (ADR-0005) : `aws sso login` (ou `granted`) par profil ; aucune clé statique sur disque.
3. **chezmoi** : `sh -c "$(curl -fsLS get.chezmoi.io)"` puis `chezmoi init --apply <repo>`.
   - Racine de confiance : machine supposée saine au bootstrap initial (TOFU assumé, cf
     THREAT-MODEL § Hypothèses). Pas de checksum à comparer ici — le dépôt, source des pins, n'est
     pas encore cloné. L'épinglage/checksum s'applique aux **bumps ultérieurs** (ADR-0003).
4. **Smoke-test** : `doctor.sh` (cf plus bas).

## Rituel de bump d'une dépendance (décision : ADR-0003)
À jouer pour tout bump de plugin vendored / outil mise / LSP / serveur MCP :
1. `git log --oneline <ancien>..<nouveau>` sur l'upstream : revue des commits introduits.
2. Diff de revue ciblée : présence de `curl|wget|nc`, `base64 -d`, lectures de `$AWS_*`/`$*_TOKEN`/
   `~/.ssh`, hooks `precmd`/`preexec`, `curl|sh`, `chmod`/`crontab`.
3. Vérifier la signature quand dispo (`git tag -v`, GPG mainteneur).
4. **Soak** : laisser passer le délai d'attente (cf ADR-0003) avant d'épingler une release fraîche.
5. Mettre à jour le pin : SHA dans `zsh-plugins.lock` (plugins) ou `mise.lock` (outils/LSP).
6. Re-cloner / réinstaller au pin, vérifier le SHA/checksum post-install ; drift ⇒ STOP.

> Gates *scriptés* (cross-witness tree-hash, etc.) = niveau 2, non construits (ADR-0003/0006).

## Sandbox agents IA (décision : ADR-0004)
- Lancer un agent en périmètre restreint : profil bubblewrap (Linux/WSL2) / `sandbox-exec` (macOS).
- Proxy réseau sortant filtré via socat selon le profil.
- **Vérifier que la sandbox tourne réellement** (ne pas l'assumer) : check de démarrage dans
  `doctor.sh` ; si le profil ne s'applique pas (WSL2 user-namespaces, Seatbelt déprécié), l'agent
  ne démarre PAS en mode "sandbox supposée".
- 1 agent = 1 worktree = 1 branche (périmètre fichiers borné).

## Schémas LSP (Crossplane/K8s) — arbitrage réseau (ADR-0003)
Pour valider/autocompléter les CRD sans appel réseau live : déposer les schémas JSON CRD+K8s en
local et pointer `yaml-language-server` dessus. Sinon, laisser la résolution distante (arbitrage
devex assumé, pas un gate).

## doctor.sh — smoke-test machine neuve
Vérifie : binaires présents ; SHA plugins == `zsh-plugins.lock` ; `mise settings` montre
`lockfile=true` + `mise.lock` présent ; sandbox agent démarre réellement ; deny-rules Claude
présentes ; aucun secret en clair rendu hors `*.tmpl`.

## Rollback (niveau 1-2, sans Nix — ADR-0006)
- État nominal : `chezmoi cd && git revert <commit> && chezmoi apply`.
- Apply cassé à mi-course (script `run_onchange_` échoué ⇒ état hybride) : chezmoi n'est pas
  atomique. Scripts idempotents (réexécutables) ; `chezmoi diff`/`--dry-run` obligatoire avant
  apply ; snapshot des confs critiques (`.zshrc`, `mise.toml`) avant bump. Ne jamais bumper la
  machine principale en plein travail.

## Stack TUI — détail vivant (ADR-0008)
Configs dans `dot_config/{wezterm,zellij,helix,yazi,lazygit}/`. Binds VS Code-like et layout agent
Zellij (`layouts/agent.kdl`). Côté WSL2 : WezTerm installé sur Windows (`winget install wez.wezterm`),
sa config `wezterm.lua` Windows est hors chezmoi (cf seam ADR-0008).
