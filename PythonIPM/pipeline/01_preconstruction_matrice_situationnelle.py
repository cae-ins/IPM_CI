"""Étape 01 du pipeline IPM — préconstruction (EHCVM 2021).

Cette étape ne calcule AUCUN indicateur et n'applique AUCUN seuil : elle prépare, ménage par
ménage, les variables de situation dont l'étape 02 a besoin pour construire les 16 indicateurs.

    Base_Individus  ->  âge, années d'études, scolarisation, alphabétisation, chômage BIT
                        puis agrégation au ménage (effectif concerné + effectif défavorable)
    Base_Menage     ->  éclairage, matériaux, eau, combustible principal, sanitaires
    Base_avoirs     ->  nombre de biens PNUD possédés, possession d'une voiture
    Base_securite_alimentaire -> score FIES (variante non retenue, conservé pour sensibilité)

Garder l'effectif concerné À CÔTÉ de l'effectif défavorable est le point important : c'est ce
qui permet à l'étape 02 de distinguer « non privé » de « non concerné » sans revenir aux
données individuelles.

Sortie : preconstruction_matrice_situationnelle_ehcvm2021.dta (12 965 ménages).

Usage :
    python 01_preconstruction_matrice_situationnelle.py
    python 01_preconstruction_matrice_situationnelle.py --check
"""
import logging
import sys
import time

import numpy as np
import pandas as pd

import dictionnaire_ehcvm as dico
from orchestrateur import (CLE, COLONNES_TECHNIQUES, DATA, LOGS, SOURCE, configurer_logs,
                           exporter_table, nom, part)

assert SOURCE == "ehcvm", "cette étape est celle de l'EHCVM : lancer avec IPM_SOURCE=ehcvm"

NOM_SORTIE = nom("preconstruction_matrice_situationnelle")
JOURNAL = LOGS / "01_preconstruction_matrice_situationnelle.log"

# tranches d'âge, telles que définies dans le tableau de référence (proposition nationale)
TRANCHES = {
    "scolarisation": (6, 16),
    "annees_etudes": (17, 95),
    "alphabetisation": (17, 49),
    "chomage": (17, 40),
    "neet": (15, 24),
    "acte_naissance": (5, 15),
}

# Question 4.18 : « ne veut pas travailler ». La main-d'œuvre potentielle suppose le DÉSIR
# d'emploi (BIT, 19e CIST) : ces personnes en sont exclues, leur réponse contredisant de
# toute façon la disponibilité qu'elles déclarent par ailleurs.
NE_VEUT_PAS_TRAVAILLER = 3

# années d'études accomplies AVANT d'entrer dans le niveau (questions 2.29 et 2.14)
ANNEES_AVANT_NIVEAU = {
    1: 0,   # maternelle
    2: 0,   # primaire                 (1re a 6e annee)
    3: 6,   # secondaire 1 general     (6e a 3e -> 7e a 10e annee)
    4: 6,   # secondaire 1 technique
    5: 10,  # secondaire 2 general     (2nde a Tle)
    6: 10,  # secondaire 2 technique
    7: 13,  # post-secondaire
    8: 13,  # superieur
}

# question 11.52 : deux principaux combustibles, ordonnés (rang 1 = principal)
COMBUSTIBLES = ["combustible_bois_ramasse", "combustible_bois_achete", "combustible_charbon",
                "combustible_gaz", "combustible_electricite", "combustible_petrole",
                "combustible_dechets_animaux", "combustible_autre"]

# Biens d'équipement, définition PNUD : « radio, télévision, téléphone, ordinateur,
# charrette, vélo, moto ou réfrigérateur ». Un bien = une ligne, même s'il correspond à
# plusieurs codes de la section 12 (le téléphone peut être fixe ou portable).
# Écart assumé : la CHARRETTE ne figure pas dans les 45 biens de la section 12 de l'EHCVM,
# le décompte porte donc sur 7 biens et non 8 (voir METHODOLOGIE.md).
EQUIPEMENTS_PNUD = {
    "radio": [19],
    "television": [20],
    "telephone": [34, 35],       # fixe ou portable
    "ordinateur": [37],
    "bicyclette": [30],
    "moto": [29],
    "refrigerateur": [16],
}
VOITURE = 28                     # le camion n'existe pas non plus dans la section 12

# Question 3.06 : raison principale de la non-consultation. Deux familles de motifs sont
# retenues — le renoncement est subi dans les deux cas, contrairement à l'automédication (4) ou
# au « pas nécessaire » (1), qui relèvent d'un choix :
#   coût            2 « Trop cher », 8 « Manque d'argent »
#   offre de soins  11 « Service spécialisé non disponible », 12 « Absence de personnel »
RAISONS_RENONCEMENT = [2, 8, 11, 12]

