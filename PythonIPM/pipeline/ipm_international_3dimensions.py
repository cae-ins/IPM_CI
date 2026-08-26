"""IPM international — 3 dimensions (Education, Santé, Conditions de vie).

Calcule l'IPM selon la méthode Alkire-Foster avec seulement les 3 dimensions
comparables au niveau international, conformément au tableau de référence ODD/ONU :

    Education        : 4 indicateurs (fréquentation, scolarité, alphabétisation, état civil)
    Santé            : 3 indicateurs (assurance maladie, insécurité alimentaire, renoncement)
    Conditions de vie : 7 indicateurs (électricité, logement, eau, cuisson, toilettes,
                                       biens d'équipement, promiscuité)

→ 14 indicateurs au total, contre 16 dans la version nationale (sans l'Emploi).

Les 3 dimensions sont équipondérées (1/3 chacune). Au sein de chaque dimension, les poids
se partagent à parts égales entre les indicateurs.

Entrée  : preconstruction_matrice_situationnelle.dta (étape 01 du pipeline national)
Sortie  : sorties/international/ — indices, contributions, classeur Excel

Usage :
    python ipm_international_3dimensions.py
    python ipm_international_3dimensions.py --check
"""
import logging
import sys
import time
from pathlib import Path

import numpy as np
import pandas as pd

# ---------------------------------------------------------------------------
# chemins — réutilise la préconstruction du pipeline national
# ---------------------------------------------------------------------------
RACINE = Path(__file__).resolve().parent.parent
SORTIES_NATIONALES = RACINE / "sorties" / "dta"
ENTREE = SORTIES_NATIONALES / "preconstruction_matrice_situationnelle.dta"
SORTIES_INTL = RACINE / "sorties" / "international"
SORTIES_INTL.mkdir(parents=True, exist_ok=True)
SORTIES_XLSX = RACINE / "sorties" / "xlsx"
SORTIES_XLSX.mkdir(parents=True, exist_ok=True)
LOGS = RACINE / "logs"
LOGS.mkdir(parents=True, exist_ok=True)

JOURNAL = LOGS / "ipm_international_3dimensions.log"
CLE = ["grappe", "menage", "vague"]
COLONNES_TECHNIQUES = ["id_menage", "ponderation_menage", "taille_menage",
                       "region", "departement", "sous_prefecture", "milieu", "sexe_cm"]

# Seuil de pauvreté Alkire-Foster
K_PAUVRETE = 1 / 3
K_VULNERABILITE = 0.2
K_SEVERE = 0.5
TOLERANCE = 1e-9

NIVEAU_CONFIANCE = 0.95
CV_PUBLIABLE = 0.20


def _t_ppf_0975(df):
    """Quantile 0.975 de la distribution t de Student (table + interpolation).

    C'est le seul quantile nécessaire pour les IC à 95 % (2-bilateraux).
    Précision : < 0.001 pour df >= 2.
    """
    # Table des valeurs exactes pour df courants
    _table = {
        1: 12.706, 2: 4.303, 3: 3.182, 4: 2.776, 5: 2.571,
        6: 2.447, 7: 2.365, 8: 2.306, 9: 2.262, 10: 2.228,
        12: 2.179, 15: 2.131, 20: 2.086, 25: 2.060, 30: 2.042,
        40: 2.021, 60: 2.000, 80: 1.990, 100: 1.984, 200: 1.972,
        500: 1.965, 1000: 1.962,
    }
    if df in _table:
        return _table[df]
    # Interpolation logarithmique entre les clés de la table
    keys = sorted(_table.keys())
    if df < keys[0]:
        return _table[keys[0]]
    if df > keys[-1]:
        return 1.960  # limite normale
    for i in range(len(keys) - 1):
        if keys[i] <= df <= keys[i + 1]:
            t1, t2 = _table[keys[i]], _table[keys[i + 1]]
            frac = (np.log(df) - np.log(keys[i])) / (np.log(keys[i + 1]) - np.log(keys[i]))
            return t1 + frac * (t2 - t1)
    return 1.960

