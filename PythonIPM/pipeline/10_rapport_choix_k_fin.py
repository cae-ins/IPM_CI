# -*- coding: utf-8 -*-
"""Rapport : choix du seuil k entre 0,25 et 0,46 (EHCVM 2021 et ENEM 2025 SU3).
Lit les deux CSV robustesse_k_fin_*, écrit sorties/docx/rapport_choix_k_fin_0.25_0.46.docx."""
import os, sys
import pandas as pd
sys.path.insert(0, os.path.expanduser("~/.claude/skills/note-docx-sobre/scripts"))
from docx_sobre import Note, pct, mil

RACINE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "sorties")
eh = pd.read_csv(f"{RACINE}/csv/robustesse_k_fin_0.25_0.46_ehcvm2021_su3.csv")
en = pd.read_csv(f"{RACINE}/csv/robustesse_k_fin_0.25_0.46_enem2025_su3.csv")
OUT = f"{RACINE}/docx/rapport_choix_k_fin_0.25_0.46.docx"
CIBLE = 0.375
vir = lambda x, d=2: f"{x:.{d}f}".replace(".", ",")
ligne = lambda r: r.iloc[0]
proche = lambda d: ligne(d.loc[[(d.H - CIBLE).abs().idxmin()]])   # k dont H est le plus proche de la cible
meilleur_eh, meilleur_en = proche(eh), proche(en)
a = lambda d, k: ligne(d[d.k.round(2) == k])
eh40, en40 = a(eh, 0.40), a(en, 0.40)
eh33, en33 = a(eh, 0.33), a(en, 0.33)

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from docx.shared import Cm
from docx.enum.text import WD_ALIGN_PARAGRAPH
DOSSIER_PNG = f"{RACINE}/png"
os.makedirs(DOSSIER_PNG, exist_ok=True)
plt.rcParams.update({"font.size": 9, "axes.spines.top": False, "axes.spines.right": False})
STYLES = {"EHCVM SU3": dict(color="black", ls="-", marker="o"), "ENEM SU3": dict(color="0.45", ls="--", marker="s")}


def courbes(fichier, colonne, titre, cv=False, cible=None):
    """Une courbe par source (noir plein / gris tireté) ; bande grise = IC à 95 %."""
    fig, ax = plt.subplots(figsize=(6.2, 3.4))
    for nom_s, d in (("EHCVM SU3", eh), ("ENEM SU3", en)):
        y = d[colonne] * 100
        ax.plot(d.k, y, label=nom_s, ms=3.5, lw=1.4, **STYLES[nom_s])
        if not cv:
            ax.fill_between(d.k, d[colonne + "_bas"] * 100, d[colonne + "_haut"] * 100, color=STYLES[nom_s]["color"], alpha=0.12, lw=0)
    if cible:
        ax.axhline(cible * 100, color="black", lw=0.8, ls=":")
        ax.text(0.2505, cible * 100 + 1, "cible 37,5 %", fontsize=8)
    ax.set_xlabel("Seuil k"); ax.set_ylabel(titre + " (%)"); ax.legend(frameon=False)
    fig.tight_layout(); chemin = f"{DOSSIER_PNG}/{fichier}.png"; fig.savefig(chemin, dpi=200); plt.close(fig)
    return chemin


def figure(chemin, texte):
    n.doc.add_picture(chemin, width=Cm(13.5))
    n.doc.paragraphs[-1].alignment = WD_ALIGN_PARAGRAPH.CENTER
    n._n_figures = getattr(n, "_n_figures", 0) + 1
    n.p([(f"Figure {n._n_figures}. ", True), (texte, False)], size=9, italic=True, space=11)


def cv_figure():
    fig, axes = plt.subplots(1, 2, figsize=(6.6, 3.2), sharey=True)
    for ax, col, ttl in zip(axes, ("CV_H", "CV_M0"), ("CV de H", "CV de M0")):
        for nom_s, d in (("EHCVM SU3", eh), ("ENEM SU3", en)):
            ax.plot(d.k, d[col] * 100, label=nom_s, ms=3, lw=1.3, **STYLES[nom_s])
        ax.set_title(ttl, fontsize=9); ax.set_xlabel("Seuil k")
    axes[0].set_ylabel("Coefficient de variation (%)"); axes[0].legend(frameon=False)
    fig.tight_layout(); chemin = f"{DOSSIER_PNG}/cv_k_fin.png"; fig.savefig(chemin, dpi=200); plt.close(fig)
    return chemin