ITEMS_FIES = ["fies_inquietude", "fies_pas_sain", "fies_peu_varie", "fies_saute_repas",
              "fies_mange_moins", "fies_plus_de_nourriture", "fies_faim",
              "fies_journee_sans_manger"]

COLONNES_MENAGE = [
    # conditions de vie
    "source_eclairage", "materiau_toit", "materiau_mur", "materiau_sol",
    "source_eau_boisson_seche", "temps_aller_source_seche",
    "combustible_principal", "type_sanitaire", "sanitaire_partage", "nb_pieces",
] + COLONNES_TECHNIQUES

logger = logging.getLogger("ipm.preconstruction")


# --------------------------------------------------------------------------- #
# 1. chargement
# --------------------------------------------------------------------------- #
def charger_base(fichier, colonnes=None):
    """Lit un .dta en codes bruts (pas les libellés) et applique les noms explicites."""
    noms = dico.BASES[fichier]
    codes = {v: k for k, v in noms.items()}
    a_lire = [codes[c] for c in colonnes] if colonnes else list(noms)

    debut = time.perf_counter()
    d = pd.read_stata(DATA / fichier, columns=a_lire, convert_categoricals=False)
    d = d.rename(columns=noms)

    logger.info("%-32s %7d lignes x %3d colonnes  (%.1f s)",
                fichier, len(d), d.shape[1], time.perf_counter() - debut)
    logger.debug("%s : colonnes lues = %s", fichier, ", ".join(d.columns))
    return d


def charger_bases():
    """Les 4 bases utiles, avec nettoyage des lignes vides de la base FIES."""
    logger.info("--- 1. chargement des bases (codes bruts, colonnes du dictionnaire) ---")
    individus = charger_base("Base_Individus.dta")
    menages = charger_base("Base_Menage.dta")
    avoirs = charger_base("Base_avoirs_du_menage.dta")
    fies = charger_base("Base_securite_alimentaire.dta")

    vides = fies[CLE].isna().all(axis=1).sum()
    fies = fies.dropna(subset=CLE)
    logger.info("base FIES : %d lignes entièrement vides supprimées -> %d lignes", vides, len(fies))

    for nom, base in [("individus", individus), ("ménages", menages),
                      ("avoirs", avoirs), ("FIES", fies)]:
        logger.info("  %-10s : %6d ménages distincts", nom, len(base[CLE].drop_duplicates()))
    return individus, menages, avoirs, fies


# --------------------------------------------------------------------------- #
# 2. situations individuelles
# --------------------------------------------------------------------------- #
def calculer_age(ind):
    """Âge = année d'enquête (vague 1 = 2021, vague 2 = 2022) - année de naissance."""
    logger.info("--- 2.1 âge ---")
    annee_enquete = np.where(ind.vague == 1, 2021, 2022)
    age = pd.Series(annee_enquete - ind.annee_naissance, index=ind.index)

    logger.info("année de naissance renseignée : %s",
                part(ind.annee_naissance.notna().sum(), len(ind)))
    logger.info("âge déclaré (1.04a) renseigné : %s -> utilisé en priorité",
                part(ind.age_declare.notna().sum(), len(ind)))

    ind["age"] = ind.age_declare.fillna(age)
    aberrants = ((ind.age < 0) | (ind.age > 110)).sum()
    logger.info("âge calculé pour %s ; âges hors bornes (0-110 ans) : %d",
                part(ind.age.notna().sum(), len(ind)), aberrants)
    logger.debug("distribution de l'âge :\n%s", ind.age.describe().round(1).to_string())
    return ind


def calculer_annees_etudes(ind):
    """Années d'études (indicateur « Année de scolarité », définition nationale).

    L'EHCVM ne demande pas le nombre d'années d'études : il est reconstruit comme
    « années accomplies avant le niveau + classe atteinte », en trois branches —
    niveau achevé (2.29/2.31), niveau en cours (2.14/2.16, moins l'année non terminée),
    et 0 année pour ceux qui n'ont jamais fréquenté l'école (2.03 = non).
    """
    logger.info("--- 2.2 années d'études ---")
    achevees = ind.niveau_instruction.map(ANNEES_AVANT_NIVEAU) + ind.derniere_classe
    en_cours = ind.niveau_en_cours.map(ANNEES_AVANT_NIVEAU) + ind.classe_en_cours - 1

    ind["annees_etudes"] = achevees.fillna(en_cours)
    jamais = ind.a_frequente_ecole == 2
    ind.loc[jamais, "annees_etudes"] = 0

    logger.info("niveau achevé (2.29 + 2.31)      : %s", part(achevees.notna().sum(), len(ind)))
    logger.info("niveau en cours (2.14 + 2.16)    : %s (complète les précédents)",
                part((achevees.isna() & en_cours.notna()).sum(), len(ind)))
    logger.info("jamais fréquenté l'école (2.03)  : %s -> 0 année", part(jamais.sum(), len(ind)))
    logger.info("années d'études indéterminées    : %s",
                part(ind.annees_etudes.isna().sum(), len(ind)))
    logger.debug("distribution des années d'études :\n%s",
                 ind.annees_etudes.describe().round(1).to_string())
    return ind