BORNES_TAILLE = [0, 2, 4, 6, 9, 100]
LIBELLES_TAILLE = ["1-2 personnes", "3-4", "5-6", "7-9", "10 et plus"]

COLONNES_PUBLIEES = ["variable", "modalite", "code", "menages", "grappes", "population",
                     "part_population",
                     "H_incidence", "H_ic_bas", "H_ic_haut",
                     "A_intensite", "A_ic_bas", "A_ic_haut",
                     "M0_ipm", "M0_ic_bas", "M0_ic_haut", "M0_erreur_type", "M0_cv",
                     "contribution_M0", "vulnerables", "pauvrete_severe"]

DESAGREGATIONS = {
    "milieu": "Milieu de résidence",
    "region": "Région",
    "departement": "Département",
    "sous_prefecture": "Sous-préfecture ou commune",
    "sexe_cm": "Sexe du chef de ménage",
    "classe_taille": "Taille du ménage",
}

logger = logging.getLogger("ipm.international")


# ---------------------------------------------------------------------------
# 1. Seuils de privation (identiques au pipeline national, sans l'Emploi)
# ---------------------------------------------------------------------------
ECLAIRAGE_ADEQUAT = [1, 2, 6]
EAU_AMELIOREE = [1, 2, 3, 4, 7, 8, 9, 10, 11, 14]
SANITAIRE_AMELIORE = [1, 2, 3, 4, 5, 6, 7]
SOL_NATUREL = [3, 4, 5]
TOIT_PRECAIRE = [4, 5, 6, 7, 8, 9]
MUR_PRECAIRE = [5, 6, 7, 8]
COMBUSTIBLE_PROPRE = ["gaz", "electricite"]
ANNEES_ETUDES_MINIMUM = 10
MINUTES_ALLER_MAXIMUM = 15
BIENS_MAXIMUM = 1
SCORE_FIES_MINIMUM = 4
PERSONNES_PAR_PIECE_MAXIMUM = 3
ALPHABETISATION_AU_MOINS_UN_NON_ALPHABETISE = True

# ---------------------------------------------------------------------------
# 2. Définition des 14 indicateurs (3 dimensions)
# ---------------------------------------------------------------------------
from collections import namedtuple
Indicateur = namedtuple("Indicateur",
                        "dimension libelle colonne situation eligibilite regle")

NATIONALE = "proposition nationale"
PNUD = "application PNUD"
FAO = "échelle FIES (FAO, ODD 2.1.2)"

def _prive_alphabetisation(X):
    if ALPHABETISATION_AU_MOINS_UN_NON_ALPHABETISE:
        return (X.membres_17_49 - X.membres_17_49_alphabetises) >= 1
    return (X.membres_17_49 >= 1) & (X.membres_17_49_alphabetises == 0)


