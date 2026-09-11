"""Étape 01 du pipeline IPM — préconstruction (RGPH 2021).

Jumelle de `01_preconstruction_matrice_situationnelle.py`, pour le recensement. Même contrat
de sortie : une ligne par ménage, et pour chaque indicateur l'effectif CONCERNÉ à côté de
l'effectif DÉFAVORABLE, sans qu'aucun seuil ne soit appliqué ici. L'étape 02 travaille ensuite
sur ces colonnes sans savoir de quelle source elles viennent.

    IPM_Data_191125.dta       -> âge, scolarisation, alphabétisation, diplôme, état civil,
                                 chômage BIT, emploi agricole du chef, puis agrégation au
                                 ménage. 28 millions de lignes : lues par morceaux.
    IPM_Data_110924_men.dta   -> logement, eau, éclairage, cuisson, sanitaires, biens
                                 d'équipement. Une ligne par ménage, jointe par l'`INDIV_ID`
                                 du chef.
    MORTALITE_RP2021_...dta   -> décès d'enfants de moins de 18 ans survenus dans le ménage,
                                 joints par la clé géographique.

Trois écarts assumés par rapport à l'EHCVM, tous imposés par le questionnaire de recensement
(voir METHODOLOGIE.md) :

    années d'études   le RGPH ne demande ni les années ni la classe atteinte -> le diplôme le
                      plus élevé sert d'approximation (BEPC et au-delà = 10 années)
    dimension Santé   ni assurance maladie, ni FIES, ni renoncement aux soins -> la mortalité
                      dans le ménage tient lieu d'indicateur unique
    promiscuité       le nombre de pièces n'est pas collecté -> indicateur absent

Sortie : preconstruction_matrice_situationnelle_rgph2021.dta (5,6 millions de ménages).

Usage :
    IPM_SOURCE=rgph python 01_rgph_preconstruction_matrice_situationnelle.py
    IPM_SOURCE=rgph python 01_rgph_preconstruction_matrice_situationnelle.py --check
"""
import logging
import sys
import time

import numpy as np
import pandas as pd

import dictionnaire_rgph as dico
from orchestrateur import (CLE, DATA, LOGS, SOURCE, configurer_logs, exporter_table, nom, part)

assert SOURCE == "rgph", "cette étape est celle du RGPH : lancer avec IPM_SOURCE=rgph"

NOM_SORTIE = nom("preconstruction_matrice_situationnelle")
JOURNAL = LOGS / "01_rgph_preconstruction_matrice_situationnelle.log"

# Tranches d'âge : les mêmes que dans l'EHCVM, pour que les deux IPM mesurent la même chose.
TRANCHES = {
    "scolarisation": (6, 16),
    "annees_etudes": (17, 95),
    "alphabetisation": (17, 49),
    "chomage": (17, 40),
    "acte_naissance": (5, 15),
}

AGE_INCONNU = 999            # code « ne sait pas » de la question 18
AGE_AU_DECES_INCONNU = 998   # idem, question 61A2
# Décès avant 18 ans : la borne du dofile officiel du RGPH 2021, et celle de l'IPM mondial
# (« un enfant de moins de 18 ans décédé dans le ménage »).
AGE_MORTALITE_JUVENILE = 18

# Question 34A : 11 = « non, aucune activité de ce genre ». Toutes les autres modalités sont
# des façons d'avoir travaillé.
SANS_ACTIVITE_7J = 11

# Statut d'activité construit par l'INS (`Statut_OQPtbb`). Vérifié contre la construction du
# dofile officiel du RGPH 2021 (`rp21_calcul_des_privations.do`, variable `Statut_OQP`, qui
# applique les trois critères BIT — sans emploi, en recherche, disponible) : les deux ne
# diffèrent que sur 18 910 individus sur 28 millions, soit 0,07 %. L'autre variable de la base,
# `Statut_OQPtb`, donne 21,6 % de ménages privés contre 5,9 % ici : elle n'intègre pas le
# reclassement INS des personnes déclarées sans activité mais en réalité occupées.
OCCUPE, CHOMEUR_BIT = 0, 1

