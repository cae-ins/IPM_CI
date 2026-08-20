"""Étape 04 du pipeline IPM — censure au seuil k, matrice censurée et score cᵢ(k).

Entrée  : matrice_privations_ponderees.dta (étape 03) = wⱼ · g0ᵢⱼ et le score brut cᵢ
Sortie  : matrice_privations_censuree — wⱼ · g0ᵢⱼ · 1(cᵢ >= k), le score censuré cᵢ(k)
                                        et les statuts de pauvreté

La censure est le cœur de la méthode Alkire-Foster : les privations des ménages NON pauvres
sont remises à zéro. Elles existent toujours dans la matrice pondérée de l'étape 03, mais elles
ne comptent pas dans l'IPM. C'est ce qui distingue M0 d'un simple comptage de privations, et ce
qui rend l'indice décomposable par indicateur.

    cᵢ(k) = cᵢ  si cᵢ >= k,  0 sinon        avec k = 1/3

Deux propriétés vérifiées par `assert` à chaque exécution :
  - la somme d'une ligne censurée redonne cᵢ(k) ;
  - la moyenne d'une colonne censurée (pondérée population) vaut wⱼ · CHⱼ, ce dont l'étape 05
    a besoin pour les contributions.

Usage :
    python 04_matrice_privations_censuree.py
    python 04_matrice_privations_censuree.py --check
"""
import logging
import sys
import time

import pandas as pd

from orchestrateur import (CLE, COLONNES_TECHNIQUES, LOGS, SORTIES_DTA, configurer_logs,
                           exporter_table, part)

ENTREE = SORTIES_DTA / "matrice_privations_ponderees.dta"
NOM_SORTIE = "matrice_privations_censuree"
JOURNAL = LOGS / "04_matrice_privations_censuree.log"

# Seuils. k = 1/3 est le seuil de pauvreté multidimensionnelle de l'IPM ; les deux autres
# servent aux indicateurs complémentaires publiés à côté de M0.
K_PAUVRETE = 1 / 3
K_VULNERABILITE = 0.2    # 0,2 <= c < 1/3 : vulnérable à la pauvreté multidimensionnelle
K_SEVERE = 0.5           # c >= 0,5       : pauvreté multidimensionnelle sévère

# Comparaison de flottants : avec ces poids cᵢ peut valoir EXACTEMENT 1/3, et selon les erreurs
# d'arrondi 0,3333333 se compare mal à 0,33333333. La convention OPHI est « cᵢ >= k ».
TOLERANCE = 1e-9

logger = logging.getLogger("ipm.privations_censurees")


def charger():
    logger.info("--- 1. lecture de la matrice pondérée (étape 03) ---")
    X = pd.read_stata(ENTREE).set_index(CLE)
    ponderees = [c for c in X.columns if c.endswith("_ponderee")]
    assert ponderees, "aucune colonne pondérée dans l'entrée"

    ecart = (X[ponderees].sum(axis=1) - X.score).abs().max()
    assert ecart < TOLERANCE, f"le score doit être la somme des colonnes pondérées ({ecart})"
    logger.info("%s : %d ménages, %d colonnes pondérées", ENTREE.name, len(X), len(ponderees))
    return X, ponderees


def statuts_pauvrete(score, poids_population, nb_menages):
    """Les trois statuts issus du score brut, avant toute mise à zéro."""
    logger.info("--- 2. statuts au seuil k = %.4f ---", K_PAUVRETE)
    pauvre = score >= K_PAUVRETE - TOLERANCE
    vulnerable = (score >= K_VULNERABILITE - TOLERANCE) & ~pauvre
    severe = score >= K_SEVERE - TOLERANCE

    for libelle, statut in [("pauvres (c >= 1/3)", pauvre),
                            ("vulnérables (0,2 <= c < 1/3)", vulnerable),
                            ("pauvreté sévère (c >= 0,5)", severe)]:
        logger.info("  %-30s %-16s | pondéré population : %.1f %%", libelle,
                    part(int(statut.sum()), nb_menages),
                    100 * (statut * poids_population).sum() / poids_population.sum())

    a_la_limite = (score - K_PAUVRETE).abs() < TOLERANCE
    logger.info("ménages au score exactement égal à k : %s — comptés comme PAUVRES "
                "(convention OPHI « c >= k »)", part(int(a_la_limite.sum()), nb_menages))
    return pauvre, vulnerable, severe


def censurer(X, ponderees, pauvre):
    """Matrice pondérée censurée : wⱼ · g0ᵢⱼ · 1(cᵢ >= k), une colonne par indicateur."""
    logger.info("--- 3. matrice de privation pondérée censurée ---")
    censuree = X[ponderees].mul(pauvre, axis=0)
    censuree.columns = [c.replace("_ponderee", "_censuree") for c in censuree.columns]

    logger.info("%d colonnes censurées ; apport moyen à M0 (= wⱼ · CHⱼ) :", censuree.shape[1])
    for colonne, moyenne in censuree.mean().sort_values(ascending=False).items():
        logger.info("  %-32s %.4f", colonne, moyenne)

    remis_a_zero = (X[ponderees].sum(axis=1) > 0) & ~pauvre
    logger.info("ménages non pauvres dont les privations sont remises à zéro : %s",
                part(int(remis_a_zero.sum()), len(X)))
    logger.info("privations pondérées effacées par la censure : %.4f sur %.4f (%.1f %%)",
                X[ponderees].sum(axis=1).sum() - censuree.sum(axis=1).sum(),
                X[ponderees].sum(axis=1).sum(),
                100 * (1 - censuree.sum(axis=1).sum() / X[ponderees].sum(axis=1).sum()))
    return censuree