INDICATEURS = [
    # --- Education (4 indicateurs) ---
    Indicateur("Education", "Fréquentation scolaire", "frequentation_scolaire",
               ["enfants_6_16_non_scolarises"], "enfants_6_16",
               lambda X: X.enfants_6_16_non_scolarises >= 1),
    Indicateur("Education", "Année de scolarité", "annee_scolarite",
               ["annees_etudes_max"], "membres_17_95",
               lambda X: X.annees_etudes_max < ANNEES_ETUDES_MINIMUM),
    Indicateur("Education", "Alphabétisation", "alphabetisation",
               ["membres_17_49_alphabetises"], "membres_17_49",
               _prive_alphabetisation),
    Indicateur("Education", "Déclaration d'état civil", "etat_civil",
               ["enfants_5_15_sans_acte"], "enfants_5_15",
               lambda X: X.enfants_5_15_sans_acte >= 1),

    # --- Santé (3 indicateurs) ---
    Indicateur("Sante", "Assurance maladie", "assurance_maladie",
               ["membres_assures"], "taille_menage",
               lambda X: X.membres_assures == 0),
    Indicateur("Sante", "Insécurité alimentaire", "insecurite_alimentaire",
               ["score_fies"], None,
               lambda X: X.score_fies >= SCORE_FIES_MINIMUM),
    Indicateur("Sante", "Renoncement aux soins", "renoncement_soins",
               ["membres_renoncement_soins"], "membres_malades_30j",
               lambda X: X.membres_renoncement_soins >= 1),

    # --- Conditions de vie (7 indicateurs) ---
    Indicateur("Conditions de vie", "Electricité", "electricite",
               ["source_eclairage"], None,
               lambda X: ~X.source_eclairage.isin(ECLAIRAGE_ADEQUAT)),
    Indicateur("Conditions de vie", "Logement", "logement",
               ["materiau_toit", "materiau_mur", "materiau_sol"], None,
               lambda X: (X.materiau_sol.isin(SOL_NATUREL)
                          | X.materiau_toit.isin(TOIT_PRECAIRE)
                          | X.materiau_mur.isin(MUR_PRECAIRE))),
    Indicateur("Conditions de vie", "Eau potable", "eau_potable",
               ["source_eau_boisson_seche", "temps_aller_source_seche"], None,
               lambda X: (~X.source_eau_boisson_seche.isin(EAU_AMELIOREE)
                          | (X.temps_aller_source_seche > MINUTES_ALLER_MAXIMUM))),
    Indicateur("Conditions de vie", "Energie de cuisson", "energie_cuisson",
               ["combustible_principal"], None,
               lambda X: ~X.combustible_principal.isin(COMBUSTIBLE_PROPRE)),
    Indicateur("Conditions de vie", "Toilette", "toilette",
               ["type_sanitaire", "sanitaire_partage"], None,
               lambda X: (~X.type_sanitaire.isin(SANITAIRE_AMELIORE)
                          | (X.sanitaire_partage == 1))),
    Indicateur("Conditions de vie", "Biens d'équipement", "biens_equipement",
               ["nb_equipements", "possede_voiture"], None,
               lambda X: (X.nb_equipements <= BIENS_MAXIMUM) & (X.possede_voiture == 0)),
    Indicateur("Conditions de vie", "Promiscuité", "promiscuite",
               ["taille_menage", "nb_pieces"], None,
               lambda X: X.taille_menage / X.nb_pieces > PERSONNES_PAR_PIECE_MAXIMUM),
]

COLONNES_INDICATEURS = [i.colonne for i in INDICATEURS]


# ---------------------------------------------------------------------------
# 3. Chargement de la préconstruction
# ---------------------------------------------------------------------------
def charger_preconstruction():
    logger.info("--- 1. lecture de la préconstruction (étape 01) ---")
    P = pd.read_stata(ENTREE).set_index(CLE)
    logger.info("%s : %d ménages x %d colonnes", ENTREE.name, *P.shape)
    return P


# ---------------------------------------------------------------------------
# 4. Application des seuils z → matrice de privation g0
# ---------------------------------------------------------------------------
def calculer_indicateurs(P):
    logger.info("--- 2. matrice de privation g0 (14 indicateurs, 3 dimensions) ---")
    poids = P.ponderation_menage * P.taille_menage
    X = pd.DataFrame(index=P.index)

    for ind in INDICATEURS:
        manquantes = [c for c in ind.situation + ([ind.eligibilite] if ind.eligibilite else [])
                      if c not in P.columns]
        assert not manquantes, f"{ind.libelle} : colonnes absentes : {manquantes}"
        X[ind.colonne] = ind.regle(P).fillna(False).astype(int)
        logger.info("  %-22s %-22s privés : %s | pondéré : %.1f %%",
                    ind.libelle, ind.colonne,
                    part(int(X[ind.colonne].sum()), len(X)),
                    100 * (X[ind.colonne] * poids).sum() / poids.sum())

    presentes = [c for c in COLONNES_TECHNIQUES if c in P.columns]
    logger.info("variables conservées : %s", ", ".join(presentes))
    return X.join(P[presentes])


