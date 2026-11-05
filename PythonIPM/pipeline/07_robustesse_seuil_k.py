"""Étape 07 — robustesse de l'IPM au seuil de pauvreté k : effet sur le niveau et sur le classement.

Entrées  : matrice_situationnelle_<suffixe>.dta (g0 de l'étape 02) et vecteur_w_<suffixe>.csv
           (poids des indicateurs de l'IPM, étape 03).
Sorties  : - sorties/png/robustesse_k_<suffixe>_*.png   les trois figures
           - sorties/csv|dta/robustesse_k_*_<suffixe>   les tables chiffrées
           - sorties/docx/robustesse_seuil_k_<suffixe>.docx   le rapport Word

Pourquoi cette étape
--------------------
Le seuil k (part de privations pondérées à partir de laquelle un ménage est pauvre) est une
convention : aucune valeur n'est « juste ». La question utile n'est donc pas de défendre le
niveau de l'indice, mais de savoir si les CONCLUSIONS (quelles zones sont les plus pauvres,
où cibler) changent quand k change. Le rapport de l'IPM du Mali (INSTAT, 2023) répond ainsi : le
niveau bouge avec k, le classement des régions reste stable. La même démarche est reprise ici.

Ce que le script calcule
------------------------
1. L'effet de k sur H, A et M0 au niveau national, avec intervalles de confiance (courbe).
2. La stabilité du classement des zones (direction régionale, région) quand k varie :
   corrélation de rang de Spearman et tau-b de Kendall contre la valeur de référence.
3. Les comparaisons par paires de zones, avec erreurs standard, comme le tableau 12 du rapport
   du Mali : une comparaison est robuste si l'ordre établi à k de référence est préservé.
4. La dominance : une zone domine une autre si son incidence H est au moins aussi élevée pour
   TOUT seuil k ; son classement ne dépend alors pas de k.

Usage (source ENEM ; --su3 pour l'IPM calculé avec le chômage SU3) :
    IPM_SOURCE=enem python 07_robustesse_seuil_k.py
    IPM_SOURCE=enem python 07_robustesse_seuil_k.py --su3
    python 07_robustesse_seuil_k.py --check
Options : --sans-word (tables et figures seulement).
"""
import importlib.util
import logging
import pickle
import sys
import time
from datetime import date
from pathlib import Path

import numpy as np
import pandas as pd
from scipy import stats

from orchestrateur import (CLE, HORS_IPM_NATIONAL, K_PAUVRETE, LIBELLE_K, LOGS, SORTIES, SORTIES_CSV, SORTIES_DTA, SOURCE,
                           SUFFIXE, configurer_logs, exporter_table, nom)

JOURNAL = LOGS / f"07_robustesse_seuil_k_{SOURCE}.log"
DOSSIER_PNG = SORTIES / "png"
DOSSIER_DOCX = SORTIES / "docx"
logger = logging.getLogger("ipm.robustesse_k")

K_REF = K_PAUVRETE      # seuil de l'IPM calculé : 1/3 par défaut, 40 % avec --k40 (orchestrateur)
# les autres seuils testés : 1/3 et 40 % y figurent toujours, le seuil de référence en est exclu
K_ALTERNATIFS = sorted({0.20, 0.25, 1 / 3, 0.40, 0.50, 0.60} - {K_REF})
GRILLE = np.unique(np.append(np.round(np.arange(0.05, 1.0001, 0.05), 4), K_REF))
# Découpage d'analyse : les 33 régions (230 à 392 ménages chacune dans l'ENEM 2025). Les 14 directions
# régionales, plus précises (492 à 973 ménages) mais moins fines, s'ajoutent avec
# ("direction_regionale", "Direction régionale", "directions régionales").
DOMAINES_PAR_SOURCE = {
    "ehcvm": [("region", "Région", "régions")],
    "rgph": [("region", "Région", "régions"), ("sous_prefecture", "Sous-préfecture", "sous-préfectures")],
    "enem": [("region", "Région", "régions")],
}
DOMAINES = DOMAINES_PAR_SOURCE[SOURCE]
# Le RGPH est un recensement : il n'y a pas d'erreur d'échantillonnage. Les comparaisons par paires avec
# erreurs standard n'ont donc pas de sens et ne sont pas faites ; aucune zone n'est écartée faute de grappes.
RECENSEMENT = SOURCE == "rgph"
MIN_GRAPPES = 1 if RECENSEMENT else 10   # enquête : en dessous de 10 grappes, l'écart-type d'une zone n'est pas fiable
SEUIL_Z = 1.96          # test bilatéral à 5 % pour comparer deux zones
SEUIL_STABLE = 0.8      # tau de Kendall à partir duquel le classement est dit stable
TOLERANCE = 1e-9
MOIS = ["janvier", "février", "mars", "avril", "mai", "juin", "juillet", "août", "septembre",
        "octobre", "novembre", "décembre"]


def _charger_etape(fichier, nom_module):
    """Les étapes commencent par un chiffre : elles ne s'importent pas avec `import`."""
    spec = importlib.util.spec_from_file_location(nom_module, Path(__file__).resolve().parent / fichier)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


m05 = _charger_etape("05_indices_ipm.py", "etape05")


# --------------------------------------------------------------------------- #
# 1. calculs
# --------------------------------------------------------------------------- #
def charger():
    """Matrice g0 et poids des indicateurs de l'IPM national : score, poids de population, grappes."""
    chemin_g0 = SORTIES_DTA / f"{nom('matrice_situationnelle')}.dta"
    chemin_z = SORTIES_CSV / f"{nom('vecteur_z')}.csv"
    for chemin in (chemin_g0, chemin_z):
        assert chemin.exists(), f"{chemin.name} absent : lancer d'abord le pipeline (source {SOURCE})"
    X = pd.read_stata(chemin_g0).set_index(CLE)
    # Poids des indicateurs : ceux de l'étape 05. ENEM : l'IPM lui-même (BIT ou SU3 selon --bit / --su3).
    # EHCVM et RGPH : l'IPM national (chômage BIT), ou, avec --su3, la variante où le SU3 remplace le BIT.
    if SOURCE != "enem" and "--su3" in sys.argv:
        exclusions = m05.VARIANTES_EMPLOI["--su3"][1][3]
    else:
        exclusions = HORS_IPM_NATIONAL
    table_w = m05.vecteur_w(None, None, exclusions, chemin_z=chemin_z)
    w = table_w.set_index("colonne").poids_indicateur
    score = (X[list(w.index)] * w).sum(axis=1)
    n = X.taille_menage * X.ponderation_menage
    grappes = pd.Series(np.asarray(m05.grappes_de(X)), index=X.index)
    dimensions = table_w.dimension.nunique()
    logger.info("%d ménages, %d indicateurs, %d dimensions, %d grappes", len(X), len(w), dimensions,
                grappes.nunique())
    return X, score, n, grappes, dimensions