# Emploi agricole de subsistance : le RGPH ne demande pas « sur son propre champ ». Le chef est
# compté comme en subsistance s'il est occupé dans une branche agricole (NAEMA divisions 01 à
# 03) et qu'il y travaille à son compte ou comme aide familial — donc hors salariat, hors
# apprentissage et hors employeur.
BRANCHES_AGRICOLES = (1000, 4000)            # bornes NAEMA [01000 ; 04000[
INDEPENDANT, AIDE_FAMILIAL = 3, 5            # question 37, situation dans la profession

# Biens d'équipement, définition PNUD : « radio, télévision, téléphone, ordinateur, charrette,
# vélo, moto ou réfrigérateur ». Le RGPH, contrairement à l'EHCVM, collecte bien la charrette
# (« véhicule à traction animale ») : les 8 biens y sont tous, sans écart à signaler.
EQUIPEMENTS_PNUD = {
    "radio": ["bien_radio"],
    "television": ["bien_television"],
    "telephone": ["bien_telephone_fixe", "bien_telephone_mobile"],
    "ordinateur": ["bien_ordinateur"],
    "charrette": ["bien_charrette"],
    "bicyclette": ["bien_velo"],
    "moto": ["bien_moto"],
    "refrigerateur": ["bien_refrigerateur"],
}

# colonnes du fichier individus effectivement lues (28 millions de lignes : rien de superflu)
COLONNES_INDIVIDUS = [
    "id_individu", "id_menage", "lien_parente_cm", "age",
    "acte_naissance", "lit_ecrit_une_langue", "lit_ecrit_francais", "frequente_ecole",
    "diplome_le_plus_eleve", "statut_activite", "branche_activite", "situation_profession",
    "region", "departement", "sous_prefecture", "zone_controle", "zone_denombrement",
    "milieu", "taille_menage", "ponderation_menage",
]
# ce que la ligne du chef apporte au ménage : géographie, pondération, taille
COLONNES_CHEF = ["id_menage", "id_individu", "region", "departement", "sous_prefecture",
                 "zone_controle", "zone_denombrement", "milieu", "taille_menage",
                 "ponderation_menage"]

LIGNES_PAR_MORCEAU = 3_000_000

logger = logging.getLogger("ipm.rgph.preconstruction")


# --------------------------------------------------------------------------- #
# 1. lecture
# --------------------------------------------------------------------------- #
def _renommer(fichier, colonnes=None):
    """Codes RGPH à lire et table de renommage, pour un sous-ensemble de noms explicites."""
    noms = dico.BASES[fichier]
    codes = {v: k for k, v in noms.items()}
    a_lire = [codes[c] for c in colonnes] if colonnes else list(noms)
    return a_lire, noms


def charger_base(fichier, colonnes=None):
    """Lit un .dta entier en codes bruts et applique les noms explicites."""
    a_lire, noms = _renommer(fichier, colonnes)
    debut = time.perf_counter()
    d = (pd.read_stata(DATA / fichier, columns=a_lire, convert_categoricals=False)
           .rename(columns=noms))
    logger.info("%-32s %9d lignes x %3d colonnes  (%.1f s)",
                fichier, len(d), d.shape[1], time.perf_counter() - debut)
    return d


def morceaux_individus(fichier=dico.FICHIER_INDIVIDUS, colonnes=COLONNES_INDIVIDUS,
                       lignes=LIGNES_PAR_MORCEAU):
    """Itère le fichier individus par morceaux : 28 millions de lignes ne tiennent pas en
    mémoire en une fois, et rien dans cette étape n'a besoin de les voir toutes ensemble."""
    a_lire, noms = _renommer(fichier, colonnes)
    lecteur = pd.read_stata(DATA / fichier, columns=a_lire, convert_categoricals=False,
                            iterator=True)
    while True:
        try:
            morceau = lecteur.get_chunk(lignes)
        except StopIteration:
            return
        if morceau.empty:
            return
        yield morceau.rename(columns=noms)