def calculer_situations_individuelles(ind):
    """Scolarisation, alphabétisation et chômage — trois définitions nationales.

    Scolarisation : « ne fréquente actuellement pas », mesuré sur l'année scolaire la plus
    récente disponible (2.08a n'est posée qu'en vague 2, 2.12 l'est aux deux vagues).
    Alphabétisation : sait lire ET écrire le français.
    Chômage : les trois critères du BIT — sans emploi, en recherche, disponible.
    """
    logger.info("--- 2.3 scolarisation, alphabétisation, chômage ---")

    recente = ind.scolarise_2021_2022 == 1
    precedente = ind.scolarise_2020_2021 == 1
    ind["scolarise"] = recente | precedente
    logger.info("scolarisé en 2021/22 (2.08a, vague 2 seule) : %s",
                part(recente.sum(), len(ind)))
    logger.info("scolarisé en 2020/21 (2.12, deux vagues)    : %s",
                part(precedente.sum(), len(ind)))

    a, b = TRANCHES["scolarisation"]
    cible = ind.age.between(a, b)
    logger.info("enfants de %d-%d ans : %s, dont non scolarisés : %s",
                a, b, part(cible.sum(), len(ind)),
                part((cible & ~ind.scolarise).sum(), cible.sum()))

    ind["alphabetise"] = (ind.lit_francais == 1) & (ind.ecrit_francais == 1)
    a, b = TRANCHES["alphabetisation"]
    cible = ind.age.between(a, b)
    logger.info("alphabétisés (lit ET écrit le français) parmi les %d-%d ans : %s",
                a, b, part((cible & ind.alphabetise).sum(), cible.sum()))

    sans_emploi = (ind.a_travaille_7j != 1) & (ind.emploi_mais_absent_7j != 1)
    recherche = (ind.recherche_emploi_30j_a == 1) | (ind.recherche_emploi_30j_b == 1)
    disponible = ind.delai_disponibilite.isin([1, 2, 3]) | (ind.disponible_emploi == 1)
    ind["chomeur_bit"] = sans_emploi & recherche & disponible

    # Main-d'œuvre potentielle : ceux qui veulent travailler sans réunir les trois critères.
    # Deux branches symétriques — cherche sans être disponible, ou disponible sans chercher
    # (c'est là que loge le découragement). SU3 = chômage BIT + main-d'œuvre potentielle.
    veut_travailler = ind.raison_non_recherche != NE_VEUT_PAS_TRAVAILLER
    ind["main_oeuvre_potentielle"] = sans_emploi & (
        (recherche & ~disponible)
        | (~recherche & (ind.disponible_emploi == 1) & veut_travailler))
    ind["su3"] = ind.chomeur_bit | ind.main_oeuvre_potentielle

    # NEET approché : l'EHCVM ne demande pas si une formation non formelle est suivie EN COURS.
    # L'indicateur observable est donc strictement « ni en emploi, ni en études » (NEE). Il est
    # conservé sous le nom neet_approx pour empêcher qu'une sortie ne masque cette limite. La
    # scolarisation reprend la meilleure observation disponible selon la vague (2021/22 ou
    # 2020/21) ; l'apprentissage de 4.09 est déjà inclus dans l'emploi via 4.10.
    a_neet, b_neet = TRANCHES["neet"]
    jeune = ind.age.between(a_neet, b_neet)
    ind["neet_approx"] = jeune & sans_emploi & ~ind.scolarise

    logger.info("chômage BIT : sans emploi %s, dont en recherche %s, dont disponibles %s",
                part(sans_emploi.sum(), len(ind)),
                part((sans_emploi & recherche).sum(), sans_emploi.sum()),
                part((sans_emploi & recherche & disponible).sum(), (sans_emploi & recherche).sum()))
    a, b = TRANCHES["chomage"]
    cible = ind.age.between(a, b)
    logger.info("chômeurs parmi les %d-%d ans : %s", a, b,
                part((cible & ind.chomeur_bit).sum(), cible.sum()))

    cherche_non_dispo = sans_emploi & recherche & ~disponible
    dispo_non_chercheur = ind.main_oeuvre_potentielle & ~recherche
    logger.info("main-d'œuvre potentielle : cherche sans être disponible %s, "
                "disponible sans chercher %s",
                part(cherche_non_dispo.sum(), len(ind)),
                part(dispo_non_chercheur.sum(), len(ind)))
    logger.info("SU3 parmi les %d-%d ans : %s (SU1 : %s)", a, b,
                part((cible & ind.su3).sum(), cible.sum()),
                part((cible & ind.chomeur_bit).sum(), cible.sum()))
    logger.info("NEET approché (en réalité NEE) parmi les %d-%d ans : %s",
                a_neet, b_neet, part(ind.neet_approx.sum(), jeune.sum()))

    # renoncement aux soins : malade (3.01), non consulté (3.05), pour une raison subie —
    # coût ou indisponibilité de l'offre (3.06)
    malade = ind.probleme_sante_30j == 1
    ind["renonce_aux_soins"] = (malade & (ind.consultation_sante_30j != 1)
                               & ind.raison_non_consultation.isin(RAISONS_RENONCEMENT))
    logger.info("problème de santé sur 30 jours (3.01) : %s, dont non consulté %s, "
                "dont pour coût ou indisponibilité (3.06 = 2, 8, 11 ou 12) : %s",
                part(malade.sum(), len(ind)),
                part((malade & (ind.consultation_sante_30j != 1)).sum(), malade.sum()),
                part(ind.renonce_aux_soins.sum(), malade.sum()))

    # emploi agricole de subsistance : occupé (4.10), uniquement son propre champ (4.06),
    # sans salariat (4.08), apprentissage (4.09) ni commerce (4.07).
    # Codage EHCVM des questions 4.06-4.09 : 1 = oui, 2 = non (il n'y a pas de 0) — le test
    # porte donc sur « pas oui » et non sur « = 0 ».
    ind["agriculture_subsistance"] = ((ind.a_travaille_7j == 1)
                                      & (ind.travail_champ_7j == 1)
                                      & (ind.travail_salarie_7j != 1)
                                      & (ind.travail_apprenti_7j != 1)
                                      & (ind.travail_commerce_7j != 1))
    occupes = ind.a_travaille_7j == 1
    logger.info("occupés (4.10) : %s, dont agriculture de subsistance seule : %s",
                part(occupes.sum(), len(ind)),
                part(ind.agriculture_subsistance.sum(), occupes.sum()))
    return ind