# ---------------------------------------------------------------------------
# 5. Vecteur w : 3 dimensions équipondérées
# ---------------------------------------------------------------------------
def calculer_poids(X):
    logger.info("--- 3. vecteur w des pondérations (3 dimensions) ---")
    dimensions = [i.dimension for i in INDICATEURS]
    dims_uniques = list(dict.fromkeys(dimensions))  # ordre préservé
    n_dims = len(dims_uniques)
    poids_dimension = 1 / n_dims

    w = pd.DataFrame({
        "dimension": [i.dimension for i in INDICATEURS],
        "indicateur": [i.libelle for i in INDICATEURS],
        "colonne": [i.colonne for i in INDICATEURS],
    })
    w["indicateurs_dans_la_dimension"] = w.groupby("dimension").colonne.transform("size")
    w["poids_dimension"] = poids_dimension
    w["poids_indicateur"] = poids_dimension / w.indicateurs_dans_la_dimension

    logger.info("%d dimensions équipondérées à %.4f", n_dims, poids_dimension)
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


# ---------------------------------------------------------------------------
# 6. Pondération et score cᵢ
# ---------------------------------------------------------------------------
def ponderer_et_score(g0, w):
    logger.info("--- 4. matrice pondérée et score cᵢ ---")
    poids = w.set_index("colonne").poids_indicateur
    ponderee = g0[poids.index].mul(poids, axis=1)
    ponderee.columns = [f"{c}_ponderee" for c in ponderee.columns]

    score = ponderee.sum(axis=1)
    assert score.between(-TOLERANCE, 1 + TOLERANCE).all(), "un score sort de [0, 1]"
    logger.info("score : moyenne %.4f, médiane %.4f, min %.4f, max %.4f",
                score.mean(), score.median(), score.min(), score.max())

    return ponderee, score


# ---------------------------------------------------------------------------
# 7. Statuts de pauvreté
# ---------------------------------------------------------------------------
def statuts_pauvrete(score, poids_population, nb_menages):
    logger.info("--- 5. statuts au seuil k = %.4f ---", K_PAUVRETE)
    pauvre = score >= K_PAUVRETE - TOLERANCE
    vulnerable = (score >= K_VULNERABILITE - TOLERANCE) & ~pauvre
    severe = score >= K_SEVERE - TOLERANCE

    for libelle, statut in [("pauvres (c >= 1/3)", pauvre),
                            ("vulnérables (0,2 <= c < 1/3)", vulnerable),
                            ("pauvreté sévère (c >= 0,5)", severe)]:
        logger.info("  %-30s %-16s | pondéré population : %.1f %%", libelle,
                    part(int(statut.sum()), nb_menages),
                    100 * (statut * poids_population).sum() / poids_population.sum())
    return pauvre, vulnerable, severe


# ---------------------------------------------------------------------------
# 8. Censure au seuil k
# ---------------------------------------------------------------------------
def censurer(ponderee, pauvre):
    logger.info("--- 6. matrice censurée ---")
    censuree = ponderee.mul(pauvre, axis=0)
    censuree.columns = [c.replace("_ponderee", "_censuree") for c in censuree.columns]
    return censuree


def score_censure(censuree, score, pauvre):
    sc = score.where(pauvre, 0.0)
    ecart = (censuree.sum(axis=1) - sc).abs().max()
    assert ecart < TOLERANCE, f"écart score censuré : {ecart}"
    return sc


# ---------------------------------------------------------------------------
# 9. Indices H, A, M0 avec IC (variance ultimate cluster)
# ---------------------------------------------------------------------------
def grappes_de(X):
    if "grappe" in (X.index.names or []):
        return X.index.get_level_values("grappe")
    return X.grappe


