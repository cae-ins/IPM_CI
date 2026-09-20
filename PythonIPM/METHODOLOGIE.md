# Méthodologie — IPM Côte d'Ivoire sur l'EHCVM 2021 et le RGPH 2021

Journal de méthode du pipeline `PythonIPM`. Il retrace les sources, les définitions retenues, les
écarts assumés et les conventions de calcul. À tenir à jour à chaque étape.

*Dernière mise à jour : 11 septembre 2026 — le pipeline calcule l'IPM sur DEUX sources, l'EHCVM 2021 (16 indicateurs) et le RGPH 2021 (13 indicateurs), plus une variante harmonisée comparable entre les deux.*

Le pipeline tourne sur deux sources, avec le même code à partir de l'étape 02. La source est portée
par la variable d'environnement `IPM_SOURCE` (`ehcvm` par défaut) ; elle détermine le dossier de
données, la clé du ménage, les désagrégations disponibles et le suffixe de tous les fichiers
produits, si bien que les deux séries de sorties cohabitent.

```
python pipeline/orchestrateur.py                  # les deux IPM, l'un après l'autre
python pipeline/orchestrateur.py --source rgph    # le RGPH seul
```

---

## 1. Sources

Enquête harmonisée sur les conditions de vie des ménages (EHCVM) 2021, Côte d'Ivoire, deux vagues
(vague 1 fin 2021, vague 2 début 2022). Quatre bases sur les 21 du dossier `EHCVM/` sont utilisées.

| Base | Lignes | Une ligne = | Rôle |
|---|---|---|---|
| `Base_Individus.dta` | 64 491 | un membre du ménage | éducation, emploi, état civil, santé |
| `Base_Menage.dta` | 12 965 | un ménage | conditions de vie, pondérations, désagrégation |
| `Base_avoirs_du_menage.dta` | 583 425 | un bien proposé au ménage (45 par ménage) | biens d'équipement |
| `Base_securite_alimentaire.dta` | 13 693 | un ménage | variante santé (FIES), non retenue |

**Clé de fusion** : `grappe` + `menage` + `vague`. Les quatre bases couvrent exactement les mêmes
**12 965 ménages**, la fusion se fait donc sans perte (jointures en `validate="1:1"`).

**Nettoyage** : `Base_securite_alimentaire.dta` contient 728 lignes entièrement vides (clé `NaN`),
supprimées avant toute fusion.

Les noms de variables explicites (`s11q54` → `type_sanitaire`) sont centralisés dans
[`dictionnaire_ehcvm.py`](dictionnaire_ehcvm.py) : 108 colonnes documentées, avec le numéro de
question du questionnaire CAPI en commentaire.

### 1 bis. Source RGPH 2021

Recensement général de la population et de l'habitation 2021. Trois fichiers du dossier
`Data/RGPH_IPM/`.

| Base | Lignes | Une ligne = | Rôle |
|---|---|---|---|
| `IPM_Data_191125.dta` | 27 984 405 | un individu (5 616 487 ménages) | éducation, emploi, état civil, démographie |
| `IPM_Data_110924_men.dta` | 5 528 535 | un ménage (la ligne du chef) | logement, eau, éclairage, cuisson, sanitaires, biens |
| `MORTALITE_RP2021_TRAITEMENT.dta` | 269 901 | un décès des 12 derniers mois | dimension Santé |

**Clé de fusion** : `ID_Menage` à l'intérieur du fichier individus ; l'`INDIV_ID` du chef de ménage
pour joindre le fichier ménages ; la clé géographique complète (`REGION` … `P10`) pour joindre les
décès, seul lien possible — le fichier des décès ne porte ni `INDIV_ID` ni `ID_Menage`.

**Pourquoi deux fichiers et pas un seul** : `IPM_Data_191125.dta` porte aussi les variables de
logement et de biens, mais renseignées pour **un tiers des ménages seulement** (fusion incomplète en
amont). Les lire là ferait perdre les conditions de vie de deux ménages sur trois. Elles sont donc
lues dans `IPM_Data_110924_men.dta`, où elles sont complètes. Restent **87 952 ménages (1,6 %)**
présents dans le fichier individus et absents du fichier ménages : conformément à la convention du
pipeline, ils ne sont privés sur aucun indicateur de conditions de vie.

**Pondération** : `EW` (taux net de couverture post-censitaire). La population représentée est de
**29,28 millions**, à 0,4 % du chiffre publié du RGPH 2021 (29 389 150). `PROJ24` est une projection
à 2024 et donnerait 31,9 millions : elle n'est pas retenue.

**Grappe** : la zone de dénombrement (`SOUSPREFID` × `P_ZC` × `P05`), 28 329 unités. Elle tient le
rôle de l'unité primaire de sondage de l'EHCVM dans le calcul des intervalles de confiance.

Les noms de variables explicites sont centralisés dans
[`dictionnaire_rgph.py`](pipeline/dictionnaire_rgph.py).

### 1 ter. Correspondance des indicateurs entre les deux sources

