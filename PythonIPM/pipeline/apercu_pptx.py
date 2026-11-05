"""Aperçu approché d'un .pptx (sans PowerPoint) : PNG par diapositive et alerte si un texte déborde de sa boîte.

Les polices Montserrat sont celles installées ; Aptos est remplacée par Arial, un peu plus large (contrôle prudent).
Les graphiques sont dessinés comme des cadres. Usage : python apercu_pptx.py deck.pptx dossier_sortie
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont
from pptx import Presentation
from pptx.util import Emu

PX = 96                                   # pixels par pouce
POLICES = Path.home() / "Library" / "Fonts"
FICHIERS = {"Montserrat Black": "Montserrat-Black", "Montserrat ExtraBold": "Montserrat-ExtraBold",
            "Montserrat SemiBold": "Montserrat-SemiBold", "Montserrat Medium": "Montserrat-Medium"}
_cache = {}


def police(nom, pt):
    cle = (nom, round(pt * PX / 72))
    if cle not in _cache:
        chemin = POLICES / f"{FICHIERS[nom]}.ttf" if nom in FICHIERS else Path("/System/Library/Fonts/Supplemental/Arial.ttf")
        _cache[cle] = ImageFont.truetype(str(chemin), cle[1])
    return _cache[cle]


def couleur(run, defaut="2A362F"):
    try:
        return "#" + str(run.font.color.rgb)
    except Exception:
        return "#" + defaut


def mise_en_page(tf, largeur_px):
    """Lignes [(x, y, mot, police, couleur)] et hauteur totale, par retour à la ligne automatique."""
    y, sorties = 0, []
    for p in tf.paragraphs:
        runs = [r for r in p.runs]
        if not runs:
            y += 18
            continue
        mots = [(m, police(r.font.name or "Aptos", r.font.size.pt), couleur(r)) for r in runs for m in r.text.replace("\n", " ").split(" ")]
        x, haut = 0, max(f.size for _, f, _ in mots)
        ligne_h = haut * 1.2
        for m, f, c in mots:
            if m == "" and len(runs) > 1:
                continue
            w = f.getlength(m + " ")
            if x + f.getlength(m) > largeur_px and x > 0:
                x, y = 0, y + ligne_h
            sorties.append((x, y, m, f, c))
            x += w
        y += ligne_h
    return sorties, y


def rendre(chemin, dossier):
    dossier = Path(dossier)
    dossier.mkdir(parents=True, exist_ok=True)
    prs = Presentation(chemin)
    W, H = int(prs.slide_width / 914400 * PX), int(prs.slide_height / 914400 * PX)
    alertes = []
    for n, s in enumerate(prs.slides, 1):
        img = Image.new("RGB", (W, H), "white")
        d = ImageDraw.Draw(img)
        for sh in s.shapes:
            x, y, w, h = (int(v / 914400 * PX) for v in (sh.left, sh.top, sh.width, sh.height))
            if sh.shape_type == 13:
                d.rectangle([x, y, x + w, y + h], outline="#D7E0DB")
            elif sh.has_chart if hasattr(sh, "has_chart") else False:
                d.rectangle([x, y, x + w, y + h], outline="#72847A")
                d.text((x + 10, y + 10), "[graphique]", fill="#72847A")
            elif getattr(sh, "has_table", False) and sh.has_table:
                cy = y
                for lig in sh.table.rows:
                    ch, cx = int(lig.height / 914400 * PX), x
                    haut_max = 0
                    for j, cel in enumerate(lig.cells):
                        cw = int(sh.table.columns[j].width / 914400 * PX)
                        d.rectangle([cx, cy, cx + cw, cy + ch], outline="#D7E0DB")
                        res, hauteur = mise_en_page(cel.text_frame, cw - 24)
                        haut_max = max(haut_max, hauteur + 10)
                        for (px, py, m, f, c) in res:
                            d.text((cx + 12 + px, cy + 5 + py), m, font=f, fill=c)
                        cx += cw
                    if haut_max > ch:
                        alertes.append(f"diapo {n} : ligne de tableau trop haute ({haut_max:.0f} px pour {ch})")
                    cy += max(ch, int(haut_max))
                if cy > H - 20:
                    alertes.append(f"diapo {n} : tableau dépasse le bas de la page (fin à {cy / PX:.2f} po)")
            elif sh.shape_type == 1:
                d.rounded_rectangle([x, y, x + w, y + h], radius=8, outline="#D7E0DB")
            elif sh.has_text_frame and sh.text_frame.text.strip():
                res, hauteur = mise_en_page(sh.text_frame, w)
                for (px, py, m, f, c) in res:
                    d.text((x + px, y + py), m, font=f, fill=c)
                if hauteur > h + 4:
                    alertes.append(f"diapo {n} : texte « {sh.text_frame.text[:40]}… » déborde ({hauteur / PX:.2f} po pour {h / PX:.2f})")
                if y + hauteur > H - 10:
                    alertes.append(f"diapo {n} : texte sort de la page")
        img.save(dossier / f"diapo_{n:02d}.png")
    print("\n".join(alertes) if alertes else "aucun débordement détecté")
    return alertes


if __name__ == "__main__":
    rendre(sys.argv[1], sys.argv[2])
