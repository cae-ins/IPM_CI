"""Étape 08 — rapport Word commun : l'IPM à k = 40 % (chômage SU3) de l'EHCVM, du RGPH et de l'ENEM.

Prérequis : le pipeline a été lancé pour chaque source avec k = 40 % et le chômage SU3, c'est-à-dire
    python orchestrateur.py --source ehcvm --su3 --k40
    python orchestrateur.py --source rgph  --su3 --k40
    python orchestrateur.py --source enem  --su3 --k40
(les classeurs `indices_ipm_su3_<source>_k40.xlsx` et `indices_ipm_ci_enem2025_su3_k40.xlsx` existent alors).

Ce que fait ce script
---------------------
1. lance l'étape 07 de chaque source en mode analyse (`--dump`) : effet de k, corrélations de rang de
   Spearman et de Kendall sur le classement des zones (régions ; sous-préfectures pour le RGPH),
   comparaisons par paires (enquêtes seulement : un recensement n'a pas d'erreur d'échantillonnage) ;
2. lit les classeurs Excel pour les dimensions, les indicateurs et les résultats ;
3. trace les figures et écrit sorties/docx/rapport_ipm_k40_su3.docx.

Usage :
    python 08_rapport_ipm_k40.py                 # réutilise les analyses déjà calculées
    python 08_rapport_ipm_k40.py --recalculer    # relance l'étape 07 pour les trois sources
"""
import os
import pickle
import subprocess
import sys
import time
from datetime import date
from pathlib import Path

import numpy as np
import pandas as pd

PIPELINE = Path(__file__).resolve().parent
RACINE = PIPELINE.parent
SORTIES = RACINE / "sorties"
DUMP = SORTIES / "robustesse_dump"
sys.path.insert(0, str(PIPELINE))

K_REF = 0.4
SEUIL_STABLE = 0.8
MOIS = ["janvier", "février", "mars", "avril", "mai", "juin", "juillet", "août", "septembre", "octobre",
        "novembre", "décembre"]
NOM_DIM = {"Education": "Éducation", "Sante": "Santé", "Emploi": "Emploi", "Conditions de vie": "Conditions de vie"}
ORDRE_DIM = ["Education", "Sante", "Emploi", "Conditions de vie"]
SOURCES = [
    {"cle": "ehcvm", "nom": "EHCVM 2021", "nature": "enquête auprès des ménages", "classeur": "indices_ipm_su3_ehcvm2021_k40",
     "recensement": False},
    {"cle": "rgph", "nom": "RGPH 2021", "nature": "recensement", "classeur": "indices_ipm_su3_rgph2021_k40",
     "recensement": True},
    {"cle": "enem", "nom": "ENEM 2025", "nature": "enquête emploi (panel)", "classeur": "indices_ipm_ci_enem2025_su3_k40",
     "recensement": False},
]


# --------------------------------------------------------------------------- #
# 1. calculs
# --------------------------------------------------------------------------- #
def analyser(source, recalculer=False):
    """Résultats de l'étape 07 pour une source : relancée en sous-processus (SOURCE est figé à l'import)."""
    DUMP.mkdir(parents=True, exist_ok=True)
    chemin = DUMP / f"{source['cle']}.pkl"
    if recalculer or not chemin.exists():
        debut = time.perf_counter()
        env = {**os.environ, "IPM_SOURCE": source["cle"]}
        r = subprocess.run([sys.executable, str(PIPELINE / "07_robustesse_seuil_k.py"), "--su3", "--k40", "--dump", str(chemin)],
                           cwd=RACINE, env=env, capture_output=True, text=True)
        assert r.returncode == 0, f"étape 07 en échec pour {source['cle']} :\n{r.stderr[-1500:]}"
        print(f"  {source['nom']} : analyse de robustesse en {time.perf_counter() - debut:.0f} s")
    with open(chemin, "rb") as f:
        return pickle.load(f)


def lire_classeur(source):
    f = SORTIES / "xlsx" / f"{source['classeur']}.xlsx"
    assert f.exists(), f"{f.name} absent : lancer le pipeline avec --su3 --k40 pour {source['cle']}"
    lire = lambda feuille: pd.read_excel(f, sheet_name=feuille)
    csv33 = SORTIES / "csv" / f"{source['classeur'].replace('_k40', '')}.csv"
    ens33 = pd.read_csv(csv33).query("variable == 'Ensemble'").iloc[0]
    return {"ens": lire("Ensemble").iloc[0], "ens33": ens33, "pond": lire("Ponderations"), "contr": lire("Contributions"),
            "milieu": lire("Milieu de résidence"), "region": lire("Région"),
            "sp": lire("Sous-préfecture ou commune")}


def precision(t):
    """Précision de l'indice par zone : effectifs, grappes et coefficient de variation de M0."""
    cv = t.M0_cv.replace([np.inf], np.nan)
    return {"zones": len(t), "men_med": float(t.menages.median()), "grappes_med": float(t.grappes.median()),
            "moins10": int((t.grappes < 10).sum()), "cv_med": float(cv.median()), "cv20": int((cv > 0.2).sum()),
            "cv_absent": int(cv.isna().sum())}


