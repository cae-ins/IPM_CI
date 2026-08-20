"""Étape 05 du pipeline IPM — indices H, A, M0 et désagrégations.

Entrée  : matrice_privations_censuree.dta (étape 04)
Sorties : indices_ipm       — une ligne « Ensemble » puis une ligne par modalité de
                              désagrégation (.dta, .csv)
          contributions_ipm — la part de chaque indicateur et de chaque dimension dans M0
                              (.dta, .csv)
          indices_ipm.xlsx  — le classeur de restitution : une feuille par objet
                              (Ensemble, Contributions, une par désagrégation, Tout)

Formules (méthode Alkire-Foster, document méthodologique national) :

    H  = Σ nᵢ · 1(cᵢ >= k) / Σ nᵢ            incidence : la part de la population pauvre
    A  = Σ nᵢ · cᵢ(k) / Σ nᵢ · 1(cᵢ >= k)    intensité : privations moyennes des pauvres
    M0 = H × A = Σ nᵢ · cᵢ(k) / Σ nᵢ         l'IPM lui-même

L'unité de construction est le ménage, l'unité de COMPTAGE est l'individu : chaque ménage pèse
nᵢ = `taille_menage` × `ponderation_menage`. Sans cette pondération les indices décrivent
l'échantillon, pas la Côte d'Ivoire.

M0 est décomposable : la somme des M0 de groupe, pondérée par la part de population de chaque
groupe, redonne M0 national. C'est vérifié par `assert` pour chaque variable de désagrégation.

Usage :
    python 05_indices_ipm.py
    python 05_indices_ipm.py --check
"""
import logging
import sys
import time

import pandas as pd

from orchestrateur import (CLE, LOGS, SORTIES_CSV, SORTIES_DTA, SORTIES_XLSX,
                           configurer_logs, exporter_table, part)

ENTREE = SORTIES_DTA / "matrice_privations_censuree.dta"
ENTREE_W = SORTIES_CSV / "vecteur_w.csv"
NOM_SORTIE = "indices_ipm"
NOM_CONTRIBUTIONS = "contributions_ipm"
JOURNAL = LOGS / "05_indices_ipm.log"

TOLERANCE = 1e-9

# variables de désagrégation : colonne de la matrice -> libellé publié
DESAGREGATIONS = {
    "milieu": "Milieu de résidence",
    "region": "Région",
    "sexe_cm": "Sexe du chef de ménage",
    "classe_taille": "Taille du ménage",
}
BORNES_TAILLE = [0, 2, 4, 6, 9, 100]
LIBELLES_TAILLE = ["1-2 personnes", "3-4", "5-6", "7-9", "10 et plus"]

COLONNES_PUBLIEES = ["variable", "modalite", "menages", "population", "part_population",
                     "H_incidence", "A_intensite", "M0_ipm", "contribution_M0",
                     "vulnerables", "pauvrete_severe"]

logger = logging.getLogger("ipm.indices")


def charger():
    logger.info("--- 1. lecture de la matrice censurée (étape 04) ---")
    X = pd.read_stata(ENTREE).set_index(CLE)

    X["poids_population"] = X.ponderation_menage * X.taille_menage
    X["classe_taille"] = pd.cut(X.taille_menage, bins=BORNES_TAILLE, labels=LIBELLES_TAILLE)

    logger.info("%s : %d ménages, %d colonnes", ENTREE.name, *X.shape)
    logger.info("population représentée : %s personnes",
                part(int(X.poids_population.sum()), 0))
    return X


def indices(X):
    """H, A et M0 sur un sous-ensemble de ménages (ou sur l'ensemble)."""
    n = X.poids_population
    pauvres = (n * X.pauvre).sum()

    H = pauvres / n.sum()
    A = (n * X.score_censure).sum() / pauvres if pauvres else 0.0
    return pd.Series({
        "menages": len(X),
        "population": n.sum(),
        "H_incidence": H,
        "A_intensite": A,
        "M0_ipm": H * A,
        "vulnerables": (n * X.vulnerable).sum() / n.sum(),
        "pauvrete_severe": (n * X.pauvrete_severe).sum() / n.sum(),
    })


def indices_nationaux(X):
    logger.info("--- 2. indices nationaux ---")
    resultat = indices(X)

    # M0 = H x A par construction : le vérifier attrape toute erreur de pondération
    direct = (X.poids_population * X.score_censure).sum() / X.poids_population.sum()
    assert abs(resultat.M0_ipm - direct) < TOLERANCE, (resultat.M0_ipm, direct)

    logger.info("  H  (incidence)  = %.4f   soit %.1f %% de la population",
                resultat.H_incidence, 100 * resultat.H_incidence)
    logger.info("  A  (intensité)  = %.4f   privations pondérées moyennes des pauvres",
                resultat.A_intensite)
    logger.info("  M0 (IPM)        = %.4f   = H x A", resultat.M0_ipm)
    logger.info("  vulnérables     = %.1f %%   | pauvreté sévère = %.1f %%",
                100 * resultat.vulnerables, 100 * resultat.pauvrete_severe)
    logger.info("population pauvre : %s personnes",
                part(int((X.poids_population * X.pauvre).sum()), 0))
    logger.info("contrôle M0 = H x A = Σnᵢcᵢ(k)/Σnᵢ : écart %.2e",
                abs(resultat.M0_ipm - direct))

    ligne = resultat.to_frame().T
    ligne.insert(0, "variable", "Ensemble")
    ligne.insert(1, "modalite", "Côte d'Ivoire")
    return ligne.reset_index(drop=True)