def ratio_et_ic(y, x, n, grappes, niveau=NIVEAU_CONFIANCE):
    denominateur = (n * x).sum()
    if denominateur <= 0:
        return 0.0, np.nan, np.nan, np.nan
    R = (n * y).sum() / denominateur
    u = (n * (y - R * x) / denominateur).groupby(grappes, observed=True).sum()
    nb_grappes = u.count()
    if nb_grappes < 2:
        return R, np.nan, np.nan, np.nan
    erreur_type = np.sqrt(nb_grappes / (nb_grappes - 1) * (u ** 2).sum())
    marge = _t_ppf_0975(nb_grappes - 1) * erreur_type
    return R, max(R - marge, 0.0), min(R + marge, 1.0), erreur_type


def calculer_indices(X):
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


# ---------------------------------------------------------------------------
# 10. Désagrégations
# ---------------------------------------------------------------------------
def modalites(colonne):
    """Libellés des modalités (copié depuis dictionnaire_ehcvm)."""
    MILIEU = {1: "Urbain", 2: "Rural"}
    SEXE = {1: "Homme", 2: "Femme"}
    if colonne == "milieu":
        return MILIEU
    if colonne == "sexe_cm":
        return SEXE
    # Régions, départements, sous-préfectures : lus depuis le .dta si besoin
    try:
        import dictionnaire_ehcvm as dico
        return dico.modalites(colonne)
    except Exception:
        return {}


def desagregations(X, M0_national, population_totale):
    logger.info("--- 8. désagrégations ---")
    X = X.copy()
    X["classe_taille"] = pd.cut(X.taille_menage, bins=BORNES_TAILLE, labels=LIBELLES_TAILLE)
    morceaux = []

    for colonne, libelle in DESAGREGATIONS.items():
        if colonne not in X.columns:
            logger.warning("désagrégation ignorée, colonne absente : %s", colonne)
            continue
        table = X.groupby(colonne, observed=True)[X.columns].apply(calculer_indices)
        table.insert(0, "variable", libelle)
        table.index.name = "modalite"
        table = table.reset_index()
        etiquettes = modalites(colonne)
        table["code"] = table.modalite
        table["modalite"] = (table.modalite.map(etiquettes) if etiquettes
                             else table.modalite).astype(str)
        morceaux.append(table)

        for _, ligne in table.iterrows():
            logger.info("  %-26s H = %5.1f %% | A = %.4f | M0 = %.4f [%.4f ; %.4f] | "
                        "%2d grappes, CV %4.1f %% | %5.1f %% de la pop",
                        ligne.modalite, 100 * ligne.H_incidence, ligne.A_intensite,
                        ligne.M0_ipm, ligne.M0_ic_bas, ligne.M0_ic_haut,
                        ligne.grappes, 100 * ligne.M0_cv,
                        100 * ligne.population / population_totale)

    D = pd.concat(morceaux, ignore_index=True)
    D["part_population"] = D.population / population_totale
    D["contribution_M0"] = D.M0_ipm * D.part_population / M0_national
    return D


# ---------------------------------------------------------------------------
# 11. Contributions des indicateurs
# ---------------------------------------------------------------------------
def contributions(X, M0, w):
    logger.info("--- 9. contributions des indicateurs à M0 ---")
    n = X.poids_population
    lignes = []
    for _, ind in w.iterrows():
        colonne = f"{ind.colonne}_censuree"
        assert colonne in X.columns, f"colonne absente : {colonne}"
        apport = (n * X[colonne]).sum() / n.sum()
        brut = (n * (X[colonne] > 0)).sum() / n.sum()
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
    assert abs(total - 1) < 1e-6, f"les contributions doivent sommer à 1, obtenu {total}"

    for _, ligne in C.iterrows():
        logger.info("  %-24s w = %.4f | privation censurée %5.1f %% | contribution %5.1f %%",
                    ligne.colonne, ligne.poids_w,
                    100 * ligne.taux_privation_censure, 100 * ligne.contribution_M0)
    logger.info("somme des contributions = %.6f", total)

    par_dimension = C.groupby("dimension").contribution_M0.sum().sort_values(ascending=False)
    logger.info("par dimension (poids nominal : 33,3 %% chacune) :")
    for dimension, contribution in par_dimension.items():
        logger.info("  %-18s %.1f %%", dimension, 100 * contribution)

    C["contribution_dimension"] = C.dimension.map(par_dimension)
    return C


