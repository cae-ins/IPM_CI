# Note de passation — session du 30 août 2026

Salut Jaurès,

Cette session (assistée par Claude Code) a repris ta branche `IPM-python` / le pipeline
`PythonIPM` pour l'améliorer sur quelques points précis, demandés par Franck. Résumé de ce qui a
changé et pourquoi, pour que tu puisses reprendre la main sans surprise.

## Ce qui a changé

**Dimension Emploi : chômage → SU3, + NEET.** L'indicateur Chômage (17-40 ans, chômage BIT) est
remplacé par le **SU3** (BIT, 19ᵉ CIST) — taux combiné chômage + main-d'œuvre potentielle,
16 ans et plus, pas de borne haute. Le SU3 englobe le chômage par construction, garder les deux
aurait fait doublon. Un indicateur **NEET** est ajouté (16-35 ans, ni emploi ni scolarisation ni
formation — la formation non formelle vient de la question 2.05, déjà dans les fichiers fusionnés
pour `Base_Individus`, aucune nouvelle source de données). Emploi passe donc de 2 à 3 indicateurs
(poids 0,0833 chacun au lieu de 0,125). Voir `01_preconstruction_matrice_situationnelle.py`
(fonctions `calculer_situations_individuelles`, `agreger_par_menage`) et
`02_construction_matrice_situationnelle.py` (constante `INDICATEURS`).

**Nouvelle désagrégation Zone.** Abidjan / Autre urbain / Rural, reconstruite en croisant
`region == 1` (Autonome d'Abidjan) et `milieu` — le `milieu` EHCVM est binaire (Urbain/Rural),
sans distinguer Abidjan. Fonction `calculer_zone` dans l'étape 01. Demandée pour retrouver le
niveau de détail des désagrégations que fait le pipeline Stata RGPH de `DofileRP21/` (milieu à
3 modalités : Abidjan ville / autres villes / rural).

**Robustesse au seuil k.** Nouvelle fonction `robustesse_k()` dans `05_indices_ipm.py` : H, A, M0
à k = 10/20/25/30/33,3(officiel)/40/50/60 %, avec vérification automatique que H et M0 sont non
croissants en k. Comblait un écart face à `mpitb` (toolbox Stata de référence OPHI), qui a ce
paramètre nativement (`klist`).

**Taux de privation non censuré publié.** `contributions_ipm_ci`/`_international` publient
maintenant `taux_privation_non_censure` (Hⱼ) à côté de `taux_privation_censure` (CHⱼ, déjà
présent) — c'était calculé en étape 02 mais jamais exporté. Toujours pour aligner sur ce que
publient `mpitb`/`mpitbR`.

**Classeur dédié `resultats_region_zone.xlsx`.** Demande explicite : uniquement Région (33) et
Zone (3), rien d'autre, en plus du classeur technique complet (qui garde ses 7 feuilles de
désagrégation habituelles).

**Construction des 4 bases sources.** Nouveau script `00_construction_bases_source.py` : les 4
bases attendues par l'étape 01 (`Base_Menage`, `Base_Individus`, `Base_avoirs_du_menage`,
`Base_securite_alimentaire`) n'existaient nulle part dans le dépôt (gitignorées) — le script les
reconstruit depuis les fichiers sectionnels bruts de l'EHCVM 2021. Deux bugs préexistants dans
`dictionnaire_ehcvm.py` ont été corrigés au passage (le pipeline n'avait apparemment jamais tourné
de bout en bout dans cet environnement avant) :
- l'identifiant individu était mappé sur `s01q00a`, colonne absente des fichiers réels →
  corrigé vers `membres__id` ;
- les libellés de département/sous-préfecture (lus depuis les *value labels* Stata de
  `Base_Menage.dta` par `dictionnaire_ehcvm.modalites()`) étaient perdus lors de la reconstruction
  des bases → recapturés et réinjectés dans `00_construction_bases_source.py`.

**Documentation à jour.** `METHODOLOGIE.md` (journal des décisions complet, section par section)
et `documentation/methodologie_ipm.tex` (recompilé) reflètent tous ces changements avec les
chiffres recalculés sur les données réelles.

## Résultats actuels (17 indicateurs)

H = 62,5 %, A = 0,5020, M0 = 0,3136 (IC 95 % [0,2980 ; 0,3291]) — 18,6 millions de personnes
pauvres. La variante internationale (3 dimensions, sans Emploi) est numériquement identique à
avant, puisqu'aucun de ses 14 indicateurs n'a changé.

## Ce qu'il te faut savoir avant de reprendre

- **Rien n'est commité.** Tout ce qui précède est dans l'arbre de travail de la branche
  `IPM-python`, pas encore versionné. À toi/Franck de décider du découpage des commits.
- **`PythonIPM/EHCVM/` (les 4 bases construites) n'est jamais commité** — `.gitignore` exclut
  tous les `.dta`. Si tu clones cette branche ailleurs, relance
  `python pipeline/00_construction_bases_source.py` après avoir ajusté la constante `SOURCE` en
  tête de fichier (chemin du dossier de données brutes EHCVM 2021).
- **Point ouvert sur le NEET** : la question 2.05 (formation non formelle) a un fort taux de
  non-réponse (35 513 sur 64 491 individus), probablement un filtre de branchement du
  questionnaire pas encore identifié précisément. Une valeur manquante est traitée comme « pas en
  formation ». À surveiller si tu creuses le questionnaire CAPI.
- Le détail complet, indicateur par indicateur et décision par décision, est dans
  `METHODOLOGIE.md` (section « Journal des décisions », entrées du 30 août 2026).

À bientôt,
Franck (via Claude Code)
