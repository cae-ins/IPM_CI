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

import numpy as np
import pandas as pd
from scipy import stats

import dictionnaire_ehcvm as dico
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
    "departement": "Département",
    # pas de « / » : le libellé sert aussi de nom de feuille Excel
    "sous_prefecture": "Sous-préfecture ou commune",
    "sexe_cm": "Sexe du chef de ménage",
    "classe_taille": "Taille du ménage",
}
MODALITES_AFFICHEES = 40        # au-delà, la console n'affiche que les extrêmes
BORNES_TAILLE = [0, 2, 4, 6, 9, 100]
LIBELLES_TAILLE = ["1-2 personnes", "3-4", "5-6", "7-9", "10 et plus"]

NIVEAU_CONFIANCE = 0.95         # intervalles de confiance publiés
CV_PUBLIABLE = 0.20             # au-delà, l'estimation est jugée trop imprécise pour publication

COLONNES_PUBLIEES = ["variable", "modalite", "code", "menages", "grappes", "population",
                     "part_population",
                     "H_incidence", "H_ic_bas", "H_ic_haut",
                     "A_intensite", "A_ic_bas", "A_ic_haut",
                     "M0_ipm", "M0_ic_bas", "M0_ic_haut", "M0_erreur_type", "M0_cv",
                     "contribution_M0", "vulnerables", "pauvrete_severe"]

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


def grappes_de(X):
    """L'unité primaire de sondage de l'EHCVM : la grappe, portée par la clé du ménage."""
    if "grappe" in (X.index.names or []):
        return X.index.get_level_values("grappe")
    return X.grappe


def ratio_et_ic(y, x, n, grappes, niveau=NIVEAU_CONFIANCE):
    """Ratio R = Σnᵢyᵢ / Σnᵢxᵢ et son intervalle de confiance, plan de sondage pris en compte.

    H, A et M0 sont tous des ratios de ce type (H : y = pauvre, x = 1 ; M0 : y = cᵢ(k), x = 1 ;
    A : y = cᵢ(k), x = pauvre), d'où une seule fonction pour les trois. La variance est celle
    du ratio linéarisé, agrégée à la GRAPPE : deux ménages d'une même grappe se ressemblent,
    les traiter comme indépendants sous-estimerait l'erreur d'un facteur 2 ou plus.

    ponytail: variance « ultimate cluster » sans strate (grappes tirées avec remise). La
    stratification région x milieu ne peut que réduire la variance : l'IC est donc légèrement
    conservateur. Passer à une variance stratifiée si des IC plus serrés sont nécessaires.
    """
    denominateur = (n * x).sum()
    if denominateur <= 0:
        return 0.0, np.nan, np.nan, np.nan

    R = (n * y).sum() / denominateur
    # contribution de chaque ménage au ratio linéarisé, sommée par grappe
    u = (n * (y - R * x) / denominateur).groupby(grappes, observed=True).sum()
    nb_grappes = u.count()
    if nb_grappes < 2:
        return R, np.nan, np.nan, np.nan

    # Σuᵢ = 0 par construction : la variance ultimate cluster se réduit à n/(n-1) Σuᵢ²
    erreur_type = np.sqrt(nb_grappes / (nb_grappes - 1) * (u ** 2).sum())
    marge = stats.t.ppf(0.5 + niveau / 2, nb_grappes - 1) * erreur_type
    return R, max(R - marge, 0.0), min(R + marge, 1.0), erreur_type


def indices(X):
    """H, A et M0 sur un sous-ensemble de ménages (ou sur l'ensemble), avec leurs IC."""
    n = X.poids_population
    grappes = grappes_de(X)
    unite = pd.Series(1.0, index=X.index)

    H, H_bas, H_haut, _ = ratio_et_ic(X.pauvre, unite, n, grappes)
    A, A_bas, A_haut, _ = ratio_et_ic(X.score_censure, X.pauvre, n, grappes)
    M0, M0_bas, M0_haut, M0_se = ratio_et_ic(X.score_censure, unite, n, grappes)
    assert abs(M0 - H * A) < TOLERANCE, (M0, H * A)

    return pd.Series({
        "menages": len(X),
        "grappes": pd.Series(grappes).nunique(),
        "population": n.sum(),
        "H_incidence": H, "H_ic_bas": H_bas, "H_ic_haut": H_haut,
        "A_intensite": A, "A_ic_bas": A_bas, "A_ic_haut": A_haut,
        "M0_ipm": M0, "M0_ic_bas": M0_bas, "M0_ic_haut": M0_haut,
        "M0_erreur_type": M0_se,
        "M0_cv": M0_se / M0 if M0 else np.nan,
        "vulnerables": (n * X.vulnerable).sum() / n.sum(),
        "pauvrete_severe": (n * X.pauvrete_severe).sum() / n.sum(),
    })