# ---------------------------------------------------------------------------
# 12. Export
# ---------------------------------------------------------------------------
def exporter(table, C, w):
    logger.info("--- 10. export ---")

    # CSV indices
    chemin_csv = SORTIES_INTL / "indices_ipm_international_3dim.csv"
    table.to_csv(chemin_csv, index=False, encoding="utf8")
    logger.info("indices -> %s", chemin_csv)

    # CSV contributions
    chemin_contrib = SORTIES_INTL / "contributions_ipm_international_3dim.csv"
    C.to_csv(chemin_contrib, index=False, encoding="utf8")
    logger.info("contributions -> %s", chemin_contrib)

    # CSV poids
    chemin_w = SORTIES_INTL / "vecteur_w_international_3dim.csv"
    w.to_csv(chemin_w, index=False, encoding="utf8")
    logger.info("poids -> %s", chemin_w)

    # XLSX — une feuille par objet, ajoutée/remplacée dans ipm_international.xlsx
    try:
        import openpyxl  # noqa: F401
        chemin_xlsx = SORTIES_XLSX / "ipm_international.xlsx"
        feuilles = {"3dim_Ensemble": table[table.variable == "Ensemble"],
                    "3dim_Contributions": C,
                    "3dim_Poids_w": w}
        for libelle in DESAGREGATIONS.values():
            morceau = table[table.variable == libelle]
            if not morceau.empty:
                feuilles[f"3dim_{libelle}"[:31]] = morceau
        existe = chemin_xlsx.exists()
        options = ({"mode": "a", "if_sheet_exists": "replace"} if existe else {})
        with pd.ExcelWriter(chemin_xlsx, engine="openpyxl", **options) as classeur:
            for feuille, morceau in feuilles.items():
                morceau.to_excel(classeur, sheet_name=feuille, index=False,
                                 freeze_panes=(1, 2))
        logger.info("classeur -> %s (%d feuilles %s)", chemin_xlsx, len(feuilles),
                    "ajoutées/remplacées" if existe else "créées")
    except ImportError:
        logger.warning("openpyxl non installé — pas de classeur XLSX")