# --------------------------------------------------------------------------- #
# 2. situations individuelles
# --------------------------------------------------------------------------- #
def situations_individuelles(ind):
    """Les cinq situations mesurées sur l'individu, avant toute agrégation.

    Convention identique à l'EHCVM : chaque colonne est un booléen, et l'appartenance à la
    tranche d'âge concernée est portée par une colonne séparée — c'est elle qui permettra à
    l'étape 02 de distinguer « non privé » de « non concerné ».
    """
    age = ind.age.where(ind.age != AGE_INCONNU)
    a_sco, b_sco = TRANCHES["scolarisation"]
    a_etu, b_etu = TRANCHES["annees_etudes"]
    a_alp, b_alp = TRANCHES["alphabetisation"]
    a_cho, b_cho = TRANCHES["chomage"]
    a_act, b_act = TRANCHES["acte_naissance"]

    S = pd.DataFrame({"id_menage": ind.id_menage})
    S[f"enfants_{a_sco}_{b_sco}"] = age.between(a_sco, b_sco)
    S[f"enfants_{a_sco}_{b_sco}_non_scolarises"] = (
        S[f"enfants_{a_sco}_{b_sco}"] & (ind.frequente_ecole != 1))

    # « année de scolarité » : faute d'années d'études dans le questionnaire, le diplôme
    S[f"membres_{a_etu}_{b_etu}"] = age.between(a_etu, b_etu)
    S[f"membres_{a_etu}_{b_etu}_dix_annees_etudes"] = (
        S[f"membres_{a_etu}_{b_etu}"]
        & ind.diplome_le_plus_eleve.isin(dico.DIPLOMES_DIX_ANNEES))

    # alphabétisation : sait lire ET écrire le français (question 29A filtrant la 29_BA)
    S[f"membres_{a_alp}_{b_alp}"] = age.between(a_alp, b_alp)
    S[f"membres_{a_alp}_{b_alp}_alphabetises"] = (
        S[f"membres_{a_alp}_{b_alp}"]
        & (ind.lit_ecrit_une_langue == 1) & (ind.lit_ecrit_francais == 1))

    # état civil : 1 = déclaré AVEC acte ; « déclaré sans acte » (2) est une privation
    S[f"enfants_{a_act}_{b_act}"] = age.between(a_act, b_act)
    S[f"enfants_{a_act}_{b_act}_sans_acte"] = (
        S[f"enfants_{a_act}_{b_act}"] & (ind.acte_naissance != 1))

    S[f"membres_{a_cho}_{b_cho}"] = age.between(a_cho, b_cho)
    S[f"chomeurs_{a_cho}_{b_cho}"] = (
        S[f"membres_{a_cho}_{b_cho}"] & (ind.statut_activite == CHOMEUR_BIT))

    # un seul chef par ménage : la somme vaut 0 ou 1
    debut, fin = BRANCHES_AGRICOLES
    S["cm_agriculture_subsistance"] = (
        (ind.lien_parente_cm == 1)
        & (ind.statut_activite == OCCUPE)
        & ind.branche_activite.between(debut, fin, inclusive="left")
        & ind.situation_profession.isin([INDEPENDANT, AIDE_FAMILIAL]))
    return S


def agreger_par_menage(S):
    """Effectifs par ménage : la somme de chaque colonne de situation."""
    return S.groupby("id_menage").sum()


def parcourir_individus(morceaux):
    """Parcourt le fichier individus et renvoie (situations agrégées, lignes des chefs).

    Un ménage peut être coupé entre deux morceaux : chaque morceau est agrégé séparément, puis
    les agrégats sont resommés par ménage — la somme d'une somme reste une somme.
    """
    logger.info("--- 1. parcours du fichier individus (par morceaux de %s lignes) ---",
                f"{LIGNES_PAR_MORCEAU:,}".replace(",", " "))
    agregats, chefs, lus = [], [], 0
    debut = time.perf_counter()

    for numero, ind in enumerate(morceaux, start=1):
        lus += len(ind)
        agregats.append(agreger_par_menage(situations_individuelles(ind)))
        chefs.append(ind.loc[ind.lien_parente_cm == 1, COLONNES_CHEF])
        logger.info("  morceau %2d : %9d individus lus au total  (%.0f s)",
                    numero, lus, time.perf_counter() - debut)

    X = pd.concat(agregats).groupby(level=0).sum()
    C = pd.concat(chefs, ignore_index=True).drop_duplicates("id_menage").set_index("id_menage")
    logger.info("%d individus -> %d ménages agrégés, %d lignes de chef",
                lus, len(X), len(C))
    assert len(X) == len(C), f"{len(X)} ménages agrégés pour {len(C)} chefs"
    return X, C


