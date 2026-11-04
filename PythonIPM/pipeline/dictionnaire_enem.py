"""Dictionnaire de la source ENEM 2025 : noms de variables, codes et libellés de désagrégation.

L'Enquête nationale sur l'emploi (ENEM) est un panel rotatif : un ménage est interrogé à t, t+1,
t+4 et t+5, et certaines questions ne sont posées qu'à la première interrogation (logement,
assurance maladie, alphabétisation). Le pipeline ne retient donc que les ménages dont TOUTES
les informations sont dans leur propre visite de 2025 (voir l'étape 01).

Les noms explicites sont centralisés ici ; les numéros de question sont ceux du questionnaire
ENE-M volet ménage (T4VF).
"""
from functools import lru_cache

import pandas as pd

from orchestrateur import DATA

TRIMESTRES = ["T1", "T2", "T3", "T4"]
ANNEE = 2025
FICHIER_POIDS_ANNUEL = DATA / "annual_2025" / "poids" / "LFS_WEIGHTS_2025.dta"


def fichier_individus(t):
    return DATA / f"{t}_{ANNEE}" / "individu" / f"individu_{t}_{ANNEE}.dta"


def fichier_menages(t):
    return DATA / f"{t}_{ANNEE}" / "menage" / f"menage_{t}_{ANNEE}.dta"


# --------------------------------------------------------------------------- #
# colonnes lues : nom dans la base -> nom explicite
# --------------------------------------------------------------------------- #
INDIVIDUS = {
    "interview__key": "interview_key",
    "membres__id": "membre",
    "AgeAnnee": "age",
    "M4": "lien_parente_cm",              # 1 = chef de ménage ; posé aux nouveaux membres
    "V1M4": "lien_parente_cm_v1",         # valeur de la visite précédente (repli pour le chef)
    "M5": "sexe",                         # 1 masculin, 2 féminin
    "M24A": "assurance_maladie",          # 1 oui, 2 non ; posé aux nouveaux résidents
    "EF1": "deja_alle_ecole",             # 1 oui, 2 non
    "EF4": "classe_achevee",              # classe la plus élevée achevée (CP1 = 4 ... 3e = 13)
    "EF6": "frequente_ecole",             # 1 oui, 2 non, année scolaire en cours
    "EF16B__1": "lit_francais",           # posé aux nouveaux membres
    "EF16B__2": "ecrit_francais",
    "EN_EMP": "en_emploi",                # statut d'occupé calculé par le questionnaire
    "SRH1": "a_cherche_emploi",           # 30 derniers jours
    "SRH2": "a_tente_creer_entreprise",   # si n'a pas cherché
    "SRH11": "disponible_deux_semaines",
    "EP3": "statut_emploi",
    "EP37": "declare_cnps",               # 1 oui, 2 non
    "branche1": "branche_activite",
    "NB_HEURE_TRAVAIL_TOTAL": "heures_travail",
    "WKI4": "veut_travailler_plus",
    "WKI5": "disponible_travailler_plus",
    "FP6": "etat_formation",              # 1 inachevée, 2 en cours, 3 achevée
    "DIF1A": "dif_vue",
    "DIF2A": "dif_ouie",
    "DIF3B": "dif_mains",
    "DIF3D": "dif_communication",
    "DIF5": "dif_cognition",
}

MENAGES = {
    "interview__key": "interview_key",
    "HH2A": "direction_regionale",
    "HH2": "region",
    "HH3": "departement",
    "HH4": "sous_prefecture",
    "HH6": "milieu",
    "rgmen": "rang_interrogation",
    "L1": "type_logement",
    "L2A": "nb_pieces",
    "L2B": "nb_pieces_dormir",
    "L3": "materiau_mur",
    "L4": "source_eclairage",
    "L7": "source_eau_boisson",
    "L8": "evacuation_ordures",
    "L9": "evacuation_eaux_usees",
    "L10": "type_sanitaire",
}

# L11 (biens possédés) : une colonne 0/1 par bien, `L11__<code>`
BIENS = {
    "telephone_fixe": 1, "internet_fixe": 2, "internet_mobile": 3, "telephone_mobile": 4,
    "ordinateur": 5, "radio": 8, "television": 9, "refrigerateur": 12, "rechaud_gaz": 14,
    "charrette": 24, "voiture": 40, "moto": 41, "velo": 43,
}
# Les 8 biens de la définition PNUD (un téléphone, fixe OU mobile, compte pour un seul bien)
EQUIPEMENTS_PNUD = ["telephone", "radio", "television", "ordinateur", "charrette", "velo",
                    "moto", "refrigerateur"]

# --------------------------------------------------------------------------- #
# codes des questions individuelles
# --------------------------------------------------------------------------- #
STATUT_SALARIE = [1, 8, 9]            # salarié, apprenti payé, stagiaire payé
STATUT_INDEPENDANT_FAMILIAL = [3, 5, 6]   # compte propre, travailleur familial, aide familial
BRANCHE_AGRICULTURE = 1
FORMATION_EN_COURS = 2
DIFFICULTE_MINIMUM = 3                # « beaucoup » ou « incapable »
CHEF_DE_MENAGE = 1

# --------------------------------------------------------------------------- #
# étiquettes des modalités de désagrégation
# --------------------------------------------------------------------------- #
MILIEU = {1: "Urbain", 2: "Rural"}
CHEF_NON_IDENTIFIE = 9
SEXE = {1: "Masculin", 2: "Féminin", CHEF_NON_IDENTIFIE: "Chef non identifié"}
MODALITES = {"milieu": MILIEU, "sexe_cm": SEXE}

# régions, départements et sous-préfectures : lus dans les value labels des fichiers ménage
ETIQUETTES_DTA = {"region": "HH2", "departement": "HH3", "sous_prefecture": "HH4"}


@lru_cache(maxsize=None)
def _value_labels():
    """Les value labels des quatre fichiers ménage, fusionnés (un code peut manquer à un trimestre)."""
    fusion = {}
    for t in TRIMESTRES:
        lecteur = pd.io.stata.StataReader(fichier_menages(t))
        lecteur.read(convert_categoricals=False, columns=["interview__key"])
        jeux = lecteur.value_labels()
        for variable, jeu in zip(lecteur._varlist, lecteur._lbllist):
            if jeu in jeux:
                fusion.setdefault(variable, {}).update(
                    {int(k): str(v).strip() for k, v in jeux[jeu].items()})
    return fusion


@lru_cache(maxsize=None)
def modalites(colonne):
    """Libellés d'une variable de désagrégation, ou None si elle n'en a pas."""
    if colonne in MODALITES:
        return MODALITES[colonne]
    if colonne not in ETIQUETTES_DTA:
        return None
    return _value_labels().get(ETIQUETTES_DTA[colonne])