# --------------------------------------------------------------------------- #
# 3. agrégation au ménage
# --------------------------------------------------------------------------- #
def agreger_par_menage(ind):
    """Pour chaque indicateur : l'effectif concerné et l'effectif en situation défavorable."""
    logger.info("--- 3. agrégation des individus par ménage ---")
    a_sco, b_sco = TRANCHES["scolarisation"]
    a_etu, b_etu = TRANCHES["annees_etudes"]
    a_alp, b_alp = TRANCHES["alphabetisation"]
    a_cho, b_cho = TRANCHES["chomage"]
    a_neet, b_neet = TRANCHES["neet"]
    a_act, b_act = TRANCHES["acte_naissance"]

    concernes_etudes = ind.age.between(a_etu, b_etu)
    situations = pd.DataFrame(index=ind.index)
    situations[f"enfants_{a_sco}_{b_sco}"] = ind.age.between(a_sco, b_sco)
    situations[f"enfants_{a_sco}_{b_sco}_non_scolarises"] = (
        situations[f"enfants_{a_sco}_{b_sco}"] & ~ind.scolarise)
    situations[f"membres_{a_etu}_{b_etu}"] = concernes_etudes
    situations[f"membres_{a_alp}_{b_alp}"] = ind.age.between(a_alp, b_alp)
    situations[f"membres_{a_alp}_{b_alp}_alphabetises"] = (
        situations[f"membres_{a_alp}_{b_alp}"] & ind.alphabetise)
    situations[f"membres_{a_cho}_{b_cho}"] = ind.age.between(a_cho, b_cho)
    situations[f"chomeurs_{a_cho}_{b_cho}"] = (
        situations[f"membres_{a_cho}_{b_cho}"] & ind.chomeur_bit)
    situations[f"chomeurs_su3_{a_cho}_{b_cho}"] = (
        situations[f"membres_{a_cho}_{b_cho}"] & ind.su3)
    situations[f"jeunes_{a_neet}_{b_neet}"] = ind.age.between(a_neet, b_neet)
    situations[f"jeunes_neet_approx_{a_neet}_{b_neet}"] = (
        situations[f"jeunes_{a_neet}_{b_neet}"] & ind.neet_approx)
    situations[f"enfants_{a_act}_{b_act}"] = ind.age.between(a_act, b_act)
    situations[f"enfants_{a_act}_{b_act}_sans_acte"] = (
        situations[f"enfants_{a_act}_{b_act}"] & (ind.acte_naissance != 1))
    situations["membres_assures"] = ind.assurance_maladie == 1
    situations["membres_malades_30j"] = ind.probleme_sante_30j == 1
    situations["membres_renoncement_soins"] = ind.renonce_aux_soins
    # un seul chef par ménage : la somme vaut 0 ou 1
    situations["cm_agriculture_subsistance"] = (
        (ind.lien_parente_cm == 1) & ind.agriculture_subsistance)

    colonnes = list(situations.columns)
    situations[CLE] = ind[CLE]
    X = situations.groupby(CLE)[colonnes].sum()

    # le maximum d'années d'études se calcule sur les seules personnes concernées
    X.insert(3, "annees_etudes_max",
             ind.assign(_e=ind.annees_etudes.where(concernes_etudes)).groupby(CLE)._e.max())

    logger.info("%d ménages agrégés à partir de %d individus", len(X), len(ind))
    for concernes, defavorables, libelle in [
            (f"enfants_{a_sco}_{b_sco}", f"enfants_{a_sco}_{b_sco}_non_scolarises",
             "un enfant non scolarisé"),
            (f"membres_{a_alp}_{b_alp}", f"membres_{a_alp}_{b_alp}_alphabetises",
             "un membre alphabétisé"),
            (f"membres_{a_cho}_{b_cho}", f"chomeurs_{a_cho}_{b_cho}", "un chômeur"),
            (f"jeunes_{a_neet}_{b_neet}", f"jeunes_neet_approx_{a_neet}_{b_neet}",
             "un jeune NEET approché"),
            (f"enfants_{a_act}_{b_act}", f"enfants_{a_act}_{b_act}_sans_acte",
             "un enfant sans acte de naissance")]:
        logger.info("  %-16s ménages sans personne concernée : %-14s | au moins %s : %s",
                    concernes, part((X[concernes] == 0).sum(), len(X)),
                    libelle, part((X[defavorables] > 0).sum(), len(X)))
    logger.info("  %-16s ménages sans personne concernée : %s",
                f"membres_{a_etu}_{b_etu}", part((X[f"membres_{a_etu}_{b_etu}"] == 0).sum(), len(X)))
    logger.info("  %-16s ménages sans aucun membre assuré : %s",
                "membres_assures", part((X.membres_assures == 0).sum(), len(X)))
    logger.info("  %-16s ménages sans malade sur 30 jours : %-14s | au moins un renoncement "
                "aux soins (coût ou indisponibilité) : %s", "membres_malades_30j",
                part((X.membres_malades_30j == 0).sum(), len(X)),
                part((X.membres_renoncement_soins > 0).sum(), len(X)))
    logger.info("  %-16s chef en agriculture de subsistance seule : %s",
                "cm_agriculture_subsistance",
                part((X.cm_agriculture_subsistance > 0).sum(), len(X)))
    return X