# --------------------------------------------------------------------------- #
# 3. conditions de vie et biens (fichier ménages)
# --------------------------------------------------------------------------- #
def conditions_de_vie():
    """Logement, eau, éclairage, cuisson, sanitaires et biens d'équipement.

    Lus dans le fichier ménages et non dans le fichier individus : ce dernier les porte aussi,
    mais renseignés pour un tiers des ménages seulement.
    """
    logger.info("--- 2. conditions de vie et biens d'équipement (fichier ménages) ---")
    men = charger_base(dico.FICHIER_MENAGES).set_index("id_individu")

    biens = pd.DataFrame(index=men.index)
    for bien, colonnes in EQUIPEMENTS_PNUD.items():
        biens[bien] = men[colonnes].eq(1).any(axis=1)
        logger.info("  %-16s %s", bien, part(int(biens[bien].sum()), len(biens)))

    men["nb_equipements"] = biens.sum(axis=1)
    men["possede_voiture"] = men.bien_voiture.eq(1).astype(int)
    logger.info("  %-16s %s", "voiture", part(int(men.possede_voiture.sum()), len(men)))
    logger.info("nombre de biens possédés sur %d : moyenne %.2f (le seuil est appliqué à "
                "l'étape 02)", len(EQUIPEMENTS_PNUD), men.nb_equipements.mean())
    logger.debug("distribution du nombre de biens :\n%s",
                 men.nb_equipements.value_counts().sort_index().to_string())
    return men.drop(columns=[c for c in men.columns if c.startswith("bien_")])


# --------------------------------------------------------------------------- #
# 4. mortalité (fichier des décès)
# --------------------------------------------------------------------------- #
def deces_juveniles(men):
    """Nombre de décès d'enfants de moins de 18 ans survenus dans le ménage.

    Cet indicateur remplace à lui seul les trois indicateurs de santé de l'EHCVM, qu'aucune
    question du recensement ne permet de reconstruire.

    La borne d'âge (18 ans) est celle du dofile officiel du RGPH 2021 et de l'IPM mondial.

    ponytail: le RGPH recense les décès des 12 DERNIERS MOIS, quand l'IPM mondial retient une
    fenêtre de 5 ans. La privation est donc plus rare ici que dans l'IPM international, et les
    deux ne se comparent pas directement. Élargir la fenêtre demanderait une autre source.
    """
    logger.info("--- 3. mortalité juvénile (fichier des décès) ---")
    deces = charger_base(dico.FICHIER_DECES)
    age = deces.age_au_deces.where(deces.age_au_deces != AGE_AU_DECES_INCONNU)

    juveniles = age < AGE_MORTALITE_JUVENILE
    logger.info("%d décès, dont %s avant le %de anniversaire ; âge au décès inconnu : %s",
                len(deces), part(int(juveniles.sum()), len(deces)), AGE_MORTALITE_JUVENILE,
                part(int(age.isna().sum()), len(deces)))

    par_menage = (deces.assign(_juvenile=juveniles.astype(int), _deces=1)
                       .groupby(dico.CLE_GEOGRAPHIQUE)[["_juvenile", "_deces"]].sum())
    logger.info("%d ménages touchés par au moins un décès", len(par_menage))

    # la jointure se fait sur la géographie : ni INDIV_ID ni ID_Menage dans le fichier décès
    D = (men[dico.CLE_GEOGRAPHIQUE]
         .join(par_menage, on=dico.CLE_GEOGRAPHIQUE)
         .rename(columns={"_juvenile": "deces_moins_18_ans", "_deces": "deces_tous_ages"})
         [["deces_moins_18_ans", "deces_tous_ages"]]
         .fillna(0).astype(int))

    apparies = (D.deces_tous_ages > 0).sum()
    logger.info("ménages appariés à un décès : %s ; dont au moins un décès juvénile : %s",
                part(int(apparies), len(D)),
                part(int((D.deces_moins_18_ans > 0).sum()), len(D)))
    if not apparies:
        logger.error("aucun ménage apparié : les codes géographiques des deux fichiers "
                     "ne concordent pas")
    return D


