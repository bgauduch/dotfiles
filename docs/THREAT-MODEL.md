# THREAT MODEL — Environnement shell + outillage + agents IA

> Référencé par les ADR `security-relevant`. Chaque menace a un ID stable utilisé dans le champ
> "Menaces adressées" des ADR. Périmètre : les 3 couches (shell, outils, agents IA).
> Profil de l'actif : poste freelance Cloud/IaC détenant credentials AWS (multi-comptes), SSH,
> état Terraform, tokens GitLab/GitHub, configs agents IA. Cible nommée par les campagnes 2026.

## Modèle d'adversaire
- **Opportuniste supply-chain** : compromet une dépendance populaire en amont (le plus probable,
  cf campagnes 2026 axios/node-ipc/Shai-Hulud). N'a pas ciblé Baptiste personnellement.
- **Ciblé** : connaît le profil (freelance Cloud), vise les credentials. Moins probable, impact élevé.
- **Injection via agent IA** : pilote un agent par contenu malveillant (prompt injection) pour
  exfiltrer ou détruire.

## Couche 1 — Shell & plugins

| ID | Menace | Vecteur | ADR couvrant |
|---|---|---|---|
| T-SC-01 | Plugin shell compromis en amont | MAJ d'un plugin sourcé au démarrage | 0003, 0007 |
| T-SC-02 | Release vérolée fraîche, fenêtre courte | bump sur un HEAD récent piégé | 0003 |
| T-SC-03 | Compte mainteneur compromis, publication hors CI | release manuelle malveillante | 0003 |
| T-SC-04 | Dépendance non validée / dormante réveillée | résolution dynamique de version | 0003, 0006 |
| T-SC-05 | Build trojanisé à provenance valide (type Miasma) | CI mainteneur compromise, SLSA valide mais malveillant | 0003 |
| T-CR-01 | Exfiltration credentials via hook preexec/precmd | plugin hooke le shell, lit $AWS_*/$*_TOKEN | 0003, 0004 |

## Couche 2 — Outils & gestion de paquets

| ID | Menace | Vecteur | ADR couvrant |
|---|---|---|---|
| T-SC-06 | Bypass vérif apt via clé globale | dépôt tiers ajouté en keyring global | 0002 |
| T-SC-07 | Paquet obsolète avec CVE non patchée | version trop ancienne faute de source à jour | 0002 |
| T-CR-02 | Secret commité en clair dans le repo dotfiles | erreur humaine, .env ajouté | 0007 |
| T-CR-03 | Provisioning : secret en clair par erreur ou geste secret implicite oublié | template mal rendu / bootstrap non tracé | 0005 |
| T-SC-08 | Binaire mise/LSP altéré au téléchargement | release GitHub compromise, vérif provenance partielle | 0003 |

> Note : les serveurs LSP installés par mise relèvent de cette couche (outils) et du cycle de
> confiance ADR-0003 — pas d'une couche séparée.

## Couche 3 — Agents IA

| ID | Menace | Vecteur | ADR couvrant |
|---|---|---|---|
| T-AG-01 | Prompt injection → exfiltration credentials | contenu piégé lu par l'agent | 0004 |
| T-AG-02 | MCP server malveillant ou compromis | ajout/MAJ d'un MCP non validé | 0004 |
| T-AG-03 | Hook exécutant du contenu dérivé du modèle | hook qui eval une sortie LLM | 0004 |
| T-AG-04 | Destruction d'infra par un agent | terraform destroy / git push --force piloté | 0004 |

> **Lecture de la colonne « ADR couvrant »** : elle liste le(s) contrôle(s) **préventif(s)
> primaire(s)**. La **détection de dérive** (audit récurrent ADR-0007) s'applique *en plus* à
> T-SC-01..07, T-CR-02 et T-AG-02 ; non répétée ligne par ligne pour garder le tableau lisible.

## Hypothèses & hors-périmètre
- **Hors périmètre** : compromission physique de la machine, malware OS hors écosystème dev,
  attaque réseau MITM sur TLS (supposé sain), compromission du compte Anthropic/GitLab/Bitwarden en amont.
- **Hypothèse** : la machine est saine au moment du bootstrap initial.
- **Limite assumée** (cf ADR-0003) : aucun scan statique ne prouve l'innocuité d'un script ;
  la défense est en profondeur (pin + soak + sandbox), pas une garantie.

## Priorisation (risque = probabilité × impact)
1. **T-SC-01 / T-CR-01** (plugin compromis → exfil credentials) : proba moyenne-haute (campagnes
   actives), impact critique. → ADR-0003 (pin) + ADR-0004 (sandbox).
2. **T-SC-08 / T-AG-01 / T-AG-02** (binaires mise/LSP + agents IA) : surface large et active, proba
   moyenne (pattern campagnes 2026 = release compromise), impact critique. → ADR-0003 + ADR-0004.
   Note : les binaires/LSP via mise sont plus exposés que les 2 plugins zsh ; effort réaligné.
3. **T-SC-06 / T-CR-02 / T-CR-03** (config & secrets) : proba moyenne, impact élevé. → ADR-0002/0007/0005.
4. Le reste : proba faible ou impact contenu.
