"""Étape 02 du pipeline IPM — matrice situationnelle X (EHCVM 2021).

Entrée  : preconstruction_matrice_situationnelle.dta (étape 01)
Sortie  : matrice_situationnelle_ehcvm2021.dta — 12 965 ménages x 12 indicateurs 0/1,
          plus la pondération et les variables de désagrégation, et rien d'autre.

Chaque indicateur suit SOIT la proposition nationale, SOIT l'application du PNUD — le choix est
porté par la constante INDICATEURS et détaillé dans METHODOLOGIE.md :

    proposition nationale : fréquentation scolaire, année de scolarité, alphabétisation,
                            état civil, assurance maladie, électricité, énergie de cuisson,
                            emploi
    PNUD                  : logement, eau potable, toilettes, biens d'équipement

Convention : 1 = privé. Un ménage non concerné (aucun enfant de 6-16 ans, aucun membre de
17-40 ans...) n'est pas privé ; une situation manquante après application du seuil vaut 0.

Usage :
    python 02_construction_matrice_situationnelle.py
    python 02_construction_matrice_situationnelle.py --check
"""
import logging
import sys
import time
from collections import namedtuple

import pandas as pd

from orchestrateur import CLE, COLONNES_TECHNIQUES, LOGS, SORTIES, configurer_logs, part

ENTREE = SORTIES / "preconstruction_matrice_situationnelle.dta"
SORTIE = SORTIES / "matrice_situationnelle_ehcvm2021.dta"
JOURNAL = LOGS / "02_construction_matrice_situationnelle.log"

NATIONALE = "proposition nationale"
PNUD = "application PNUD"

Indicateur = namedtuple("Indicateur",
                        "dimension libelle source definition colonne situation eligibilite regle")

# Modalités considérées comme adéquates (codes EHCVM, voir les codebooks)
ECLAIRAGE_ADEQUAT = [1, 2, 6]                       # réseau, groupe électrogène, solaire
EAU_AMELIOREE = [1, 2, 3, 4, 7, 8, 9, 10, 11, 14]   # robinet, forage, puits/source protégés, bouteille
SANITAIRE_AMELIORE = [1, 2, 3, 4, 5, 6, 7]          # chasse d'eau, VIP, ECOSAN, SANPLAT
SOL_NATUREL = [3, 4, 5]                             # terre/sable, bouse, autre
TOIT_PRECAIRE = [4, 5, 6, 7, 8, 9]                  # paille, banco, chaume, nattes, autre, plastique
MUR_PRECAIRE = [5, 6, 7, 8]                         # récupération, pierres simples, paille/banco, autre
COMBUSTIBLE_PROPRE = ["gaz", "electricite"]
ANNEES_ETUDES_MINIMUM = 10                          # niveau 3e (proposition nationale)
MINUTES_ALLER_MAXIMUM = 15                          # 30 minutes aller-retour (PNUD)
BIENS_MAXIMUM = 1                                   # « ne possède qu'un seul de ces biens » (PNUD)

# Lecture de l'indicateur alphabétisation. L'énoncé national dit « UN membre de 17-49 ans ne
# sait pas lire ou écrire » ; le RGPH 2021 codait « AUCUN membre alphabétisé ». L'écart est
# considérable : 61,7 % des ménages privés dans le premier cas, 35,0 % dans le second.
ALPHABETISATION_AU_MOINS_UN_NON_ALPHABETISE = True  # True = énoncé littéral du tableau


def _prive_alphabetisation(X):
    if ALPHABETISATION_AU_MOINS_UN_NON_ALPHABETISE:
        return (X.membres_17_49 - X.membres_17_49_alphabetises) >= 1
    return (X.membres_17_49 >= 1) & (X.membres_17_49_alphabetises == 0)


