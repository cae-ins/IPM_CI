"""Étape 03 du pipeline IPM — pondérations w, matrice pondérée et score cᵢ.

Entrée  : matrice_situationnelle_ehcvm2021.dta (étape 02) = la matrice de privation g0,
          12 965 ménages x 17 indicateurs en 0/1.
Sorties : vecteur_w                     — le poids de chaque indicateur
          matrice_privations_ponderees  — g0 pondérée (wⱼ · g0ᵢⱼ) et le score cᵢ

Méthode Alkire-Foster (chapitre 4 du guide ODD), dans l'ordre :

    1. vecteur w    : 4 dimensions équipondérées, le poids d'une dimension se partage à parts
                      égales entre ses indicateurs. Σ wⱼ = 1.
    2. g0 pondérée  : chaque colonne de privation multipliée par son poids (wⱼ · g0ᵢⱼ).
    3. score cᵢ     : la somme de la ligne — la part de privations pondérées du ménage i,
                      entre 0 (aucune privation) et 1 (privé partout).

AUCUNE censure ici : cᵢ est le score brut, tous ménages confondus. La censure au seuil k et le
score censuré cᵢ(k) font l'objet de l'étape 04.

Le vecteur w est déduit de `vecteur_z.csv` (colonne `dimension`) : la liste des indicateurs et
leur dimension n'est donc écrite qu'une fois, dans l'étape 02.

Usage :
    python 03_matrice_privations_ponderees.py
    python 03_matrice_privations_ponderees.py --check
"""
import logging
import sys
import time

import pandas as pd

from orchestrateur import (CLE, COLONNES_TECHNIQUES, LOGS, SORTIES_CSV, SORTIES_DTA,
                           configurer_logs, exporter_table, part)

ENTREE = SORTIES_DTA / "matrice_situationnelle_ehcvm2021.dta"
ENTREE_Z = SORTIES_CSV / "vecteur_z.csv"
NOM_W = "vecteur_w"
NOM_SORTIE = "matrice_privations_ponderees"
JOURNAL = LOGS / "03_matrice_privations_ponderees.log"

# Comparaison de flottants : avec 4 dimensions à 0,25 le score peut valoir EXACTEMENT 1/3
# (0,25 + 2 x 0,041666...), et 0,3333333 < 0,33333333 selon les erreurs d'arrondi.
TOLERANCE = 1e-9

logger = logging.getLogger("ipm.privations_ponderees")


# --------------------------------------------------------------------------- #
# 1. vecteur w
# --------------------------------------------------------------------------- #
def vecteur_w(chemin_z=ENTREE_Z):
    """Poids de chaque indicateur : dimensions équipondérées, partage égal à l'intérieur.

    Aucune liste d'indicateurs n'est réécrite ici : elle est lue dans le vecteur z produit par
    l'étape 02, ce qui garantit que w et z portent sur exactement les mêmes 16 colonnes.
    """
    logger.info("--- 1. vecteur w des pondérations ---")
    z = pd.read_csv(chemin_z)
    dimensions = z.dimension.unique()
    poids_dimension = 1 / len(dimensions)

    w = z[["dimension", "indicateur", "colonne"]].copy()
    w["indicateurs_dans_la_dimension"] = w.groupby("dimension").colonne.transform("size")
    w["poids_dimension"] = poids_dimension
    w["poids_indicateur"] = poids_dimension / w.indicateurs_dans_la_dimension

    logger.info("%d dimensions équipondérées à %.4f", len(dimensions), poids_dimension)
    for dimension, groupe in w.groupby("dimension", sort=False):
        logger.info("  %-18s %d indicateur(s) x %.4f = %.4f",
                    dimension, len(groupe), groupe.poids_indicateur.iloc[0],
                    groupe.poids_indicateur.sum())
        for _, ligne in groupe.iterrows():
            logger.debug("      %-24s %.6f", ligne.colonne, ligne.poids_indicateur)

    total = w.poids_indicateur.sum()
    assert abs(total - 1) < TOLERANCE, f"les poids doivent sommer à 1, obtenu {total}"
    logger.info("somme des poids = %.6f", total)
    return w