# --------------------------------------------------------------------------- #
# 5. assemblage et contrôles
# --------------------------------------------------------------------------- #
def preconstruire():
    """Enchaîne les étapes 1 à 4 et assemble la table de préconstruction."""
    X, chefs = parcourir_individus(morceaux_individus())
    men = conditions_de_vie()
    men = men.join(deces_juveniles(men)).drop(columns=dico.CLE_GEOGRAPHIQUE)

    logger.info("--- 4. assemblage de la table de préconstruction ---")
    # le ménage est identifié par id_menage, le fichier ménages par l'INDIV_ID de son chef
    X = X.join(chefs, how="left", validate="1:1")
    avant = len(X)
    X = X.join(men, on="id_individu", how="left").drop(columns="id_individu")
    non_apparies = X.nb_equipements.isna().sum()
    logger.info("  jointure conditions de vie : %d ménages, %s sans ligne dans le fichier "
                "ménages -> comptés non privés par convention",
                avant, part(int(non_apparies), avant))

    # la zone de dénombrement est l'unité primaire du recensement : elle tient lieu de grappe
    X["grappe"] = (X.sous_prefecture.astype("int64") * 10_000_000
                   + X.zone_controle.astype("int64") * 10_000
                   + X.zone_denombrement.astype("int64"))
    X = X.drop(columns=["zone_controle", "zone_denombrement"])
    X.index.name = CLE[0]

    logger.info("table de préconstruction : %d ménages x %d colonnes", *X.shape)
    return X


def controler(X):
    """Contrôles de qualité : unicité, pondération, distributions, valeurs manquantes."""
    logger.info("--- 5. contrôles ---")
    assert X.index.is_unique, "l'identifiant de ménage doit être unique"
    assert X.ponderation_menage.gt(0).all(), "une pondération est nulle ou négative"
    logger.info("clé unique : oui (%d ménages), %d zones de dénombrement",
                len(X), X.grappe.nunique())
    logger.info("population représentée (taille x pondération) : %s personnes",
                part(int((X.ponderation_menage * X.taille_menage).sum()), 0))

    chiffrees = ["enfants_6_16_non_scolarises", "membres_17_95_dix_annees_etudes",
                 "membres_17_49_alphabetises", "enfants_5_15_sans_acte", "chomeurs_17_40",
                 "nb_equipements", "deces_moins_18_ans", "taille_menage"]
    logger.info("statistiques des situations chiffrées :\n%s",
                X[chiffrees].describe().round(2).to_string())

    manquants = X.isna().mean().sort_values(ascending=False)
    manquants = manquants[manquants > 0]
    if manquants.empty:
        logger.info("aucune valeur manquante")
    else:
        logger.info("valeurs manquantes (part des ménages) :")
        for colonne, taux in manquants.items():
            logger.info("  %-28s %.2f %%", colonne, 100 * taux)
        logger.info("il s'agit des ménages absents du fichier ménages : l'étape 02 les traite "
                    "comme non privés, conformément à la convention du pipeline")
    return X