# --------------------------------------------------------------------------- #
# 4. situations propres au ménage
# --------------------------------------------------------------------------- #
def situations_menage(men):
    """Combustible principal = celui de rang 1 dans la question 11.52 (définition nationale :
    énergie propre = électricité ou gaz)."""
    logger.info("--- 4.1 combustible principal ---")
    rangs = men[COMBUSTIBLES]
    men["combustible_principal"] = np.where(
        rangs.eq(1).any(axis=1),
        rangs.eq(1).idxmax(axis=1).str.replace("combustible_", "", regex=False),
        None)

    for combustible, n in men.combustible_principal.value_counts(dropna=False).items():
        logger.info("  %-16s %s", combustible, part(n, len(men)))
    return men


def equipement(avoirs):
    """Biens d'équipement, définition PNUD, et possession d'une voiture.

    Un bien compte pour 1 même s'il couvre plusieurs codes (téléphone fixe ou portable).
    La charrette est absente de la section 12 de l'EHCVM : 7 biens au lieu de 8.
    """
    logger.info("--- 4.2 biens d'équipement (définition PNUD) ---")
    par_bien = (avoirs.assign(_possede=avoirs.possede_bien == 1)
                      .pivot_table(index=CLE, columns="code_bien", values="_possede",
                                   aggfunc="max")
                      .fillna(0).astype(bool))

    X = pd.DataFrame(index=par_bien.index)
    for nom, codes in EQUIPEMENTS_PNUD.items():
        presents = [c for c in codes if c in par_bien.columns]
        X[nom] = par_bien[presents].any(axis=1)
        logger.info("  %-16s %s", nom, part(X[nom].sum(), len(X)))

    X["nb_equipements"] = X[list(EQUIPEMENTS_PNUD)].sum(axis=1)
    X["possede_voiture"] = par_bien[VOITURE].astype(int)
    logger.info("  %-16s %s", "voiture", part(X.possede_voiture.sum(), len(X)))
    logger.info("charrette : absente des 45 biens de la section 12 -> décompte sur %d biens",
                len(EQUIPEMENTS_PNUD))
    logger.info("nombre de biens possédés : moyenne %.2f (le seuil est appliqué à l'étape 02)",
                X.nb_equipements.mean())
    logger.debug("distribution du nombre de biens :\n%s",
                 X.nb_equipements.value_counts().sort_index().to_string())
    return X[["nb_equipements", "possede_voiture"]]