def desagregations(X, M0_national, population_totale):
    """H, A et M0 par sous-population, avec la contribution de chaque groupe à M0 national."""
    logger.info("--- 3. désagrégations ---")
    morceaux = []

    for colonne, libelle in DESAGREGATIONS.items():
        if colonne not in X.columns:
            logger.warning("désagrégation ignorée, colonne absente : %s", colonne)
            continue

        table = X.groupby(colonne, observed=True)[X.columns].apply(indices)
        table.insert(0, "variable", libelle)
        table.index.name = "modalite"
        table = table.reset_index()
        table["modalite"] = table.modalite.astype(str)
        morceaux.append(table)

        logger.info("%s :", libelle)
        for _, ligne in table.iterrows():
            logger.info("  %-14s H = %5.1f %% | A = %.4f | M0 = %.4f | %5.1f %% de la population",
                        ligne.modalite, 100 * ligne.H_incidence, ligne.A_intensite,
                        ligne.M0_ipm, 100 * ligne.population / population_totale)

    D = pd.concat(morceaux, ignore_index=True)
    D["part_population"] = D.population / population_totale
    D["contribution_M0"] = D.M0_ipm * D.part_population / M0_national

    for libelle, groupe in D.groupby("variable"):
        somme = groupe.contribution_M0.sum()
        assert abs(somme - 1) < 1e-6, f"{libelle} : contributions à {somme}, attendu 1"
        assert abs(groupe.part_population.sum() - 1) < 1e-6, f"{libelle} : population incomplète"
    logger.info("contrôle de décomposabilité : pour chaque variable, les M0 de groupe pondérés "
                "par la part de population redonnent M0 national")
    return D


def contributions(X, M0):
    """Cⱼ = wⱼ · CHⱼ / M0 — la part de chaque indicateur dans l'IPM.

    CHⱼ est le taux de privation CENSURÉ : la privation des seuls ménages pauvres. Comme les
    colonnes `_censuree` de l'étape 04 portent déjà wⱼ · g0ᵢⱼ · 1(pauvre), leur moyenne pondérée
    population vaut directement wⱼ · CHⱼ. Les Cⱼ somment à 1 par construction.
    """
    logger.info("--- 4. contributions des indicateurs à M0 ---")
    w = pd.read_csv(ENTREE_W)
    n = X.poids_population

    lignes = []
    for _, ind in w.iterrows():
        colonne = f"{ind.colonne}_censuree"
        assert colonne in X.columns, f"colonne censurée absente : {colonne}"

        apport = (n * X[colonne]).sum() / n.sum()          # = wⱼ · CHⱼ
        brut = (n * (X[colonne] > 0)).sum() / n.sum()      # privation censurée, en effectif
        lignes.append({
            "dimension": ind.dimension,
            "indicateur": ind.indicateur,
            "colonne": ind.colonne,
            "poids_w": ind.poids_indicateur,
            "taux_privation_censure": brut,
            "apport_a_M0": apport,
            "contribution_M0": apport / M0,
        })

    C = pd.DataFrame(lignes).sort_values("contribution_M0", ascending=False)
    total = C.contribution_M0.sum()
    assert abs(total - 1) < 1e-9, f"les contributions doivent sommer à 1, obtenu {total}"

    for _, ligne in C.iterrows():
        logger.info("  %-24s w = %.4f | privation censurée %5.1f %% | contribution %5.1f %%",
                    ligne.colonne, ligne.poids_w,
                    100 * ligne.taux_privation_censure, 100 * ligne.contribution_M0)
    logger.info("somme des contributions = %.6f", total)

    par_dimension = C.groupby("dimension").contribution_M0.sum().sort_values(ascending=False)
    logger.info("par dimension (poids nominal : 25,0 %% chacune) :")
    for dimension, contribution in par_dimension.items():
        logger.info("  %-18s %.1f %%", dimension, 100 * contribution)

    # une dimension qui contribue bien plus que son poids nominal domine l'indice
    C["contribution_dimension"] = C.dimension.map(par_dimension)
    return C


def assembler(national, D):
    """Une seule table : la ligne Ensemble puis les désagrégations, colonnes ordonnées."""
    logger.info("--- 5. assemblage de la table publiée ---")
    national = national.assign(part_population=1.0, contribution_M0=1.0)
    table = pd.concat([national, D], ignore_index=True)[COLONNES_PUBLIEES]

    table.menages = table.menages.astype(int)
    table.population = table.population.round(0).astype(int)
    for colonne in ["part_population", "H_incidence", "A_intensite", "M0_ipm",
                    "contribution_M0", "vulnerables", "pauvrete_severe"]:
        table[colonne] = table[colonne].round(6)

    logger.info("%d lignes : 1 ensemble + %d modalités sur %d variables",
                len(table), len(D), D.variable.nunique())
    return table


