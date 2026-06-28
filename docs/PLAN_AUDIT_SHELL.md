# PLAN — Audit shell (Oh-My-Zsh → Zsh natif)

> **Prérequis de la Phase 5bis** (PLAN_SETUP_TUI). À exécuter **sur la machine réelle**
> avant de remplir les sections 5 et 6 de `dot_zshrc.tmpl`. Ne peut pas tourner dans le
> conteneur cloud (nécessite le `~/.zshrc`, `~/.oh-my-zsh` et l'historique de l'utilisateur).

## Objectif
Inventorier ce qui est réellement utilisé dans le setup Oh-My-Zsh actuel, pour ne porter vers
le `.zshrc` natif **que** les alias/fonctions/plugins utiles — pas tout OMZ. Décision déjà
tranchée (ADR-0003) : Zsh natif + 2 plugins vendored épinglés, zéro plugin-manager.

## Procédure

### 1. Snapshot de l'existant
```sh
# Alias et fonctions effectivement chargés dans le shell courant
alias | sort > ~/omz-snapshot-aliases.txt
print -l ${(k)functions} | sort > ~/omz-snapshot-functions.txt
# Plugins OMZ activés
grep -E '^\s*plugins=' ~/.zshrc > ~/omz-plugins.txt || true
```

### 2. Croisement avec l'usage réel (historique)
```sh
# Top des commandes tapées — pour savoir quels alias OMZ sont vraiment utilisés
fc -l 1 | awk '{print $2}' | sort | uniq -c | sort -rn | head -50 > ~/omz-usage.txt
```
Croiser `omz-usage.txt` avec `omz-snapshot-aliases.txt` : ne retenir que les alias OMZ
(ex. plugin git : `gst`/`gco`/`gp`…) qui apparaissent réellement dans l'historique.

### 3. Séparer "à moi" vs "fourni par OMZ"
- Bloc **"à moi"** : alias/fonctions définis par l'utilisateur dans `~/.zshrc`/`~/.zsh/` →
  recopiés **verbatim** en section 5 de `dot_zshrc.tmpl`.
- Bloc **OMZ regrettés** : uniquement les alias OMZ confirmés par l'étape 2 → **redéfinis à la
  main** en section 6 (ne PAS réintroduire OMZ).

### 4. Intégration
Remplir les sections 5 et 6 de `dot_zshrc.tmpl`, puis `chezmoi apply`.

### 5. Filet de sécurité (vérification post-migration)
```sh
alias | sort > ~/native-aliases.txt
diff <(sort ~/omz-snapshot-aliases.txt) <(sort ~/native-aliases.txt)
```
Le diff ne doit plus contenir que des alias OMZ **volontairement abandonnés**. Sinon : STOP,
compléter la section 6, recommencer.

## Sortie attendue
- Sections 5 et 6 de `dot_zshrc.tmpl` remplies.
- `~/omz-snapshot-*.txt` conservés le temps de la migration (jetables ensuite).
