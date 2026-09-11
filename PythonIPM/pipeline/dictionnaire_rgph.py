"""Noms explicites des variables RGPH 2021 utiles à l'IPM.

Même rôle que `dictionnaire_ehcvm` : un dictionnaire par base, {code RGPH : nom explicite},
plus les libellés des modalités de désagrégation. Le numéro de question du questionnaire de
recensement figure en commentaire.

L'extrait RGPH est réparti sur trois fichiers, et c'est le point à connaître avant de lire le
code de l'étape 01 :

    IPM_Data_191125.dta       27 984 405 individus, 5 616 487 ménages — démographie, éducation,
                              emploi. Il porte AUSSI les variables de logement et de biens,
                              mais renseignées pour un tiers des ménages seulement (fusion
                              incomplète en amont) : elles ne sont pas lues ici.
    IPM_Data_110924_men.dta    5 528 535 ménages, une ligne par chef de ménage — logement et
                              biens d'équipement, complets. C'est la source retenue pour la
                              dimension Conditions de vie, jointe par `INDIV_ID` du chef.
    MORTALITE_RP2021_...dta      269 901 décès survenus dans les 12 mois précédant le
                              recensement, joints par la clé géographique du ménage.
"""

from functools import lru_cache

import pandas as pd

from orchestrateur import DATA

FICHIER_INDIVIDUS = "IPM_Data_191125.dta"
FICHIER_MENAGES = "IPM_Data_110924_men.dta"
FICHIER_DECES = "MORTALITE_RP2021_TRAITEMENT.dta"

# Clé géographique du ménage, seul lien possible avec le fichier des décès (qui ne porte ni
# INDIV_ID ni ID_Menage). Les mêmes codes, dans le même ordre, dans les deux fichiers.
CLE_GEOGRAPHIQUE = ["REGION", "DEPART", "SOUSPREFID", "P_ZC", "P04", "P05",
                    "P06", "P07", "P09", "P09A", "P09B", "P10"]

INDIVIDUS = {
    # identification, pondération et géographie
    "INDIV_ID": "id_individu",
    "ID_Menage": "id_menage",
    "REGION": "region",
    "DEPART": "departement",
    "SOUSPREFID": "sous_prefecture",
    "P_ZC": "zone_controle",              # zone de contrôle
    "P05": "zone_denombrement",           # ZD : l'unité primaire, sert de « grappe »
    "P08": "milieu",                      # milieu de résidence (1 urbain, 2 rural, 3 semi-urbain)
    "TAILLE_MENAGE": "taille_menage",
    "EW": "ponderation_menage",           # taux net de couverture post-censitaire (EPC)
    "PROJ24": "ponderation_projection_2024",
    # démographie
    "P15D": "situation_residence",        # 1 résident présent, 2 résident absent, 3 visiteur
    "P16": "lien_parente_cm",             # 1 = chef de ménage
    "P18A_AGE": "age",
    "P20": "acte_naissance",              # 1 déclaré avec acte, 2 déclaré sans acte, 3 non, 8 NSP
    # éducation
    "P29A": "lit_ecrit_une_langue",       # 1 oui, 2 non          (posée à partir de 15 ans)
    "P29_BA": "lit_ecrit_francais",       # 0 non, 1 oui
    "P30A": "frequente_ecole",            # 1 oui, 2 non mais a fréquenté, 3 jamais, 8 NSP
    "P32": "diplome_le_plus_eleve",       # voir DIPLOMES_DIX_ANNEES
    # emploi
    "P34A": "activite_7j",                # 0-10 = a travaillé, 11 = aucune activité
    "p34C": "recherche_emploi_30j",       # 1 oui, 2 non, 8 NSP
    "P34D": "disponible_emploi",          # 1 oui, 2 non, 8 NSP
    "Statut_OQPtbb": "statut_activite",   # INS : 0 occupé, 1 chômeur BIT, 2 inactif, 3 potentiel
    "P36BNEWtb": "branche_activite",      # nomenclature NAEMA : 01000-03999 = agriculture
    "P37NEWtb": "situation_profession",   # 3 indépendant, 5 aide familial
}