# Carte officielle des indicateurs : une entrée par ligne du tableau de référence.
# `colonne`     = colonne produite dans X (1 = privé, 0 = non privé)
# `regle`       = seuil appliqué aux colonnes de situation pour obtenir cette colonne
# `situation`   = colonnes de la préconstruction qui portent la situation brute du ménage
# `eligibilite` = colonne qui dit combien de membres sont concernés (None si tous le sont)
INDICATEURS = [
    Indicateur("Education", "Fréquentation scolaire", NATIONALE,
               "Le ménage a un enfant de 6-16 ans qui ne fréquente actuellement pas",
               "frequentation_scolaire", ["enfants_6_16_non_scolarises"], "enfants_6_16",
               lambda X: X.enfants_6_16_non_scolarises >= 1),
    Indicateur("Education", "Année de scolarité", NATIONALE,
               "Aucun membre du ménage âgé de 17-95 ans n'a complété 10 années d'études",
               "annee_scolarite", ["annees_etudes_max"], "membres_17_95",
               lambda X: X.annees_etudes_max < ANNEES_ETUDES_MINIMUM),
    Indicateur("Education", "Alphabétisation", NATIONALE,
               "Un membre du ménage de 17-49 ans ne sait pas lire ou écrire (français)",
               "alphabetisation", ["membres_17_49_alphabetises"], "membres_17_49",
               _prive_alphabetisation),
    Indicateur("Education", "Déclaration d'état civil", NATIONALE,
               "Un membre de 5-15 ans n'a pas d'acte de naissance ou n'est pas déclaré",
               "etat_civil", ["enfants_5_15_sans_acte"], "enfants_5_15",
               lambda X: X.enfants_5_15_sans_acte >= 1),

    Indicateur("Sante", "Assurance maladie", NATIONALE,
               "Aucun membre du ménage n'est couvert par une assurance maladie",
               "assurance_maladie", ["membres_assures"], "taille_menage",
               lambda X: X.membres_assures == 0),

    Indicateur("Emploi", "Chômage", NATIONALE,
               "Un membre du ménage âgé de 17-40 ans est au chômage",
               "chomage", ["chomeurs_17_40"], "membres_17_40",
               lambda X: X.chomeurs_17_40 >= 1),

    Indicateur("Conditions de vie", "Electricité", NATIONALE,
               "La source d'éclairage n'est pas : électricité, groupe électrogène ou solaire",
               "electricite", ["source_eclairage"], None,
               lambda X: ~X.source_eclairage.isin(ECLAIRAGE_ADEQUAT)),
    Indicateur("Conditions de vie", "Logement", PNUD,
               "Sol en matériaux naturels et/ou toit et/ou murs en matériaux naturels "
               "ou rudimentaires",
               "logement", ["materiau_toit", "materiau_mur", "materiau_sol"], None,
               lambda X: (X.materiau_sol.isin(SOL_NATUREL)
                          | X.materiau_toit.isin(TOIT_PRECAIRE)
                          | X.materiau_mur.isin(MUR_PRECAIRE))),
    Indicateur("Conditions de vie", "Eau potable", PNUD,
               "Pas d'eau améliorée (ODD), ou eau à 30 minutes ou plus à pied aller-retour",
               "eau_potable", ["source_eau_boisson_seche", "temps_aller_source_seche"], None,
               lambda X: (~X.source_eau_boisson_seche.isin(EAU_AMELIOREE)
                          | (X.temps_aller_source_seche > MINUTES_ALLER_MAXIMUM))),
    Indicateur("Conditions de vie", "Energie de cuisson", NATIONALE,
               "Le ménage n'utilise pas d'énergie propre pour la cuisson (électricité et gaz)",
               "energie_cuisson", ["combustible_principal"], None,
               lambda X: ~X.combustible_principal.isin(COMBUSTIBLE_PROPRE)),
    Indicateur("Conditions de vie", "Toilette", PNUD,
               "Installations sanitaires non améliorées (ODD), ou améliorées mais partagées",
               "toilette", ["type_sanitaire", "sanitaire_partage"], None,
               lambda X: (~X.type_sanitaire.isin(SANITAIRE_AMELIORE)
                          | (X.sanitaire_partage == 1))),
    Indicateur("Conditions de vie", "Biens d'équipement", PNUD,
               "Le ménage ne possède qu'un seul bien parmi radio, télévision, téléphone, "
               "ordinateur, charrette, vélo, moto, réfrigérateur, et pas de voiture",
               "biens_equipement", ["nb_equipements", "possede_voiture"], None,
               lambda X: (X.nb_equipements <= BIENS_MAXIMUM) & (X.possede_voiture == 0)),
]

# les 12 colonnes indicateurs, dans l'ordre du tableau de référence
COLONNES_INDICATEURS = [i.colonne for i in INDICATEURS]

logger = logging.getLogger("ipm.matrice_situationnelle")


def charger_preconstruction(chemin=ENTREE):
    logger.info("--- 1. lecture de la préconstruction (étape 01) ---")
    P = pd.read_stata(chemin).set_index(CLE)
    logger.info("%s : %d ménages x %d colonnes", chemin.name, *P.shape)
    return P


def calculer_indicateurs(P):
    """Applique le seuil de chaque indicateur : une colonne 0/1 par ligne du tableau."""
    logger.info("--- 2. calcul des indicateurs (seuils appliqués) ---")
    poids = P.ponderation_menage * P.taille_menage
    X = pd.DataFrame(index=P.index)

    for ind in INDICATEURS:
        manquantes = [c for c in ind.situation + ([ind.eligibilite] if ind.eligibilite else [])
                      if c not in P.columns]
        assert not manquantes, f"{ind.libelle} : colonnes absentes de la préconstruction : {manquantes}"

        X[ind.colonne] = ind.regle(P).fillna(False).astype(int)

        logger.info("  %-22s [%s] %-22s privés : %s | pondéré population : %.1f %%",
                    ind.libelle, ind.source[:11], ind.colonne,
                    part(X[ind.colonne].sum(), len(X)),
                    100 * (X[ind.colonne] * poids).sum() / poids.sum())
        logger.debug("      définition : %s", ind.definition)
        logger.debug("      calculé à partir de : %s%s", ", ".join(ind.situation),
                     f" (éligibilité : {ind.eligibilite})" if ind.eligibilite else "")

    sources = pd.Series([i.source for i in INDICATEURS]).value_counts()
    logger.info("%d indicateurs calculés : %s", len(INDICATEURS),
                ", ".join(f"{n} {s}" for s, n in sources.items()))
    logger.info("rappel : la mortalité juvénile du tableau n'existe pas dans l'EHCVM, "
                "la dimension santé est mesurée par l'assurance maladie")

    presentes = [c for c in COLONNES_TECHNIQUES if c in P.columns]
    logger.info("variables de pondération et de désagrégation conservées : %s",
                ", ".join(presentes))
    return X.join(P[presentes])