def score_fies(fies):
    """Score FIES = nombre de « oui » sur les 8 questions (98 NSP et 99 Refus = manquant).

    Variante de sensibilité pour la dimension santé — non retenue : l'indicateur santé est
    l'assurance maladie (voir METHODOLOGIE.md).
    """
    logger.info("--- 4.3 score d'insécurité alimentaire (FIES, variante non retenue) ---")
    reponses = fies.set_index(CLE)[ITEMS_FIES].replace({98: np.nan, 99: np.nan, 2: 0})
    non_reponse = reponses.isna().sum().sum()
    X = pd.DataFrame({"score_fies": reponses.sum(axis=1, min_count=len(ITEMS_FIES))})

    logger.info("%d non-réponses (NSP/Refus) sur %d items ; ménages sans score complet : %s",
                non_reponse, reponses.size, part(X.score_fies.isna().sum(), len(X)))
    logger.debug("distribution du score FIES :\n%s",
                 X.score_fies.value_counts(dropna=False).sort_index().to_string())
    return X


# --------------------------------------------------------------------------- #
# 5. assemblage et contrôles
# --------------------------------------------------------------------------- #
def preconstruire():
    """Enchaîne les étapes 1 à 4 et assemble la table de préconstruction."""
    individus, menages, avoirs, fies = charger_bases()

    individus = calculer_age(individus)
    individus = calculer_annees_etudes(individus)
    individus = calculer_situations_individuelles(individus)

    X_individus = agreger_par_menage(individus)
    menages = situations_menage(menages)
    X_biens = equipement(avoirs)
    X_fies = score_fies(fies)

    logger.info("--- 5. assemblage de la table de préconstruction ---")
    X = menages.set_index(CLE)[COLONNES_MENAGE]
    for nom, morceau in [("individus", X_individus), ("équipement", X_biens), ("FIES", X_fies)]:
        avant = len(X)
        X = X.join(morceau, how="left", validate="1:1")
        manquants = X[morceau.columns[0]].isna().sum()
        logger.info("  jointure %-11s : %d lignes conservées, %d ménages non appariés",
                    nom, avant, manquants)

    logger.info("table de préconstruction : %d ménages x %d colonnes", *X.shape)
    return X


def controler(X):
    """Contrôles de qualité : unicité, distributions, valeurs manquantes."""
    logger.info("--- 6. contrôles ---")
    assert X.index.is_unique, "la clé grappe/menage/vague doit être unique"
    logger.info("clé unique : oui (%d ménages)", len(X))

    manquantes = [c for c in COLONNES_TECHNIQUES if c not in X.columns]
    assert not manquantes, f"colonnes de pondération/désagrégation absentes : {manquantes}"
    assert X.ponderation_menage.gt(0).all(), "une pondération est nulle ou négative"
    logger.info("population représentée (taille x pondération) : %s personnes",
                part(int((X.ponderation_menage * X.taille_menage).sum()), 0))

    a_cho, b_cho = TRANCHES["chomage"]
    logger.info("statistiques des situations chiffrées :\n%s",
                X[["annees_etudes_max", "enfants_6_16_non_scolarises",
                   f"chomeurs_{a_cho}_{b_cho}", "enfants_5_15_sans_acte", "nb_equipements",
                   "score_fies", "taille_menage"]].describe().round(2).to_string())

    manquants = X.isna().mean().sort_values(ascending=False)
    manquants = manquants[manquants > 0]
    if manquants.empty:
        logger.info("aucune valeur manquante")
    else:
        logger.info("valeurs manquantes (part des ménages) :")
        for colonne, taux in manquants.items():
            logger.info("  %-28s %.1f %%", colonne, 100 * taux)
        logger.info("ces vides sont des filtres du questionnaire, pas des données perdues :")
        logger.info("  - sanitaire_partage (11.55) n'est pas posée aux ménages sans toilettes "
                    "-> déjà comptés comme privés par le type de sanitaire")
        logger.info("  - temps_aller_source_seche (11.28a) n'est pas posée quand l'eau est sur "
                    "place (distance nulle) -> temps nul")
    return X