def estimer(score, n, grappes, k):
    """H, A et M0 au seuil k, avec intervalles de confiance (variance par grappe, comme l'étape 05)."""
    pauvre = (score >= k - TOLERANCE).astype(float)
    sc = score * pauvre
    un = pd.Series(1.0, index=score.index)
    H = m05.ratio_et_ic(pauvre, un, n, grappes)
    A = m05.ratio_et_ic(sc, pauvre, n, grappes)
    M = m05.ratio_et_ic(sc, un, n, grappes)
    return {"k": k, "H": H[0], "H_bas": H[1], "H_haut": H[2], "A": A[0], "A_bas": A[1],
            "A_haut": A[2], "M0": M[0], "M0_bas": M[1], "M0_haut": M[2]}


def courbe_nationale(score, n, grappes):
    ks = np.unique(np.append(GRILLE, K_ALTERNATIFS))
    c = pd.DataFrame([estimer(score, n, grappes, k) for k in ks])
    # l'intensité n'est pas définie quand plus personne n'est pauvre (H = 0) : elle n'est pas tracée
    sans_pauvre = c.H <= 0
    c.loc[sans_pauvre, ["A", "A_bas", "A_haut"]] = np.nan
    return c


def par_zone(X, score, n, grappes, colonne, k):
    """M0, écart-type et H de chaque zone au seuil k ; les zones à moins de MIN_GRAPPES grappes sont écartées."""
    pauvre = (score >= k - TOLERANCE).astype(float)
    d = pd.DataFrame({"zone": X[colonne].values, "n": n.values, "p": pauvre.values,
                      "sc": (score * pauvre).values, "gr": grappes.values})
    lignes = []
    for zone, g in d.groupby("zone"):
        g = g.reset_index(drop=True)
        if g.gr.nunique() < MIN_GRAPPES:
            continue
        R, _, _, se = m05.ratio_et_ic(g.sc, pd.Series(1.0, index=g.index), g.n, g.gr)
        lignes.append((zone, R, 0.0 if np.isnan(se) else se, np.average(g.p, weights=g.n), len(g)))
    return pd.DataFrame(lignes, columns=["zone", "M0", "se", "H", "menages"]).set_index("zone")


def paires_discordantes(a, b):
    """Nombre de paires de zones dont l'ordre s'inverse entre deux séries de valeurs."""
    v, w = np.asarray(a, float), np.asarray(b, float)
    di = v[:, None] - v[None, :]
    dj = w[:, None] - w[None, :]
    haut = np.triu(np.ones_like(di, dtype=bool), 1)
    return int(((di * dj < 0) & haut).sum()), int(haut.sum())