# --------------------------------------------------------------------------- #
# 2 à 4. pondération, score, censure
# --------------------------------------------------------------------------- #
def ponderer(g0, w):
    """g0 pondérée : wⱼ · g0ᵢⱼ, une colonne `<indicateur>_ponderee` par indicateur."""
    logger.info("--- 2. matrice de privation pondérée ---")
    poids = w.set_index("colonne").poids_indicateur
    manquantes = [c for c in poids.index if c not in g0.columns]
    assert not manquantes, f"indicateurs absents de la matrice de privation : {manquantes}"

    ponderee = g0[poids.index].mul(poids, axis=1)
    ponderee.columns = [f"{c}_ponderee" for c in ponderee.columns]

    logger.info("%d colonnes pondérées ; contribution moyenne au score :", ponderee.shape[1])
    for colonne, moyenne in ponderee.mean().sort_values(ascending=False).items():
        logger.info("  %-32s %.4f", colonne, moyenne)
    return ponderee


def calculer_score(ponderee):
    """Score cᵢ = somme de la ligne pondérée, dans [0, 1]."""
    logger.info("--- 3. score de privation cᵢ ---")
    score = ponderee.sum(axis=1)

    assert score.between(-TOLERANCE, 1 + TOLERANCE).all(), "un score sort de [0, 1]"
    logger.info("score : moyenne %.4f, médiane %.4f, min %.4f, max %.4f",
                score.mean(), score.median(), score.min(), score.max())
    logger.debug("déciles du score :\n%s",
                 score.quantile([i / 10 for i in range(1, 10)]).round(4).to_string())
    return score


def construire():
    logger.info("--- 0. lecture de la matrice de privation g0 (étape 02) ---")
    g0 = pd.read_stata(ENTREE).set_index(CLE)
    logger.info("%s : %d ménages x %d colonnes", ENTREE.name, *g0.shape)

    w = vecteur_w()
    ponderee = ponderer(g0, w)
    score = calculer_score(ponderee)

    logger.info("--- 4. assemblage ---")
    X = pd.concat([score.rename("score"), ponderee,
                   g0[[c for c in COLONNES_TECHNIQUES if c in g0.columns]]], axis=1)
    logger.info("matrice pondérée : %d ménages x %d colonnes", *X.shape)
    return w, X


def exporter(w, X):
    logger.info("--- 5. export (Stata + CSV) ---")
    exporter_table(w, NOM_W, logger, index=False)
    exporter_table(X, NOM_SORTIE, logger)


# --------------------------------------------------------------------------- #
# auto-contrôle
# --------------------------------------------------------------------------- #
def verifier():
    """Trois ménages aux scores calculables à la main."""
    configurer_logs(logger, niveau=logging.WARNING)

    z = pd.DataFrame({
        "dimension": ["Education"] * 4 + ["Sante", "Emploi"] + ["Conditions de vie"] * 6,
        "indicateur": [f"i{n}" for n in range(12)],
        "colonne": [f"i{n}" for n in range(12)],
    })
    chemin = SORTIES_CSV / "_test_vecteur_z.csv"
    z.to_csv(chemin, index=False)
    w = vecteur_w(chemin)
    chemin.unlink()

    # 4 dimensions à 0,25 : Éducation 4 x 0,0625, Santé 0,25, Emploi 0,25, Cadre de vie 6 x 1/24
    assert abs(w.poids_indicateur.sum() - 1) < TOLERANCE
    assert abs(w.poids_indicateur[0] - 0.0625) < TOLERANCE, w.poids_indicateur[0]
    assert abs(w.poids_indicateur[4] - 0.25) < TOLERANCE
    assert abs(w.poids_indicateur[6] - 0.25 / 6) < TOLERANCE

    #  A : privé partout                       -> c = 1
    #  B : privé nulle part                    -> c = 0
    #  C : santé + 2 conditions de vie         -> c = 0,25 + 2/24 = 1/3 exactement
    g0 = pd.DataFrame(0, index=["A", "B", "C"], columns=[f"i{n}" for n in range(12)])
    g0.loc["A"] = 1
    g0.loc["C", ["i4", "i6", "i7"]] = 1
    g0["ponderation_menage"] = 1.0
    g0["taille_menage"] = 4

    ponderee = ponderer(g0, w)
    score = calculer_score(ponderee)
    assert abs(score["A"] - 1) < TOLERANCE, score["A"]
    assert score["B"] == 0
    assert abs(score["C"] - 1 / 3) < TOLERANCE, score["C"]

    print("auto-contrôle 03 : OK")


def main():
    configurer_logs(logger, JOURNAL)
    debut = time.perf_counter()
    logger.info("=== étape 03 : pondérations w, matrice pondérée et score cᵢ ===")

    w, X = construire()
    exporter(w, X)

    logger.info("=== terminé en %.1f s ===", time.perf_counter() - debut)
    return X


if __name__ == "__main__":
    if "--check" in sys.argv:
        verifier()
    else:
        main()
