# Note — pourquoi la dimension Santé ne peut pas reposer sur la seule assurance maladie

*20 août 2026 — IPM Côte d'Ivoire, EHCVM 2021*

## 1. Le point de départ

Le tableau de référence place dans la dimension Santé un indicateur de **mortalité juvénile**.
L'EHCVM ne permet pas de le construire : l'enquête n'a ni module décès ni historique des
naissances, et la base `Base_chocs` enregistre bien « décès d'un membre du ménage » (1 328 ménages
sur trois ans) mais **sans l'âge du défunt**. Impossible d'isoler les moins de 18 ans.

La dimension a donc d'abord été mesurée par un seul indicateur de substitution :
**aucun membre du ménage n'est couvert par une assurance maladie** (question 3.32, renseignée à
100 %). Le choix se défendait : couverture complète, aucun biais de sélection, lecture directe.

## 2. Le problème

Avec 4 dimensions équipondérées à 0,25, un indicateur seul dans sa dimension **porte tout son
poids**. Or 93,4 % des ménages n'ont aucun membre assuré.

Deux conséquences arithmétiques, pas statistiques :

**a) L'indicateur dominait le score.** L'assurance maladie apportait en moyenne **0,2336** sur un
score moyen de 0,4603, soit **50,8 % du score de privation** à elle seule. Les douze autres
indicateurs se partageaient l'autre moitié.

**b) Elle fonctionnait comme un laissez-passer vers le seuil de pauvreté.** Un ménage non assuré
part déjà à 0,25 sur les 0,3333 requis. Deux privations de conditions de vie (2 × 0,0417 = 0,0833)
suffisent alors à franchir exactement k. **403 ménages** étaient dans ce cas précis, et 396 se
retrouvaient au score exactement égal au seuil — un ménage sur trente basculait sur une différence
de troisième décimale.

**c) Le résultat n'était pas plausible.** Simulation en retirant l'indicateur et en renormalisant
les poids :

| Configuration | H (population pauvre) |
|---|---|
| 13 indicateurs dont assurance seule en Santé | **79,7 %** |
| Les mêmes, sans l'assurance maladie | **45,7 %** |

Le second ordre de grandeur est celui publié pour la Côte d'Ivoire dans la table globale de l'OPHI
(H ≈ 46 %). Le premier ne l'est pas. Un indicateur qui prive 93 % de la population ne discrimine
plus : il déplace le niveau de l'indice sans rien apprendre sur qui est pauvre.

Ce n'était pas une erreur de calcul — le code appliquait fidèlement les choix actés. C'était la
rencontre de deux décisions qui se combinent mal : **substituer l'assurance maladie à la mortalité
juvénile** et **garder quatre dimensions équipondérées**.

## 3. La décision

Ajouter un **second indicateur dans la dimension Santé** : l'insécurité alimentaire mesurée par
l'échelle **FIES** de la FAO (section 8A de l'EHCVM, 8 questions oui/non sur 12 mois, score 0-8),
seuil **score ≥ 4** = insécurité modérée ou sévère, seuil standardisé de l'**indicateur ODD 2.1.2**.

Justification de fond, et pas seulement d'opportunité : dans l'IPM mondial, la dimension Santé est
composée de la **nutrition** et de la mortalité juvénile. Remplacer la seconde (impossible) par une
mesure de la première ne dénature pas la dimension — c'est son autre pilier officiel.

La dimension Santé compte désormais 2 indicateurs à **0,125** chacun. Le poids de l'assurance
maladie est mécaniquement divisé par deux.

### Effet mesuré

| | Avant (assurance seule) | Après (assurance + FIES) |
|---|---|---|
| Poids de l'assurance maladie | 0,2500 | **0,1250** |
| Part de l'assurance dans le score moyen | 50,8 % | **29,4 %** |
| Score moyen | 0,4603 | 0,3968 |
| **H — incidence** | 79,7 % | **65,8 %** |
| Vulnérables | 12,7 % | 19,1 % |
| Pauvreté sévère | 44,0 % | 26,8 % |
| Ménages au score exactement égal à k | 396 | 928 |

### Pourquoi le FIES et pas autre chose

Sa distribution le sépare nettement de l'assurance maladie :

| Score FIES | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 |
|---|---|---|---|---|---|---|---|---|---|
| Part des ménages | 30,5 % | 7,5 % | 7,8 % | 10,1 % | 9,2 % | 9,8 % | 7,9 % | 8,5 % | 7,4 % |

Un tiers des ménages à zéro, le reste étalé sur toute l'échelle. L'assurance maladie, elle, oppose
93,4 % à 6,6 % : elle sépare mal parce qu'elle ne varie presque pas.

Taux de privation retenu : **42,7 % des ménages, 40,8 % de la population** (score ≥ 4).

## 4. Limites assumées

- Le FIES mesure l'**insécurité alimentaire vécue**, pas l'état nutritionnel. L'OPHI mesure la
  nutrition par l'**anthropométrie** (IMC, retard de croissance) ; l'EHCVM n'a pas de module
  anthropométrique. Le FIES est le meilleur substitut disponible, pas un équivalent.
- C'est du **déclaratif rétrospectif sur 12 mois**, sensible à la saison de collecte. Nos deux
  vagues sont collectées à des saisons différentes : à surveiller.
- **195 ménages (1,5 %)** n'ont pas de score complet (NSP/Refus). Ils sont traités comme non
  privés, conformément à la convention générale du pipeline (voir `METHODOLOGIE.md`, § 4).

## 5. Ce qui reste ouvert

**H = 65,8 % demeure au-dessus de l'ordre de grandeur de référence (≈ 46 %).** L'assurance maladie
pèse encore 29,4 % du score moyen — moins qu'avant, mais beaucoup pour un indicateur qui prive
93 % des ménages. Trois leviers restent disponibles, non tranchés à ce jour :

1. **Abandonner l'assurance maladie** et ne garder que le FIES en Santé. Cohérent avec le constat
   qu'un indicateur à 93 % n'informe pas, mais laisse la dimension sur une seule jambe.
2. **Rééquilibrer les dimensions** : rien n'oblige à quatre dimensions égales. L'IPM mondial en a
   trois (Santé, Éducation, Niveau de vie) à 1/3.
3. **Revoir d'autres seuils** dans le même esprit : l'année de scolarité (72,5 %), l'énergie de
   cuisson (76,8 %) et les toilettes (77,3 %) privent aussi une large majorité des ménages.

Ces arbitrages relèvent du cadrage, pas du code : chacun se change en une ligne dans
`pipeline/02_construction_matrice_situationnelle.py`.