def table(d):
    return [[vir(r.k), pct(r.H), pct(r.CV_H), pct(r.A), pct(r.M0), pct(r.CV_M0)] for r in d.itertuples()]


n = Note(entete="Rapport. Choix du seuil de pauvreté k", pied="Cellule d'Analyse Économique. Usage interne")
n.bandeau("République de Côte d'Ivoire", "Cellule d'Analyse Économique")
n.titre_note("RAPPORT TECHNIQUE", "Sensibilité de l'IPM au seuil de pauvreté k, de 0,25 à 0,46, "
             "et choix du k au regard du coefficient de variation")
n.bloc_identification([
    ("Objet", "Mesurer H, A et M0 pour chaque k de 0,25 à 0,46 (pas de 0,01) et choisir le seuil qui "
              "donne une incidence proche de 37,5 % avec le coefficient de variation le plus faible."),
    ("Sources", f"EHCVM 2021, variante SU3 ({mil(12965)} ménages) et ENEM 2025, variante SU3 ({mil(9749)} ménages)."),
    ("Méthode", "Variance par grappe, intervalles de confiance à 95 %, coefficient de variation = "
                "erreur-type / estimation."),
])

n.titre("Synthèse", 1)
n.p([("Question. ", True), ("Quel seuil k donne une incidence de la pauvreté multidimensionnelle d'environ 37,5 %, "
     "avec l'estimation la plus précise ?", False)])
n.p([("Réponse. ", True),
     (f"Pour l'EHCVM SU3, k = {vir(meilleur_eh.k)} donne H = {pct(meilleur_eh.H)} avec un coefficient de variation de "
      f"{pct(meilleur_eh.CV_H)}. Pour l'ENEM SU3, k = {vir(meilleur_en.k)} donne H = {pct(meilleur_en.H)} "
      f"(coefficient de variation {pct(meilleur_en.CV_H)}). Les deux sources n'atteignent donc pas 37,5 % au même seuil : "
      f"l'écart de {vir((meilleur_eh.k-meilleur_en.k)*100,0)} centièmes de k traduit, dans l'ENEM, une proportion plus faible de ménages cumulant "
      "beaucoup de privations.", False)])
n.p([("Réserve. ", True),
     (f"À ces seuils, M0 vaut {pct(meilleur_eh.M0)} (EHCVM) et {pct(meilleur_en.M0)} (ENEM). Une valeur de 37,5 % "
      "pour l'IPM lui-même n'est atteinte pour aucun k de la plage, M0 y restant inférieur à "
      f"{pct(eh.M0.max())} (EHCVM) et {pct(en.M0.max())} (ENEM).", False)])
n.p([("Pour le décideur. ", True),
     ("Le choix du k relève d'un arbitrage entre trois critères : la cohérence avec la cible de 37,5 %, la "
      "précision, et la comparabilité internationale (k = 1/3). Les sections suivantes fournissent les éléments de chacun.", False)])

n.titre("1. Comment lire H, A, M0 et le coefficient de variation", 1)
n.p("Cette section précise les quatre mesures utilisées dans les tableaux, avant de les comparer d'un seuil à l'autre.")
n.puce([("H, l'incidence", True), (" : part de la population dont le score pondéré de privations atteint ou dépasse k. "
        "Un H de 37,9 % signifie que 37,9 % des personnes sont multidimensionnellement pauvres.", False)])
n.puce([("A, l'intensité", True), (" : score moyen de privations parmi les seuls pauvres. Un A de 56 % signifie qu'un pauvre "
        "subit en moyenne 56 % des privations pondérées. A est toujours supérieur ou égal à k.", False)])
n.puce([("M0, l'IPM", True), (" : produit de H par A. Il rapporte les privations subies par les pauvres à l'ensemble "
        "des privations possibles de la population. Il baisse si les pauvres sont moins nombreux (H) ou moins "
        "profondément privés (A).", False)])