def calculer_score_censure(censuree, score, pauvre):
    """cᵢ(k) : le score des pauvres, zéro pour les autres."""
    logger.info("--- 4. score de privation censuré cᵢ(k) ---")
    score_censure = score.where(pauvre, 0.0)

    ecart = (censuree.sum(axis=1) - score_censure).abs().max()
    assert ecart < TOLERANCE, f"la somme des lignes censurées doit redonner cᵢ(k), écart {ecart}"

    chez_les_pauvres = score_censure[pauvre]
    logger.info("cᵢ(k) : moyenne %.4f sur l'ensemble, %.4f chez les seuls pauvres (= A non "
                "pondéré)", score_censure.mean(), chez_les_pauvres.mean())
    logger.info("contrôle : la somme des lignes censurées redonne cᵢ(k) (écart max %.2e)", ecart)
    return score_censure


def construire():
    X, ponderees = charger()
    poids_population = X.ponderation_menage * X.taille_menage

    pauvre, vulnerable, severe = statuts_pauvrete(X.score, poids_population, len(X))
    censuree = censurer(X, ponderees, pauvre)
    score_censure = calculer_score_censure(censuree, X.score, pauvre)

    logger.info("--- 5. assemblage ---")
    statuts = pd.DataFrame({
        "score": X.score,
        "score_censure": score_censure,
        "pauvre": pauvre.astype(int),
        "vulnerable": vulnerable.astype(int),
        "pauvrete_severe": severe.astype(int),
    })
    C = pd.concat([statuts, censuree,
                   X[[c for c in COLONNES_TECHNIQUES if c in X.columns]]], axis=1)
    logger.info("matrice censurée : %d ménages x %d colonnes", *C.shape)
    return C


# --------------------------------------------------------------------------- #
# auto-contrôle
# --------------------------------------------------------------------------- #
def verifier():
    """Trois ménages aux scores connus, dont un exactement au seuil."""
    configurer_logs(logger, niveau=logging.WARNING)

    #  A : c = 0,50 (pauvre et sévère)   B : c = 0,25 (vulnérable)   C : c = 1/3 (au seuil)
    X = pd.DataFrame({
        "i1_ponderee": [0.25, 0.25, 0.25],
        "i2_ponderee": [0.25, 0.00, 1 / 12],
        "ponderation_menage": [1.0, 1.0, 1.0],
        "taille_menage": [4, 4, 4],
    }, index=["A", "B", "C"])
    X["score"] = X[["i1_ponderee", "i2_ponderee"]].sum(axis=1)
    poids = X.ponderation_menage * X.taille_menage

    pauvre, vulnerable, severe = statuts_pauvrete(X.score, poids, len(X))
    # C est exactement à k : pauvre selon la convention « c >= k »
    assert pauvre.tolist() == [True, False, True], pauvre.tolist()
    assert vulnerable.tolist() == [False, True, False]
    assert severe.tolist() == [True, False, False]

    censuree = censurer(X, ["i1_ponderee", "i2_ponderee"], pauvre)
    assert list(censuree.columns) == ["i1_censuree", "i2_censuree"]
    # la ligne du ménage non pauvre est entièrement remise à zéro
    assert censuree.loc["B"].tolist() == [0.0, 0.0]
    assert censuree.loc["A"].tolist() == [0.25, 0.25]

    score_censure = calculer_score_censure(censuree, X.score, pauvre)
    assert score_censure["B"] == 0.0
    assert abs(score_censure["A"] - 0.5) < TOLERANCE
    assert abs(score_censure["C"] - 1 / 3) < TOLERANCE, score_censure["C"]
    # la moyenne d'une colonne censurée vaut bien wⱼ · CHⱼ : i1 privé chez A et C -> 0,25 x 2/3
    assert abs(censuree.i1_censuree.mean() - 0.25 * 2 / 3) < TOLERANCE

    print("auto-contrôle 04 : OK")


def main():
    configurer_logs(logger, JOURNAL)
    debut = time.perf_counter()
    logger.info("=== étape 04 : censure au seuil k, matrice censurée et score cᵢ(k) ===")

    C = construire()
    logger.info("--- 6. export (Stata + CSV) ---")
    exporter_table(C, NOM_SORTIE, logger)

    logger.info("=== terminé en %.1f s ===", time.perf_counter() - debut)
    return C


if __name__ == "__main__":
    if "--check" in sys.argv:
        verifier()
    else:
        main()
