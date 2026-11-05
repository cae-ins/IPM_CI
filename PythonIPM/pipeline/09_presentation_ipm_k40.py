"""Étape 09 — présentation PowerPoint : l'IPM à k = 40 % (chômage SU3) sur trois bases, et les difficultés rencontrées.

Le design reprend celui de la présentation d'atelier de l'IPM-CI : fond blanc, vert-gris et orange, titres
Montserrat, texte Aptos, cartes arrondies à filet vert pâle, chiffres clés en orange, logo de l'ANSTAT.

Les chiffres ne sont pas écrits à la main : ils viennent des classeurs de l'étape 05 et des analyses de
l'étape 07, relues par l'étape 08 (`08_rapport_ipm_k40.py`). Prérequis : le pipeline a été lancé pour les trois
sources avec `--su3 --k40`.

Usage :
    python 09_presentation_ipm_k40.py              # écrit sorties/pptx/ipm_k40_resultats_et_difficultes.pptx
    python 09_presentation_ipm_k40.py --apercu     # écrit aussi des aperçus PNG (contrôle des débordements)
"""
import importlib.util
import sys
from pathlib import Path

import numpy as np
import pandas as pd
from pptx import Presentation
from pptx.chart.data import CategoryChartData
from pptx.dml.color import RGBColor
from pptx.enum.chart import XL_CHART_TYPE, XL_LEGEND_POSITION, XL_MARKER_STYLE
from pptx.enum.dml import MSO_LINE
from pptx.enum.shapes import MSO_SHAPE
from pptx.enum.text import MSO_ANCHOR, PP_ALIGN
from pptx.util import Emu, Inches, Pt

PIPELINE = Path(__file__).resolve().parent
RACINE = PIPELINE.parent
SORTIE = RACINE / "sorties" / "pptx" / "ipm_k40_resultats_et_difficultes.pptx"
LOGO = PIPELINE / "ressources" / "logo_anstat.png"

# palette et polices de la présentation d'atelier
SOMBRE, VERT, GRIS, ORANGE, PALE, BLANC = "2A362F", "49655A", "72847A", "F97316", "D7E0DB", "FFFFFF"
NOIR_VERT = SOMBRE
F_TITRE, F_EXTRA, F_SEMI, F_MEDIUM, F_BODY = ("Montserrat Black", "Montserrat ExtraBold", "Montserrat SemiBold",
                                              "Montserrat Medium", "Aptos")


def _charger(fichier, nom):
    spec = importlib.util.spec_from_file_location(nom, PIPELINE / fichier)
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m


m08 = _charger("08_rapport_ipm_k40.py", "etape08")
SOURCES = m08.SOURCES


# --------------------------------------------------------------------------- #
# outils de mise en page
# --------------------------------------------------------------------------- #
def rgb(h):
    return RGBColor.from_string(h)


def texte(slide, x, y, w, h, paragraphes, anchor=MSO_ANCHOR.TOP, nom=None):
    """Zone de texte. `paragraphes` : liste de paragraphes, chacun une liste de (texte, taille, police, couleur)
    ou un seul tuple. Marges nulles, retour à la ligne automatique, alignement à gauche."""
    tb = slide.shapes.add_textbox(Inches(x), Inches(y), Inches(w), Inches(h))
    if nom:
        tb.name = nom
    tf = tb.text_frame
    tf.word_wrap = True
    tf.margin_left = tf.margin_right = tf.margin_top = tf.margin_bottom = 0
    tf.vertical_anchor = anchor
    if isinstance(paragraphes, tuple):
        paragraphes = [[paragraphes]]
    for i, para in enumerate(paragraphes):
        p = tf.paragraphs[0] if i == 0 else tf.add_paragraph()
        p.alignment = PP_ALIGN.LEFT
        if isinstance(para, tuple):
            para = [para]
        for txt, taille, police, couleur in para:
            r = p.add_run()
            r.text = txt
            r.font.size, r.font.name, r.font.color.rgb = Pt(taille), police, rgb(couleur)
    return tb


def carte(slide, x, y, w, h):
    forme = slide.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, Inches(x), Inches(y), Inches(w), Inches(h))
    forme.adjustments[0] = 0.04
    forme.fill.solid()
    forme.fill.fore_color.rgb = rgb(BLANC)
    forme.line.color.rgb = rgb(PALE)
    forme.line.width = Pt(1)
    forme.shadow.inherit = False
    return forme


def logo(slide, x=11.58, y=0.42, w=1.05, h=0.40):
    slide.shapes.add_picture(str(LOGO), Inches(x), Inches(y), Inches(w), Inches(h))


def en_tete(slide, titre, sous_titre):
    logo(slide)
    texte(slide, 0.70, 0.40, 10.60, 0.70, (titre, 27, F_EXTRA, VERT), nom="Titre")
    texte(slide, 0.70, 1.10, 10.60, 0.55, (sous_titre, 14.5, F_BODY, GRIS), nom="Sous-titre")


def chiffre(slide, x, y, w, valeur, legende, taille=30):
    texte(slide, x, y, w, 0.9, (valeur, taille, F_TITRE, ORANGE))
    texte(slide, x, y + 0.9, w, 0.7, (legende, 14, F_BODY, GRIS))


