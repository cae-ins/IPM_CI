"""Noms explicites des variables EHCVM 2021 utiles à l'IPM.

Un dictionnaire par base : {code de la variable : nom explicite}.
Source : libellés des .dta + questionnaire CAPI ménage vague 1
(le numéro de question figure en commentaire).
"""

from functools import lru_cache

import pandas as pd

from orchestrateur import DATA

MENAGE = {
    # identification et pondération
    "grappe": "grappe",
    "menage": "menage",
    "vague": "vague",
    "hhid": "id_menage",
    "hhweight": "ponderation_menage",
    "hhsize": "taille_menage",
    "region": "region",
    "milieu": "milieu",
    "dtot": "conso_totale_annuelle",
    "pcexp": "depense_par_tete",
    "zref": "seuil_pauvrete_national",
    "hgender": "sexe_cm",
    "hage": "age_cm",
    "hcsp": "csp_cm",
    # découpage administratif (section 0) : 33 régions, 108 départements, 442 sous-préfectures
    "s00q02": "departement",                 # 0.02 Préfecture/Arrondissement
    "s00q03": "sous_prefecture",             # 0.03 Commune / sous-préfecture
    # logement (section 11)
    "s11q01": "type_logement",               # 11.01
    "s11q02": "nb_pieces",                   # 11.02
    "s11q04": "statut_occupation_logement",  # 11.04
    "s11q18": "materiau_mur",                # 11.18
    "s11q19": "materiau_toit",               # 11.19
    "s11q20": "materiau_sol",                # 11.20
    # eau
    "s11q21": "connecte_reseau_eau",         # 11.21
    "s11q26a": "source_eau_boisson_seche",   # 11.26a
    "s11q26b": "source_eau_boisson_pluies",  # 11.26b
    "s11q27": "distance_source_eau_seche",   # 11.27 (en mètres)
    "s11q28a": "temps_aller_source_seche",  # 11.28a (en minutes, aller simple)
    # électricité et éclairage
    "s11q33": "connecte_reseau_electrique",  # 11.33
    "s11q37": "source_eclairage",            # 11.37
    # combustibles de cuisson (11.52, choix multiple ordonné : 1 = principal)
    "s11q52__1": "combustible_bois_ramasse",
    "s11q52__2": "combustible_bois_achete",
    "s11q52__3": "combustible_charbon",
    "s11q52__4": "combustible_gaz",
    "s11q52__5": "combustible_electricite",
    "s11q52__6": "combustible_petrole",
    "s11q52__7": "combustible_dechets_animaux",
    "s11q52__8": "combustible_autre",
    # assainissement
    "s11q53": "evacuation_ordures",          # 11.53
    "s11q54": "type_sanitaire",              # 11.54
    "s11q55": "sanitaire_partage",           # 11.55
    "s11q57": "evacuation_excrements",       # 11.57
    "s11q59": "evacuation_eaux_usees",       # 11.59
    # TIC
    "s11q45": "connecte_internet",           # 11.45
    "s11q49": "abonnement_tv",               # 11.49
}

INDIVIDUS = {
    # identification et démographie (section 1)
    "grappe": "grappe",
    "menage": "menage",
    "vague": "vague",
    "s01q00a": "id_membre",
    "s01q01": "sexe",                      # 1.01
    "s01q02": "lien_parente_cm",           # 1.02
    "s01q03b": "mois_naissance",           # 1.03b
    "s01q03c": "annee_naissance",          # 1.03c
    "s01q04a": "age_declare",              # 1.04a (renseigné pour 6 % des membres)
    "s01q05": "acte_naissance",            # 1.05 : 1 oui, 2 non, 3 NSP
    "s01q07": "situation_matrimoniale",    # 1.07
    "s01q11": "present_menage",            # 1.11
    "s01q12": "reside_6_mois",             # 1.12
    "s01q14": "religion",                  # 1.14
    "s01q15": "nationalite",               # 1.15
    "s01q36": "possede_telephone",         # 1.36
    # éducation (section 2)
    "s02q01__1": "lit_francais",           # 2.01
    "s02q02__1": "ecrit_francais",         # 2.02
    "s02q02a__1": "comprend_francais",     # 2.02a
    "s02q03": "a_frequente_ecole",         # 2.03
    "s02q12": "scolarise_2020_2021",       # 2.12
    "s02q08a": "scolarise_2021_2022",      # 2.08a
    "s02q13": "raison_non_scolarisation",  # 2.13
    "s02q14": "niveau_en_cours",           # 2.14 (niveau suivi en 20/21)
    "s02q16": "classe_en_cours",           # 2.16 (classe suivie en 20/21)
    "s02q29": "niveau_instruction",        # 2.29
    "s02q31": "derniere_classe",           # 2.31
    "s02q33": "diplome_plus_eleve",        # 2.33 : 0 aucun, 1 CEPE, 2 BEPC, ...
    # santé (section 3)
    "s03q01": "probleme_sante_30j",        # 3.01
    "s03q05": "consultation_sante_30j",    # 3.05
    "s03q06": "raison_non_consultation",   # 3.06 : 2 « Trop cher », 8 « Manque d'argent »
    "s03q32": "assurance_maladie",         # 3.32
    "s03q38": "moustiquaire",              # 3.38
    # emploi (section 4A)
    "s04q06": "travail_champ_7j",          # 4.06
    "s04q07": "travail_commerce_7j",       # 4.07
    "s04q08": "travail_salarie_7j",        # 4.08
    "s04q09": "travail_apprenti_7j",       # 4.09
    "s04q10": "a_travaille_7j",            # 4.10 : vrai si oui à 4.06-4.09
    "s04q11": "emploi_mais_absent_7j",     # 4.11
    "s04q12": "raison_non_travail_7j",     # 4.12
    "s04q15": "recherche_emploi_30j_a",    # 4.15 (branche : n'a pas travaillé)
    "s04q17": "recherche_emploi_30j_b",    # 4.17 (branche : sans emploi)
    "s04q19": "disponible_emploi",         # 4.19 (posé aux non-chercheurs)
    "s04q20": "delai_disponibilite",       # 4.20 (posé si 4.17 ou 4.19 = oui)
    "s04q21": "mois_sans_emploi",          # 4.21
    "s04q22": "mois_de_recherche",         # 4.22
}