def correlations(ref, alt):
    """Spearman et Kendall (tau-b) entre le M0 des zones à k de référence et à un autre k."""
    a, b = ref.align(alt, join="inner")
    if b.nunique() < 2:
        return {"spearman": np.nan, "p_spearman": np.nan, "kendall": np.nan, "p_kendall": np.nan,
                "discordantes": np.nan, "paires": len(a) * (len(a) - 1) // 2}
    rho, p_rho = stats.spearmanr(a, b)
    tau, p_tau = stats.kendalltau(a, b)
    disc, paires = paires_discordantes(a, b)
    return {"spearman": rho, "p_spearman": p_rho, "kendall": tau, "p_kendall": p_tau,
            "discordantes": disc, "paires": paires}


def statuts_paires(m0, se):
    """+1 si la zone i est significativement plus pauvre que j, -1 si l'inverse, 0 si indéterminé."""
    zones = list(m0.index)
    sortie = {}
    for i in range(len(zones)):
        for j in range(i + 1, len(zones)):
            ecart = m0.iloc[i] - m0.iloc[j]
            s = np.hypot(se.iloc[i], se.iloc[j])
            if s == 0:
                statut = int(np.sign(ecart))
            else:
                z = ecart / s
                statut = 1 if z > SEUIL_Z else -1 if z < -SEUIL_Z else 0
            sortie[(zones[i], zones[j])] = statut
    return pd.Series(sortie)


def robustesse_paires(ref, alt):
    """Tableau 12 du rapport du Mali : robustesse des comparaisons par paire à un autre k."""
    significatives = ref != 0
    return {"paires": len(ref), "significatives": int(significatives.sum()),
            "part_significatives": float(significatives.mean()),
            "robustes_toutes": float((alt == ref).mean()),
            "robustes_significatives": int((alt[significatives] == ref[significatives]).sum()),
            "ratio_robustesse": float((alt[significatives] == ref[significatives]).mean())
            if significatives.any() else np.nan}


def dominance(H_grille):
    """Paires de zones où l'une a une incidence H au moins égale à l'autre pour TOUT k."""
    zones = list(H_grille.index)
    total, dominees = 0, 0
    for i in range(len(zones)):
        for j in range(i + 1, len(zones)):
            total += 1
            a, b = H_grille.iloc[i].values, H_grille.iloc[j].values
            if (a >= b - 1e-12).all() or (b >= a - 1e-12).all():
                dominees += 1
    return {"paires": total, "avec_dominance": dominees,
            "part": dominees / total if total else np.nan}


def analyser_domaine(X, score, n, grappes, colonne):
    ks = np.unique(np.append(GRILLE, K_ALTERNATIFS))
    ref = par_zone(X, score, n, grappes, colonne, K_REF)
    ecartees = X[colonne].nunique() - len(ref)
    par_k = {k: par_zone(X, score, n, grappes, colonne, k).reindex(ref.index) for k in ks}
    corr = pd.DataFrame([{"k": k, **correlations(ref.M0, par_k[k].M0)} for k in ks])
    if RECENSEMENT:
        paires = None
    else:
        st_ref = statuts_paires(ref.M0, ref.se)
        paires = pd.DataFrame([{"k": k, **robustesse_paires(
            st_ref, statuts_paires(par_k[k].M0, par_k[k].se.fillna(0)))} for k in K_ALTERNATIFS])
    extremes = pd.DataFrame([{"k": k, "plus_pauvre": par_k[k].M0.idxmax(),
                              "moins_pauvre": par_k[k].M0.idxmin()} for k in ks])
    H_grille = pd.DataFrame({k: par_k[k].H for k in GRILLE})
    return {"ref": ref, "par_k": par_k, "corr": corr, "paires": paires, "extremes": extremes,
            "H_grille": H_grille, "dominance": dominance(H_grille), "ecartees": ecartees}


def etiquettes(colonne, zones):
    """Libellés lisibles des zones (value labels de la source ; les chaînes restent telles quelles)."""
    table = m05.dico.modalites(colonne)
    out = {}
    for z in zones:
        libelle = table.get(z, z) if table else z
        out[z] = str(libelle).strip().title() if isinstance(libelle, str) else f"code {libelle}"
    return out


def analyser(donnees=None):
    X, score, n, grappes, dimensions = donnees or charger()
    res = {"dimensions": dimensions, "n_menages": len(X), "population": float(n.sum()),
           "courbe": courbe_nationale(score, n, grappes), "domaines": {}}
    for colonne, libelle, pluriel in DOMAINES:
        if colonne not in X.columns or X[colonne].nunique() < 5:
            logger.info("domaine %s ignoré (absent ou moins de 5 zones)", colonne)
            continue
        d = analyser_domaine(X, score, n, grappes, colonne)
        d["libelle"] = libelle
        d["pluriel"] = pluriel
        d["etiquettes"] = etiquettes(colonne, d["ref"].index)
        res["domaines"][colonne] = d
        c = d["corr"].set_index("k")
        logger.info("%s : %d zones (%d écartées) | Kendall à k=%.2f : %.3f ; à k=%.2f : %.3f | "
                    "paires avec dominance : %s", libelle, len(d["ref"]), d["ecartees"], 0.25,
                    c.kendall.get(0.25, np.nan), 0.5, c.kendall.get(0.5, np.nan),
                    f"{d['dominance']['avec_dominance']}/{d['dominance']['paires']}")
    return res


# --------------------------------------------------------------------------- #
# 2. figures (noir et gris : lisibles à l'impression, comme la charte du rapport)
# --------------------------------------------------------------------------- #
def _style():
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    plt.rcParams.update({"font.size": 8, "axes.spines.top": False, "axes.spines.right": False,
                         "axes.grid": True, "grid.color": "#dddddd", "grid.linewidth": 0.5,
                         "figure.dpi": 100, "savefig.dpi": 200})
    return plt


def _axe_k(ax):
    from matplotlib.ticker import FuncFormatter
    ax.xaxis.set_major_formatter(FuncFormatter(lambda v, _: f"{100 * v:.0f} %"))
    ax.axvline(K_REF, color="black", linestyle=":", linewidth=0.9)
    ax.set_xlabel("Seuil de pauvreté k")


def figure_nationale(res, chemin):
    plt = _style()
    c = res["courbe"]
    fig, axes = plt.subplots(1, 3, figsize=(7.6, 2.5))
    for ax, (cle, titre, pourcent) in zip(axes, [("H", "Incidence H", True), ("A", "Intensité A", False),
                                                  ("M0", "Indice M0", False)]):
        mult = 100 if pourcent else 1
        ax.fill_between(c.k, mult * c[cle + "_bas"], mult * c[cle + "_haut"], color="#bbbbbb", alpha=0.6,
                        linewidth=0)
        ax.plot(c.k, mult * c[cle], color="black", marker="o", markersize=2.5, linewidth=1)
        ax.set_title(titre, fontsize=9)
        ax.set_ylabel("%" if pourcent else "valeur")
        _axe_k(ax)
    fig.tight_layout()
    fig.savefig(chemin)
    plt.close(fig)


def figure_zones(res, chemin):
    plt = _style()
    doms = list(res["domaines"].items())
    fig, axes = plt.subplots(1, len(doms), figsize=(7.6, 3.0), squeeze=False)
    for ax, (colonne, d) in zip(axes[0], doms):
        H = d["H_grille"] * 100
        haut, bas = d["ref"].M0.idxmax(), d["ref"].M0.idxmin()
        for zone, ligne in H.iterrows():
            ax.plot(H.columns, ligne.values, color="#aaaaaa", linewidth=0.7)
        for zone, style in ((haut, "-"), (bas, "--")):
            ax.plot(H.columns, H.loc[zone].values, color="black", linewidth=1.6, linestyle=style,
                    label=d["etiquettes"][zone])
        ax.set_title(f"Incidence H par {d['libelle'].lower()}", fontsize=9)
        ax.set_ylabel("H (%)")
        ax.legend(fontsize=7, frameon=False, loc="upper right")
        _axe_k(ax)
    fig.tight_layout()
    fig.savefig(chemin)
    plt.close(fig)


def figure_correlations(res, chemin):
    plt = _style()
    doms = list(res["domaines"].items())
    # au-delà du dernier seuil où H atteint 1 % de la population, presque plus personne n'est pauvre :
    # les corrélations de rang n'ont plus de sens et ne sont pas tracées
    kmax = res["courbe"][res["courbe"].H >= 0.01].k.max()
    fig, axes = plt.subplots(1, len(doms), figsize=(7.6, 2.8), squeeze=False)
    for ax, (colonne, d) in zip(axes[0], doms):
        c = d["corr"][d["corr"].k <= kmax]
        ax.plot(c.k, c.spearman, color="black", marker="o", markersize=3, linewidth=1, label="Spearman")
        ax.plot(c.k, c.kendall, color="black", marker="s", markersize=3, linewidth=1, linestyle="--",
                label="Kendall")
        ax.axhline(SEUIL_STABLE, color="#888888", linewidth=0.8)
        ax.text(0.99, SEUIL_STABLE + 0.012, "seuil de stabilité 0,8", ha="right", fontsize=6.5, color="#555555",
                transform=ax.get_yaxis_transform())
        ax.set_ylim(min(0.4, np.nanmin(c[["spearman", "kendall"]].values) - 0.05), 1.02)
        ax.set_title(f"Stabilité du classement : {d['libelle'].lower()}", fontsize=9)
        ax.set_ylabel(f"Corrélation avec le classement à k = {LIBELLE_K}")
        ax.legend(fontsize=7, frameon=False, loc="lower left")
        _axe_k(ax)
    fig.tight_layout()
    fig.savefig(chemin)
    plt.close(fig)


# --------------------------------------------------------------------------- #
# 3. exports chiffrés
# --------------------------------------------------------------------------- #
def exporter_tables(res):
    exporter_table(res["courbe"], nom("robustesse_k_courbe"), logger, index=False)
    corr = pd.concat([d["corr"].assign(domaine=c) for c, d in res["domaines"].items()])
    exporter_table(corr, nom("robustesse_k_correlations"), logger, index=False)
    paires = [d["paires"].assign(domaine=c) for c, d in res["domaines"].items() if d["paires"] is not None]
    if paires:
        exporter_table(pd.concat(paires), nom("robustesse_k_paires"), logger, index=False)


# --------------------------------------------------------------------------- #
# 4. rapport Word
# --------------------------------------------------------------------------- #
def _p(x, d=1):
    return f"{100 * x:.{d}f} %".replace(".", ",")


def _n(x, d=3):
    return "sans objet" if pd.isna(x) else f"{x:.{d}f}".replace(".", ",")


def _ic(v, lo, hi, pourcent=False, d=3):
    if pourcent:
        return f"{_p(v)} ({100 * lo:.1f} ; {100 * hi:.1f})".replace(".", ",")
    return f"{_n(v, d)} ({_n(lo, d)} ; {_n(hi, d)})"


def _lire(valeur):
    """Grille de lecture adoptée ici (convention de travail, non normative)."""
    if pd.isna(valeur):
        return "sans objet"
    return ("très stable" if valeur >= 0.9 else "stable" if valeur >= SEUIL_STABLE
            else "modérément stable" if valeur >= 0.6 else "fragile")


def _plage_stable(c):
    """Plus grande plage de k testés contigus autour de K_REF où le Kendall reste au-dessus du seuil."""
    ks = [k for k in c.k if c.set_index("k").kendall.get(k, np.nan) >= SEUIL_STABLE]
    bas = haut = K_REF
    grille = list(c.k)
    i = grille.index(K_REF)
    j = i
    while j > 0 and grille[j - 1] in ks:
        j -= 1
    m = i
    while m < len(grille) - 1 and grille[m + 1] in ks:
        m += 1
    return grille[j], grille[m]


def exemple_detaille(d, k_alt):
    """Le classement des zones à k de référence et à k_alt, avec écarts de rang, pour expliquer les tests."""
    ref = d["ref"].M0
    alt = d["par_k"][k_alt].M0
    r1 = ref.rank(ascending=False, method="average")
    r2 = alt.rank(ascending=False, method="average")
    t = pd.DataFrame({"zone": [d["etiquettes"][z] for z in ref.index], "M0_ref": ref.values, "rang_ref": r1.values,
                      "M0_alt": alt.values, "rang_alt": r2.values}).sort_values("rang_ref")
    t["ecart"] = t.rang_alt - t.rang_ref
    t["carre"] = t.ecart ** 2
    zones = list(ref.index)
    inversees = []
    for i in range(len(zones)):
        for j in range(i + 1, len(zones)):
            if (ref.iloc[i] - ref.iloc[j]) * (alt.iloc[i] - alt.iloc[j]) < 0:
                inversees.append((d["etiquettes"][zones[i]], d["etiquettes"][zones[j]]))
    return t, inversees


def rapport_word(res, chemins):
    from docx.shared import Cm
    from docx_sobre import CENTRE, Note, mil

    n = Note(entete="Rapport technique. Robustesse de l'IPM au seuil de pauvreté k",
             pied="Projet IPM Côte d'Ivoire. Usage interne")
    # les textes écrits « k = 1/3 » désignent le seuil de référence : ils suivent l'option --k33 / --k40
    _run_brut = n._run
    n._run = lambda par, txt, **kw: _run_brut(par, txt.replace("k = 1/3", f"k = {LIBELLE_K}"), **kw)
    aujourdhui = date.today()
    etiquette = SUFFIXE
    n.bandeau("Projet IPM Côte d'Ivoire", f"Robustesse de l'indice au seuil k ({etiquette})")
    n.titre_note("RAPPORT TECHNIQUE", "Le seuil de pauvreté k change-t-il les conclusions de l'IPM ? "
                 "Effet de k sur le niveau et sur le classement, tests de Spearman et de Kendall")
    n.bloc_identification([
        ("Destinataire", "Équipe de calcul de l'IPM"),
        ("Objet", "Mesurer l'effet du seuil de pauvreté k sur l'indice et sur le classement des zones, et appliquer "
                  "les tests de corrélation de rang de Spearman et de Kendall à nos données"),
        ("Source", f"Sorties du pipeline PythonIPM, source {SOURCE}, version {etiquette} "
                   f"({mil(res['n_menages'])} ménages, {str(round(res['population'] / 1e6, 1)).replace('.', ',')} "
                   "millions de personnes représentées)"),
        ("Référence méthodologique", "Rapport de l'IPM du Mali (INSTAT, 2023), partie 5 sur la robustesse"),
        ("Date", f"{aujourdhui.day} {MOIS[aujourdhui.month - 1]} {aujourdhui.year}"),
    ])

    c = res["courbe"].set_index("k")
    ref = c.loc[K_REF]
    doms = res["domaines"]
    premier = next(iter(doms.values()))
    cp = premier["corr"]
    k_bas, k_haut = _plage_stable(cp)
    pc = premier["corr"].set_index("k")

    # ------------------------------------------------------------------ 1. synthèse
    n.titre("1. Synthèse", 1)
    n.p("La question traitée est la suivante : le choix du seuil de pauvreté k = 1/3 conditionne-t-il les conclusions que l'on "
        "tire de l'indice ? Un seuil est une convention, aucune valeur n'est juste en soi, et la seule vérification utile est de "
        "savoir si les conclusions résistent à son changement.")
    n.p([("Le niveau de l'indice dépend fortement de k. ", True),
         (f"L'incidence H passe de {_p(c.loc[0.2, 'H'], 0)} pour k = 20 % à {_p(c.loc[0.5, 'H'], 0)} pour k = 50 %, et M0 de "
          f"{_n(c.loc[0.2, 'M0'])} à {_n(c.loc[0.5, 'M0'])}. Aucun niveau ne se défend sans dire quel k a été retenu.", False)])
    n.p([("Le classement des zones est beaucoup plus stable. ", True),
         (f"Pour les {len(premier['ref'])} {premier['pluriel']}, le tau de Kendall avec le classement à k = 1/3 reste au-dessus de "
          f"{SEUIL_STABLE:.1f} de k = {_p(k_bas, 0)} à k = {_p(k_haut, 0)}".replace(".", ",") +
          f" (Spearman au moins égal à {_n(np.floor(pc.loc[k_bas:k_haut].spearman.min() * 100) / 100, 2)} sur cette plage). La zone la plus pauvre à k = 1/3 est "
          f"{premier['etiquettes'][premier['ref'].M0.idxmax()]} et la moins pauvre {premier['etiquettes'][premier['ref'].M0.idxmin()]}.", False)])
    n.p("Le choix de k modifie donc le niveau mais pas les priorités, à condition de ne publier que le classement "
        "et jamais le niveau seul. Le rapport explique d'abord ce que mesurent les tests de Spearman et de Kendall (partie 3), puis "
        "présente l'effet de k sur le niveau (partie 4), sur le classement (partie 5) et sur les comparaisons par paires (partie 6), avant "
        "la lecture d'ensemble (partie 7).")

    # ------------------------------------------------------------------ 2. le seuil k
    n.titre("2. Le seuil k et ce qu'on teste", 1)
    dims = res["dimensions"]
    n.p(f"Dans la méthode d'Alkire et Foster, chaque ménage reçoit un score de privation : la somme des poids des indicateurs dans lesquels "
        f"il est privé. Le seuil k est la part de privations pondérées à partir de laquelle le ménage est dit pauvre (score supérieur ou égal à k). "
        f"Avec {dims} dimensions équipondérées, k = 1/3 équivaut à environ {str(round(K_REF * dims, 2)).replace('.', ',')} dimensions de privation. "
        f"Le rapport de l'IPM du Mali retient k = 60 % avec cinq dimensions, soit trois dimensions sur cinq, et vérifie la robustesse de ses résultats "
        f"pour k = 50 % et k = 70 %.")
    n.p("Trois questions sont posées ici. Le niveau de l'indice change-t-il, et de combien ? L'ordre des zones, de la plus pauvre à la moins pauvre, "
        "change-t-il ? Et les différences entre zones restent-elles statistiquement établies ? Les valeurs testées vont de 20 % à 60 %, la "
        "courbe couvrant l'ensemble de 5 % à 100 %.")

    # ------------------------------------------------------------------ 3. comment lire Spearman et Kendall
    n.titre("3. Comment lire les tests de Spearman et de Kendall", 1)
    n.p("Ces deux tests répondent à la même question : si l'on classe les zones de la plus pauvre à la moins pauvre avec k = 1/3, puis avec un autre k, "
        "obtient-on le même ordre ? Ils comparent deux classements et donnent un nombre entre -1 et 1 : 1 signifie un classement identique, "
        "0 aucun lien entre les deux classements, -1 un classement exactement inversé.")
    n.p([("Le coefficient de Spearman ", True),
         ("compare les rangs eux-mêmes. Pour chaque zone, on calcule l'écart d (en nombre de places) entre son rang à k = 1/3 et son rang à l'autre k, "
          "puis la formule 1 - 6 × Σd² / (N × (N² - 1)), où N est le nombre de zones, donne le coefficient. Comme les écarts sont élevés au carré, "
          "une zone qui saute de plusieurs places pèse beaucoup plus que plusieurs zones qui bougent d'une place.", False)])
    n.p([("Le tau de Kendall ", True),
         ("compte les paires de zones dont l'ordre s'inverse. Pour N zones il y a N × (N - 1) / 2 paires ; chacune est soit concordante (même ordre "
          "dans les deux classements) soit discordante (ordre inversé). Le tau vaut (concordantes - discordantes) / paires, ce qui se lit directement : "
          "un tau de 0,82 signifie qu'environ 9 paires sur 100 changent d'ordre.", False)])
    n.p("Les deux sont utilisés ensemble parce qu'ils se complètent : Kendall dit combien de comparaisons changent, Spearman dit si certaines zones "
        "changent beaucoup. Le tableau suivant propose une grille de lecture, adoptée ici comme convention de travail et non comme norme.")
    n.tableau(["Valeur du tau de Kendall", "Lecture", "Ce que cela signifie en pratique"],
              [["0,9 et plus", "Très stable", "Moins de 5 % des paires changent d'ordre"],
               ["0,8 à 0,9", "Stable", "Entre 5 % et 10 % des paires changent d'ordre"],
               ["0,6 à 0,8", "Modérément stable", "Entre 10 % et 20 % des paires changent d'ordre"],
               ["Moins de 0,6", "Fragile", "Plus de 20 % des paires changent d'ordre : le classement dépend de k"]],
              widths=[4.0, 3.6, 8.6], fs=9, legende="Grille de lecture du tau de Kendall (sans égalités entre zones).")

    colonne_ex, d_ex = next(iter(doms.items()))
    k_ex = 0.5
    t, inversees = exemple_detaille(d_ex, k_ex)
    N = len(t)
    n.p([(f"Application à nos données. ", True),
         (f"Le tableau suivant détaille le calcul pour les {N} {d_ex['pluriel']}, en comparant le classement à k = 1/3 (rang 1 pour la plus pauvre) "
          f"et à k = {_p(k_ex, 0)}. La colonne d est l'écart de rang et la dernière colonne son carré.", False)])
    lignes = [[r.zone, _n(r.M0_ref), _n(r.rang_ref, 0), _n(r.M0_alt), _n(r.rang_alt, 0), ("0" if r.ecart == 0 else f"{r.ecart:+.0f}"), _n(r.carre, 0)]
              for r in t.itertuples()]
    n.tableau(["Zone", "M0 à k = 1/3", "Rang", f"M0 à k = {_p(k_ex, 0)}", "Rang", "d", "d²"], lignes,
              widths=[4.2, 2.2, 1.4, 2.6, 1.4, 1.2, 1.2], fs=8.5,
              legende=f"Classement des {d_ex['pluriel']} à k = 1/3 et à k = {_p(k_ex, 0)} ; d = rang à l'autre seuil moins rang à k = 1/3.")
    somme = float(t.carre.sum())
    rho_formule = 1 - 6 * somme / (N * (N ** 2 - 1))
    row = d_ex["corr"].set_index("k").loc[k_ex]
    n.p(f"La somme des carrés des écarts vaut {_n(somme, 0)}. La formule de Spearman donne 1 - 6 × {_n(somme, 0)} / ({N} × ({N}² - 1)) = {_n(rho_formule)}, "
        + (f"valeur identique à celle calculée par le logiciel ({_n(row.spearman)}). " if abs(rho_formule - row.spearman) < 5e-4 else
        f"valeur proche de celle calculée par le logiciel ({_n(row.spearman)}), l'écart tenant aux zones à égalité parfaite. ") + f"Pour Kendall, sur "
        f"{int(row.paires)} paires de zones, {int(row.discordantes)} changent d'ordre, d'où un tau de {_n(row.kendall)}.")
    if inversees:
        liste = "; ".join(f"{a} et {b}" for a, b in inversees[:10])
        n.p(f"Les paires qui s'inversent entre k = 1/3 et k = {_p(k_ex, 0)} sont : {liste}{' (liste tronquée)' if len(inversees) > 10 else ''}. "
            "Ce sont presque toujours des zones dont l'indice est proche : un changement de seuil suffit à les faire passer l'une devant l'autre.")
    else:
        n.p(f"Aucune paire ne s'inverse entre k = 1/3 et k = {_p(k_ex, 0)}.")

    # ------------------------------------------------------------------ 4. niveau national
    n.titre("4. Effet de k sur le niveau de l'indice", 1)
    n.p("Les valeurs de H, A et M0 sont calculées pour une grille de seuils de 5 % à 100 %, avec leurs intervalles de confiance à 95 % (variance par grappe). "
        "Le tableau donne les valeurs aux seuils testés, la figure la courbe complète.")
    lignes = []
    for k in sorted({0.2, 0.25, 1 / 3, 0.4, 0.5, 0.6} | {K_REF}):
        r = c.loc[k]
        etiquette_k = (f"{LIBELLE_K} (référence)" if abs(k - K_REF) < 1e-9
                       else "1/3" if abs(k - 1 / 3) < 1e-9 else _p(k, 0))
        lignes.append([etiquette_k, _n(k * dims, 2),
                       _ic(r.H, r.H_bas, r.H_haut, True), _ic(r.A, r.A_bas, r.A_haut), _ic(r.M0, r.M0_bas, r.M0_haut)])
    n.tableau(["Seuil k", "Équivalent en dimensions", "H, incidence (IC 95 %)", "A, intensité (IC 95 %)", "M0 (IC 95 %)"], lignes,
              widths=[2.6, 2.4, 4.0, 3.6, 3.6], fs=8.5, legende="Effet de k sur H, A et M0 au niveau national.")
    figure_n = [0]

    def figure(chemin, texte):
        figure_n[0] += 1
        n.doc.add_picture(str(chemin), width=Cm(16.0))
        n.doc.paragraphs[-1].alignment = CENTRE
        par = n.p([(f"Figure {figure_n[0]}. ", True)], size=9, before=3, space=11, align=CENTRE)
        n._run(par, texte, size=9, italic=True)

    figure(chemins["nationale"], "Effet du seuil k sur H, A et M0 (bande grise : intervalle de confiance à 95 %, trait pointillé : k = 1/3).")
    n.p(f"Lorsque k augmente, moins de ménages franchissent le seuil, donc H baisse, tandis que l'intensité A augmente car les ménages encore pauvres sont les plus privés. "
        f"M0, produit de H et de A, baisse. À k = 1/3, H = {_p(ref.H)} et M0 = {_n(ref.M0)}. Les intervalles de confiance sont étroits devant l'ampleur de la variation : "
        f"le niveau dépend de k bien plus qu'il ne dépend de l'échantillon.")

    # ------------------------------------------------------------------ 5. classement
    n.titre("5. Effet de k sur le classement des zones", 1)
    for colonne, d in doms.items():
        r0 = d["ref"]
        cv = r0.se / r0.M0
        n.p(f"Les {len(r0)} {d['pluriel']} comptent de {mil(r0.menages.min())} à {mil(r0.menages.max())} ménages (médiane {mil(r0.menages.median())}) ; "
            f"le coefficient de variation de M0 est de {_p(cv.median())} en médiane et de {_p(cv.max())} au maximum à k = 1/3. Les estimations par zone sont donc "
            "utilisables, mais moins précises que pour des ensembles plus larges.")
    n.p("Le tableau suivant donne, pour chaque domaine de zones, la corrélation entre le classement à k = 1/3 et le classement aux autres seuils testés.")
    for colonne, d in doms.items():
        n.titre(f"5.{list(doms).index(colonne) + 1} {d['libelle']}", 2)
        lignes = []
        for k in K_ALTERNATIFS:
            r = d["corr"].set_index("k").loc[k]
            ex = d["extremes"].set_index("k").loc[k]
            lignes.append([_p(k, 0), _n(r.spearman), _n(r.kendall), f"{int(r.discordantes)} sur {int(r.paires)}" if not pd.isna(r.discordantes) else "sans objet",
                           _lire(r.kendall), d["etiquettes"][ex.plus_pauvre]])
        n.tableau(["Seuil k", "Spearman", "Kendall", "Paires inversées", "Lecture", "Zone la plus pauvre"], lignes,
                  widths=[1.8, 2.2, 2.2, 3.0, 3.2, 3.8], fs=8.5,
                  legende=f"Stabilité du classement des {d['pluriel']} par rapport à k = 1/3 ({len(d['ref'])} zones"
                          f"{', ' + str(d['ecartees']) + ' écartées faute de grappes' if d['ecartees'] else ''}).")
        stables = [k for k in K_ALTERNATIFS if d["corr"].set_index("k").kendall.get(k, np.nan) >= SEUIL_STABLE]
        seuil = str(SEUIL_STABLE).replace(".", ",")
        if stables:
            texte = f"Le classement est stable (Kendall au moins égal à {seuil}) pour k = " + ", ".join(_p(k, 0) for k in stables) + "."
        else:
            texte = f"Aucun des seuils testés ne donne un classement stable (Kendall au moins égal à {seuil})."
        if len(stables) < len(K_ALTERNATIFS):
            texte += " Il se dégrade aux seuils les plus élevés, où peu de ménages restent pauvres et où les estimations par zone deviennent bruitées."
        n.p(texte)
        if any(str(v).startswith("code ") for v in d["etiquettes"].values()):
            n.p(f"Les libellés des {d['pluriel']} ne figurent pas dans les fichiers de la source : les zones sont désignées par leur code.")
    figure(chemins["correlations"], "Corrélation de Spearman (trait plein) et de Kendall (pointillé) entre le classement à k = 1/3 et le classement à chaque autre seuil.")
    figure(chemins["zones"], "Incidence H de chaque zone selon le seuil k (en noir, les zones extrêmes à k = 1/3).")
    n.p("La première figure montre où le classement commence à bouger : tant que la courbe reste au-dessus du seuil de stabilité, le choix de k n'a pas "
        "d'effet sur les priorités. La seconde montre que les courbes des zones se croisent peu : une zone très pauvre le reste quel que soit k.")

    # ------------------------------------------------------------------ 6. paires et dominance
    n.titre("6. Comparaisons par paires et dominance", 1)
    n.p("Les corrélations de rang ignorent l'incertitude d'échantillonnage : deux zones proches peuvent s'inverser sans que cela soit significatif. "
        "Comme dans le rapport du Mali, on compare donc chaque paire de zones avec les erreurs standard, au niveau de confiance de 95 %. À k = 1/3, une paire est dite "
        "significative si l'on peut établir quelle zone est la plus pauvre ; elle est robuste à un autre k si le même ordre significatif est retrouvé.")
    for colonne, d in doms.items():
        if d["paires"] is None:
            continue
        p0 = d["paires"].iloc[0]
        lignes = [[_p(r.k, 0), mil(r.paires), f"{int(r.significatives)} ({_p(r.part_significatives, 0)})", _p(r.robustes_toutes, 0),
                   f"{int(r.robustes_significatives)} sur {int(r.significatives)} ({_p(r.ratio_robustesse, 0)})"]
                  for r in d["paires"].itertuples()]
        n.tableau(["Seuil k", "Paires de zones", "Significatives à k = 1/3", "Même statut, toutes paires", "Robustes, paires significatives"], lignes,
                  widths=[1.8, 2.4, 3.6, 3.6, 4.8], fs=8.5,
                  legende=f"Robustesse des comparaisons par paire de {d['pluriel']} (méthode du tableau 12 du rapport du Mali).")
        dom = d["dominance"]
        n.p(f"Pour les {d['pluriel']}, {int(p0.significatives)} paires sur {int(p0.paires)} ({_p(p0.part_significatives, 0)}) sont significativement différentes à k = 1/3. "
            f"Parmi elles, {_p(d['paires'].ratio_robustesse.mean(), 0)} en moyenne restent établies dans le même sens aux autres seuils. La dominance, qui exige que l'incidence H d'une zone "
            f"soit au moins égale à celle d'une autre pour tout k, est vérifiée pour {dom['avec_dominance']} paires sur {dom['paires']} ({_p(dom['part'], 0)}) : "
            "pour ces paires, l'ordre ne dépend pas du tout du seuil.")

    # ------------------------------------------------------------------ 7. lecture
    n.titre("7. Lecture d'ensemble et recommandation", 1)
    n.p([("Ce que les données établissent. ", True),
         (f"Le niveau de l'indice dépend de k (H de {_p(c.loc[0.5, 'H'], 0)} à {_p(c.loc[0.2, 'H'], 0)} pour k de 50 % à 20 %). Le classement des zones, lui, est stable pour k allant de "
          f"{_p(k_bas, 0)} à {_p(k_haut, 0)}, et les comparaisons par paires significatives sont en grande partie préservées.", False)])
    n.p([("Ce que cela permet de dire. ", True),
         ("Le choix de k = 1/3 ne détermine pas où cibler l'action. "
          + ("Il est donc défendable de le conserver, ce qui aligne l'ENEM sur l'EHCVM et le RGPH. " if abs(K_REF - 1 / 3) < 1e-9 else
             "Ce seuil diffère toutefois du 1/3 retenu pour l'EHCVM et le RGPH : les niveaux ne sont pas comparables entre ces sources. ")
          + "La publication doit présenter le classement et ses intervalles de confiance, et signaler que le niveau n'est comparable ni à celui d'une autre source, ni à celui d'un autre pays.", False)])
    n.p([("Ce qui reste à décider. ", True),
         ("Faut-il publier un seuil unique ou plusieurs ? Il est proposé de publier k = 1/3 comme référence et de joindre en annexe la courbe et le tableau de stabilité de ce rapport.", False)])

    # ------------------------------------------------------------------ 8. limites
    n.titre("8. Limites", 1)
    n.puce([("Seul k varie. ", True), ("Les poids des dimensions et les définitions des indicateurs sont inchangés ; leur robustesse se teste séparément, comme dans la partie 5 du rapport du Mali.", False)])
    n.puce([("Les deux classements viennent des mêmes données. ", True), ("Le bruit d'échantillonnage est en partie commun aux deux, ce qui rend les corrélations un peu plus favorables que si les données étaient indépendantes.", False)])
    n.puce([("Des zones à effectifs limités. ", True), (f"Les estimations par zone reposent sur peu de ménages dans les petits domaines ; les zones à moins de {MIN_GRAPPES} grappes sont écartées.", False)])
    n.puce([("Une grille de lecture conventionnelle. ", True), ("Le seuil de 0,8 pour le tau de Kendall est un repère de travail, non une norme.", False)])
    n.puce([("Des scores discrets. ", True), ("Les poids des indicateurs ne prennent que quelques valeurs, si bien que de nombreux ménages ont le même score ; H varie donc par paliers lorsque k change.", False)])

    # ------------------------------------------------------------------ 9. note de méthode
    n.titre("9. Note de sources et de méthode", 1)
    n.p("Les chiffres sont recalculés par le script 07_robustesse_seuil_k.py à partir de la matrice de privation et des poids des indicateurs produits par le pipeline. "
        "H, A et M0 et leurs intervalles de confiance utilisent la fonction de l'étape 05 (variance du ratio linéarisé, grappe comme unité). "
        "Les tests de Spearman et de Kendall (tau-b) sont ceux de la bibliothèque scipy ; le nombre de paires inversées est compté directement. "
        "Les comparaisons par paires suivent le tableau 12 du rapport de l'IPM du Mali (INSTAT, 2023) : test bilatéral à 5 % sur la différence des M0, en supposant les zones indépendantes. "
        "La dominance est évaluée sur la grille de seuils de 5 % à 100 %.", size=9.5)

    DOSSIER_DOCX.mkdir(parents=True, exist_ok=True)
    sortie = DOSSIER_DOCX / f"robustesse_seuil_k_{SUFFIXE}.docx"
    n.save(str(sortie))
    return sortie


# --------------------------------------------------------------------------- #
# auto-contrôle
# --------------------------------------------------------------------------- #
def verifier():
    """Cas construits à la main, aux résultats connus."""
    configurer_logs(logger, niveau=logging.WARNING)
    # Spearman et Kendall : même classement -> 1, une paire échangée -> 0,8 et 0,667, inversé -> -1
    ref = pd.Series([0.4, 0.3, 0.2, 0.1], index=list("ABCD"))
    assert abs(correlations(ref, ref)["spearman"] - 1) < 1e-12
    echange = pd.Series([0.4, 0.2, 0.3, 0.1], index=list("ABCD"))
    r = correlations(ref, echange)
    assert abs(r["spearman"] - 0.8) < 1e-12 and abs(r["kendall"] - 2 / 3) < 1e-12, r
    assert (r["discordantes"], r["paires"]) == (1, 6)
    assert abs(correlations(ref, ref[::-1].set_axis(ref.index))["kendall"] + 1) < 1e-12
    # comparaisons par paires : écart net -> significatif ; écart noyé dans le bruit -> indéterminé
    m0 = pd.Series([0.30, 0.20], index=["a", "b"])
    assert statuts_paires(m0, pd.Series([0.01, 0.01], index=["a", "b"])).iloc[0] == 1
    assert statuts_paires(m0, pd.Series([0.10, 0.10], index=["a", "b"])).iloc[0] == 0
    rob = robustesse_paires(pd.Series([1, 0, -1]), pd.Series([1, 1, 0]))
    assert rob["significatives"] == 2 and rob["robustes_significatives"] == 1 and abs(rob["robustes_toutes"] - 1 / 3) < 1e-12
    # dominance : une courbe au-dessus de l'autre pour tout k domine, deux courbes qui se croisent non
    H = pd.DataFrame([[1, .5, 0], [1, .4, 0], [1, .3, .2]], index=["x", "y", "z"], columns=[.2, .4, .6])
    d = dominance(H)
    assert (d["paires"], d["avec_dominance"]) == (3, 1), d      # x domine y ; z croise x et y
    # H, A, M0 : 4 ménages de scores 0, 0,2, 0,5 et 1 au seuil 1/3 -> H = 0,5 ; M0 = 0,375 ; A = 0,75
    score = pd.Series([0.0, 0.2, 0.5, 1.0], index=list("abcd"))
    e = estimer(score, pd.Series(1.0, index=score.index), pd.Series([1, 1, 2, 2], index=score.index), K_REF)
    assert abs(e["H"] - 0.5) < 1e-12 and abs(e["M0"] - 0.375) < 1e-12 and abs(e["A"] - 0.75) < 1e-12, e
    print("auto-contrôle 07 : OK")


def main(avec_word=True):
    configurer_logs(logger, JOURNAL)
    debut = time.perf_counter()
    logger.info("=== étape 07 : robustesse au seuil k — source %s (%s) ===", SOURCE, SUFFIXE)
    res = analyser()
    if "--dump" in sys.argv:        # analyse seule : les résultats sont enregistrés pour le rapport commun
        chemin = sys.argv[sys.argv.index("--dump") + 1]
        res.update({"source": SOURCE, "suffixe": SUFFIXE, "k_ref": K_REF, "libelle_k": LIBELLE_K, "recensement": RECENSEMENT})
        with open(chemin, "wb") as f:
            pickle.dump(res, f)
        logger.info("résultats enregistrés : %s", chemin)
        logger.info("=== terminé en %.1f s ===", time.perf_counter() - debut)
        return res
    DOSSIER_PNG.mkdir(parents=True, exist_ok=True)
    chemins = {cle: DOSSIER_PNG / f"robustesse_k_{SUFFIXE}_{cle}.png" for cle in ("nationale", "zones", "correlations")}
    figure_nationale(res, chemins["nationale"])
    figure_zones(res, chemins["zones"])
    figure_correlations(res, chemins["correlations"])
    logger.info("figures : %s", ", ".join(p.name for p in chemins.values()))
    exporter_tables(res)
    if avec_word:
        logger.info("rapport Word : %s", rapport_word(res, chemins))
    logger.info("=== terminé en %.1f s ===", time.perf_counter() - debut)
    return res


if __name__ == "__main__":
    if "--check" in sys.argv:
        verifier()
    else:
        main(avec_word="--sans-word" not in sys.argv)