n.puce([("Coefficient de variation (CV)", True), (" : erreur-type divisée par l'estimation. Un CV de 3,5 % indique une "
        "erreur-type égale à 3,5 % de la valeur estimée. Repères usuels : moins de 5 %, très précis ; de 5 à 15 %, "
        "acceptable ; au-delà de 15 à 20 %, à manier avec prudence. Il se lit comme une mesure de précision, "
        "non de qualité du concept mesuré.", False)])
n.p("Le CV de H et de M0 croît avec k, car relever le seuil réduit le nombre de ménages pauvres sur lesquels "
    "repose l'estimation. Minimiser le CV conduit donc mécaniquement au k le plus bas, ce qui n'a de sens que "
    "sous la contrainte d'une cible sur H, objet de la section suivante.")

n.titre("2. Résultats de k = 0,25 à k = 0,46", 1)
n.p("Les deux tableaux donnent, pour chaque seuil, l'incidence, son CV, l'intensité, l'IPM et son CV. "
    "Les valeurs de H les plus proches de 37,5 % sont aux lignes correspondant aux seuils retenus en section 3.")
ent = ["k", "H", "CV de H", "A", "M0", "CV de M0"]
w = [1.8, 2.6, 2.6, 2.6, 2.6, 2.6]
n.tableau(ent, table(eh), widths=w, fs=9, legende="EHCVM 2021, variante SU3 : H, A, M0 et coefficients de variation selon k.")
n.tableau(ent, table(en), widths=w, fs=9, legende="ENEM 2025, variante SU3 : H, A, M0 et coefficients de variation selon k.")
n.p([("Lecture. ", True),
     (f"De k = 0,25 à k = 0,46, H passe de {pct(eh.H.iloc[0])} à {pct(eh.H.iloc[-1])} dans l'EHCVM et de "
      f"{pct(en.H.iloc[0])} à {pct(en.H.iloc[-1])} dans l'ENEM. Le CV de M0 passe dans le même temps de "
      f"{pct(eh.CV_M0.iloc[0])} à {pct(eh.CV_M0.iloc[-1])} (EHCVM) et de {pct(en.CV_M0.iloc[0])} à "
      f"{pct(en.CV_M0.iloc[-1])} (ENEM). Tous restent sous 5 %, donc la précision demeure bonne sur toute la plage. "
      "L'ENEM est un peu moins précise que l'EHCVM, ce qui tient à sa taille d'échantillon plus faible.", False)])
n.p("Les graphiques suivants visualisent ces résultats. La bande grisée figure l'intervalle de confiance à 95 %.")
figure(courbes("h_k_fin", "H", "Incidence H", cible=CIBLE), "Incidence H selon le seuil k. La ligne pointillée marque la cible de 37,5 %.")
figure(courbes("m0_k_fin", "M0", "IPM M0"), "IPM (M0) selon le seuil k.")
figure(cv_figure(), "Coefficients de variation de H et de M0 selon le seuil k.")
n.p("La courbe de l'ENEM se situe sous celle de l'EHCVM sur toute la plage, avec un écart de 2 à 10 points de H qui s'élargit quand k augmente. "
    "Les bandes de confiance se chevauchent aux seuils bas puis se séparent de façon systématique à partir de k = 0,40 : à ces seuils, l'écart entre sources n'est plus explicable par le seul aléa d'échantillonnage. "
    "La cible de 37,5 % est franchie vers k = 0,42 dans l'ENEM et entre k = 0,45 et k = 0,46 dans l'EHCVM. "
    "Les CV croissent régulièrement avec k, sans rupture, ce qui confirme qu'aucun seuil de la plage ne dégrade brutalement la précision.")

n.titre("3. Choix du seuil", 1)
n.p("Deux critères se combinent : s'approcher de 37,5 % pour H, puis minimiser le CV.")
n.tableau(["Source", "k retenu", "H", "CV de H", "A", "M0", "CV de M0"],
          [["EHCVM 2021 SU3", vir(meilleur_eh.k), pct(meilleur_eh.H), pct(meilleur_eh.CV_H), pct(meilleur_eh.A),
            pct(meilleur_eh.M0), pct(meilleur_eh.CV_M0)],
           ["ENEM 2025 SU3", vir(meilleur_en.k), pct(meilleur_en.H), pct(meilleur_en.CV_H), pct(meilleur_en.A),
            pct(meilleur_en.M0), pct(meilleur_en.CV_M0)]],
          widths=[3.4, 2.0, 2.2, 2.2, 2.2, 2.2, 2.2], fs=9,
          legende="Seuil donnant l'incidence la plus proche de 37,5 %.")