def tableau(slide, x, y, largeurs, lignes, taille=14, hauteur_ligne=0.55):
    """Tableau à en-tête vert, première colonne vert pâle, comme dans la présentation d'atelier."""
    forme = slide.shapes.add_table(len(lignes), len(largeurs), Inches(x), Inches(y), Inches(sum(largeurs)),
                                   Inches(hauteur_ligne * len(lignes)))
    t = forme.table
    for j, w in enumerate(largeurs):
        t.columns[j].width = Inches(w)
    for i, ligne in enumerate(lignes):
        t.rows[i].height = Inches(hauteur_ligne)
        for j, valeur in enumerate(ligne):
            c = t.cell(i, j)
            c.margin_left = c.margin_right = Inches(0.12)
            c.margin_top = c.margin_bottom = Inches(0.05)
            c.vertical_anchor = MSO_ANCHOR.MIDDLE
            c.fill.solid()
            entete = i == 0
            c.fill.fore_color.rgb = rgb(VERT if entete else PALE if j == 0 else BLANC)
            tf = c.text_frame
            tf.word_wrap = True
            p = tf.paragraphs[0]
            p.alignment = PP_ALIGN.LEFT
            r = p.add_run()
            r.text = str(valeur)
            r.font.size = Pt(taille)
            r.font.name = F_SEMI if (entete or j == 0) else F_BODY
            r.font.color.rgb = rgb(BLANC if entete else SOMBRE)
    return forme


def graphique(slide, x, y, w, h, categories, series, titre_x, titre_y, vmin, vmax, format_val="0 %", couleurs=None,
              pointilles=()):
    """Courbes natives (modifiables dans PowerPoint) aux couleurs de la présentation."""
    cd = CategoryChartData()
    cd.categories = categories
    for nom, valeurs in series:
        cd.add_series(nom, valeurs)
    gf = slide.shapes.add_chart(XL_CHART_TYPE.LINE_MARKERS, Inches(x), Inches(y), Inches(w), Inches(h), cd)
    ch = gf.chart
    ch.font.size, ch.font.name, ch.font.color.rgb = Pt(12), F_BODY, rgb(GRIS)
    ch.has_title = False
    ch.has_legend = True
    ch.legend.position = XL_LEGEND_POSITION.BOTTOM
    ch.legend.include_in_layout = False
    ch.legend.font.size = Pt(12)
    va, ca = ch.value_axis, ch.category_axis
    va.minimum_scale, va.maximum_scale = vmin, vmax
    va.has_major_gridlines = True
    va.major_gridlines.format.line.color.rgb = rgb(PALE)
    va.format.line.fill.background()
    va.tick_labels.number_format, va.tick_labels.number_format_is_linked = format_val, False
    ca.has_major_gridlines = False
    ca.format.line.color.rgb = rgb(PALE)
    for axe, titre in ((ca, titre_x), (va, titre_y)):
        axe.has_title = True
        axe.axis_title.text_frame.text = titre
        run = axe.axis_title.text_frame.paragraphs[0].runs[0]
        run.font.size, run.font.bold, run.font.name, run.font.color.rgb = Pt(12), False, F_BODY, rgb(GRIS)
    couleurs = couleurs or [VERT, ORANGE, GRIS, SOMBRE]
    for i, ser in enumerate(ch.plots[0].series):
        c = couleurs[i % len(couleurs)]
        ser.smooth = False
        ser.format.line.color.rgb = rgb(c)
        ser.format.line.width = Pt(2.5)
        if i in pointilles:
            ser.format.line.dash_style = MSO_LINE.DASH
            ser.format.line.width = Pt(1.5)
            ser.marker.style = XL_MARKER_STYLE.NONE
        else:
            ser.marker.style, ser.marker.size = XL_MARKER_STYLE.CIRCLE, 6
            ser.marker.format.fill.solid()
            ser.marker.format.fill.fore_color.rgb = rgb(c)
            ser.marker.format.line.color.rgb = rgb(c)
    return gf


def notes(slide, txt):
    slide.notes_slide.notes_text_frame.text = txt


# --------------------------------------------------------------------------- #
# les diapositives
# --------------------------------------------------------------------------- #
def _p(x, d=1):
    return f"{100 * x:.{d}f} %".replace(".", ",")


def _n(x, d=3):
    return f"{x:.{d}f}".replace(".", ",")


def _mil(x):
    return f"{int(round(x)):,}".replace(",", " ")


def _ic(v, lo, hi, d=3, pourcent=False):
    if pourcent:
        return f"{_p(v)} ({100 * lo:.1f} ; {100 * hi:.1f})".replace(".", ",")
    return f"{_n(v, d)} ({_n(lo, d)} ; {_n(hi, d)})"


SECTIONS = ["Les trois bases", "Dimensions et indicateurs", "Les résultats à k = 40 %", "La stabilité du classement",
            "Difficultés et limites"]