def exporter_classeur(table, C, nom=NOM_SORTIE):
    """Un classeur, une feuille par objet : l'ensemble, les contributions, puis une feuille
    par variable de désagrégation."""
    chemin = SORTIES_XLSX / f"{nom}.xlsx"

    feuilles = {"Ensemble": table[table.variable == "Ensemble"],
                "Contributions": C}
    for libelle in DESAGREGATIONS.values():
        morceau = table[table.variable == libelle]
        if not morceau.empty:
            # un nom de feuille Excel fait au plus 31 caractères
            feuilles[libelle[:31]] = morceau
    feuilles["Tout"] = table

    with pd.ExcelWriter(chemin, engine="openpyxl") as classeur:
        for feuille, morceau in feuilles.items():
            morceau.to_excel(classeur, sheet_name=feuille, index=False, freeze_panes=(1, 2))

    logger.info("%-42s -> xlsx %.2f Mo  (%d feuilles : %s)", nom,
                chemin.stat().st_size / 1e6, len(feuilles), ", ".join(feuilles))
    return chemin


# --------------------------------------------------------------------------- #
# auto-contrôle
# --------------------------------------------------------------------------- #
def verifier():
    """Quatre ménages aux indices calculables à la main."""
    configurer_logs(logger, niveau=logging.WARNING)

    #  A : pauvre, c = 0,50, 2 personnes      B : pauvre, c = 1,00, 8 personnes
    #  C : non pauvre, c = 0,25, 5 personnes  D : non pauvre, c = 0,00, 5 personnes
    X = pd.DataFrame({
        "score": [0.50, 1.00, 0.25, 0.00],
        "score_censure": [0.50, 1.00, 0.00, 0.00],
        "pauvre": [1, 1, 0, 0],
        "vulnerable": [0, 0, 1, 0],
        "pauvrete_severe": [1, 1, 0, 0],
        "taille_menage": [2, 8, 5, 5],
        "ponderation_menage": [1.0, 1.0, 1.0, 1.0],
        "milieu": [1, 1, 2, 2],
    }, index=["A", "B", "C", "D"])
    X["poids_population"] = X.ponderation_menage * X.taille_menage

    # population = 20 ; pauvres = 2 + 8 = 10 -> H = 0,5
    # A = (2 x 0,50 + 8 x 1,00) / 10 = 0,9 ; M0 = 0,5 x 0,9 = 0,45
    resultat = indices(X)
    assert resultat.population == 20
    assert abs(resultat.H_incidence - 0.5) < TOLERANCE, resultat.H_incidence
    assert abs(resultat.A_intensite - 0.9) < TOLERANCE, resultat.A_intensite
    assert abs(resultat.M0_ipm - 0.45) < TOLERANCE, resultat.M0_ipm
    assert abs(resultat.vulnerables - 0.25) < TOLERANCE       # C pèse 5 sur 20
    # la taille compte : à poids égaux, A et B pèsent pareil et A = (0,5 + 1,0)/2
    assert abs(indices(X.assign(poids_population=1.0)).A_intensite - 0.75) < TOLERANCE

    national = indices_nationaux(X)
    assert national.modalite.iloc[0] == "Côte d'Ivoire"

    # désagrégation : le milieu 1 porte toute la pauvreté
    D = desagregations(X, resultat.M0_ipm, resultat.population)
    milieu = D.set_index("modalite")
    assert abs(milieu.loc["1", "H_incidence"] - 1.0) < TOLERANCE
    assert abs(milieu.loc["2", "M0_ipm"]) < TOLERANCE
    assert abs(milieu.loc["1", "contribution_M0"] - 1.0) < TOLERANCE
    # décomposabilité : 0,5 x 0,9 x (10/20) + 0 = 0,225... redonne M0 x part
    assert abs((D.M0_ipm * D.part_population).sum() - resultat.M0_ipm) < TOLERANCE

    table = assembler(national, D)
    assert list(table.columns) == COLONNES_PUBLIEES
    assert table.variable.tolist() == ["Ensemble", "Milieu de résidence", "Milieu de résidence"]

    print("auto-contrôle 05 : OK")


def main():
    configurer_logs(logger, JOURNAL)
    debut = time.perf_counter()
    logger.info("=== étape 05 : indices H, A, M0 et désagrégations ===")

    X = charger()
    national = indices_nationaux(X)
    M0 = national.M0_ipm.iloc[0]
    D = desagregations(X, M0, national.population.iloc[0])
    C = contributions(X, M0)
    table = assembler(national, D)

    logger.info("--- 6. export (Stata + CSV + XLSX) ---")
    exporter_table(table, NOM_SORTIE, logger, index=False)
    exporter_table(C, NOM_CONTRIBUTIONS, logger, index=False)
    exporter_classeur(table, C)

    logger.info("=== terminé en %.1f s ===", time.perf_counter() - debut)
    return table


if __name__ == "__main__":
    if "--check" in sys.argv:
        verifier()
    else:
        main()