n.p(f"Pour l'EHCVM, le k retenu est celui dont H est le plus proche de la cible ; il coïncide avec un CV de H de "
    f"{pct(meilleur_eh.CV_H)}. Pour l'ENEM, le k retenu donne {pct(meilleur_en.H)}, soit {vir(abs(meilleur_en.H-CIBLE)*100,1)} "
    f"point d'écart avec la cible, avec un CV de {pct(meilleur_en.CV_H)}. Deux seuils adjacents ne diffèrent que "
    "de quelques dixièmes de point de CV : le critère de précision ne départage pas ces candidats, c'est la proximité de la cible qui le fait.")
n.p([("Comparaison avec les seuils usuels. ", True),
     (f"À k = 1/3 (arrondi à 0,33), H vaut {pct(eh33.H)} (EHCVM) et {pct(en33.H)} (ENEM), pour un M0 de {pct(eh33.M0)} "
      f"et {pct(en33.M0)}. À k = 0,40, H vaut {pct(eh40.H)} et {pct(en40.H)}, et M0 {pct(eh40.M0)} et {pct(en40.M0)}.", False)])

n.titre("4. Limites et points à trancher", 1)
n.puce([("Cible portant sur H ou sur M0. ", True), ("Un H de 37,5 % s'obtient vers k = 0,42 à 0,45 ; un M0 de 37,5 % exigerait un k "
        "inférieur à 0,25, proche d'une approche par union, peu discriminante.", False)])
n.puce([("Seuil élevé. ", True), ("Un k de 0,42 à 0,45 exige 42 à 45 % des privations pondérées pour être déclaré pauvre. Il s'écarte "
        "du standard international (k = 1/3) et réduit la comparabilité.", False)])
n.puce([("Variante ENEM. ", True), ("Seule la variante SU3 est présentée. Le fichier d'indices de la variante BIT n'a pas pu être "
        "reproduit à partir des matrices (H de 39,9 % recalculé contre 46,5 % dans le fichier à k = 0,40) et doit être vérifié avant tout usage.", False)])
n.puce([("Dumps de robustesse. ", True), ("Les fichiers robustesse_dump/*.pkl ne recoupent pas les fichiers d'indices officiels et "
        "n'ont pas été utilisés ici. Les calculs reposent sur les matrices situationnelles.", False)])
n.puce([("Erreur-type. ", True), ("Elle est déduite de l'intervalle de confiance à 95 % (largeur / 3,92), ce qui suppose une loi approximativement normale.", False)])

n.titre("5. Décisions sollicitées", 1)
n.p("1. Préciser si la cible de 37,5 % porte sur l'incidence H ou sur l'IPM M0.")
n.p(f"2. Choisir entre un seuil unique pour les deux sources et un seuil par source (k = {vir(meilleur_eh.k)} pour l'EHCVM, "
    f"k = {vir(meilleur_en.k)} pour l'ENEM).")
n.p("3. Décider si k = 1/3 reste publié en référence internationale à côté du seuil retenu.")
n.p("4. Autoriser la vérification de la variante ENEM BIT avant intégration dans les publications.")

n.titre("Note de sources et de méthode", 1)
n.p("Les valeurs proviennent des fichiers robustesse_k_fin_0.25_0.46_ehcvm2021_su3.csv et robustesse_k_fin_0.25_0.46_enem2025_su3.csv "
    "(dossier sorties/csv), produits par la fonction d'estimation de l'étape 07 du pipeline (poids de population, variance par grappe). "
    "À k = 0,40, les valeurs recalculées recoupent les fichiers d'indices officiels de l'EHCVM SU3 (H 48,4 %, M0 26,0 %) et de l'ENEM SU3 (H 41,1 %, M0 20,8 %). Les deux sources utilisent le même indicateur de chômage (SU3), ce qui rend la comparaison homogène.")

n.save(OUT)
print(OUT)
