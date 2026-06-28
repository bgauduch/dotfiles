---
status: proposed
date: YYYY-MM-DD
decision-makers: [Baptiste]
security-relevant: false        # true => les 4 champs sécu en bas sont obligatoires
review-by: YYYY-MM-DD           # ou trigger:<événement>
supersedes: []
---

# ADR-NNNN — <titre court de la décision>

## Contexte et énoncé du problème
<Quel problème, quelles contraintes (cross-OS macOS/WSL2, supply-chain, etc.).>

## Drivers de décision
- <critère 1, ex. portabilité>
- <critère 2, ex. surface d'attaque minimale>
- <critère 3, ex. simplicité de maintenance>

## Options considérées
- Option A — <nom>
- Option B — <nom>
- Option C — <nom>

## Décision
<Option retenue + justification en 2-4 phrases.>

## Conséquences
- Bonnes : <...>
- Mauvaises / coûts acceptés : <...>

## Comparatif (optionnel)
| Critère | Option A | Option B | Option C |
|---|---|---|---|

---
<!-- Champs ci-dessous OBLIGATOIRES si security-relevant: true -->

## Menaces adressées
<IDs depuis docs/THREAT-MODEL.md, ex. T-SC-01 (plugin compromis), T-AG-01 (agent exfiltration).>

## Surface d'attaque résiduelle
<Ce que cette décision NE protège pas. Honnêteté > faux confort.>

## Revue / expiration
<Date ou trigger de re-revue. Pourquoi cette décision peut se périmer.>

## Vérification
<Commande(s) concrète(s) prouvant que la décision est en vigueur sur la machine.>