def diapo_titre(prs):
    s = prs.slides.add_slide(prs.slide_layouts[6])
    logo(s, 5.64, 1.00, 2.05, 0.77)
    texte(s, 1.50, 2.68, 10.33, 0.40, ("Direction de la Donnée et de l'Innovation (DDI)", 14, F_SEMI, ORANGE))
    texte(s, 1.50, 3.38, 10.33, 1.80, ("L'IPM-CI sur trois bases : résultats à k = 40 % et difficultés rencontrées", 36, F_TITRE, VERT))
    texte(s, 1.50, 5.28, 10.33, 0.40, ("Novembre 2026", 13, F_MEDIUM, GRIS))
    notes(s, "Présentation des résultats du calcul de l'IPM sur l'EHCVM 2021, le RGPH 2021 et l'ENEM 2025, au seuil k = 40 % avec le chômage SU3.")


def diapo_realise(prs):
    s = prs.slides.add_slide(prs.slide_layouts[6])
    en_tete(s, "Ce que nous avons réalisé", "Trois bases, un seuil modifiable, des tests de robustesse")
    cartes = [("Une troisième base", "L'ENEM 2025, enquête emploi en panel, s'ajoute à l'EHCVM 2021 et au RGPH 2021."),
              ("Un seuil k modifiable", "Le calcul se fait à k = 1/3 ou k = 40 %, pour les trois bases, d'une seule option."),
              ("Le chômage SU3 partout", "Le même chômage, le SU3, est retenu dans les trois bases à la place du chômage BIT."),
              ("Des tests de robustesse", "Corrélations de rang de Spearman et de Kendall sur les régions, et sur les sous-préfectures du RGPH.")]
    for i, (titre, corps) in enumerate(cartes):
        x, y = 0.70 + (i % 2) * 6.08, 2.00 + (i // 2) * 2.30
        carte(s, x, y, 5.85, 2.05)
        texte(s, x + 0.30, y + 0.22, 5.30, 0.45, (titre, 18, F_SEMI, VERT))
        texte(s, x + 0.30, y + 0.80, 5.30, 1.10, (corps, 14, F_BODY, SOMBRE))
    notes(s, "Les résultats viennent des classeurs Excel de l'étape 05 du pipeline et des analyses de l'étape 07.")


def diapo_plan(prs):
    s = prs.slides.add_slide(prs.slide_layouts[6])
    logo(s)
    texte(s, 2.60, 0.62, 8.60, 0.70, ("Plan", 27, F_EXTRA, VERT))
    texte(s, 2.60, 1.32, 8.60, 0.55, ("La présentation suit cinq étapes", 14.5, F_BODY, GRIS))
    for i, nom in enumerate(SECTIONS):
        y = 2.15 + i * 0.85
        texte(s, 2.60, y, 1.20, 0.70, (f"{i + 1:02d}", 28, F_TITRE, ORANGE))
        texte(s, 4.00, y + 0.06, 7.50, 0.70, (nom, 18, F_SEMI, VERT))


def diapo_section(prs, i, sous_titre):
    s = prs.slides.add_slide(prs.slide_layouts[6])
    logo(s)
    texte(s, 0.90, 1.60, 4.00, 1.60, (f"{i + 1:02d}", 96, F_TITRE, ORANGE))
    texte(s, 0.90, 3.30, 11.50, 0.90, (SECTIONS[i], 36, F_EXTRA, VERT))
    texte(s, 0.90, 4.30, 11.00, 0.70, (sous_titre, 18, F_BODY, GRIS))
    for j, nom in enumerate(SECTIONS):
        actif = j == i
        texte(s, 0.90 + j * 2.40, 6.40, 2.25, 0.70, (nom, 11.5, F_SEMI if actif else F_BODY, VERT if actif else GRIS))
    return s


def diapo_bases(prs, A, K, P, champ):
    s = prs.slides.add_slide(prs.slide_layouts[6])
    en_tete(s, "Trois bases, trois couvertures", "L'EHCVM et l'ENEM sont des enquêtes, le RGPH est un recensement")
    nb = {c: len(K[c]["pond"]) for c in K}
    lignes = [["", "EHCVM 2021", "RGPH 2021", "ENEM 2025"],
              ["Nature", "Enquête auprès des ménages", "Recensement exhaustif", "Enquête emploi en panel"],
              ["Ménages", _mil(A["ehcvm"]["n_menages"]), _mil(A["rgph"]["n_menages"]), f"{_mil(A['enem']['n_menages'])} retenus"],
              ["Population", f"{A['ehcvm']['population'] / 1e6:.1f} millions".replace(".", ","),
               f"{A['rgph']['population'] / 1e6:.1f} millions".replace(".", ","), f"{A['enem']['population'] / 1e6:.1f} millions".replace(".", ",")],
              ["Indicateurs", str(nb["ehcvm"]), str(nb["rgph"]), str(nb["enem"])],
              ["Plus petite maille fiable", "Région", "Sous-préfecture", "Région"]]
    tableau(s, 0.70, 1.95, [2.9, 3.0, 3.0, 3.03], lignes, taille=14, hauteur_ligne=0.60)
    carte(s, 0.70, 5.85, 11.93, 0.85)
    texte(s, 1.00, 5.85, 11.40, 0.85, (f"Seul le RGPH descend à la sous-préfecture. L'ENEM ne retient que {_p(A['enem']['n_menages'] / champ['roster'], 0)} "
                                        "des ménages ayant un roster, car certaines questions ne sont posées qu'à l'entrée.", 14, F_SEMI, VERT),
          anchor=MSO_ANCHOR.MIDDLE)
    notes(s, "Ménages : EHCVM 12 965 ; RGPH 5 616 487 ; ENEM 9 806 ménages à leur première interrogation de 2025.")


def diapo_dimensions(prs, K):
    s = prs.slides.add_slide(prs.slide_layouts[6])
    en_tete(s, "Quatre dimensions, des indicateurs inégaux", "Chaque dimension pèse un quart, mais le nombre d'indicateurs varie d'une base à l'autre")
    dims = ["Education", "Sante", "Emploi", "Conditions de vie"]
    cpt = {c: K[c]["pond"].groupby("dimension").size() for c in K}
    lignes = [["Dimension", "EHCVM", "RGPH", "ENEM"]]
    for d in dims:
        lignes.append([m08.NOM_DIM[d]] + [f"{int(cpt[c].get(d, 0))} indicateurs" for c in ("ehcvm", "rgph", "enem")])
    lignes.append(["Total"] + [f"{int(cpt[c].sum())} indicateurs" for c in ("ehcvm", "rgph", "enem")])
    tableau(s, 0.70, 1.95, [3.3, 2.9, 2.9, 2.83], lignes, taille=14, hauteur_ligne=0.58)
    ctr = K["rgph"]["contr"].set_index("colonne")
    sante = ctr.loc["mortalite", "contribution_M0"]
    carte(s, 0.70, 5.55, 11.93, 1.20)
    texte(s, 1.00, 5.55, 11.40, 1.20, [[("Au RGPH, la mortalité porte seule le quart de l'indice, ", 14, F_SEMI, VERT),
                                         (f"mais elle ne contribue que pour {_p(sante)} à M0. À l'EHCVM, la santé compte quatre indicateurs, "
                                          "dont l'assurance maladie.", 14, F_BODY, SOMBRE)]], anchor=MSO_ANCHOR.MIDDLE)
    notes(s, "Les poids : chaque dimension 25 %, partagé à parts égales entre ses indicateurs (le renoncement aux soins de l'EHCVM partage un poids).")


def diapo_valeurs(prs, K):
    s = prs.slides.add_slide(prs.slide_layouts[6])
    en_tete(s, "Les valeurs de l'IPM à k = 40 %", "Chômage SU3 dans les trois bases ; les niveaux ne se comparent pas d'une base à l'autre")
    for i, src in enumerate(SOURCES):
        e = K[src["cle"]]["ens"]
        chiffre(s, 0.70 + i * 4.10, 1.95, 3.90, _n(e.M0_ipm), f"{src['nom']} : M0, avec H = {_p(e.H_incidence)}")
    lignes = [["Base", "H, incidence (IC 95 %)", "A, intensité (IC 95 %)", "M0 (IC 95 %)"]]
    for src in SOURCES:
        e = K[src["cle"]]["ens"]
        lignes.append([src["nom"], _ic(e.H_incidence, e.H_ic_bas, e.H_ic_haut, pourcent=True), _ic(e.A_intensite, e.A_ic_bas, e.A_ic_haut),
                       _ic(e.M0_ipm, e.M0_ic_bas, e.M0_ic_haut, d=4)])
    tableau(s, 0.70, 3.85, [2.3, 3.4, 3.2, 3.03], lignes, taille=13, hauteur_ligne=0.56)
    texte(s, 0.70, 6.25, 11.93, 0.60, ("Les intervalles du RGPH, recensement, reposent sur la convention du pipeline (zones de dénombrement comme grappes) "
                                       "et ne mesurent pas une erreur d'échantillonnage.", 12, F_BODY, GRIS))
    notes(s, "M0 = H x A. Indice avec le chômage SU3 ; EHCVM et RGPH : variante SU3 + emploi agricole de subsistance.")


def diapo_effet_k(prs, A, K):
    s = prs.slides.add_slide(prs.slide_layouts[6])
    en_tete(s, "Un seuil plus haut réduit l'incidence", "Passer de 1/3 à 40 % retire de la pauvreté les ménages proches du seuil")
    ks = [round(0.05 * i, 2) for i in range(1, 17)]
    series = []
    for src in SOURCES:
        c = A[src["cle"]]["courbe"].set_index(A[src["cle"]]["courbe"].k.round(4))
        series.append((src["nom"], [float(c.loc[k].H) for k in ks]))
    graphique(s, 0.60, 1.85, 7.70, 4.95, [f"{int(100 * k)} %" for k in ks], series, "Seuil de pauvreté k", "Incidence H", 0, 1)
    for i, src in enumerate(SOURCES):
        e40, e33 = K[src["cle"]]["ens"], K[src["cle"]]["ens33"]
        ecart = 100 * (e40.H_incidence - e33.H_incidence)
        y = 2.00 + i * 1.60
        texte(s, 8.80, y, 3.9, 0.8, (f"{ecart:+.1f} points".replace(".", ",").replace("-", "−"), 28, F_TITRE, ORANGE))
        texte(s, 8.80, y + 0.80, 3.9, 0.7, (f"{src['nom']} : H passe de {_p(e33.H_incidence)} à {_p(e40.H_incidence)}", 14, F_BODY, GRIS))
    notes(s, "Courbes d'incidence H selon le seuil k, pour le chômage SU3. Trait vertical de référence : k = 40 %.")


def diapo_milieu(prs, K):
    s = prs.slides.add_slide(prs.slide_layouts[6])
    en_tete(s, "Le milieu rural est le plus touché", "Rapport du M0 rural au M0 urbain, et régions aux extrêmes, à k = 40 %")
    for i, src in enumerate(SOURCES):
        m = K[src["cle"]]["milieu"].set_index("modalite")
        rapport = m.loc["Rural", "M0_ipm"] / m.loc["Urbain", "M0_ipm"]
        x = 0.70 + i * 4.10
        texte(s, x, 1.95, 3.90, 0.9, (f"{rapport:.1f} fois".replace(".", ","), 30, F_TITRE, ORANGE))
        texte(s, x, 2.85, 3.90, 0.45, (f"{src['nom']} : rural contre urbain", 14, F_BODY, GRIS))
        r = K[src["cle"]]["region"].sort_values("M0_ipm", ascending=False)
        haut = ", ".join(m08._nom_zone(z) for z in r.head(3).modalite)
        bas = ", ".join(m08._nom_zone(z) for z in r.tail(2).iloc[::-1].modalite)
        carte(s, x, 3.55, 3.90, 3.10)
        texte(s, x + 0.25, 3.72, 3.40, 0.35, ("Plus pauvres", 14, F_SEMI, VERT))
        texte(s, x + 0.25, 4.10, 3.40, 0.95, (haut, 14, F_BODY, SOMBRE))
        texte(s, x + 0.25, 5.15, 3.40, 0.35, ("Moins pauvres", 14, F_SEMI, VERT))
        texte(s, x + 0.25, 5.53, 3.40, 0.95, (bas, 14, F_BODY, SOMBRE))
    notes(s, "Rural et urbain : rapport des M0 à k = 40 % ; régions classées par M0 décroissant.")


def diapo_lire(prs, A):
    s = prs.slides.add_slide(prs.slide_layouts[6])
    en_tete(s, "Comment lire Spearman et Kendall", "Deux façons de comparer le classement des zones à k = 40 % et à un autre k")
    carte(s, 0.70, 1.95, 5.85, 2.55)
    texte(s, 1.00, 2.10, 5.30, 0.40, ("Spearman : l'écart de rang", 17, F_SEMI, VERT))
    texte(s, 1.00, 2.65, 5.30, 1.75, ("On regarde de combien de places chaque zone change entre les deux classements. "
                                      "Un grand saut pèse beaucoup plus que plusieurs petits.", 14, F_BODY, SOMBRE))
    carte(s, 6.78, 1.95, 5.85, 2.55)
    texte(s, 7.08, 2.10, 5.30, 0.40, ("Kendall : les paires inversées", 17, F_SEMI, VERT))
    texte(s, 7.08, 2.65, 5.30, 1.75, ("On compte les paires de zones dont l'ordre s'inverse. Un tau de 0,9 correspond à 5 paires sur 100 inversées.", 14, F_BODY, SOMBRE))
    d = A["enem"]["domaines"]["region"]["corr"].set_index("k")
    r = d.loc[0.5]
    carte(s, 0.70, 4.75, 11.93, 2.05)
    texte(s, 1.00, 4.88, 11.40, 0.40, ("Exemple : régions de l'ENEM, k = 50 % contre k = 40 %", 15, F_SEMI, VERT))
    texte(s, 1.00, 5.38, 11.40, 0.60, (f"{int(r.discordantes)} paires de régions sur {_mil(r.paires)} s'inversent ({_p(r.discordantes / r.paires)}) : "
                                       f"Kendall {_n(r.kendall)}, Spearman {_n(r.spearman)}.", 14, F_BODY, SOMBRE))
    texte(s, 1.00, 6.05, 11.40, 0.60, ("Lecture : 0,9 et plus très stable ; 0,8 à 0,9 stable ; 0,6 à 0,8 modérément stable ; moins de 0,6 fragile.", 13, F_BODY, GRIS))
    notes(s, "1 = classement identique, 0 = aucun lien, -1 = classement inversé. La grille de lecture est un repère de travail.")


def diapo_rangs(prs, A):
    s = prs.slides.add_slide(prs.slide_layouts[6])
    en_tete(s, "Les classements des zones sont préservés", "Kendall entre le classement à k = 40 % et celui obtenu aux autres seuils")
    panneaux = [("EHCVM, régions", "ehcvm", "region"), ("RGPH, régions", "rgph", "region"),
                ("RGPH, sous-préfectures", "rgph", "sous_prefecture"), ("ENEM, régions", "enem", "region")]
    c0 = A["enem"]["courbe"]
    ks = [round(0.05 * i, 2) for i in range(1, 14)]
    series = []
    for nom, cle, col in panneaux:
        corr = A[cle]["domaines"][col]["corr"]
        corr = corr.set_index(corr.k.round(4))
        series.append((nom, [float(corr.loc[k].kendall) if k in corr.index else None for k in ks]))
    series.append(("Seuil de stabilité (0,8)", [0.8] * len(ks)))
    graphique(s, 0.60, 1.85, 7.70, 4.95, [f"{int(100 * k)} %" for k in ks], series, "Seuil de pauvreté k", "Tau de Kendall", 0.2, 1.0,
              format_val="0.0", couleurs=[VERT, ORANGE, GRIS, SOMBRE, PALE], pointilles=(4,))
    for i, (nom, cle, col) in enumerate(panneaux):
        corr = A[cle]["domaines"][col]["corr"]
        bas, haut = m08.plage_stable(corr)
        y = 2.00 + i * 1.18
        texte(s, 8.80, y, 3.9, 0.35, (nom, 14, F_SEMI, VERT))
        texte(s, 8.80, y + 0.38, 3.9, 0.7, (f"Stable (Kendall ≥ 0,8) de k = {_p(bas, 0)} à {_p(haut, 0)}", 13.5, F_BODY, SOMBRE))
    notes(s, "Repère de stabilité : tau de Kendall de 0,8. Le classement reste stable autour de k = 40 % dans les quatre cas.")


def diapo_sp(prs, A, P):
    s = prs.slides.add_slide(prs.slide_layouts[6])
    en_tete(s, "Les sous-préfectures du RGPH tiennent", "Seule base assez fine pour classer 519 sous-préfectures")
    d = A["rgph"]["domaines"]["sous_prefecture"]
    c = d["corr"].set_index("k")
    k13 = c.loc[1 / 3]
    chiffre(s, 0.70, 1.95, 3.90, f"{len(d['ref'])}", "sous-préfectures classées")
    chiffre(s, 4.80, 1.95, 3.90, _n(k13.kendall), "Kendall entre k = 1/3 et k = 40 %")
    chiffre(s, 8.90, 1.95, 3.90, _p(k13.discordantes / k13.paires), "des paires de sous-préfectures changent d'ordre")
    carte(s, 0.70, 4.20, 11.93, 2.45)
    texte(s, 1.00, 4.35, 11.40, 0.40, ("Pourquoi le RGPH seul ?", 17, F_SEMI, VERT))
    texte(s, 1.00, 4.95, 11.40, 1.55, (f"Le RGPH compte {_mil(P['rgph']['sp']['men_med'])} ménages en médiane par sous-préfecture, contre "
                                       f"{_mil(P['ehcvm']['sp']['men_med'])} à l'EHCVM et {_mil(P['enem']['sp']['men_med'])} à l'ENEM. "
                                       "Le classement des sous-préfectures est stable autour de k = 40 %, un peu moins que celui des régions.", 14, F_BODY, SOMBRE))
    notes(s, "Les comparaisons par paires avec erreurs standard ne sont pas faites pour le RGPH, recensement sans erreur d'échantillonnage.")


def diapo_panel(prs, A, champ):
    s = prs.slides.add_slide(prs.slide_layouts[6])
    en_tete(s, "L'ENEM ne pose pas tout à tout le panel", "Certaines questions ne sont posées qu'à l'entrée du ménage")
    carte(s, 0.70, 1.95, 5.85, 3.00)
    texte(s, 1.00, 2.10, 5.30, 0.40, ("Posé seulement à l'entrée", 17, F_SEMI, VERT))
    texte(s, 1.00, 2.65, 5.30, 2.75, [[("Logement, eau, toilette, biens : ", 14, F_SEMI, SOMBRE), ("à l'entrée et au quatrième passage du logement.", 14, F_BODY, SOMBRE)],
                                      [("", 8, F_BODY, SOMBRE)],
                                      [("Assurance maladie, alphabétisation, handicap : ", 14, F_SEMI, SOMBRE), ("aux nouveaux membres seulement.", 14, F_BODY, SOMBRE)]])
    carte(s, 6.78, 1.95, 5.85, 3.00)
    texte(s, 7.08, 2.10, 5.30, 0.40, ("Comment nous l'avons résolu", 17, F_SEMI, VERT))
    etapes = ["Ne garder que les ménages dont toutes les informations sont dans leur visite de 2025",
              "Écarter le chaînage entre visites, trop incertain",
              "Caler les poids pour représenter toute la population",
              "Retenir le SU3, insensible à l'effet de rotation"]
    texte(s, 7.08, 2.65, 5.30, 2.75, [para for i, t in enumerate(etapes) for para in ([(f"{i + 1}.  ", 14, F_SEMI, ORANGE), (t, 14, F_BODY, SOMBRE)], [("", 6, F_BODY, SOMBRE)])])
    texte(s, 0.70, 5.30, 3.9, 0.7, (f"{_mil(A['enem']['n_menages'])} sur {_mil(champ['roster'])}", 24, F_TITRE, ORANGE))
    texte(s, 0.70, 5.95, 5.8, 0.5, (f"ménages retenus ({_p(A['enem']['n_menages'] / champ['roster'], 0)})", 14, F_BODY, GRIS))
    texte(s, 6.78, 5.30, 3.9, 0.7, (_n(champ["deff"], 2), 24, F_TITRE, ORANGE))
    texte(s, 6.78, 5.95, 5.9, 0.5, (f"effet de plan : {_mil(champ['n_eff'])} ménages équivalents", 14, F_BODY, GRIS))
    notes(s, "Chaînage testé : parmi les individus reliés d'une visite à l'autre, 6 % n'ont pas le même sexe et l'âge est incohérent pour un tiers.")


def diapo_granularite(prs, P):
    s = prs.slides.add_slide(prs.slide_layouts[6])
    en_tete(s, "L'EHCVM ne descend pas à la sous-préfecture", "Trop peu de ménages et de grappes par sous-préfecture pour un indice fiable")
    e = P["ehcvm"]["sp"]
    chiffre(s, 0.70, 1.95, 3.90, _mil(e["men_med"]), "ménages en médiane par sous-préfecture (EHCVM)")
    chiffre(s, 4.80, 1.95, 3.90, f"{e['moins10']} sur {e['zones']}", "sous-préfectures à moins de 10 grappes")
    chiffre(s, 8.90, 1.95, 3.90, f"{e['cv_absent']}", "sans estimation de variance (moins de 2 grappes)")
    lignes = [["Sous-préfectures", "Zones", "Ménages (médiane)", "Moins de 10 grappes", "CV médian de M0"]]
    for src in SOURCES:
        p = P[src["cle"]]["sp"]
        lignes.append([src["nom"], str(p["zones"]), _mil(p["men_med"]), f"{p['moins10']} sur {p['zones']}", _p(p["cv_med"])])
    tableau(s, 0.70, 4.05, [3.1, 1.6, 2.7, 2.9, 1.63], lignes, taille=13, hauteur_ligne=0.56)
    notes(s, "À la maille de la région, les trois bases donnent des estimations utilisables (CV médian de 4 % à 11 %).")


def diapo_limites(prs, P):
    s = prs.slides.add_slide(prs.slide_layouts[6])
    en_tete(s, "Autres limites propres à chaque base", "Ce que chacune ne permet pas de mesurer")
    contenu = [("EHCVM 2021", ["Pas de module sur les décès : pas de mortalité", "La charrette manque : 7 biens sur 8", "Années d'études reconstruites"]),
               ("RGPH 2021", ["Santé réduite à la mortalité des 12 derniers mois", "Indicateurs approchés : diplôme, eau, toilette", "Pas d'erreur d'échantillonnage : intervalles par convention"]),
               ("ENEM 2025", ["Logement réduit aux murs, eau et toilette partielles", "Cuisson approchée par le réchaud à gaz", "Sous-emploi différent entre entrants et suivis"])]
    for i, (titre, puces) in enumerate(contenu):
        x = 0.70 + i * 4.10
        carte(s, x, 1.95, 3.90, 4.75)
        texte(s, x + 0.25, 2.12, 3.40, 0.45, (titre, 18, F_SEMI, VERT))
        texte(s, x + 0.25, 2.80, 3.40, 3.70, [[("•  ", 14, F_SEMI, ORANGE), (p, 14, F_BODY, SOMBRE)] for p in puces for _ in (0,)] and
              [item for p in puces for item in ([[("•  ", 14, F_SEMI, ORANGE), (p, 14, F_BODY, SOMBRE)]], [[("", 7, F_BODY, SOMBRE)]])] and
              [para for p in puces for para in ([("•  ", 14, F_SEMI, ORANGE), (p, 14, F_BODY, SOMBRE)], [("", 7, F_BODY, SOMBRE)])])
    notes(s, "Sources : METHODOLOGIE.md du projet et partie 6 du rapport Word.")


def diapos_indicateurs(prs, K, i_src):
    """Indicateurs détaillés d'une source : définition de la privation, poids, taux. Une diapo par groupe de dimensions."""
    src = SOURCES[i_src]
    defs = m08.definitions(src["cle"])
    w, c = K[src["cle"]]["pond"], K[src["cle"]]["contr"].set_index("colonne")
    groupes, courant = [], []
    for dim in m08.ORDRE_DIM:                       # on regroupe les dimensions tant que la diapo tient (6 lignes au plus)
        g = w[w.dimension == dim]
        if courant and sum(len(x) for _, x in courant) + len(g) > 6:
            groupes.append(courant)
            courant = []
        courant.append((dim, g))
    groupes.append(courant)
    for k, groupe in enumerate(groupes, 1):
        s = prs.slides.add_slide(prs.slide_layouts[6])
        noms = " et ".join(m08.NOM_DIM[d] for d, _ in groupe).lower()
        en_tete(s, f"{src['nom']} : {noms}",
                "Un ménage est privé dans l'indicateur lorsque la condition de la troisième colonne est remplie")
        lignes = [["Dimension", "Indicateur", "Un ménage est privé si", "Poids", "Taux censuré"]]
        for dim, g in groupe:
            for j, r in enumerate(g.itertuples()):
                lignes.append([m08.NOM_DIM[dim] if j == 0 else "", str(r.indicateur), defs[r.colonne][0], _n(r.poids_indicateur, 3),
                               _p(c.loc[r.colonne, "taux_privation_censure"])])
        tableau(s, 0.60, 1.80, [1.5, 2.55, 6.35, 0.8, 0.93], lignes, taille=11, hauteur_ligne=0.55)
        texte(s, 0.60, 6.85, 12.1, 0.4, ("Taux censuré : part des ménages pauvres à k = 40 % et privés dans l'indicateur.", 11, F_BODY, GRIS))
        notes(s, f"Définitions lues dans l'étape 02 du pipeline ({src['nom']}), poids et taux dans le classeur Excel à k = 40 %.")


def diapo_technique(prs):
    s = prs.slides.add_slide(prs.slide_layouts[6])
    en_tete(s, "Des difficultés techniques surmontées", "Quatre obstacles rencontrés pendant le calcul")
    lignes = [("Un recensement de 28 millions de lignes", "Le RGPH est lu par morceaux de 3 millions de lignes ; le calcul complet prend moins de deux minutes."),
              ("Un schéma qui change d'un trimestre à l'autre", "Le fichier ménage de l'ENEM compte de 344 à 630 variables selon le trimestre ; les codes ont été vérifiés un à un."),
              ("Des libellés absents des fichiers", "Les noms des 33 régions ne figurent pas dans les données 2025 : ils sont repris du questionnaire."),
              ("Un lien entre visites trop incertain", "Parmi les individus reliés d'une visite à l'autre, 6 % n'ont pas le même sexe : le chaînage est écarté.")]
    for i, (titre, corps) in enumerate(lignes):
        y = 1.95 + i * 1.20
        texte(s, 0.70, y, 1.2, 0.8, (f"{i + 1:02d}", 28, F_TITRE, ORANGE))
        texte(s, 2.10, y + 0.02, 10.5, 0.45, (titre, 18, F_SEMI, VERT))
        texte(s, 2.10, y + 0.50, 10.5, 0.6, (corps, 14, F_BODY, SOMBRE))
    notes(s, "RGPH : pipeline complet à k = 40 % en 102 secondes.")


def diapo_decisions(prs):
    s = prs.slides.add_slide(prs.slide_layouts[6])
    en_tete(s, "Ce que l'atelier doit trancher", "Quatre points pour valider les résultats")
    lignes = [("Le seuil k", "Garder 1/3, comparable aux autres sources, ou passer à 40 % : le classement des zones ne change pas."),
              ("Le chômage", "Retenir le SU3 dans les trois bases, le chômage BIT restant en variante."),
              ("Les indicateurs de l'ENEM", "Garder ou retirer l'emploi de subsistance, inclus dans l'emploi vulnérable, et le sous-emploi."),
              ("Le niveau géographique", "Publier les sous-préfectures avec le seul RGPH, et les régions avec les trois bases.")]
    for i, (titre, corps) in enumerate(lignes):
        y = 1.95 + i * 1.20
        texte(s, 0.70, y, 1.2, 0.8, (f"{i + 1:02d}", 28, F_TITRE, ORANGE))
        texte(s, 2.10, y + 0.02, 10.5, 0.45, (titre, 18, F_SEMI, VERT))
        texte(s, 2.10, y + 0.50, 10.5, 0.6, (corps, 14, F_BODY, SOMBRE))
    notes(s, "Les huit décisions détaillées figurent dans le rapport technique de l'IPM ENEM.")


# --------------------------------------------------------------------------- #
# construction
# --------------------------------------------------------------------------- #
def construire():
    A = {s["cle"]: m08.analyser(s) for s in SOURCES}
    K = {s["cle"]: m08.lire_classeur(s) for s in SOURCES}
    P = {s["cle"]: {"region": m08.precision(K[s["cle"]]["region"]), "sp": m08.precision(K[s["cle"]]["sp"])} for s in SOURCES}
    champ = m08.champ_enem()

    prs = Presentation()
    prs.slide_width, prs.slide_height = Inches(13.333), Inches(7.5)
    diapo_titre(prs)
    diapo_realise(prs)
    diapo_plan(prs)
    diapo_section(prs, 0, "Trois sources, trois couvertures")
    diapo_bases(prs, A, K, P, champ)
    diapo_section(prs, 1, "Quatre dimensions, mais pas les mêmes indicateurs")
    diapo_dimensions(prs, K)
    for i in range(3):
        diapos_indicateurs(prs, K, i)
    diapo_section(prs, 2, "Le niveau de l'indice et son évolution avec le seuil")
    diapo_valeurs(prs, K)
    diapo_effet_k(prs, A, K)
    diapo_milieu(prs, K)
    diapo_section(prs, 3, "Les mêmes zones restent les plus pauvres")
    diapo_lire(prs, A)
    diapo_rangs(prs, A)
    diapo_sp(prs, A, P)
    diapo_section(prs, 4, "Ce que chaque base ne permet pas de faire")
    diapo_panel(prs, A, champ)
    diapo_granularite(prs, P)
    diapo_limites(prs, P)
    diapo_technique(prs)
    diapo_decisions(prs)
    SORTIE.parent.mkdir(parents=True, exist_ok=True)
    prs.save(SORTIE)
    return prs


if __name__ == "__main__":
    prs = construire()
    print(f"présentation : {SORTIE} ({len(prs.slides)} diapositives)")
    if "--apercu" in sys.argv:
        sys.path.insert(0, str(PIPELINE))
        apercu = _charger("apercu_pptx.py", "apercu")
        apercu.rendre(SORTIE, SORTIE.parent / "apercu")
