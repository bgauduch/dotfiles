---
status: accepted
date: 2026-06-28
decision-makers: [Baptiste]
consulted: []
informed: []
---

# ADR-0000 — Processus de décision (ADR) & conventions du dépôt dotfiles chezmoi

> ADR "méta" : il ne décrit pas un choix technique du setup, mais **comment les choix sont
> tracés** dans ce dépôt, et **comment le dépôt cible chezmoi est structuré** pour accueillir
> les décisions présentes et futures. À lire en premier.

## Contexte et énoncé du problème

Ce dépôt gère un environnement de développement portable (macOS + WSL2/Debian) via chezmoi :
shell (Zsh natif), multiplexer (Zellij), éditeur (Helix), émulateur (WezTerm), outils
(apt/brew + mise), et agents IA (Claude Code, MCP, hooks). Les décisions structurantes touchent
à la sécurité supply-chain et doivent rester traçables dans le temps : pourquoi un plugin est
épinglé à tel SHA, pourquoi apt plutôt que Homebrew côté Linux, pourquoi tel niveau
d'immutabilité. Sans traçabilité, ces choix deviennent du folklore et personne (toi inclus dans
6 mois) ne sait s'ils sont encore valides.

**Décision : adopter MADR (Markdown Any Decision Records) étendu de 4 champs propres à notre
contexte shell/outillage/sécurité, et figer les conventions du dépôt chezmoi ci-dessous.**

## Décision : format ADR = MADR étendu

MADR standard couvre : contexte, drivers de décision, options considérées, issue/décision,
conséquences (bonnes/mauvaises), confirmation. C'est suffisant pour des décisions d'archi
classiques, mais il manque des slots pour ce qui est central dans un setup orienté supply-chain.
On ajoute donc 4 champs custom (optionnels pour les ADR non-sécu, obligatoires pour les ADR
marqués `security-relevant: true` dans le front-matter) :

| Champ ajouté | Rôle | Pourquoi MADR standard ne suffit pas |
|---|---|---|
| **Menaces adressées** | lister les scénarios d'attaque que la décision contre (réf. modèle de menace) | MADR n'a pas de lien explicite décision → menace |
| **Surface d'attaque résiduelle** | ce que la décision NE protège PAS (honnêteté) | éviter le faux sentiment de sécurité |
| **Revue / expiration** | date ou trigger de re-revue obligatoire | une décision sécu se périme ; MADR est atemporel |
| **Vérification** | commande/procédure concrète qui prouve que la décision est en vigueur | rendre la décision testable, pas déclarative |

Front-matter étendu de chaque ADR :
```yaml
---
status: proposed | accepted | rejected | deprecated | superseded by ADR-XXXX
date: YYYY-MM-DD
decision-makers: [...]
security-relevant: true | false     # si true, les 4 champs custom sont obligatoires
review-by: YYYY-MM-DD | trigger:<événement>   # ex: trigger:bump-plugin
supersedes: [ADR-XXXX]              # optionnel
---
```

### Pourquoi pas Nygard simple
Nygard (contexte / décision / conséquences) est plus léger mais n'a ni options comparées ni
champs sécu. Pour des décisions où le "pourquoi pas l'autre option" est le cœur de la valeur
(apt vs brew, vendored vs package-manager, pin-SHA vs latest), perdre la colonne "options
considérées" appauvrit la trace. MADR étendu est le bon compromis.

## Décision : granularité des ADR

Quatre types d'ADR, marqués dans la colonne *Type* du README :
- **méta** : ne trace pas un choix technique du setup mais le *processus* de décision et les
  conventions du dépôt (cet ADR-0000). Un seul attendu.
- **doctrine** : règle transverse durable qui s'applique à plusieurs sujets (ex. routage des
  paquets ADR-0002, cycle de confiance ADR-0003). Évite de répéter la même règle par sujet.
- **granulaire** : un choix structurant = un fichier (voir ci-dessous).
- **groupé** : une famille de choix cohérents = un fichier (voir ci-dessous).

- **ADR granulaire (1 décision = 1 fichier)** pour les choix structurants : gestion de paquets,
  modèle de plugins, immutabilité, agents IA, pipeline d'audit. Ce sont les décisions à fort
  "pourquoi" et à conséquences sécu.
- **ADR groupé (1 fichier = une famille de choix)** pour les listes : inventaire d'outils
  (Brewfile), runtimes mise, liste de plugins. Le "pourquoi" est partagé ; détailler chaque
  outil en ADR séparé serait du bruit. Le détail vit dans le fichier de conf (Brewfile,
  mise.toml, zsh-plugins.lock), l'ADR groupé porte la *politique* (critère d'inclusion/exclusion).