# ---------------------------------------------------------------------------
# Pipeline principal
# ---------------------------------------------------------------------------
def main():
    configurer_logs(logger, JOURNAL)
    debut = time.perf_counter()
    logger.info("=" * 78)
    logger.info("IPM INTERNATIONAL — 3 DIMENSIONS (Education, Santé, Conditions de vie)")
    logger.info("=" * 78)

    # Étape 1 : charger
    P = charger_preconstruction()

    # Étape 2 : matrice de privation g0
    g0 = calculer_indicateurs(P)
    assert g0.index.is_unique, "clé non unique"
    assert not g0[COLONNES_INDICATEURS].isna().any().any(), "manquants dans g0"
    assert g0[COLONNES_INDICATEURS].isin([0, 1]).all().all(), "g0 n'est pas binaire"

    # Étape 3 : poids
    w = calculer_poids(g0)

    # Étape 4 : pondération et score
    ponderee, score = ponderer_et_score(g0, w)

    # Étape 5 : statuts
    poids_population = g0.ponderation_menage * g0.taille_menage
    pauvre, vulnerable, severe = statuts_pauvrete(score, poids_population, len(g0))

    # Étape 6 : censure
    censuree = censurer(ponderee, pauvre)
    sc = score_censure(censuree, score, pauvre)

    # Étape 7 : assemblage
    logger.info("--- 7. assemblage ---")
    statuts = pd.DataFrame({
        "score": score,
        "score_censure": sc,
        "pauvre": pauvre.astype(int),
        "vulnerable": vulnerable.astype(int),
        "pauvrete_severe": severe.astype(int),
    })
    X = pd.concat([statuts, censuree,
                   g0[[c for c in COLONNES_TECHNIQUES if c in g0.columns]]], axis=1)
    X["poids_population"] = X.ponderation_menage * X.taille_menage
    logger.info("matrice complète : %d ménages x %d colonnes", *X.shape)

    # Étape 8 : indices nationaux
    logger.info("--- 8. indices nationaux ---")
    resultat = calculer_indices(X)
    M0 = resultat.M0_ipm

    logger.info("")
    logger.info("=" * 60)
    logger.info("RÉSULTATS — IPM INTERNATIONAL (3 DIMENSIONS)")
    logger.info("=" * 60)
    logger.info("  H  (incidence)  = %.4f   IC 95%% [%.4f ; %.4f]   soit %.1f %% de la population",
                resultat.H_incidence, resultat.H_ic_bas, resultat.H_ic_haut,
                100 * resultat.H_incidence)
    logger.info("  A  (intensité)  = %.4f   IC 95%% [%.4f ; %.4f]",
                resultat.A_intensite, resultat.A_ic_bas, resultat.A_ic_haut)
    logger.info("  M0 (IPM)        = %.4f   IC 95%% [%.4f ; %.4f]   = H x A",
                resultat.M0_ipm, resultat.M0_ic_bas, resultat.M0_ic_haut)
    logger.info("  erreur-type     = %.4f | CV = %.1f %%",
                resultat.M0_erreur_type, 100 * resultat.M0_cv)
    logger.info("  vulnérables     = %.1f %%   | pauvreté sévère = %.1f %%",
                100 * resultat.vulnerables, 100 * resultat.pauvrete_severe)
    logger.info("  population pauvre : %s personnes",
                part(int((X.poids_population * X.pauvre).sum()), 0))
    logger.info("=" * 60)

    national = resultat.to_frame().T
    national.insert(0, "variable", "Ensemble")
    national.insert(1, "modalite", "Côte d'Ivoire")
    national = national.reset_index(drop=True)
    national = national.assign(code=0, part_population=1.0, contribution_M0=1.0)

    # Étape 9 : désagrégations
    D = desagregations(X, M0, resultat.population)

    # Étape 10 : contributions
    C = contributions(X, M0, w)

    # Assemblage final
    table = pd.concat([national, D], ignore_index=True)[COLONNES_PUBLIEES]
    table.code = pd.to_numeric(table.code, errors="coerce").fillna(0).astype(int)
    table.menages = table.menages.astype(int)
    table.grappes = table.grappes.astype(int)
    table.population = table.population.round(0).astype(int)
    for colonne in [c for c in COLONNES_PUBLIEES
                    if c not in ("variable", "modalite", "code", "menages", "grappes",
                                 "population")]:
        table[colonne] = table[colonne].round(6)

    # Export
    exporter(table, C, w)

    logger.info("")
    logger.info("=== terminé en %.1f s ===", time.perf_counter() - debut)
    return table, C, w


def configurer_logs(logger, fichier=None, niveau=logging.INFO):
    logger.setLevel(logging.DEBUG)
    logger.handlers.clear()
    console = logging.StreamHandler(sys.stdout)
    console.setLevel(niveau)
    console.setFormatter(logging.Formatter("%(message)s"))
    logger.addHandler(console)
    if fichier:
        journal = logging.FileHandler(fichier, mode="w", encoding="utf8")
        journal.setLevel(logging.DEBUG)
        journal.setFormatter(logging.Formatter("%(asctime)s  %(levelname)-7s  %(message)s"))
        logger.addHandler(journal)
    return logger