def champ_enem():
    """Ménages avec roster (journal de l'étape 01 ENEM) et effet de plan des poids des ménages retenus."""
    import re
    journal = (RACINE / "logs" / "01_enem_preconstruction_matrice_situationnelle.log").read_text(encoding="utf8")
    roster = sum(int(b) for _, b in re.findall(r"(T\d) : \d+ ménages retenus sur (\d+)", journal))
    g0 = pd.read_stata(SORTIES / "dta" / "matrice_situationnelle_enem2025_su3.dta", columns=["taille_menage", "ponderation_menage"])
    n_ = g0.taille_menage * g0.ponderation_menage
    deff = len(n_) * (n_ ** 2).sum() / n_.sum() ** 2
    return {"roster": roster, "deff": float(deff), "n_eff": len(n_) / float(deff)}


def plage_stable(corr):
    """Plus grande plage de seuils testés, autour de K_REF, où le Kendall reste au moins égal au seuil de stabilité."""
    c = corr.set_index("k").kendall
    grille = list(c.index)
    i = min(range(len(grille)), key=lambda j: abs(grille[j] - K_REF))
    j = m = i
    while j > 0 and c.iloc[j - 1] >= SEUIL_STABLE:
        j -= 1
    while m < len(grille) - 1 and c.iloc[m + 1] >= SEUIL_STABLE:
        m += 1
    return grille[j], grille[m]


# --------------------------------------------------------------------------- #
# 2. figures (noir et gris)
# --------------------------------------------------------------------------- #
def _plt():
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    plt.rcParams.update({"font.size": 8, "axes.spines.top": False, "axes.spines.right": False, "axes.grid": True,
                         "grid.color": "#dddddd", "grid.linewidth": 0.5, "savefig.dpi": 200})
    return plt


def _axe_k(ax):
    from matplotlib.ticker import FuncFormatter
    ax.xaxis.set_major_formatter(FuncFormatter(lambda v, _: f"{100 * v:.0f} %"))
    ax.axvline(K_REF, color="black", linestyle=":", linewidth=0.9)
    ax.set_xlabel("Seuil de pauvreté k")


def figure_niveau(analyses, chemin):
    plt = _plt()
    styles = {"ehcvm": ("-", "o"), "rgph": ("--", "s"), "enem": ("-.", "^")}
    fig, axes = plt.subplots(1, 2, figsize=(7.6, 2.8))
    for s in SOURCES:
        c = analyses[s["cle"]]["courbe"]
        ls, mk = styles[s["cle"]]
        axes[0].plot(c.k, 100 * c.H, color="black", linestyle=ls, marker=mk, markersize=2.5, linewidth=1, label=s["nom"])
        axes[1].plot(c.k, c.M0, color="black", linestyle=ls, marker=mk, markersize=2.5, linewidth=1, label=s["nom"])
    axes[0].set_title("Incidence H (%)", fontsize=9)
    axes[1].set_title("Indice M0", fontsize=9)
    for ax in axes:
        _axe_k(ax)
    axes[0].legend(fontsize=7, frameon=False)
    fig.tight_layout()
    fig.savefig(chemin)
    plt.close(fig)


def figure_rangs(analyses, chemin):
    plt = _plt()
    panneaux = [(s, col, d) for s in SOURCES for col, d in analyses[s["cle"]]["domaines"].items()]
    fig, axes = plt.subplots(2, 2, figsize=(7.6, 5.4), squeeze=False)
    for ax, (s, col, d) in zip(axes.ravel(), panneaux):
        c = analyses[s["cle"]]["courbe"]
        kmax = c[c.H >= 0.01].k.max()
        corr = d["corr"][d["corr"].k <= kmax]
        ax.plot(corr.k, corr.spearman, color="black", marker="o", markersize=2.5, linewidth=1, label="Spearman")
        ax.plot(corr.k, corr.kendall, color="black", marker="s", markersize=2.5, linewidth=1, linestyle="--", label="Kendall")
        ax.axhline(SEUIL_STABLE, color="#888888", linewidth=0.8)
        ax.set_ylim(min(0.3, np.nanmin(corr[["spearman", "kendall"]].values) - 0.05), 1.02)
        ax.set_title(f"{s['nom']} : {d['pluriel']} ({len(d['ref'])})", fontsize=8.5)
        ax.set_ylabel("Corrélation avec le classement à k = 40 %")
        ax.legend(fontsize=6.5, frameon=False, loc="lower left")
        _axe_k(ax)
    for ax in axes.ravel()[len(panneaux):]:
        ax.axis("off")
    fig.tight_layout()
    fig.savefig(chemin)
    plt.close(fig)


# --------------------------------------------------------------------------- #
# 3. rapport Word
# --------------------------------------------------------------------------- #
def _p(x, d=1):
    return f"{100 * x:.{d}f} %".replace(".", ",")


def _n(x, d=3):
    return "sans objet" if pd.isna(x) else f"{x:.{d}f}".replace(".", ",")


def _ic(v, lo, hi, pourcent=False, d=4):
    if pourcent:
        return f"{_p(v)} ({100 * lo:.1f} ; {100 * hi:.1f})".replace(".", ",")
    return f"{_n(v, d)} ({_n(lo, d)} ; {_n(hi, d)})"


def _lire(valeur):
    if pd.isna(valeur):
        return "sans objet"
    return ("très stable" if valeur >= 0.9 else "stable" if valeur >= SEUIL_STABLE
            else "modérément stable" if valeur >= 0.6 else "fragile")


def _nom_zone(s):
    """Majuscules du fichier source -> casse usuelle."""
    t = str(s).strip().title()
    for a, b in ((" D'", " d'"), (" De ", " de "), (" Du ", " du "), (" Des ", " des "), (" Et ", " et "), (" La ", " la ")):
        t = t.replace(a, b)
    return t