MENAGES = {
    "INDIV_ID": "id_individu",            # l'individu chef : la clé de jointure avec INDIVIDUS
    # clé géographique, reprise telle quelle : c'est par elle que se joignent les décès
    **{f"{c}_NEW" if c in ("REGION", "DEPART", "SOUSPREFID") else c: c
       for c in CLE_GEOGRAPHIQUE},
    # logement (questions 45 à 52)
    "P45": "materiau_mur",
    "P46": "materiau_toit",
    "P47": "materiau_sol",
    "P48": "type_sanitaire",
    "P49": "source_eau_boisson",
    "P51": "source_eclairage",
    "P52": "mode_cuisson",
    # biens d'équipement (questions 55 à 57) : 1 = possédé, manquant = non possédé
    "P55AA": "bien_velo",
    "P55BB": "bien_moto",
    "P55CC": "bien_voiture",
    "P55FF": "bien_charrette",            # véhicule à traction animale
    "P56BB": "bien_refrigerateur",
    "P57AA": "bien_radio",
    "P57BB": "bien_television",
    "P57CC": "bien_telephone_fixe",
    "P57DD": "bien_telephone_mobile",
    "P57EE": "bien_ordinateur",
}

DECES = {
    "M61A2_AGE": "age_au_deces",          # en années révolues, 998 = ne sait pas
    "M61A1_SEXE": "sexe_du_defunt",
}

# base .dta -> dictionnaire de noms explicites
BASES = {
    FICHIER_INDIVIDUS: INDIVIDUS,
    FICHIER_MENAGES: MENAGES,
    FICHIER_DECES: {**{c: c for c in CLE_GEOGRAPHIQUE}, **DECES},
}

# Diplômes valant au moins 10 années d'études accomplies, c'est-à-dire la 3e achevée.
# Le RGPH ne demande NI le nombre d'années d'études NI la classe atteinte : l'indicateur
# « année de scolarité » est approché par le diplôme le plus élevé (question 32). Le CEPE
# (code 2, 6 années) et le CQP (code 3) restent donc en deçà du seuil ; le CAP, le BEP et le BT
# sont comptés au-dessus, bien qu'ils puissent en Côte d'Ivoire s'obtenir avant la 3e.
# Le code 22 « Autres à préciser » est compté au-dessus du seuil, comme dans le dofile officiel
# du RGPH 2021 ; il ne concerne qu'une poignée de personnes (0,02 point sur l'indicateur).
DIPLOMES_DIX_ANNEES = list(range(4, 23))   # 4 BEPC ... 21 PhD, 22 autres ; hors 23 « ne sait pas »

# --------------------------------------------------------------------------- #
# étiquettes des modalités de désagrégation
# --------------------------------------------------------------------------- #
# Le RGPH distingue trois milieux, là où l'EHCVM n'en code que deux.
MILIEU = {1: "Urbain", 2: "Rural", 3: "Semi-urbain"}

MODALITES = {"milieu": MILIEU}

# Régions (33), départements (111) et sous-préfectures/communes : lus dans les value labels du
# fichier individus plutôt que recopiés — ils y sont déjà, et à jour.
ETIQUETTES_DTA = {"region": "REGION", "departement": "DEPART",
                  "sous_prefecture": "SOUSPREFID"}


@lru_cache(maxsize=None)
def _value_labels():
    """Les value labels du fichier individus, associés à leur variable (pandas ne fait que la
    moitié du chemin : `value_labels()` est indexé par jeu d'étiquettes, pas par variable)."""
    lecteur = pd.io.stata.StataReader(DATA / FICHIER_INDIVIDUS)
    jeux = lecteur.value_labels()
    return {variable: jeux[jeu]
            for variable, jeu in zip(lecteur._varlist, lecteur._lbllist) if jeu in jeux}


@lru_cache(maxsize=None)
def modalites(colonne):
    """Libellés d'une variable de désagrégation, ou None si elle n'en a pas."""
    if colonne in MODALITES:
        return MODALITES[colonne]
    if colonne not in ETIQUETTES_DTA:
        return None
    return _value_labels().get(ETIQUETTES_DTA[colonne])