AVOIRS = {
    "grappe": "grappe",
    "menage": "menage",
    "vague": "vague",
    "s12q01": "code_bien",        # 12.01 (28 = voiture, 35 = portable, ...)
    "s12q02": "possede_bien",     # 12.02 : 1 oui, 2 non
    "s12q03": "nombre_biens",     # 12.03
    "s12q09": "valeur_actuelle",  # 12.09
}

# échelle FIES de la FAO (section 8A) : 1 Oui, 2 Non, 98 NSP, 99 Refus
SECURITE_ALIMENTAIRE = {
    "grappe": "grappe",
    "menage": "menage",
    "vague": "vague",
    "s08aq01": "fies_inquietude",           # 8A.01  sévérité légère
    "s08aq02": "fies_pas_sain",             # 8A.02  légère
    "s08aq03": "fies_peu_varie",            # 8A.03  légère
    "s08aq04": "fies_saute_repas",          # 8A.04  modérée
    "s08aq05": "fies_mange_moins",          # 8A.05  modérée
    "s08aq06": "fies_plus_de_nourriture",   # 8A.06  modérée
    "s08aq07": "fies_faim",                 # 8A.07  sévère
    "s08aq07a": "fies_faim_frequence",      # 8A.07a
    "s08aq08": "fies_journee_sans_manger",  # 8A.08  sévère
    "s08aq08a": "fies_journee_frequence",   # 8A.08a
}

# base .dta -> dictionnaire de noms explicites
BASES = {
    "Base_Menage.dta": MENAGE,
    "Base_Individus.dta": INDIVIDUS,
    "Base_avoirs_du_menage.dta": AVOIRS,
    "Base_securite_alimentaire.dta": SECURITE_ALIMENTAIRE,
}

# Étiquettes des modalités, reprises des value labels des .dta (EHCVM 2021).
# Servent aux désagrégations : la matrice porte les codes, les tableaux publiés
# portent les libellés.
MILIEU = {1: "Urbain", 2: "Rural"}
SEXE = {1: "Masculin", 2: "Féminin"}
REGION = {
    1: "Autonome D'Abidjan",
    2: "Haut-Sassandra",
    3: "Poro",
    4: "Gbeke",
    5: "Indenie-Djuablin",
    6: "Tonkpi",
    7: "Yamoussoukro",
    8: "Gontougo",
    9: "San-Pedro",
    10: "Kabadougou",
    11: "N'Zi",
    12: "Marahoue",
    13: "Sud-Comoe",
    14: "Worodougou",
    15: "Lôh-Djiboua",
    16: "Agneby-Tiassa",
    17: "Gôh",
    18: "Cavally",
    19: "Bafing",
    20: "Bagoue",
    21: "Belier",
    22: "Bere",
    23: "Bounkani",
    24: "Folon",
    25: "Gbôkle",
    26: "Grands-Ponts",
    27: "Guemon",
    28: "Hambol",
    29: "Iffou",
    30: "La Me",
    31: "Nawa",
    32: "Tchologo",
    33: "Moronou",
}

# désagrégation -> table de correspondance
MODALITES = {"milieu": MILIEU, "region": REGION, "sexe_cm": SEXE}

# Départements (108) et sous-préfectures/communes (442) : trop nombreux pour être recopiés ici,
# leurs libellés sont lus dans les value labels de Base_Menage.dta.
ETIQUETTES_DTA = {"departement": "s00q02", "sous_prefecture": "s00q03"}


@lru_cache(maxsize=None)
def modalites(colonne):
    """Libellés d'une variable de désagrégation, ou None si elle n'en a pas."""
    if colonne in MODALITES:
        return MODALITES[colonne]
    if colonne not in ETIQUETTES_DTA:
        return None
    labels = pd.io.stata.StataReader(DATA / "Base_Menage.dta").value_labels()
    return labels[ETIQUETTES_DTA[colonne]]