Le RGPH mesure **13 des 16 indicateurs** de l'EHCVM et en apporte **un** que l'enquête n'a pas.

| Indicateur | EHCVM | RGPH |
|---|---|---|
| Fréquentation scolaire | ✅ | ✅ `P30A` |
| Année de scolarité | ✅ années d'études reconstruites | ⚠️ **approché** par le diplôme (`P32` ≥ BEPC) |
| Alphabétisation | ✅ | ✅ `P29A` + `P29_BA` |
| Déclaration d'état civil | ✅ | ✅ `P20` |
| Assurance maladie | ✅ | ❌ aucune question de santé au recensement |
| Insécurité alimentaire (FIES) | ✅ | ❌ |
| Renoncement aux soins | ✅ | ❌ |
| **Mortalité dans le ménage** | ❌ aucun module | ✅ fichier des décès |
| Chômage | ✅ critères BIT reconstruits | ✅ `Statut_OQPtbb` (statut BIT construit par l'INS) |
| Emploi agricole de subsistance | ✅ | ⚠️ **approché** : branche agricole × indépendant ou aide familial |
| Électricité | ✅ | ✅ `P51` |
| Logement | ✅ | ✅ `P45` / `P46` / `P47` |
| Eau potable | ✅ source ODD **et** temps de trajet | ⚠️ source ODD seule — le temps de trajet n'est pas demandé |
| Énergie de cuisson | ✅ | ✅ `P52` |
| Toilette | ✅ ODD **et** partage | ⚠️ ODD seule — le partage n'est pas demandé |
| Biens d'équipement | ⚠️ 7 biens : la charrette manque | ✅ **les 8 biens PNUD**, charrette comprise (`P55F`) |
| Promiscuité | ✅ | ❌ le nombre de pièces n'est pas collecté |

Trois choix de cadrage en découlent.

**Dimension Santé du RGPH = la mortalité seule.** Le décès d'un enfant de moins de 5 ans dans le
ménage remplace les trois indicateurs de santé de l'EHCVM. Elle porte donc à elle seule le quart du
poids de l'indice, pour une privation rare (le recensement ne recense que les décès des **12 derniers
mois**, quand l'IPM mondial retient une fenêtre de **5 ans**). Conséquence mécanique : l'IPM national
du RGPH est nettement plus bas que celui de l'EHCVM, et les deux **ne se comparent pas en niveau**.

**Chômage = `Statut_OQPtbb`**, le statut d'activité BIT construit par l'INS, qui intègre le
reclassement de personnes déclarées sans activité mais en réalité occupées. Le recalcul brut
(sans emploi + recherche + disponibilité, comme dans l'EHCVM) donnerait 21 % de chômeurs chez les
17-40 ans contre 0,9 % ici : l'écart vient entièrement de ce reclassement, et c'est la version INS
qui fait foi.

**Variante harmonisée.** Comme les périmètres diffèrent, le pipeline produit pour chaque source une
troisième variante restreinte au **socle commun** — les 12 indicateurs que les deux sources savent
mesurer, en 3 dimensions (la Santé n'en a aucun de commun). C'est la seule variante dont les
niveaux se comparent d'une source à l'autre. Le socle est déclaré une fois, dans
`orchestrateur.SOCLE_COMMUN`.

### 1 quater. Réconciliation avec la production Stata antérieure

Le RGPH 2021 avait déjà été traité en Stata (`DofileRP21/rp21_calcul_des_privations.do`,
`rp21_compute_mpi_milieu_region.do`), avec une sortie conservée dans `Sortie/Old/IPM21_REGION.smcl`.
Chaque règle de ce dofile a été rejouée sur les données pour distinguer ce qui relève d'un écart de
définition de ce qui relèverait d'une erreur. **Aucune erreur : appliquée telle quelle, chaque règle
Stata est reproduite à 0,1 point près.** Taux de privation, pondérés population.

| Indicateur | Stata (.smcl) | règle Stata rejouée | règle retenue ici | écart dû à |
|---|---|---|---|---|
| Fréquentation scolaire | 30,10 % | 30,14 % | **35,60 %** | tranche d'âge : le `.smcl` date d'une version en 6-14 ans ; le dofile **courant** dit 6-16, comme ici |
| Année de scolarité | 63,05 % | 63,15 % | **63,17 %** | — ✅ |
| Alphabétisation | 30,10 % | 33,15 % | **70,43 %** | lecture de l'énoncé (voir ci-dessous) |
| Chômage | 2,58 % | 5,27 % | **5,92 %** | tranche d'âge 16-35 (RGPH) contre 17-40 (énoncé national) |
| État civil | 9,65 % | 9,73 % | **15,22 %** | déclaration contre possession de l'acte (voir ci-dessous) |
| Électricité | 11,59 % | — | **11,5 %** | — ✅ |
| Eau potable | 14,43 % | — | **14,3 %** | — ✅ |
| Énergie de cuisson | 63,40 % | — | **62,7 %** | — ✅ |
| Logement | 25,25 % | — | **25,0 %** | — ✅ après alignement sur le dofile |
| Biens d'équipement | 18,72 % | — | **18,2 %** | — ✅ |
| Mortalité | 1,121 % | — | **1,1 %** | — ✅ après passage à 18 ans |
| Toilette | 33,09 % | 46,55 % | **45,1 %** | ⚠️ **non réconcilié** |

**Trois corrections apportées après cette comparaison**, toutes dans le sens du dofile officiel :

1. **Mortalité : moins de 18 ans**, et non moins de 5 ans. C'est la borne du dofile RGPH *et* celle
   de l'IPM mondial. Le taux passe de 0,7 % à 1,1 %, soit exactement le 1,121 % du `.smcl`.
2. **Logement : matériaux définis par exclusion**, comme le dofile — est rudimentaire tout ce qui
   n'est ni ciment/carreau/moquette (sol), ni tôle/béton/tuile (toit), ni semi-dur/géobéton/dur
   (mur). Cela ajoute le sol en bois et le mur en tôle, conformément à la classification DHS. Le
   taux passe de 24,0 % à 25,0 %, contre 25,25 % au `.smcl`.
3. **Diplôme : le code 22 « Autres à préciser » compte au-dessus du seuil**, comme le dofile
   (0,02 point).

**Quatre écarts maintenus**, parce que le cadrage retenu est celui de l'EHCVM :

- **Alphabétisation.** Le dofile RGPH code « AUCUN membre alphabétisé » (33,2 %) ; l'énoncé national
  dit « UN membre ne sait pas lire ou écrire » (70,4 %). C'est l'énoncé littéral qui est appliqué,
  aux deux sources, par le même drapeau `ALPHABETISATION_AU_MOINS_UN_NON_ALPHABETISE` — elles ne
  peuvent pas diverger sur ce point sans qu'on le décide.
- **État civil.** La question EHCVM (1.05) est « dispose d'un acte de naissance ? » : « déclaré SANS
  acte » (`P20 = 2`) est donc une privation. Le dofile RGPH mesure la déclaration et non la
  possession, et ne compte privés que les codes 3 et 8. La lecture retenue (15,2 %) est aussi la
  plus proche de l'EHCVM (26,3 %).
- **Chômage sur les 17-40 ans**, énoncé du tableau national, contre 16-35 dans le dofile RGPH.
  La **variable** de statut, en revanche, a été validée : `Statut_OQPtbb` ne diffère de la
  construction `Statut_OQP` du dofile (les trois critères BIT) que sur 18 910 individus sur
  28 millions, soit 0,07 %. L'autre variable de la base, `Statut_OQPtb`, donnerait 21,6 % : elle
  n'intègre pas le reclassement INS et n'est pas retenue.
- **Emploi agricole de subsistance.** Absent de l'IPM RGPH officiel, mais présent dans les 16
  indicateurs de l'EHCVM : il est donc calculé, par approximation (46,0 % contre 40,5 % à l'EHCVM).
  C'est le premier contributeur à M₀ (26,6 %) — à revoir en priorité si l'approximation est jugée
  trop lâche.

**Un écart non réconcilié : la toilette.** Règle identique de part et d'autre
(`!inlist(P48,1,2,5,7)`), même fichier source, et pourtant 33,09 % au `.smcl` contre 46,55 % ici.
Aucune version du dofile présente dans le dépôt ne produit 33 % ; la liste
`inlist(P48,1,2,3,4,5,7)` — qui ajouterait la chasse d'eau à l'air libre et vers un lieu inconnu —
donnerait 34,19 %, l'ordre de grandeur du `.smcl`. Le `.smcl` vient vraisemblablement d'un
millésime antérieur du code ou des données. **À confirmer auprès de l'INS** ; la valeur retenue ici
est celle du dofile courant, et elle est cohérente avec l'EHCVM (67,2 %, qui ajoute le critère de
partage des sanitaires, absent du recensement).

**Ce qui n'est pas comparable, et pourquoi.** Le dofile officiel construit un IPM à **5 dimensions
équipondérées à 0,2** — Éducation, Emploi, Conditions de vie, Santé et **Identification** (l'état
civil y est une dimension à part entière) — et remplace les manquants par une privation. Le pipeline
suit le cadrage EHCVM : **4 dimensions à 0,25**, l'état civil rangé dans l'Éducation, et un ménage
dont aucune situation n'est renseignée compté non privé. H = 0,100 et M₀ = 0,045 au `.smcl` ne se
comparent donc pas aux H = 0,388 et M₀ = 0,166 produits ici.

---

## 2. Définitions retenues

Chaque indicateur suit **soit** la proposition nationale, **soit** l'application du PNUD. Ce choix
est porté dans le code par la constante `INDICATEURS` de
[`02_construction_matrice_situationnelle.py`](02_construction_matrice_situationnelle.py) et rappelé dans le log à chaque
exécution.

| Dimension | Indicateur | Source | Colonne de X | Seuil appliqué | Ménages privés |
|---|---|---|---|---|---|
| Éducation | Fréquentation scolaire | nationale | `frequentation_scolaire` | au moins un enfant de 6-16 ans non scolarisé | 27,9 % |
| Éducation | Année de scolarité | nationale | `annee_scolarite` | `annees_etudes_max` < 10 (17-95 ans) | 72,5 % |
| Éducation | Alphabétisation | nationale | `alphabetisation` | au moins un membre de 17-49 ans ne lit/écrit pas le français | 61,7 % |
| Éducation | Déclaration d'état civil | nationale | `etat_civil` | au moins un enfant de 5-15 ans sans acte | 23,5 % |
| Santé | Assurance maladie | nationale | `assurance_maladie` | aucun membre couvert | 93,4 % |
| Santé | Insécurité alimentaire | FAO | `insecurite_alimentaire` | score FIES ≥ 4 sur 8 (modérée ou sévère) | 42,7 % |
| Santé | Renoncement aux soins (coût ou indisponibilité) | nationale | `renoncement_soins` | un membre malade sur 30 j n'a pas consulté, pour raison subie : coût (2 « trop cher », 8 « manque d'argent ») ou offre (11 « service indisponible », 12 « absence de personnel ») | 9,3 % |
| Emploi | Chômage | nationale | `chomage` | au moins un chômeur BIT de 17-40 ans | 3,7 % |
| Emploi | Emploi agricole de subsistance | nationale | `emploi_subsistance` | chef occupé ne travaillant que son propre champ (sans salariat, apprentissage ni commerce) | 48,1 % |
| Conditions de vie | Électricité | nationale | `electricite` | éclairage hors réseau / groupe électrogène / solaire | 13,3 % |
| Conditions de vie | Logement | PNUD | `logement` | sol naturel **ou** toit **ou** murs précaires | 22,3 % |
| Conditions de vie | Eau potable | PNUD | `eau_potable` | source non améliorée **ou** plus de 15 min à l'aller (30 min aller-retour) | 24,6 % |
| Conditions de vie | Énergie de cuisson | nationale | `energie_cuisson` | combustible principal ni gaz ni électricité | 76,8 % |
| Conditions de vie | Toilettes | PNUD | `toilette` | sanitaires non améliorés **ou** partagés | 77,3 % |
| Conditions de vie | Biens d'équipement | PNUD | `biens_equipement` | au plus 1 bien sur 7 **et** pas de voiture | 29,2 % |
| Conditions de vie | Promiscuité | nationale | `promiscuite` | plus de 3 personnes par pièce à coucher | 8,4 % |