def exporter(X, nom=NOM_SORTIE):
    logger.info("--- 7. export (Stata + CSV) ---")
    exporter_table(X, nom, logger)


# --------------------------------------------------------------------------- #
# auto-contrôle
# --------------------------------------------------------------------------- #
def verifier():
    """Rejoue la chaîne sur des cas construits à la main, aux résultats connus."""
    configurer_logs(logger, niveau=logging.WARNING)

    ind = pd.DataFrame({
        "grappe": [1, 1, 2, 2], "menage": [1.0, 1.0, 1.0, 1.0], "vague": [1.0, 1.0, 1.0, 1.0],
        "annee_naissance": [2010.0, 1983.0, 1980.0, 2015.0],
        "age_declare": [np.nan, np.nan, np.nan, np.nan],
        # études : en cours (P1), primaire achevé (P2), secondaire 1 achevé (P3), jamais (P4)
        "niveau_instruction": [np.nan, 2.0, 3.0, np.nan],
        "derniere_classe": [np.nan, 6.0, 4.0, np.nan],
        "niveau_en_cours": [2.0, np.nan, np.nan, np.nan],
        "classe_en_cours": [5.0, np.nan, np.nan, np.nan],
        "a_frequente_ecole": [1.0, 1.0, 1.0, 2.0],
        # scolarisation : P1 déscolarisé, P4 scolarisé
        "scolarise_2021_2022": [2.0, np.nan, np.nan, 1.0],
        "scolarise_2020_2021": [2.0, np.nan, np.nan, np.nan],
        "lit_francais": [0.0, 1.0, 1.0, 0.0],
        "ecrit_francais": [0.0, 1.0, 0.0, 0.0],
        # emploi : P2 chômeur BIT à 38 ans (hors de l'ancienne tranche 16-35, dans 17-40),
        # P4 ne cherche pas mais se déclare disponible faute d'emploi -> main-d'œuvre
        # potentielle, donc SU3 mais pas SU1
        "a_travaille_7j": [1.0, 0.0, 1.0, 0.0],
        "emploi_mais_absent_7j": [2.0, 2.0, 2.0, 2.0],
        "recherche_emploi_30j_a": [np.nan, 1.0, 2.0, 2.0],
        "recherche_emploi_30j_b": [np.nan, np.nan, np.nan, np.nan],
        "disponible_emploi": [np.nan, np.nan, np.nan, 1.0],
        "delai_disponibilite": [np.nan, 1.0, np.nan, np.nan],
        "raison_non_recherche": [np.nan, np.nan, np.nan, 12.0],
        "acte_naissance": [2.0, 1.0, 1.0, 1.0],
        "assurance_maladie": [2.0, 2.0, 1.0, 2.0],
        # santé : P1 malade et renonce faute d'argent, P2 malade mais a consulté,
        # P3 malade et renonce mais par automédication (choix, pas contrainte), P4 pas malade
        "probleme_sante_30j": [1.0, 1.0, 1.0, 2.0],
        "consultation_sante_30j": [2.0, 1.0, 2.0, np.nan],
        "raison_non_consultation": [8.0, np.nan, 4.0, np.nan],
        # emploi : P1 chef, agriculture seule ; P3 chef, champ + commerce
        "lien_parente_cm": [1.0, 3.0, 1.0, 3.0],
        "travail_champ_7j": [1.0, 2.0, 1.0, np.nan],
        "travail_commerce_7j": [2.0, 2.0, 1.0, np.nan],
        "travail_salarie_7j": [2.0, 2.0, 2.0, np.nan],
        "travail_apprenti_7j": [2.0, 2.0, 2.0, np.nan],
    })

    ind = calculer_age(ind)
    assert ind.age.tolist() == [11.0, 38.0, 41.0, 6.0], ind.age.tolist()

    ind = calculer_annees_etudes(ind)
    # P1 : 2e année du primaire en cours -> 4 ; P2 : primaire achevé -> 6 ;
    # P3 : secondaire 1, 4e année -> 10 ; P4 : jamais scolarisé -> 0
    assert ind.annees_etudes.tolist() == [4.0, 6.0, 10.0, 0.0], ind.annees_etudes.tolist()

    ind = calculer_situations_individuelles(ind)
    assert ind.scolarise.tolist() == [False, False, False, True]
    assert ind.alphabetise.tolist() == [False, True, False, False]
    assert ind.chomeur_bit.tolist() == [False, True, False, False]
    # SU3 = chômage BIT + main-d'œuvre potentielle : P2 par le chômage, P4 par la disponibilité
    assert ind.main_oeuvre_potentielle.tolist() == [False, False, False, True]
    assert ind.su3.tolist() == [False, True, False, True]
    # P1 a 11 ans ; P2 a 38 ans ; P3 a 41 ans ; P4 a 6 ans : aucun n'est dans 15-24.
    assert not ind.neet_approx.any()
    # « ne veut pas travailler » (4.18 = 3) sort de la main-d'œuvre potentielle : le désir
    # d'emploi fait partie de la définition
    refus = calculer_situations_individuelles(
        ind.assign(raison_non_recherche=[np.nan, np.nan, np.nan, float(NE_VEUT_PAS_TRAVAILLER)]))
    assert refus.su3.tolist() == [False, True, False, False], refus.su3.tolist()
    assert ind.renonce_aux_soins.tolist() == [True, False, False, False]
    # les motifs d'offre comptent au même titre que le coût, l'automédication non
    motifs = ind.assign(raison_non_consultation=[11.0, np.nan, 12.0, np.nan])
    assert (calculer_situations_individuelles(motifs).renonce_aux_soins.tolist()
            == [True, False, True, False])
    assert ind.agriculture_subsistance.tolist() == [True, False, False, False]

    X = agreger_par_menage(ind)
    m1, m2 = X.loc[(1, 1.0, 1.0)], X.loc[(2, 1.0, 1.0)]
    assert m1.enfants_6_16 == 1 and m1.enfants_6_16_non_scolarises == 1
    assert m2.enfants_6_16 == 1 and m2.enfants_6_16_non_scolarises == 0
    assert m1.annees_etudes_max == 6 and m2.annees_etudes_max == 10
    assert m1.membres_17_49 == 1 and m1.membres_17_49_alphabetises == 1
    assert m2.membres_17_49 == 1 and m2.membres_17_49_alphabetises == 0
    # le chômeur a 38 ans : compté dans la tranche 17-40 de la proposition nationale
    assert m1.membres_17_40 == 1 and m1.chomeurs_17_40 == 1
    assert m1.chomeurs_su3_17_40 == 1
    assert m1.jeunes_15_24 == 0 and m2.jeunes_15_24 == 0
    assert m2.chomeurs_17_40 == 0
    assert m1.enfants_5_15_sans_acte == 1 and m2.enfants_5_15_sans_acte == 0
    assert m1.membres_assures == 0 and m2.membres_assures == 1
    assert m1.membres_malades_30j == 2 and m1.membres_renoncement_soins == 1
    assert m2.membres_malades_30j == 1 and m2.membres_renoncement_soins == 0
    # P1 est chef et en agriculture de subsistance ; P3, chef du ménage 2, fait aussi du commerce
    assert m1.cm_agriculture_subsistance == 1 and m2.cm_agriculture_subsistance == 0

    # équipement PNUD : ménage 1 = radio + téléphone fixe + téléphone portable -> 2 biens
    # (le téléphone ne compte qu'une fois) ; ménage 2 = réfrigérateur + voiture -> 1 bien
    avoirs = pd.DataFrame({
        "grappe": [1, 1, 1, 1, 2, 2],
        "menage": [1.0, 1.0, 1.0, 1.0, 1.0, 1.0],
        "vague": [1.0, 1.0, 1.0, 1.0, 1.0, 1.0],
        "code_bien": [19, 34, 35, VOITURE, 16, VOITURE],
        "possede_bien": [1, 1, 1, 2, 1, 1],
    })
    E = equipement(avoirs)
    assert E.loc[(1, 1.0, 1.0), "nb_equipements"] == 2, E
    assert E.loc[(1, 1.0, 1.0), "possede_voiture"] == 0
    assert E.loc[(2, 1.0, 1.0), "nb_equipements"] == 1
    assert E.loc[(2, 1.0, 1.0), "possede_voiture"] == 1

    print("auto-contrôle 01 : OK")


def main():
    configurer_logs(logger, JOURNAL)
    debut = time.perf_counter()
    logger.info("=== étape 01 : préconstruction de la matrice situationnelle (EHCVM 2021) ===")

    X = preconstruire()
    controler(X)
    exporter(X)

    logger.info("=== terminé en %.1f s ===", time.perf_counter() - debut)
    return X


if __name__ == "__main__":
    if "--check" in sys.argv:
        verifier()
    else:
        main()