# --------------------------------------------------------------------------- #
# auto-contrôle
# --------------------------------------------------------------------------- #
def verifier():
    """Rejoue la chaîne sur des cas construits à la main, aux résultats connus."""
    configurer_logs(logger, niveau=logging.WARNING)

    ind = pd.DataFrame({
        "id_menage": [1, 1, 2, 2],
        "lien_parente_cm": [1, 3, 1, 3],
        #        chef 38 ans   enfant 11   chef 30 ans   enfant 6, âge inconnu chez personne
        "age": [38, 11, 30, 6],
        # P1 chômeur BIT, P3 occupé agriculteur indépendant
        "statut_activite": [1.0, np.nan, 0.0, np.nan],
        "branche_activite": [np.nan, np.nan, 1110.0, np.nan],
        "situation_profession": [np.nan, np.nan, 3.0, np.nan],
        # scolarisation : P2 déscolarisé, P4 scolarisé
        "frequente_ecole": [2.0, 2.0, 2.0, 1.0],
        # diplôme : P1 BEPC (>= 10 années), P3 CEPE (< 10 années)
        "diplome_le_plus_eleve": [4.0, np.nan, 2.0, np.nan],
        # alphabétisation : P1 lit et écrit le français, P3 lit une langue mais pas le français
        "lit_ecrit_une_langue": [1.0, np.nan, 1.0, np.nan],
        "lit_ecrit_francais": [1.0, np.nan, 0.0, np.nan],
        # état civil : P2 déclaré sans acte (privation), P4 avec acte
        "acte_naissance": [1, 2, 1, 1],
    })

    S = situations_individuelles(ind)
    assert S.enfants_6_16.tolist() == [False, True, False, True]
    assert S.enfants_6_16_non_scolarises.tolist() == [False, True, False, False]
    assert S.membres_17_95_dix_annees_etudes.tolist() == [True, False, False, False]
    assert S.membres_17_49_alphabetises.tolist() == [True, False, False, False]
    # « déclaré sans acte de naissance » est bien compté comme une privation
    assert S.enfants_5_15_sans_acte.tolist() == [False, True, False, False]
    assert S.chomeurs_17_40.tolist() == [True, False, False, False]
    assert S.cm_agriculture_subsistance.tolist() == [False, False, True, False]
    # un chef salarié de la même branche agricole n'est PAS en subsistance
    salarie = ind.assign(situation_profession=[np.nan, np.nan, 1.0, np.nan])
    assert not situations_individuelles(salarie).cm_agriculture_subsistance.any()
    # un âge « ne sait pas » ne fait entrer dans aucune tranche
    inconnu = ind.assign(age=[AGE_INCONNU] * 4)
    assert not situations_individuelles(inconnu).enfants_6_16.any()

    X = agreger_par_menage(S)
    assert X.loc[1, "enfants_6_16"] == 1 and X.loc[1, "enfants_6_16_non_scolarises"] == 1
    assert X.loc[2, "enfants_6_16"] == 1 and X.loc[2, "enfants_6_16_non_scolarises"] == 0
    assert X.loc[1, "membres_17_95_dix_annees_etudes"] == 1
    assert X.loc[2, "membres_17_95_dix_annees_etudes"] == 0
    assert X.loc[1, "cm_agriculture_subsistance"] == 0
    assert X.loc[2, "cm_agriculture_subsistance"] == 1

    # l'agrégation par morceaux doit donner exactement le même résultat qu'en une fois
    par_morceaux, chefs = parcourir_individus([ind.assign(**COMPLEMENT_CHEF).iloc[:3],
                                               ind.assign(**COMPLEMENT_CHEF).iloc[3:]])
    assert par_morceaux[X.columns].equals(X), par_morceaux
    assert len(chefs) == 2

    # les 8 biens PNUD sont tous présents dans le RGPH : la charrette y figure
    assert "charrette" in EQUIPEMENTS_PNUD and len(EQUIPEMENTS_PNUD) == 8

    print("auto-contrôle 01 RGPH : OK")


# colonnes portées par la ligne du chef, sans intérêt pour l'auto-contrôle mais exigées par
# `parcourir_individus`
COMPLEMENT_CHEF = {c: 1 for c in COLONNES_CHEF if c not in ("id_menage", "lien_parente_cm")}


def main():
    configurer_logs(logger, JOURNAL)
    debut = time.perf_counter()
    logger.info("=== étape 01 : préconstruction de la matrice situationnelle (RGPH 2021) ===")

    X = preconstruire()
    controler(X)
    logger.info("--- 6. export (Stata + CSV) ---")
    exporter_table(X, NOM_SORTIE, logger)

    logger.info("=== terminé en %.1f s ===", time.perf_counter() - debut)
    return X


if __name__ == "__main__":
    if "--check" in sys.argv:
        verifier()
    else:
        main()