Les seuils sont portés par la constante `INDICATEURS` de `02_construction_matrice_situationnelle.py` : chaque
entrée réunit la dimension, le libellé, la source de la définition, l'énoncé, la colonne produite
et la règle appliquée. Convention : un ménage **non concerné** (aucun enfant de 6-16 ans, aucun
membre de 17-40 ans…) n'est **pas** privé.

⚠️ **Point ouvert — alphabétisation.** L'énoncé national dit « **un** membre de 17-49 ans ne sait
pas lire ou écrire » (61,7 % des ménages privés) ; le RGPH 2021 codait « **aucun** membre
alphabétisé » (35,0 %). Le code suit l'énoncé littéral du tableau ; la bascule se fait en passant
`ALPHABETISATION_AU_MOINS_UN_NON_ALPHABETISE` à `False`.

**Structure et pondérations** : 4 dimensions équipondérées à 0,25 — l'acte de naissance est rattaché
à l'Éducation, il n'y a pas de dimension Identification séparée.

| Dimension | Indicateurs | Poids par indicateur |
|---|---|---|
| Éducation | 4 | 0,0625 |
| Santé | 3 | 0,0833 |
| Emploi | 2 | 0,125 |
| Conditions de vie | 7 | 0,0357 |

Seuil de pauvreté multidimensionnelle : **k = 1/3**. Vulnérabilité : 0,2 < score < 1/3. Pauvreté
sévère : score ≥ 0,5.