def controler_matrice(X):
    logger.info("--- 3. contrôles de la matrice X ---")
    assert X.index.is_unique, "la clé grappe/menage/vague doit être unique"
    assert not X[COLONNES_INDICATEURS].isna().any().any(), "un indicateur contient des manquants"
    assert X[COLONNES_INDICATEURS].isin([0, 1]).all().all(), "un indicateur n'est pas en 0/1"
    logger.info("clé unique, %d colonnes indicateurs complètes et en 0/1",
                len(COLONNES_INDICATEURS))

    poids = X.ponderation_menage * X.taille_menage
    nb = X[COLONNES_INDICATEURS].sum(axis=1)
    logger.info("nombre de privations par ménage : moyenne %.2f, médiane %.0f, maximum %d",
                nb.mean(), nb.median(), nb.max())
    logger.info("ménages sans aucune privation : %s (pondéré population : %.1f %%)",
                part((nb == 0).sum(), len(X)), 100 * ((nb == 0) * poids).sum() / poids.sum())

    for cle in ["milieu", "region"]:
        logger.debug("privations moyennes par %s :\n%s", cle,
                     nb.groupby(X[cle]).mean().round(2).to_string())
    return X


def exporter(X, chemin=SORTIE):
    X.to_stata(chemin, write_index=True, version=118)
    logger.info("matrice écrite : %s (%.1f Mo) — %d ménages x %d colonnes",
                chemin, chemin.stat().st_size / 1e6, *X.shape)


def verifier():
    """Deux ménages aux privations connues : privé partout, privé nulle part."""
    configurer_logs(logger, niveau=logging.WARNING)

    P = pd.DataFrame({
        "source_eclairage": [4, 1],                 # lampe à pile / réseau
        "materiau_toit": [4, 3], "materiau_mur": [7, 1], "materiau_sol": [3, 2],
        "source_eau_boisson_seche": [13, 1],        # rivière / robinet dans le logement
        "temps_aller_source_seche": [40.0, float("nan")],
        "combustible_principal": ["bois_ramasse", "gaz"],
        "type_sanitaire": [11, 1], "sanitaire_partage": [float("nan"), 2],
        "nb_equipements": [1, 5], "possede_voiture": [0, 1],
        "enfants_6_16": [2, 2], "enfants_6_16_non_scolarises": [1, 0],
        "membres_17_95": [2, 2], "annees_etudes_max": [3.0, 13.0],
        "membres_17_49": [2, 2], "membres_17_49_alphabetises": [0, 2],
        "membres_17_40": [1, 1], "chomeurs_17_40": [1, 0],
        "enfants_5_15": [1, 1], "enfants_5_15_sans_acte": [1, 0],
        "membres_assures": [0, 1],
        "ponderation_menage": [1.0, 1.0], "taille_menage": [4, 4],
    }, index=["A", "B"])

    X = calculer_indicateurs(P)
    assert X.loc["A", COLONNES_INDICATEURS].tolist() == [1] * 12, X.loc["A"]
    assert X.loc["B", COLONNES_INDICATEURS].tolist() == [0] * 12, X.loc["B"]
    # le ménage sans toilettes (11.55 non posée) est bien privé malgré le manquant
    assert X.loc["A", "toilette"] == 1
    # eau améliorée mais à plus de 15 minutes aller = privé
    lointain = P.assign(source_eau_boisson_seche=[1, 1], temps_aller_source_seche=[20.0, 5.0])
    assert calculer_indicateurs(lointain).eau_potable.tolist() == [1, 0]

    print("auto-contrôle 02 : OK")


def main():
    configurer_logs(logger, JOURNAL)
    debut = time.perf_counter()
    logger.info("=== étape 02 : matrice situationnelle X (12 indicateurs) ===")

    X = calculer_indicateurs(charger_preconstruction())
    controler_matrice(X)
    exporter(X)

    logger.info("=== terminé en %.1f s ===", time.perf_counter() - debut)
    return X


if __name__ == "__main__":
    if "--check" in sys.argv:
        verifier()
    else:
        main()