def definitions(cle):
    """{colonne: (énoncé de la privation, grandeur et seuil retenus)} lus dans l'étape 02 : la définition qui rend un ménage privé."""
    import importlib.util
    os.environ.setdefault("IPM_SOURCE", cle)
    spec = importlib.util.spec_from_file_location("etape02_defs", PIPELINE / "02_construction_matrice_situationnelle.py")
    m02 = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m02)
    z = {"ehcvm": m02.PARAMETRES_Z, "rgph": m02.PARAMETRES_Z_RGPH, "enem": m02.PARAMETRES_Z_ENEM}[cle]
    bas = lambda t: t[0].lower() + t[1:] if len(t) > 1 and not t[1].isupper() else t     # « privé si le ménage… »
    return {i.colonne: (bas(i.definition).rstrip(".") + ".", z[i.colonne][0]) for i in m02.INDICATEURS_PAR_SOURCE[cle]}


def rapport(analyses, classeurs, chemins):
    from docx.shared import Cm
    from docx_sobre import CENTRE, Note, mil

    n = Note(entete="Rapport technique. IPM à k = 40 % : EHCVM, RGPH et ENEM",
             pied="Projet IPM Côte d'Ivoire. Usage interne")
    aujourdhui = date.today()
    n.bandeau("Projet IPM Côte d'Ivoire", "IPM à k = 40 % (chômage SU3) pour les trois sources")
    n.titre_note("RAPPORT TECHNIQUE", "L'indice de pauvreté multidimensionnelle à k = 40 % dans l'EHCVM 2021, le RGPH 2021 et l'ENEM 2025 : "
                 "dimensions, résultats et stabilité du classement des régions et des sous-préfectures")
    n.bloc_identification([
        ("Destinataire", "Équipe de calcul de l'IPM"),
        ("Objet", "Présenter les dimensions de chaque source et l'indice obtenu avec le seuil de pauvreté k = 40 % et le chômage SU3, "
                  "puis tester par les corrélations de rang de Spearman et de Kendall si le classement des régions (et des sous-préfectures "
                  "pour le RGPH) est préservé quand k varie"),
        ("Sources", "Classeurs de l'étape 05 du pipeline PythonIPM à k = 40 % (EHCVM 2021, RGPH 2021, ENEM 2025), branche ipm_avec_enem"),
        ("Date", f"{aujourdhui.day} {MOIS[aujourdhui.month - 1]} {aujourdhui.year}"),
    ])

    E = {s["cle"]: classeurs[s["cle"]]["ens"] for s in SOURCES}
    E33 = {s["cle"]: classeurs[s["cle"]]["ens33"] for s in SOURCES}

    # ------------------------------------------------------------------ 1. synthèse
    n.titre("1. Synthèse", 1)
    n.p("La question traitée est la suivante : quel indice obtient-on dans chacune des trois sources avec le seuil de pauvreté k = 40 % et le chômage SU3, "
        "et le classement des zones, régions et sous-préfectures, résiste-t-il à ce choix de seuil ? Le rapport répond en trois temps : les dimensions "
        "de chaque source (partie 3), l'indice à k = 40 % (partie 4), la stabilité du classement (partie 5). Les limites propres à chaque base sont décrites en partie 6.")
    lignes = "; ".join(f"{s['nom']} M0 = {_n(E[s['cle']].M0_ipm)} (H = {_p(E[s['cle']].H_incidence)})" for s in SOURCES)
    n.p([("À k = 40 %, ", True), (f"l'indice vaut : {lignes}. Les niveaux ne se comparent pas d'une source à l'autre, car les indicateurs diffèrent.", False)])
    n.p([("Le classement est préservé. ", True),
         ("Pour les régions de chaque source, le tau de Kendall avec le classement à k = 40 % reste au-dessus de " + _n(SEUIL_STABLE, 1) +
          " sur la plage suivante : " + "; ".join(
              f"{s['nom']} {_p(plage_stable(analyses[s['cle']]['domaines']['region']['corr'])[0], 0)} à "
              f"{_p(plage_stable(analyses[s['cle']]['domaines']['region']['corr'])[1], 0)}" for s in SOURCES) + ". "
          "Pour les sous-préfectures du RGPH, " +
          (lambda c, p: f"la plage est de {_p(p[0], 0)} à {_p(p[1], 0)}")(analyses["rgph"]["domaines"]["sous_prefecture"]["corr"],
                                                                        plage_stable(analyses["rgph"]["domaines"]["sous_prefecture"]["corr"])) + ".", False)])
    n.p("Le seuil de 40 % modifie donc le niveau de l'indice mais pas l'ordre des zones : les priorités territoriales sont les mêmes qu'avec le seuil de 1/3, "
        "à condition de présenter le classement et de toujours indiquer le seuil quand on donne un niveau.")

    # ------------------------------------------------------------------ 2. cadre
    n.titre("2. Cadre et méthode", 1)
    n.p("L'indice suit la méthode d'Alkire et Foster. Chaque ménage reçoit un score de privation, somme des poids des indicateurs dans lesquels il est privé ; "
        "il est pauvre si ce score atteint au moins k. L'incidence H est la part de la population pauvre, l'intensité A le score moyen des pauvres et M0 le produit de H et de A. "
        "Le seuil k = 40 % exige donc de cumuler au moins 40 % des privations pondérées, contre 33,3 % pour le seuil habituel de 1/3. "
        "Pour les trois sources, le chômage retenu est le SU3 (sous-utilisation de la main-d'œuvre), qui ajoute au chômage au sens du BIT la main-d'œuvre potentielle.")
    lignes = []
    for s in SOURCES:
        a, w = analyses[s["cle"]], classeurs[s["cle"]]["pond"]
        lignes.append([s["nom"], s["nature"], mil(a["n_menages"]), f"{a['population'] / 1e6:.1f}".replace(".", ","), str(len(w)),
                       str(w.dimension.nunique())])
    n.tableau(["Source", "Nature", "Ménages", "Population représentée (millions)", "Indicateurs", "Dimensions"], lignes,
              widths=[2.6, 4.0, 2.6, 3.6, 2.0, 2.0], fs=9, legende="Les trois sources.")
    n.p("Les trois sources n'ont pas la même couverture. Le RGPH, recensement exhaustif, n'a pas d'erreur d'échantillonnage : les intervalles de confiance du classeur "
        "reposent sur la convention du pipeline, qui traite les zones de dénombrement comme des grappes, et ne doivent pas être lus comme une incertitude d'échantillonnage. "
        "L'ENEM ne retient que les ménages à leur première interrogation de 2025, avec un échantillon réduit.")

    # ------------------------------------------------------------------ 3. dimensions
    n.titre("3. Dimensions et indicateurs de chaque source", 1)
    n.p("Chaque dimension pèse un quart de l'indice et son poids se partage à parts égales entre ses indicateurs. Le nombre d'indicateurs par dimension varie d'une source à l'autre, "
        "ce qui change le poids de chacun. Les tableaux donnent, pour chaque source, les indicateurs, leur poids et leur contribution à M0 à k = 40 %.")
    for i, s in enumerate(SOURCES, 1):
        n.titre(f"3.{i} {s['nom']}", 2)
        w, c = classeurs[s["cle"]]["pond"], classeurs[s["cle"]]["contr"]
        m = w.merge(c[["colonne", "contribution_M0", "contribution_dimension"]], on="colonne")
        lig = []
        for dim in ORDRE_DIM:
            g = m[m.dimension == dim]
            for j, r in enumerate(g.itertuples()):
                lig.append([NOM_DIM[dim] if j == 0 else "", str(r.indicateur).replace("—", ","), _n(r.poids_indicateur, 4), _p(r.contribution_M0)])
            if len(g):
                lig.append(["", f"Total {NOM_DIM[dim].lower()}", _p(g.poids_indicateur.sum()), _p(g.contribution_M0.sum())])
        n.tableau(["Dimension", "Indicateur", "Poids", "Contribution à M0"], lig, widths=[3.2, 8.2, 2.2, 2.8], fs=8.5,
                  legende=f"Dimensions, indicateurs, poids et contribution à M0 à k = 40 % ({s['nom']}).")
        defs = definitions(s["cle"])
        taux = c.set_index("colonne").taux_privation_censure
        lig = []
        for dim in ORDRE_DIM:
            for j, r in enumerate(m[m.dimension == dim].itertuples()):
                lig.append([NOM_DIM[dim] if j == 0 else "", str(r.indicateur), defs[r.colonne][0], _n(r.poids_indicateur, 4),
                            _p(taux[r.colonne])])
        n.tableau(["Dimension", "Indicateur", "Un ménage est privé si", "Poids", "Taux de privation censuré"], lig,
                  widths=[2.2, 3.0, 7.0, 1.4, 1.8], fs=8,
                  legende=f"Définition de la privation de chaque indicateur ({s['nom']}). Le taux de privation censuré est la part des ménages à la fois pauvres à k = 40 % et privés dans l'indicateur.")
        dims = m.groupby("dimension").agg(n=("colonne", "size"), contrib=("contribution_M0", "sum"))
        plus = dims.contrib.idxmax()
        n.p(f"{s['nom']} compte {len(m)} indicateurs en {len(dims)} dimensions. La dimension qui contribue le plus à M0 est "
            f"{NOM_DIM[plus].lower()} ({_p(dims.contrib.max())}), pour {int(dims.loc[plus, 'n'])} indicateurs.")

    # ------------------------------------------------------------------ 4. résultats
    n.titre("4. L'indice à k = 40 %", 1)
    n.p("Le tableau donne l'incidence H, l'intensité A et l'indice M0 à k = 40 %, avec leurs intervalles de confiance à 95 %, et la valeur de M0 au seuil habituel de 1/3 pour la même source et le même chômage.")
    lig = []
    for s in SOURCES:
        e, e3 = E[s["cle"]], E33[s["cle"]]
        lig.append([s["nom"], _ic(e.H_incidence, e.H_ic_bas, e.H_ic_haut, True), _ic(e.A_intensite, e.A_ic_bas, e.A_ic_haut, d=3),
                    _ic(e.M0_ipm, e.M0_ic_bas, e.M0_ic_haut), _n(e3.M0_ipm, 4)])
    n.tableau(["Source", "H, incidence (IC 95 %)", "A, intensité (IC 95 %)", "M0 (IC 95 %)", "M0 à k = 1/3"], lig,
              widths=[2.6, 4.0, 3.6, 4.2, 2.2], fs=8.5, legende="Indice à k = 40 % (chômage SU3).")
    lig = []
    for s in SOURCES:
        e, e3 = E[s["cle"]], E33[s["cle"]]
        lig.append([s["nom"], _p(e3.H_incidence), _p(e.H_incidence), f"{100 * (e.H_incidence - e3.H_incidence):+.1f} points".replace(".", ","),
                    _n(e3.A_intensite, 3), _n(e.A_intensite, 3), _p(e.M0_ipm / e3.M0_ipm - 1, 0).replace("%", "%")])
    n.tableau(["Source", "H à 1/3", "H à 40 %", "Écart de H", "A à 1/3", "A à 40 %", "Variation de M0"], lig,
              widths=[2.4, 2.0, 2.0, 3.0, 2.0, 2.0, 2.8], fs=8.5, legende="Effet du passage de k = 1/3 à k = 40 %.")
    n.p("Passer de 1/3 à 40 % retire de la pauvreté les ménages dont le score se situe entre ces deux valeurs, donc l'incidence baisse, de 12 à 17 points selon la source. "
        "L'intensité augmente, car les ménages qui restent pauvres sont les plus privés, et M0 baisse moins vite que H.")
    figure_n = [0]

    def figure(chemin, texte):
        figure_n[0] += 1
        n.doc.add_picture(str(chemin), width=Cm(16.0))
        n.doc.paragraphs[-1].alignment = CENTRE
        par = n.p([(f"Figure {figure_n[0]}. ", True)], size=9, before=3, space=11, align=CENTRE)
        n._run(par, texte, size=9, italic=True)

    figure(chemins["niveau"], "Incidence H et indice M0 selon le seuil k, pour les trois sources (trait pointillé vertical : k = 40 %).")

    n.titre("4.1 Milieu de résidence", 2)
    lig = []
    for s in SOURCES:
        for r in classeurs[s["cle"]]["milieu"].itertuples():
            lig.append([s["nom"], str(r.modalite), _p(r.part_population, 0), _p(r.H_incidence), _ic(r.M0_ipm, r.M0_ic_bas, r.M0_ic_haut)])
    n.tableau(["Source", "Milieu", "Part de la population", "H", "M0 (IC 95 %)"], lig, widths=[2.6, 3.0, 3.0, 2.2, 5.2], fs=8.5,
              legende="Indice à k = 40 % par milieu de résidence.")
    n.p("Le milieu rural est le plus touché dans les trois sources, avec un écart considérable avec le milieu urbain : "
        + "; ".join(f"{s['nom']} {_n(classeurs[s['cle']]['milieu'].set_index('modalite').loc['Rural', 'M0_ipm'] / classeurs[s['cle']]['milieu'].set_index('modalite').loc['Urbain', 'M0_ipm'], 1)} fois" for s in SOURCES) +
        " (rapport du M0 rural au M0 urbain).")

    n.titre("4.2 Régions les plus et les moins pauvres", 2)
    for s in SOURCES:
        r = classeurs[s["cle"]]["region"].sort_values("M0_ipm", ascending=False)
        lig = [[("Plus pauvres" if i == 0 else ""), _nom_zone(x.modalite), _p(x.H_incidence), _ic(x.M0_ipm, x.M0_ic_bas, x.M0_ic_haut)]
               for i, x in enumerate(r.head(5).itertuples())]
        lig += [[("Moins pauvres" if i == 0 else ""), _nom_zone(x.modalite), _p(x.H_incidence), _ic(x.M0_ipm, x.M0_ic_bas, x.M0_ic_haut)]
                for i, x in enumerate(r.tail(5).iloc[::-1].itertuples())]
        n.tableau(["", "Région", "H", "M0 (IC 95 %)"], lig, widths=[3.0, 5.6, 2.2, 5.4], fs=8.5,
                  legende=f"Les cinq régions les plus et les moins pauvres à k = 40 % ({s['nom']}).")

    # ------------------------------------------------------------------ 5. robustesse du classement
    n.titre("5. Le classement des zones est-il préservé ?", 1)
    n.p("Un seuil est une convention : la vraie question est de savoir si l'ordre des zones, de la plus pauvre à la moins pauvre, dépend de lui. "
        "Pour chaque source, on classe les zones à k = 40 %, puis à d'autres seuils (20 %, 25 %, 1/3, 50 %, 60 %), et on mesure à quel point les deux classements concordent.")
    n.titre("5.1 Comment lire les tests", 2)
    n.p([("Spearman ", True), ("compare le rang de chaque zone dans les deux classements : on calcule l'écart de rang d de chaque zone, puis 1 - 6 × Σd² / (N × (N² - 1)). "
         "Il pénalise surtout les zones qui changent beaucoup de places.", False)])
    n.p([("Kendall ", True), ("compte les paires de zones dont l'ordre s'inverse : tau = (paires concordantes - paires discordantes) / nombre de paires, soit une part de (1 - tau) / 2 de paires inversées. "
         "Un tau de 0,9 correspond à 5 paires sur 100 inversées.", False)])
    n.p("Les deux valent 1 pour un classement identique, 0 pour aucun lien, -1 pour un classement inversé. Le tableau suivant est la grille de lecture retenue ici, qui est un repère de travail et non une norme.")
    n.tableau(["Tau de Kendall", "Lecture", "Part des paires inversées"],
              [["0,9 et plus", "Très stable", "Moins de 5 %"], ["0,8 à 0,9", "Stable", "5 % à 10 %"],
               ["0,6 à 0,8", "Modérément stable", "10 % à 20 %"], ["Moins de 0,6", "Fragile", "Plus de 20 %"]],
              widths=[4.0, 4.4, 5.0], fs=9, legende="Grille de lecture du tau de Kendall.")

    n.titre("5.2 Résultats", 2)
    for s in SOURCES:
        for col, d in analyses[s["cle"]]["domaines"].items():
            corr = d["corr"].set_index("k")
            ks = [0.2, 0.25, 1 / 3, 0.5, 0.6]
            lig = [[("1/3" if abs(k - 1 / 3) < 1e-9 else _p(k, 0)), _n(corr.loc[k].spearman), _n(corr.loc[k].kendall),
                    f"{int(corr.loc[k].discordantes)} sur {mil(corr.loc[k].paires)}", _p(corr.loc[k].discordantes / corr.loc[k].paires),
                    _lire(corr.loc[k].kendall)] for k in ks]
            n.tableau(["Seuil k", "Spearman", "Kendall", "Paires inversées", "Part", "Lecture"], lig, widths=[1.8, 2.2, 2.2, 4.0, 2.0, 3.6], fs=8.5,
                      legende=f"Stabilité du classement des {d['pluriel']} ({len(d['ref'])} zones, {s['nom']}) par rapport à k = 40 %.")
    figure(chemins["rangs"], "Corrélation de Spearman (trait plein) et de Kendall (pointillé) avec le classement à k = 40 %, selon le seuil k. "
                             "La ligne grise marque 0,8.")

    lec = []
    for s in SOURCES:
        for col, d in analyses[s["cle"]]["domaines"].items():
            c = d["corr"].set_index("k")
            lec.append((s["nom"], d["pluriel"], c.loc[1 / 3].kendall, c.loc[1 / 3].discordantes / c.loc[1 / 3].paires, c.loc[0.25].kendall,
                        c.loc[0.5].kendall, plage_stable(d["corr"])))
    for nom, plu, k13, part13, k25, k50, (bas, haut) in lec:
        n.p(f"{nom}, {plu} : entre k = 1/3 et k = 40 %, {_p(part13)} des paires de zones changent d'ordre (Kendall {_n(k13)}, lecture {_lire(k13)}). "
            f"Le classement à k = 40 % reste stable (Kendall au moins égal à 0,8) de k = {_p(bas, 0)} à k = {_p(haut, 0)} ; le Kendall vaut {_n(k25)} à 25 % et {_n(k50)} à 50 %.")

    n.titre("5.3 Comparaisons par paires et dominance", 2)
    n.p("Les corrélations de rang ignorent l'incertitude d'échantillonnage. Pour les deux enquêtes, on compare aussi chaque paire de régions avec les erreurs standard (test bilatéral à 5 %) : une paire est robuste "
        "si l'ordre établi à k = 40 % est retrouvé aux autres seuils. Cette comparaison n'a pas de sens pour le RGPH, recensement sans erreur d'échantillonnage.")
    for s in SOURCES:
        if s["recensement"]:
            continue
        d = analyses[s["cle"]]["domaines"]["region"]
        p = d["paires"]
        lig = [[("1/3" if abs(r.k - 1 / 3) < 1e-9 else _p(r.k, 0)), f"{int(r.significatives)} sur {mil(r.paires)} ({_p(r.part_significatives, 0)})", _p(r.robustes_toutes, 0),
                f"{int(r.robustes_significatives)} sur {int(r.significatives)} ({_p(r.ratio_robustesse, 0)})"] for r in p.itertuples()]
        n.tableau(["Seuil k", "Paires significatives à k = 40 %", "Même statut, toutes paires", "Robustes, paires significatives"], lig,
                  widths=[2.0, 5.4, 3.8, 5.0], fs=8.5, legende=f"Robustesse des comparaisons par paire de régions ({s['nom']}).")
    lig = []
    for s in SOURCES:
        for col, d in analyses[s["cle"]]["domaines"].items():
            dom = d["dominance"]
            lig.append([s["nom"], d["libelle"], mil(dom["paires"]), mil(dom["avec_dominance"]), _p(dom["part"], 0)])
    n.tableau(["Source", "Zones", "Paires de zones", "Avec dominance", "Part"], lig, widths=[2.8, 4.0, 3.4, 3.4, 2.0], fs=8.5,
              legende="Dominance : l'incidence H d'une zone est au moins égale à celle de l'autre pour tout seuil k.")
    n.p("Pour les paires avec dominance, l'ordre ne dépend du seuil à aucun niveau. Les autres paires ont des courbes qui se croisent, donc un ordre qui peut changer avec k : ce sont les zones proches.")

    # ------------------------------------------------------------------ 6. limites propres à chaque base
    n.titre("6. Limites propres à chaque base", 1)
    n.p("Les trois sources n'ont pas les mêmes forces ni les mêmes faiblesses. Cette partie les décrit une à une, en indiquant à chaque fois ce que la limite empêche de faire "
        "et, quand c'est le cas, comment elle a été traitée dans le calcul.")
    n.titre("6.1 Précision selon le niveau géographique", 2)
    P = {s["cle"]: {"region": precision(classeurs[s["cle"]]["region"]), "sp": precision(classeurs[s["cle"]]["sp"])} for s in SOURCES}
    lig = []
    for s in SOURCES:
        for niveau, lib in (("region", "Région"), ("sp", "Sous-préfecture")):
            p = P[s["cle"]][niveau]
            lig.append([s["nom"], lib, mil(p["zones"]), mil(p["men_med"]), f"{p['moins10']} sur {p['zones']}", _p(p["cv_med"]) if not pd.isna(p["cv_med"]) else "sans objet",
                        f"{p['cv20']} sur {p['zones']}"])
    n.tableau(["Source", "Niveau", "Zones", "Ménages par zone (médiane)", "Zones à moins de 10 grappes", "CV médian de M0", "Zones à CV > 20 %"], lig,
              widths=[2.2, 2.6, 1.5, 2.8, 2.9, 2.2, 2.2], fs=8.5,
              legende="Précision de l'indice à k = 40 % selon le niveau géographique (CV : coefficient de variation de M0).")
    e, r, en = P["ehcvm"], P["rgph"], P["enem"]
    n.p(f"Le tableau se lit ainsi : à la maille de la région, les trois sources donnent des estimations utilisables (CV médian de {_p(e['region']['cv_med'], 0)} pour l'EHCVM, "
        f"{_p(r['region']['cv_med'], 0)} pour le RGPH, {_p(en['region']['cv_med'], 0)} pour l'ENEM). À la maille de la sous-préfecture, seul le RGPH tient : "
        f"{mil(r['sp']['men_med'])} ménages en médiane, contre {mil(e['sp']['men_med'])} pour l'EHCVM et {mil(en['sp']['men_med'])} pour l'ENEM.")

    n.titre("6.2 EHCVM 2021 : un échantillon trop petit pour les localités fines", 2)
    n.p([("Limite principale. ", True),
         (f"L'EHCVM est une enquête de {mil(analyses['ehcvm']['n_menages'])} ménages. Elle permet des résultats au niveau national, par milieu et par région, mais pas à une maille plus fine. "
          f"Les {e['sp']['zones']} sous-préfectures ou communes comptent en médiane {mil(e['sp']['men_med'])} ménages et {mil(e['sp']['grappes_med'])} grappes ; "
          f"{e['sp']['moins10']} sur {e['sp']['zones']} ont moins de 10 grappes, et {e['sp']['cv_absent']} n'ont aucune estimation de variance, faute de deux grappes au moins. "
          "L'indice par sous-préfecture n'est donc pas publiable avec l'EHCVM, et c'est pourquoi la stabilité du classement des sous-préfectures est testée sur le RGPH seul.", False)])
    n.puce([("Pas de module sur les décès. ", True), ("L'EHCVM ne permet pas de mesurer la mortalité des enfants : l'indicateur de mortalité de l'IPM est absent, et la Santé repose sur l'assurance maladie, l'insécurité alimentaire et le renoncement aux soins.", False)])
    n.puce([("Un bien d'équipement manque. ", True), ("La charrette n'est pas dans la liste des biens : l'indicateur compte 7 biens au lieu de 8.", False)])
    n.puce([("Les années d'études sont reconstruites. ", True), ("L'enquête ne demande pas le nombre d'années d'études ; il est reconstitué à partir du niveau et de la classe, et reste indéterminé pour une petite part des individus.", False)])

    n.titre("6.3 RGPH 2021 : exhaustif, mais pauvre en questions", 2)
    n.p([("Limite principale. ", True),
         ("Le recensement couvre toute la population et descend jusqu'à la sous-préfecture, mais son questionnaire est court. Il ne contient aucune question de santé ni sur le nombre de pièces : "
          "l'assurance maladie, l'insécurité alimentaire, le renoncement aux soins et la promiscuité sont absents. La dimension Santé ne repose que sur la mortalité des enfants, qui pèse un quart de l'indice "
          "pour une privation rare, et contribue pourtant pour moins de 2 % à M0.", False)])
    n.puce([("Des indicateurs approchés. ", True), ("Les années d'études sont approchées par le diplôme (BEPC ou plus), l'emploi de subsistance par la branche et le statut du chef de ménage ; l'eau et la toilette n'ont que leur critère de source ou de type, sans temps de trajet ni partage.", False)])
    n.puce([("Une mortalité observée sur 12 mois. ", True), ("Le recensement ne compte que les décès des 12 derniers mois, alors que l'IPM mondial retient une fenêtre de 5 ans.", False)])
    n.puce([("Pas d'erreur d'échantillonnage. ", True), (f"Les intervalles de confiance du classeur reposent sur une convention, et {r['sp']['moins10']} sous-préfectures sur {r['sp']['zones']} comptent moins de 10 zones de dénombrement.", False)])

    n.titre("6.4 ENEM 2025 : des questions qui ne sont pas posées à tout le panel", 2)
    n.p([("Limite principale. ", True),
         ("L'ENEM est un panel rotatif : un ménage est interrogé à l'entrée, puis un trimestre plus tard, puis un an et un an et un trimestre plus tard. Or plusieurs questions dont l'IPM a besoin ne sont posées "
          "qu'à la première interrogation : la section logement (type de logement, murs, éclairage, eau, toilette, biens, pièces) est posée à l'entrée et au quatrième passage du logement ; "
          "l'assurance maladie, l'alphabétisation et le handicap ne sont posés qu'aux nouveaux membres. Un ménage suivi n'a donc pas de réponse à ces questions dans sa visite.", False)])
    n.p("Comment cela a été résolu. Quatre choix ont été faits, par ordre d'importance :")
    ch = champ_enem()
    n.puce([("Règle d'information complète. ", True), (f"Un ménage n'est retenu que si toutes les informations nécessaires figurent dans sa propre visite de 2025, ce qui revient aux ménages à leur première interrogation. "
            f"Aucune information n'est empruntée à une visite d'une autre année, ni de 2024 ni de 2026. Cela retient {mil(analyses['enem']['n_menages'])} ménages sur {mil(ch['roster'])} ménages-trimestres ayant un roster ({_p(analyses['enem']['n_menages'] / ch['roster'], 0)}).", False)])
    n.puce([("Chaînage des individus testé puis écarté. ", True), ("Reprendre la réponse d'une visite précédente aurait évité de perdre des ménages, mais le lien entre visites est trop incertain : parmi les paires d'individus reliées, 6 % n'ont pas le même sexe et l'âge est incohérent pour environ un tiers.", False)])
    n.puce([("Calage des poids. ", True), ("Les ménages à leur première interrogation ne sont qu'une partie de l'échantillon : leurs poids sont calés, trimestre par trimestre, sur les totaux de population de chaque direction régionale et milieu, pour représenter toute la population.", False)])
    n.puce([("Le SU3 plutôt que le BIT. ", True), ("Le chômage au sens du BIT dépend de la recherche d'emploi déclarée, qui diffère entre les ménages entrants et les ménages déjà suivis (effet de groupe de rotation) ; le SU3 y est insensible. Le sous-emploi subit le même effet : il reste dans l'indice, avec cette réserve.", False)])
    n.p([("Ce que cela coûte. ", True),
         (f"L'échantillon est réduit et ses poids sont très inégaux : l'effet de plan est de {_n(ch['deff'], 2)}, soit l'équivalent de {mil(ch['n_eff'])} ménages seulement. Les estimations par région reposent sur "
          f"{mil(en['region']['men_med'])} ménages en médiane et celles par sous-préfecture, sur {mil(en['sp']['men_med'])}, ce qui les rend inutilisables.", False)])
    n.puce([("Des indicateurs partiels ou approchés. ", True), ("Le logement ne compte que les murs, l'eau et la toilette n'ont que leur critère de source ou de type, l'énergie de cuisson est approchée par le réchaud à gaz, "
            "et l'état civil, l'insécurité alimentaire, le renoncement aux soins et la mortalité sont absents.", False)])

    # ------------------------------------------------------------------ 7. lecture et limites communes
    n.titre("7. Lecture d'ensemble et limites communes", 1)
    n.p([("Ce que les données établissent. ", True),
         ("Dans les trois sources, le classement des régions est stable autour de k = 40 %, et celui des sous-préfectures du RGPH l'est aussi dans la plage indiquée. "
          "Le choix de 40 % plutôt que 1/3 modifie le niveau de l'indice mais pas les zones à cibler.", False)])
    n.p([("Ce que cela ne dit pas. ", True),
         ("Les niveaux ne se comparent pas d'une source à l'autre : les indicateurs et leur nombre diffèrent, et le RGPH n'a, par exemple, qu'un seul indicateur de santé. "
          "La stabilité du classement ne dit rien non plus de la valeur du niveau de l'indice.", False)])
    n.puce([("Un recensement n'a pas d'erreur d'échantillonnage. ", True), ("Les intervalles de confiance du RGPH ne s'interprètent pas comme ceux des enquêtes, et les comparaisons par paires ne sont pas faites.", False)])
    n.puce([("Les deux classements viennent des mêmes données. ", True), ("Le bruit d'échantillonnage est en partie commun, ce qui rend les corrélations un peu plus favorables que si les données étaient indépendantes.", False)])
    n.puce([("L'ENEM repose sur un échantillon réduit. ", True), ("Seuls les ménages à leur première interrogation sont retenus ; les estimations par région sont moins précises que pour l'EHCVM.", False)])
    n.puce([("Seul k varie. ", True), ("Les poids des dimensions et les définitions des indicateurs sont inchangés : leur robustesse se teste séparément.", False)])
    n.puce([("Une grille de lecture conventionnelle. ", True), ("Le seuil de 0,8 pour le tau de Kendall est un repère de travail.", False)])

    # ------------------------------------------------------------------ 7. note de méthode
    n.titre("8. Note de sources et de méthode", 1)
    n.p("Les résultats par source viennent des classeurs de l'étape 05 (indices_ipm_su3_ehcvm2021_k40, indices_ipm_su3_rgph2021_k40, indices_ipm_ci_enem2025_su3_k40). "
        "Les tests de Spearman et de Kendall (tau-b) et les comparaisons par paires sont calculés par l'étape 07 du pipeline, dont les résultats sont repris ici ; "
        "le nombre de paires inversées est compté directement. Les régions de l'EHCVM et de l'ENEM sont comparées avec les erreurs standard par grappe ; "
        "les sous-préfectures du RGPH ne le sont pas. Pour l'EHCVM et le RGPH, l'indice avec le chômage SU3 est la variante dans laquelle le SU3 remplace le chômage BIT et où l'Emploi "
        "compte aussi l'emploi agricole de subsistance ; pour l'ENEM, le SU3 est l'indice lui-même.", size=9.5)

    sortie = SORTIES / "docx" / "rapport_ipm_k40_su3.docx"
    sortie.parent.mkdir(parents=True, exist_ok=True)
    n.save(str(sortie))
    return sortie


def main(recalculer=False):
    debut = time.perf_counter()
    print("=== étape 08 : rapport IPM à k = 40 % (chômage SU3), trois sources ===")
    analyses = {s["cle"]: analyser(s, recalculer) for s in SOURCES}
    classeurs = {s["cle"]: lire_classeur(s) for s in SOURCES}
    (SORTIES / "png").mkdir(parents=True, exist_ok=True)
    chemins = {"niveau": SORTIES / "png" / "ipm_k40_niveau.png", "rangs": SORTIES / "png" / "ipm_k40_rangs.png"}
    figure_niveau(analyses, chemins["niveau"])
    figure_rangs(analyses, chemins["rangs"])
    print("rapport Word :", rapport(analyses, classeurs, chemins))
    print(f"=== terminé en {time.perf_counter() - debut:.1f} s ===")


if __name__ == "__main__":
    main(recalculer="--recalculer" in sys.argv)