---

## 3. Écarts assumés

| Écart | Constat | Traitement |
|---|---|---|
| **Mortalité juvénile** | L'EHCVM n'a ni module décès ni historique des naissances. `Base_chocs` enregistre bien « décès d'un membre du ménage » (1 328 ménages sur 3 ans, avec la date) mais **sans l'âge du défunt** : impossible d'isoler les moins de 18 ans. | Indicateur abandonné, dimension Santé mesurée par l'**assurance maladie** (question 3.32, renseignée à 100 %). |
| **Années d'études** | L'EHCVM ne demande pas le nombre d'années d'études. | Reconstruites : années accomplies avant le niveau + classe atteinte, en trois branches — niveau achevé (2.29/2.31), niveau en cours (2.14/2.16, moins l'année non terminée), 0 année si jamais scolarisé (2.03). Restent 8,5 % d'individus indéterminés, soit 6 ménages après agrégation par le maximum. |
| **Charrette** | Absente des 45 biens de la section 12 de l'EHCVM (le camion aussi). | Le décompte PNUD porte sur **7 biens** au lieu de 8. |
| **Chômage** | Aucune variable de statut d'activité BIT toute faite. | Reconstruit avec les trois critères : sans emploi (4.10 et 4.11), en recherche (4.15 ou 4.17), disponible (4.20 pour les chercheurs, 4.19 sinon). |
| **Fréquentation scolaire** | La question 2.08a (année 2021/22) n'est posée qu'en **vague 2** ; la 2.12 (année 2020/21) l'est aux deux vagues. | Année la plus récente disponible : scolarisé si 2.08a = oui **ou** 2.12 = oui. |
| **Électricité** | La variable « connecté au réseau » (11.33) ne capte ni le groupe électrogène ni le solaire : elle classerait 2 597 ménages de plus comme privés (4 319 soit 33,3 %, contre 1 722 soit 13,3 %). | L'indicateur repose sur la **source d'éclairage** (11.37), conformément à l'énoncé national. |

---

## 4. Conventions de calcul

- **Unité de construction : le ménage.** Le score de privation se calcule une fois par ménage.
- **Unité de comptage : l'individu.** Chaque ménage compte nᵢ fois dans H, A et M₀, avec
  nᵢ = `taille_menage` × `ponderation_menage` (roster complet, cohérent avec le poids d'enquête).
  Formules du document méthodologique national : H = Σnᵢ·1(sᵢ>1/3) / Σnᵢ, A = Σnᵢ·sᵢ·1(sᵢ>1/3) / q.
- **« Non concerné » ≠ « non privé »** : pour chaque indicateur mesuré sur les personnes, X porte
  deux colonnes — l'effectif concerné et l'effectif en situation défavorable. Un ménage sans
  personne concernée sera traité comme non privé (convention du RGPH 2021), mais l'information
  reste disponible pour en changer.
- **Âge** : année d'enquête (2021 en vague 1, 2022 en vague 2) moins l'année de naissance ; l'âge
  déclaré (1.04a), renseigné pour 6,1 % des membres, prime quand il existe.
- **Filtres du questionnaire à ne pas confondre avec des données manquantes** :
  - `sanitaire_partage` (11.55) n'est pas posée aux ménages sans toilettes → 24,6 % de vides ;
    ces ménages sont déjà privés par le type de sanitaire, la règle les compte donc correctement ;
  - `temps_aller_source_seche` (11.28a) n'est posée que si la distance est > 0 → 49,5 % de vides,
    qui valent **temps nul** (eau sur place ; les 6 423 ménages concernés ont tous une distance
    11.27 exactement nulle). La **norme PNUD est de 30 minutes aller-retour** ; la question mesure
    le trajet **aller seul** (libellé : « Tps (min) aller [se] rendre [à la] principale source »),
    donc le seuil appliqué à la colonne est de **15 minutes**. 6,9 % des ménages dépassent 15 min
    à l'aller.

  ⚠️ **Point ouvert — inclusivité du seuil eau.** La définition PNUD dit « 30 minutes **ou plus** »,
  donc un aller-retour d'exactement 30 min (15 à l'aller) est privé et la règle devrait être
  `>= 15`. Le code applique `> 15`. L'écart porte sur les **402 ménages** qui déclarent exactement
  15 minutes (3,1 % de l'échantillon, 2,71 % de la population — effet d'arrondi aux multiples de
  5) : la privation en eau passerait de 24,6 % à ≈ 27,7 % des ménages.
- **Valeurs manquantes résiduelles** : une situation encore manquante après application du seuil
  vaut « non privé ». Ne concerne que 6 ménages (`annees_etudes_max`, ménages sans membre de
  17-95 ans), qui sont de toute façon hors champ de l'indicateur.

---

## 5. Étapes du pipeline

Tous les fichiers produits portent le suffixe de leur source (`_ehcvm2021`, `_rgph2021`).

| Étape | Fichier | Entrée | Sortie |
|---|---|---|---|
| 01 — préconstruction EHCVM | `01_preconstruction_matrice_situationnelle.py` | les 4 bases EHCVM | `preconstruction_matrice_situationnelle_ehcvm2021.dta` (12 965 × 35) |
| 01 — préconstruction RGPH | `01_rgph_preconstruction_matrice_situationnelle.py` | les 3 bases RGPH | `preconstruction_matrice_situationnelle_rgph2021.dta` (5 616 487 × 29) |
| 02 — matrice situationnelle X | `02_construction_matrice_situationnelle.py` | la préconstruction | `matrice_situationnelle_<source>.dta` : **16 indicateurs 0/1** (EHCVM) ou **13** (RGPH), + pondération + désagrégation |
| 03 — pondérations w, matrice pondérée, score cᵢ | `03_matrice_privations_ponderees.py` | X | `vecteur_w_<source>`, `matrice_privations_ponderees_<source>` |
| 04 — censure au seuil k | `04_matrice_privations_censuree.py` | la matrice pondérée | `matrice_privations_censuree_<source>` : statuts pauvre / vulnérable / sévère |
| 05 — H, A, M₀, désagrégations, contributions | `05_indices_ipm.py` | X | pour chacune des 3 variantes : `indices_ipm_<variante>_<source>` (.dta/.csv/.xlsx) et `contributions_…` |

Seule l'étape 01 diffère d'une source à l'autre : elle lit des bases sans rapport. À partir de
l'étape 02 le code est commun — il ne travaille plus que sur des colonnes de situation normalisées.

**L'étape 01 du RGPH lit le fichier individus par morceaux de 3 millions de lignes** : 28 millions
de lignes ne tiennent pas en mémoire. Un ménage coupé entre deux morceaux n'est pas un problème,
chaque morceau est agrégé séparément puis les agrégats sont resommés par ménage.

**Place disque** : la chaîne RGPH écrit environ **2,2 Go** de tables de travail (5,6 millions de
ménages). Deux garde-fous limitent la facture : les colonnes entières et les flottants qui ne
portent que des entiers sont réduits au plus petit type qui les contient avant écriture
(`orchestrateur.compacter`), et le doublon CSV n'est plus écrit au-delà d'un million de lignes.

Chaque étape s'exécute seule et dispose d'un auto-contrôle (`--check`) qui rejoue la logique sur un
mini-jeu de données aux résultats connus. `pipeline/orchestrateur.py` tient les deux rôles de socle
commun (chemins, clé de fusion, colonnes techniques, journalisation — les modules commençant par un
chiffre ne peuvent pas s'importer entre eux) et de chef d'orchestre :

```
python pipeline/orchestrateur.py            # enchaîne les étapes -> logs/00_pipeline.log
python pipeline/orchestrateur.py --check    # les auto-contrôles de chaque étape
python pipeline/orchestrateur.py --su3 --su3_seul --su3_neet  # variantes Emploi (EHCVM)
python pipeline/02_construction_matrice_situationnelle.py   # une étape seule
```

**Variantes Emploi.** Quatre options ajoutent un jeu de sorties à l'étape 05, sans rien changer à
l'IPM national : `--su1_su3` place SU3 à côté du chômage BIT et de l'emploi de subsistance ;
`--su3` retient **SU3 + emploi agricole de subsistance** ; `--su3_seul` donne tout le poids de la
dimension à **SU3 uniquement** ; `--su3_neet` retient **SU3 + NEET approché**. Ce dernier est en
réalité un NEE (« ni en emploi ni en études »), car l'EHCVM ne mesure pas la formation en cours.
Ces variantes n'existent que
pour l'EHCVM — le RGPH ne pose aucune question de recherche d'emploi ni de disponibilité, SU3 n'y
est pas constructible — et l'orchestrateur les retire du passage sur le recensement. L'indicateur
`chomage_su3`, comme `neet_approx`, est produit par l'étape 02 mais reste **hors de l'IPM
national** (`orchestrateur.HORS_IPM_NATIONAL`). SU3 englobe le chômage BIT : les additionner
compterait deux fois les mêmes chômeurs. Voir la *Note sur la dimension Emploi*.

Les étapes sont lancées en sous-processus : une étape en échec arrête la chaîne et les suivantes ne
tournent pas, plutôt que de produire une sortie incomplète.

Une étape **06** hors chaîne (`06_validation_afmpi.py`) recalcule H, A, M₀ et les contributions
avec le package [`afmpi`](https://github.com/cae-ins/afmpi), implémentation indépendante de la
méthode Alkire-Foster, et s'arrête si l'écart avec le pipeline dépasse 1e-6. Les deux chemins
concordent aujourd'hui sur les deux sources, erreur-type de M₀ comprise.

### Organisation du dossier

```
PythonIPM/
├── METHODOLOGIE.md
├── Data/
│   ├── EHCVM/      les 21 bases .dta de l'enquête, jamais écrites
│   └── RGPH_IPM/   les 3 bases .dta du recensement, jamais écrites
├── pipeline/       orchestrateur.py, dictionnaire_ehcvm.py, dictionnaire_rgph.py, les étapes
├── sorties/
│   ├── dta/        tables produites au format Stata (relues par l'étape suivante)
│   └── csv/        les mêmes tables en texte (lecture, Excel, R)
├── logs/           00_pipeline.log + un journal détaillé par étape
├── notebooks/      exploration et prise en main
└── documentation/  codebooks des bases + les sources LaTeX des documents livrables
```

### Documents livrables

`python documentation/generer_documents.py` compile les sources LaTeX de `documentation/` vers
`sorties/pdf/` (le PDF livrable), `sorties/docx/` (la version Word modifiable) et `sorties/tex/`
(la source, pour qu'un dossier de sorties soit auto-suffisant). Huit documents : deux par source sur la méthode et les
sorties, une note, et trois analyses d'alignement au PND 2026-2030 :

| Document | Source | Contenu |
|---|---|---|
| `methodologie_ipm.pdf` | EHCVM | méthodologie de calcul, 16 indicateurs |
| `dictionnaire_sorties.pdf` | EHCVM | chaque feuille et chaque colonne des classeurs |
| `methodologie_ipm_rgph.pdf` | RGPH | méthodologie de calcul, 13 indicateurs, réconciliation Stata |
| `lecture_des_sorties_rgph.pdf` | RGPH | ce que contiennent les classeurs et comment les lire |
| `note_dimension_sante.pdf` | EHCVM | pourquoi l'assurance maladie seule ne suffisait pas |
| `alignement_pnd_ipm_ehcvm.pdf` | EHCVM | alignement au PND 2026-2030, cible par cible |
| `alignement_pnd_ipm_rgph.pdf` | RGPH | alignement au PND 2026-2030, cible par cible |
| `alignement_pnd_comparaison.pdf` | les deux | quel IPM sert le mieux le PND, et comment les employer ensemble |

Les définitions colonne par colonne sont communes aux deux sources : le document RGPH ne les
répète pas, il renvoie au dictionnaire de l'EHCVM et ne traite que ce que le recensement change.

**Le PDF fait foi** : c'est lui qui est mis en page. Le `.docx`, produit par `pandoc`, est là pour
être retouché — il garde tout le contenu, les tableaux, les titres, les formules et la table des
matières, mais perd la mise en page fine (encadrés colorés, filets des tableaux). Deux limites du
moteur de formules de pandoc sont contournées à la conversion, sans toucher au PDF : `\ensuremath`
dans une formule, et une commande de police à l'intérieur d'un `\text{}` mathématique — l'une comme
l'autre lui font abandonner la formule entière. Les titres des encadrés, que pandoc jette parce
qu'ils sont un argument optionnel d'environnement, sont réinjectés en gras.

### Contenu de la préconstruction (étape 01)

Des **situations brutes** (effectifs, maximum, code de modalité) : aucun seuil n'y est appliqué.
Colonnes : les effectifs concernés et défavorables des indicateurs individuels
(`enfants_6_16` / `enfants_6_16_non_scolarises`, `membres_17_40` / `chomeurs_17_40`,
`enfants_5_15` / `enfants_5_15_sans_acte`, `membres_17_49` / `membres_17_49_alphabetises`,
`membres_17_95` / `annees_etudes_max`, `membres_assures`, `membres_malades_30j` /
`membres_renoncement_soins`), les codes de modalité des conditions de
vie (`source_eclairage`, `materiau_toit`, `materiau_mur`, `materiau_sol`,
`source_eau_boisson_seche`, `temps_aller_source_seche`, `combustible_principal`, `type_sanitaire`,
`sanitaire_partage`), l'équipement (`nb_equipements`, `possede_voiture`), la variante non retenue
`score_fies`, et les colonnes techniques.

Garder l'effectif **concerné** à côté de l'effectif **défavorable** est ce qui permet à l'étape 02
de distinguer « non privé » de « non concerné » sans revenir aux données individuelles.

### Contenu de la matrice situationnelle X (étape 02)

Les 16 colonnes indicateurs en 0/1 (1 = privé), puis les colonnes techniques et rien d'autre :
`id_menage`, `ponderation_menage`, `taille_menage`, `region`, `milieu`, `sexe_cm` — pondération et
désagrégations de l'étape 04. Moyenne de 5,26 privations par ménage, 2,0 % des ménages sans aucune
privation (3,3 % de la population).

Quelques ordres de grandeur produits par l'étape 01 : 33,3 % des ménages n'ont aucun enfant de
6-16 ans, 18,5 % aucun membre de 17-40 ans, 93,4 % aucun membre assuré, 67,2 % ont eu au moins un
malade sur 30 jours et 9,3 % au moins un renoncement aux soins ; `annees_etudes_max` a une
médiane de 5 années et un 3ᵉ quartile de 10 ; le nombre de biens possédés est de 2,20 en moyenne.

---

## 6. Journal des décisions

| Date | Décision | Motif |
|---|---|---|
| 18 août 2026 | 4 bases retenues sur 21 | les autres (consommation, agriculture, chocs…) ne portent aucun indicateur de l'IPM |
| 19 août 2026 | Unité de construction = ménage, unité de comptage = individu | formules du document méthodologique national (nᵢ dans H et A) |
| 19 août 2026 | nᵢ = `taille_menage` × `ponderation_menage` | cohérence avec la pondération officielle de l'enquête ; `hhsize` correspond au roster complet pour 97,5 % des ménages |
| 19 août 2026 | Dimension Santé = assurance maladie | mortalité juvénile impossible ; 100 % de réponses et aucun biais de sélection, contrairement au renoncement aux soins mesuré chez les seuls malades |
| 20 août 2026 | 4 dimensions à 0,25, acte de naissance dans Éducation | décision de cadrage ; le tableau officiel fait foi pour les définitions, pas pour les poids |
| 20 août 2026 | Définitions mixtes nationale / PNUD | choix indicateur par indicateur (voir § 2) |
| 20 août 2026 | Chômage sur les 17-40 ans | énoncé du tableau officiel (le RGPH 2021 utilisait 16-35) |
| 20 août 2026 | Variante PNUD non produite en parallèle | une seule série de résultats à publier |
| 20 août 2026 | Pipeline scindé en 01 préconstruction / 02 construction | X ne doit contenir que les 16 indicateurs et les variables de pondération et de désagrégation ; les situations brutes restent traçables dans la préconstruction |
| 27 août 2026 | Renoncement aux soins élargi au coût **et** à l'offre (3.06 = 2, 8, 11, 12) | motifs **subis** — coût (trop cher, manque d'argent) ou indisponibilité du service (service spécialisé indisponible, absence de personnel) — ; l'automédication (4) et le « pas nécessaire » (1) relèvent d'un arbitrage, pas d'une contrainte. N'ajoute que 14 personnes et 10 ménages (privation 9,3 %) ; déplace l'IPM de 0,00008 — décision de définition, pas d'effet sur les résultats |
| 11 septembre 2026 | Pipeline étendu au RGPH 2021, source portée par `IPM_SOURCE` | même méthode Alkire-Foster sur les deux sources ; seule l'étape 01 diffère, le reste du code est commun |
| 11 septembre 2026 | Conditions de vie du RGPH lues dans `IPM_Data_110924_men.dta` | le fichier individus les porte aussi, mais renseignées pour un tiers des ménages seulement |
| 11 septembre 2026 | Indicateur `chomage_su3` (sous-utilisation SU3) produit mais hors IPM national, exposé par `--su1_su3` et `--su3` | le chômage BIT ne prive que 6,5 % de la population pour 12,5 % des pondérations et rate les découragés ; SU3 double le périmètre (12,1 %). Ajouté en variante et non dans l'IPM publié : SU3 englobe SU1, le cumul compterait deux fois les mêmes ménages |
| 20 septembre 2026 | Variantes `--su3_seul` et `--su3_neet` ; indicateur `neet_approx` hors IPM national | comparaison demandée des montages SU3 + subsistance, SU3 uniquement et SU3 + NEET. L'EHCVM ne mesure pas la formation en cours : `neet_approx` est explicitement un NEE et ne doit pas être publié comme un NEET complet |
| 11 septembre 2026 | Pondération RGPH = `EW`, non `PROJ24` | `EW` redonne la population du RGPH 2021 à 0,4 % près ; `PROJ24` projette à 2024 (31,9 millions) |
| 11 septembre 2026 | Dimension Santé du RGPH = mortalité juvénile seule | aucune question de santé au recensement ; conserve les 4 dimensions équipondérées, au prix d'une privation rare (fenêtre de 12 mois et non de 5 ans) |
| 11 septembre 2026 | Chômage RGPH = `Statut_OQPtbb` (INS) | intègre le reclassement INS des personnes déclarées sans activité mais occupées ; le recalcul brut donnerait 21 % de chômeurs chez les 17-40 ans contre 0,9 % |
| 11 septembre 2026 | Année de scolarité RGPH approchée par le diplôme (BEPC ou plus) | le recensement ne demande ni les années d'études ni la classe atteinte |
| 11 septembre 2026 | Troisième variante « harmonisée » sur le socle commun aux deux sources | les IPM complets ne se comparent pas en niveau, chacun exploitant ce que sa source mesure ; le socle (12 indicateurs, 3 dimensions) le permet |
| 11 septembre 2026 | Un ménage dont aucune situation d'un indicateur n'est renseignée n'est pas privé | une règle en `~…isin(…)` rendait privé tout ménage manquant ; garde-fou posé dans l'étape 02, sans effet sur l'EHCVM (aucun manquant) |
| 11 septembre 2026 | Mortalité RGPH portée à « moins de 18 ans » | borne du dofile officiel RGPH 2021 et de l'IPM mondial ; reproduit exactement le 1,121 % de la sortie Stata antérieure |
| 11 septembre 2026 | Matériaux du logement RGPH définis par exclusion, comme le dofile officiel | ajoute le sol en bois et le mur en tôle (classification DHS) ; 25,0 % contre 25,25 % à la sortie Stata |
| 11 septembre 2026 | Divergence non résolue sur la toilette (45,1 % ici, 33,09 % au `.smcl`) | règle pourtant identique ; aucune version du dofile du dépôt ne reproduit 33 % — à confirmer auprès de l'INS |
| 11 septembre 2026 | Deux documents livrables ajoutés pour le RGPH (méthodologie + lecture des sorties) | parité avec l'EHCVM ; le titre des encadrés d'avertissement du préambule était écrit en rouge sur fond rouge, donc invisible dans tous les PDF — corrigé au passage |
| 11 septembre 2026 | Version Word de chaque document, produite par `pandoc` dans `sorties/docx/` | les documents doivent pouvoir être retouchés ; le PDF reste la version mise en page qui fait foi |
| 11 septembre 2026 | Trois analyses d'alignement au PND 2026-2030 (EHCVM, RGPH, comparaison) | le plan fixe des cibles chiffrées par pilier mais aucune cible de pauvreté à 2030 ; l'EHCVM couvre 11 des 22 cibles éclairables contre 7 au RGPH, mais le RGPH est seul à rendre opérationnels les pôles économiques, le registre social et le ciblage des 827 000 ménages de filets sociaux |