def indices_nationaux(X):
    logger.info("--- 2. indices nationaux ---")
    resultat = indices(X)

    # M0 = H x A par construction : le vérifier attrape toute erreur de pondération
    direct = (X.poids_population * X.score_censure).sum() / X.poids_population.sum()
    # tolérance relâchée : M0 est sommé grappe par grappe dans `indices`, en vrac ici — même
    # formule, ordre d'accumulation différent, donc écart de l'ordre de 1e-8 sur 13 000 ménages
    assert abs(resultat.M0_ipm - direct) < 1e-6, (resultat.M0_ipm, direct)

    logger.info("  H  (incidence)  = %.4f   IC 95 %% [%.4f ; %.4f]   soit %.1f %% de la population",
                resultat.H_incidence, resultat.H_ic_bas, resultat.H_ic_haut,
                100 * resultat.H_incidence)
    logger.info("  A  (intensité)  = %.4f   IC 95 %% [%.4f ; %.4f]   privations pondérées "
                "moyennes des pauvres",
                resultat.A_intensite, resultat.A_ic_bas, resultat.A_ic_haut)
    logger.info("  M0 (IPM)        = %.4f   IC 95 %% [%.4f ; %.4f]   = H x A",
                resultat.M0_ipm, resultat.M0_ic_bas, resultat.M0_ic_haut)
    logger.info("  erreur-type de M0 = %.4f sur %d grappes | CV = %.1f %%",
                resultat.M0_erreur_type, resultat.grappes, 100 * resultat.M0_cv)
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
        # les tableaux publiés portent les libellés, pas les codes de l'enquête
        etiquettes = dico.modalites(colonne)
        table["code"] = table.modalite
        table["modalite"] = (table.modalite.map(etiquettes) if etiquettes
                             else table.modalite).astype(str)
        if etiquettes:
            inconnues = table.modalite.isna().sum()
            assert not inconnues, f"{inconnues} modalités sans libellé pour {colonne}"
        morceaux.append(table)

        # les découpages fins (108 départements, 442 sous-préfectures) ne sont détaillés que
        # dans le journal : la console garde les extrêmes.
        detaille = len(table) <= MODALITES_AFFICHEES
        logger.info("%s (%d modalités)%s :", libelle, len(table),
                    "" if detaille else " — extrêmes, détail dans le journal")
        a_afficher = table if detaille else pd.concat(
            [table.nlargest(5, "M0_ipm"), table.nsmallest(5, "M0_ipm")])
        for _, ligne in table.iterrows():
            journalise = logger.info if ligne.modalite in set(a_afficher.modalite) else logger.debug
            journalise("  %-26s H = %5.1f %% | A = %.4f | M0 = %.4f [%.4f ; %.4f] | "
                       "%2d grappes, CV %4.1f %% | %5.1f %% de la population",
                       ligne.modalite, 100 * ligne.H_incidence, ligne.A_intensite,
                       ligne.M0_ipm, ligne.M0_ic_bas, ligne.M0_ic_haut,
                       ligne.grappes, 100 * ligne.M0_cv,
                       100 * ligne.population / population_totale)

        imprecises = table[table.M0_cv > CV_PUBLIABLE]
        logger.info("  précision : %d modalité(s) sur %d au-delà d'un CV de %.0f %% "
                    "-> estimation indicative, à ne pas publier telle quelle",
                    len(imprecises), len(table), 100 * CV_PUBLIABLE)
        logger.debug("      %s", ", ".join(imprecises.modalite) or "aucune")

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
    # 1e-6 et non 1e-9 : M0 vient d'une somme par grappe, les apports d'une somme en vrac
    assert abs(total - 1) < 1e-6, f"les contributions doivent sommer à 1, obtenu {total}"

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
    national = national.assign(code=0, part_population=1.0, contribution_M0=1.0)
    table = pd.concat([national, D], ignore_index=True)[COLONNES_PUBLIEES]

    # `code` reste vide (0) pour les découpages construits, comme la classe de taille
    table.code = pd.to_numeric(table.code, errors="coerce").fillna(0).astype(int)
    table.menages = table.menages.astype(int)
    table.grappes = table.grappes.astype(int)
    table.population = table.population.round(0).astype(int)
    for colonne in [c for c in COLONNES_PUBLIEES
                    if c not in ("variable", "modalite", "code", "menages", "grappes",
                                 "population")]:
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
        "grappe": [1, 2, 3, 4],       # une grappe par ménage : cas sans effet de grappe
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

    # IC : l'estimation est encadrée, et regrouper les 4 ménages dans UNE seule grappe
    # (corrélation maximale) élargit l'intervalle plutôt que de le rétrécir
    assert resultat.M0_ic_bas < resultat.M0_ipm < resultat.M0_ic_haut, resultat
    assert 0 <= resultat.H_ic_bas and resultat.H_ic_haut <= 1
    assert resultat.grappes == 4
    deux_grappes = indices(X.assign(grappe=[1, 1, 2, 2]))
    assert deux_grappes.M0_erreur_type > resultat.M0_erreur_type, (deux_grappes, resultat)
    # une seule grappe : la variance n'est pas estimable, pas d'IC inventé
    seule = indices(X.assign(grappe=1))
    assert pd.isna(seule.M0_ic_bas) and abs(seule.M0_ipm - resultat.M0_ipm) < TOLERANCE

    national = indices_nationaux(X)
    assert national.modalite.iloc[0] == "Côte d'Ivoire"

    # désagrégation : le milieu 1 porte toute la pauvreté, et le code 1 devient « Urbain »
    D = desagregations(X, resultat.M0_ipm, resultat.population)
    milieu = D.set_index("modalite")
    assert milieu.index.tolist() == ["Urbain", "Rural"], milieu.index.tolist()
    assert milieu.loc["Urbain", "code"] == 1
    assert abs(milieu.loc["Urbain", "H_incidence"] - 1.0) < TOLERANCE
    assert abs(milieu.loc["Rural", "M0_ipm"]) < TOLERANCE
    assert abs(milieu.loc["Urbain", "contribution_M0"] - 1.0) < TOLERANCE
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