def part(effectif, total):
    if not total:
        return f"{effectif:,}".replace(",", " ")
    return f"{effectif:,}".replace(",", " ") + f" ({effectif / total:.1%})"


# ---------------------------------------------------------------------------
# Auto-contrôle
# ---------------------------------------------------------------------------
def verifier():
    configurer_logs(logger, niveau=logging.WARNING)

    #  A : privé partout (14/14)  →  c = 1
    #  B : privé nulle part (0/14) →  c = 0
    #  C : privé en santé (3/14) + 1 condition de vie (1/21) → c = 3/9 + 1/21 = 0.381
    P = pd.DataFrame({
        "source_eclairage": [4, 1, 1],
        "materiau_toit": [4, 3, 3], "materiau_mur": [7, 1, 1], "materiau_sol": [3, 2, 2],
        "source_eau_boisson_seche": [13, 1, 1],
        "temps_aller_source_seche": [40.0, float("nan"), float("nan")],
        "combustible_principal": ["bois_ramasse", "gaz", "gaz"],
        "type_sanitaire": [11, 1, 1], "sanitaire_partage": [float("nan"), 2, 2],
        "nb_equipements": [1, 5, 5], "possede_voiture": [0, 1, 1],
        "enfants_6_16": [2, 2, 2], "enfants_6_16_non_scolarises": [1, 0, 0],
        "membres_17_95": [2, 2, 2], "annees_etudes_max": [3.0, 13.0, 13.0],
        "membres_17_49": [2, 2, 2], "membres_17_49_alphabetises": [0, 2, 2],
        "enfants_5_15": [1, 1, 1], "enfants_5_15_sans_acte": [1, 0, 0],
        "membres_assures": [0, 1, 1],
        "score_fies": [8.0, 0.0, 0.0],
        "membres_malades_30j": [2, 0, 0], "membres_renoncement_soins": [1, 0, 0],
        "nb_pieces": [1.0, 4.0, 4.0],
        "ponderation_menage": [1.0, 1.0, 1.0], "taille_menage": [4, 4, 4],
    }, index=["A", "B", "C"])

    X = calculer_indicateurs(P)
    assert X.loc["A", COLONNES_INDICATEURS].tolist() == [1] * 14, X.loc["A", COLONNES_INDICATEURS]
    assert X.loc["B", COLONNES_INDICATEURS].tolist() == [0] * 14, X.loc["B", COLONNES_INDICATEURS]

    w = calculer_poids(X)
    ponderee, score = ponderer_et_score(X, w)

    # A : c = 1.0, B : c = 0.0
    assert abs(score["A"] - 1.0) < TOLERANCE, score["A"]
    assert score["B"] == 0.0

    # Vérifier que les poids sont corrects pour 3 dimensions
    # Education : 4 indic. → 1/3 / 4 = 1/12 ≈ 0.0833
    # Santé : 3 indic. → 1/3 / 3 = 1/9 ≈ 0.1111
    # Conditions de vie : 7 indic. → 1/3 / 7 = 1/21 ≈ 0.0476
    poids_edu = w[w.dimension == "Education"].poids_indicateur.iloc[0]
    poids_sante = w[w.dimension == "Sante"].poids_indicateur.iloc[0]
    poids_cv = w[w.dimension == "Conditions de vie"].poids_indicateur.iloc[0]
    assert abs(poids_edu - 1/12) < TOLERANCE, poids_edu
    assert abs(poids_sante - 1/9) < TOLERANCE, poids_sante
    assert abs(poids_cv - 1/21) < TOLERANCE, poids_cv

    print("auto-contrôle ipm_international : OK")


if __name__ == "__main__":
    if "--check" in sys.argv:
        verifier()
    else:
        main()