## Décision : structure du dépôt cible chezmoi

```
~/.local/share/chezmoi/                 # source state (= ce repo git)
├── docs/
│   ├── adr/                            # tous les ADR (ce dossier)
│   │   ├── 0000-adr-process-and-repo-conventions.md   # cet ADR
│   │   ├── 0001-*.md ...              # ADR de choix
│   │   └── _template.md               # gabarit MADR étendu
│   ├── THREAT-MODEL.md                # modèle de menace 3 couches (réf. par les ADR)
│   └── RUNBOOK.md                     # procédures (bump plugin, rotation, incident)
├── .chezmoi.toml.tmpl                 # prompts d'init (nom, email, remote)
├── .chezmoidata.toml                  # données partagées (osid dérivé)
├── .chezmoiignore                     # ignore par OS
├── .chezmoiscripts/                   # scripts run_once_ / run_onchange_
├── dot_config/                        # configs (wezterm, zellij, helix, yazi, lazygit, starship, mise)
├── dot_zshrc.tmpl                     # shell, templaté OS
├── dot_local/
│   ├── bin/                           # scripts perso (newagent, audit, install-zsh-plugins)
│   └── share/zsh/plugins/             # plugins vendored (gérés par lockfile, voir ADR-0003)
├── zsh-plugins.lock                   # lockfile plugins (repo + SHA + tag + date revue)
├── Brewfile.tmpl                      # outils macOS (voir ADR groupé outils)
└── audit/                             # pipeline d'audit récurrent (voir ADR-0007)
    ├── gates/                         # gates déterministes (soak, signature, cross-witness)
    └── scan/                          # scan heuristique diff
```

### Conventions
- **Une décision technique nouvelle ou modifiée ⇒ un ADR** (ou mise à jour d'un existant via
  `status: superseded by`). Pas de choix structurant non tracé.
- **Décision durable vs état mouvant.** Un ADR trace une **décision structurante durable** (un
  choix, une doctrine, un principe qui survit dans le temps). Un **état mouvant** — liste d'outils,
  versions, inventaire, ce qui change au fil des projets — ne va PAS dans un ADR : il vit dans un
  **fichier de conf versionné** (`Brewfile`, `mise.toml`, `zsh-plugins.lock`), auto-documenté, et
  l'ADR n'y fait que référence. Règle de discrimination : *choisir Helix = décision (ADR) ; lister
  les 40 outils installés = état (fichier de conf)*. Tracer un état en ADR le périme dès la première
  modification et pollue l'historique de décisions avec du bruit de maintenance.
- **Numérotation** : `NNNN-titre-kebab.md`, incrémentale, jamais réutilisée (un ADR déprécié
  reste, on ne supprime pas l'historique).
- **Immutabilité de l'historique** : un ADR accepté n'est pas réécrit ; il est *superseded* par
  un nouveau. La trace du "pourquoi on pensait ça à l'époque" est la valeur.
- **Lien ADR ↔ menace** : tout ADR `security-relevant` référence les IDs de menace de
  `docs/THREAT-MODEL.md` dans son champ "Menaces adressées".
- **Templating chezmoi** : différences OS via `.tmpl` + `{{ if eq .chezmoi.os ... }}`, jamais
  de fichiers dupliqués par OS. Détection WSL via `.chezmoi.kernel.osrelease | lower | contains "microsoft"`.
- **Secrets** : jamais en clair dans le repo ; références Bitwarden CLI / SSO AWS (ADR-0005).

## Conséquences
- Bonnes : traçabilité durable, onboarding d'une nouvelle machine documenté, décisions sécu
  re-revues à date, format standard outillable (lint MADR possible en CI).
- Mauvaises : discipline requise (chaque choix = un ADR) ; léger surcoût rédactionnel. Accepté :
  le coût d'un setup non tracé est plus élevé sur la durée.

## Revue / expiration
`review-by: trigger:nouvelle-couche` — revoir ces conventions si une 4e couche est ajoutée
(ex. gestion de secrets dédiée, ou bascule Nix qui changerait la structure du repo).

## Vérification
- L'index `README.md` est la source de vérité de la liste des ADR (PAS de compteur en dur ici :
  le nombre d'ADR est un état mouvant, il ne se trace pas dans un ADR).
- Chaque ADR `security-relevant: true` a les 4 champs custom non vides (lint possible).
