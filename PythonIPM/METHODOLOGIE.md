# Méthodologie — IPM Côte d'Ivoire sur l'EHCVM 2021

Journal de méthode du pipeline `PythonIPM`. Il retrace les sources, les définitions retenues, les
écarts assumés et les conventions de calcul. À tenir à jour à chaque étape.

*Dernière mise à jour : 20 août 2026 — étapes 01 (préconstruction) et 02 (matrice situationnelle X, 12 indicateurs) terminées.*

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
| Emploi | Chômage | nationale | `chomage` | au moins un chômeur BIT de 17-40 ans | 3,7 % |
| Conditions de vie | Électricité | nationale | `electricite` | éclairage hors réseau / groupe électrogène / solaire | 13,3 % |
| Conditions de vie | Logement | PNUD | `logement` | sol naturel **ou** toit **ou** murs précaires | 22,3 % |
| Conditions de vie | Eau potable | PNUD | `eau_potable` | source non améliorée **ou** plus de 15 min à l'aller (30 min aller-retour) | 24,6 % |
| Conditions de vie | Énergie de cuisson | nationale | `energie_cuisson` | combustible principal ni gaz ni électricité | 76,8 % |
| Conditions de vie | Toilettes | PNUD | `toilette` | sanitaires non améliorés **ou** partagés | 77,3 % |
| Conditions de vie | Biens d'équipement | PNUD | `biens_equipement` | au plus 1 bien sur 7 **et** pas de voiture | 29,2 % |

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
| Santé | 1 | 0,25 |
| Emploi | 1 | 0,25 |
| Conditions de vie | 6 | 0,0417 |

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
    qui valent **temps nul** (eau sur place). La question mesure le trajet **aller** : le seuil
    PNUD de 30 minutes aller-retour correspond donc à plus de 15 minutes.
- **Valeurs manquantes résiduelles** : une situation encore manquante après application du seuil
  vaut « non privé ». Ne concerne que 6 ménages (`annees_etudes_max`, ménages sans membre de
  17-95 ans), qui sont de toute façon hors champ de l'indicateur.

---

## 5. Étapes du pipeline

| Étape | Fichier | Entrée | Sortie | Journal |
|---|---|---|---|---|
| 01 — préconstruction | `01_preconstruction_matrice_situationnelle.py` ✅ | les 4 bases `.dta` | `preconstruction_matrice_situationnelle.dta` (12 965 × 29 : situations brutes + colonnes techniques) | `01_…log` |
| 02 — matrice situationnelle X | `02_construction_matrice_situationnelle.py` ✅ | la préconstruction | `matrice_situationnelle_ehcvm2021.dta` (12 965 × 18 : **12 indicateurs 0/1** + pondération + désagrégation) | `02_…log` |
| 03 — matrice de privations, pondérations w, score cᵢ et censure | `03_…` (à venir) | X | score, statuts pauvre / vulnérable / sévère | — |
| 04 — H, A, M₀ et contributions | `04_…` (à venir) | score | indices et désagrégations | — |

Chaque étape s'exécute seule et dispose d'un auto-contrôle (`--check`) qui rejoue la logique sur un
mini-jeu de données aux résultats connus. `pipeline/orchestrateur.py` tient les deux rôles de socle
commun (chemins, clé de fusion, colonnes techniques, journalisation — les modules commençant par un
chiffre ne peuvent pas s'importer entre eux) et de chef d'orchestre :

```
python pipeline/orchestrateur.py            # enchaîne les étapes -> logs/00_pipeline.log
python pipeline/orchestrateur.py --check    # les auto-contrôles de chaque étape
python pipeline/02_construction_matrice_situationnelle.py   # une étape seule
```

Les étapes sont lancées en sous-processus : une étape en échec arrête la chaîne et les suivantes ne
tournent pas, plutôt que de produire une sortie incomplète.

### Organisation du dossier

```
PythonIPM/
├── METHODOLOGIE.md
├── EHCVM/          les 21 bases .dta d'origine, jamais écrites
├── pipeline/       orchestrateur.py, dictionnaire_ehcvm.py, les étapes numérotées
├── sorties/        les tables produites (.dta)
├── logs/           00_pipeline.log + un journal détaillé par étape
├── notebooks/      exploration et prise en main
└── documentation/  codebooks des bases
```

### Contenu de la préconstruction (étape 01)

Des **situations brutes** (effectifs, maximum, code de modalité) : aucun seuil n'y est appliqué.
Colonnes : les effectifs concernés et défavorables des indicateurs individuels
(`enfants_6_16` / `enfants_6_16_non_scolarises`, `membres_17_40` / `chomeurs_17_40`,
`enfants_5_15` / `enfants_5_15_sans_acte`, `membres_17_49` / `membres_17_49_alphabetises`,
`membres_17_95` / `annees_etudes_max`, `membres_assures`), les codes de modalité des conditions de
vie (`source_eclairage`, `materiau_toit`, `materiau_mur`, `materiau_sol`,
`source_eau_boisson_seche`, `temps_aller_source_seche`, `combustible_principal`, `type_sanitaire`,
`sanitaire_partage`), l'équipement (`nb_equipements`, `possede_voiture`), la variante non retenue
`score_fies`, et les colonnes techniques.

Garder l'effectif **concerné** à côté de l'effectif **défavorable** est ce qui permet à l'étape 02
de distinguer « non privé » de « non concerné » sans revenir aux données individuelles.

### Contenu de la matrice situationnelle X (étape 02)

Les 12 colonnes indicateurs en 0/1 (1 = privé), puis les colonnes techniques et rien d'autre :
`id_menage`, `ponderation_menage`, `taille_menage`, `region`, `milieu`, `sexe_cm` — pondération et
désagrégations de l'étape 04. Moyenne de 5,26 privations par ménage, 2,0 % des ménages sans aucune
privation (3,3 % de la population).

Quelques ordres de grandeur produits par l'étape 01 : 33,3 % des ménages n'ont aucun enfant de
6-16 ans, 18,5 % aucun membre de 17-40 ans, 93,4 % aucun membre assuré ; `annees_etudes_max` a une
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
| 20 août 2026 | Pipeline scindé en 01 préconstruction / 02 construction | X ne doit contenir que les 12 indicateurs et les variables de pondération et de désagrégation ; les situations brutes restent traçables dans la préconstruction |
