# -*- coding: utf-8 -*-
"""Construction de notes Word sobres (python-docx).

Charte imposée : une seule police (Aptos par défaut), texte noir uniquement,
aucun aplat de couleur, aucun encadré, aucun filet de séparation, tableaux en
grille simple à trait fin. La méthode `save` refuse d'écrire un document
contenant un tiret cadratin ou demi-cadratin.

Usage minimal :

    from docx_sobre import Note, pct, num, mil

    n = Note(entete="Note stratégique", pied="Usage interne")
    n.bandeau("République de Côte d'Ivoire", "Cellule d'Analyse Économique")
    n.titre_note("NOTE STRATÉGIQUE", "Intitulé complet de la note")
    n.bloc_identification([("Destinataire", "Monsieur le Directeur")])
    n.titre("Synthèse exécutive", 1)
    n.p([("L'indice vaut ", False), (num(0.1664), True), (" en 2021.", False)])
    n.tableau(["Région", "Indice"], [["Bounkani", num(0.3654)]],
              widths=[8, 4], legende="Indice par région.")
    n.save("note.docx")
"""
from docx import Document
from docx.shared import Pt, Cm, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH, WD_TAB_ALIGNMENT
from docx.enum.table import WD_TABLE_ALIGNMENT
from docx.oxml.ns import qn
from docx.oxml import OxmlElement

NOIR = RGBColor(0x00, 0x00, 0x00)
JUST = WD_ALIGN_PARAGRAPH.JUSTIFY
GAUCHE = WD_ALIGN_PARAGRAPH.LEFT
CENTRE = WD_ALIGN_PARAGRAPH.CENTER

# --------------------------------------------------------------- formats FR
def pct(x, d=1):
    """0.3882 -> '38,8 %'. Le séparateur décimal français est la virgule."""
    return f"{x*100:.{d}f} %".replace('.', ',')

def num(x, d=4):
    """0.166438 -> '0,1664'."""
    return f"{x:.{d}f}".replace('.', ',')

def mil(x):
    """5616487 -> '5 616 487' (espace comme séparateur de milliers)."""
    return f"{int(round(x)):,}".replace(',', ' ')


class Note:
    """Document Word sobre. Chaque méthode renvoie le paragraphe ou le tableau
    créé, ce qui permet un ajustement ponctuel sans sortir de la charte."""

    def __init__(self, police="Aptos", entete=None, pied=None,
                 marges=(2.2, 2.0, 2.4, 2.4), corps=11, interligne=1.15):
        self.police = police
        self.doc = Document()
        self._n_tableaux = 0
        self._styles(corps, interligne)
        haut, bas, gauche, droite = marges
        s = self.doc.sections[0]
        s.top_margin, s.bottom_margin = Cm(haut), Cm(bas)
        s.left_margin, s.right_margin = Cm(gauche), Cm(droite)
        s.header_distance = s.footer_distance = Cm(1.1)
        self.section = s
        if entete or pied:
            self.entete_pied(entete, pied)

    # ------------------------------------------------------------- styles
    def _police_style(self, style, size=None, bold=None, italic=None):
        f = style.font
        f.name = self.police
        f.color.rgb = NOIR
        if size is not None: f.size = Pt(size)
        if bold is not None: f.bold = bold
        if italic is not None: f.italic = italic
        rf = style.element.get_or_add_rPr().get_or_add_rFonts()
        for a in ('w:ascii', 'w:hAnsi', 'w:cs', 'w:eastAsia'):
            rf.set(qn(a), self.police)
        # les attributs de thème priment sur w:ascii : il faut les retirer
        for a in ('w:asciiTheme', 'w:hAnsiTheme', 'w:cstheme', 'w:eastAsiaTheme'):
            if rf.get(qn(a)) is not None:
                del rf.attrib[qn(a)]

    def _styles(self, corps, interligne):
        st = self.doc.styles
        n = st['Normal']
        self._police_style(n, size=corps)
        n.paragraph_format.space_after = Pt(8)
        n.paragraph_format.line_spacing = interligne
        self._police_style(st['Heading 1'], size=corps + 2.5, bold=True, italic=False)
        self._police_style(st['Heading 2'], size=corps + 0.5, bold=True, italic=False)
        self._police_style(st['Heading 3'], size=corps, bold=True, italic=True)
        for h, (av, ap) in {'Heading 1': (18, 8), 'Heading 2': (13, 5),
                            'Heading 3': (10, 4)}.items():
            pf = st[h].paragraph_format
            pf.space_before, pf.space_after = Pt(av), Pt(ap)
            pf.keep_with_next = True   # un titre ne reste jamais seul en bas de page
        for nom in ('List Bullet', 'List Number', 'Caption', 'Header', 'Footer'):
            try: self._police_style(st[nom])
            except KeyError: pass

    def _run(self, p, txt, bold=False, italic=False, size=None):
        r = p.add_run(txt)
        r.bold, r.italic = bold, italic
        r.font.color.rgb = NOIR
        if size: r.font.size = Pt(size)
        rf = r._element.get_or_add_rPr().get_or_add_rFonts()
        for a in ('w:ascii', 'w:hAnsi', 'w:cs', 'w:eastAsia'):
            rf.set(qn(a), self.police)
        return r

    # ------------------------------------------------------- texte courant
    def p(self, parts, align=JUST, space=8, before=0, size=None, italic=False,
          style=None):
        """`parts` est soit une chaîne, soit une liste de couples (texte, gras).
        Le découpage en couples sert à mettre en gras les seules valeurs qui
        portent la démonstration, sans recourir à la couleur."""
        par = self.doc.add_paragraph(style=style) if style else self.doc.add_paragraph()
        par.alignment = align
        par.paragraph_format.space_after = Pt(space)
        par.paragraph_format.space_before = Pt(before)
        if isinstance(parts, str):
            parts = [(parts, False)]
        for t, b in parts:
            self._run(par, t, bold=b, size=size, italic=italic)
        return par

    def puce(self, parts, space=4):
        return self.p(parts, space=space, style='List Bullet')

    def titre(self, texte, niveau=1):
        h = self.doc.add_heading(texte, niveau)
        for r in h.runs:
            r.font.color.rgb = NOIR
            rf = r._element.get_or_add_rPr().get_or_add_rFonts()
            for a in ('w:ascii', 'w:hAnsi', 'w:cs', 'w:eastAsia'):
                rf.set(qn(a), self.police)
        return h

    def saut_page(self):
        self.doc.add_page_break()

    # ------------------------------------------------------------ tableaux
    def _grille(self, t, sz=4):
        tp = t._tbl.tblPr
        for vieux in tp.findall(qn('w:tblBorders')):
            tp.remove(vieux)
        b = OxmlElement('w:tblBorders')
        for arete in ('top', 'left', 'bottom', 'right', 'insideH', 'insideV'):
            e = OxmlElement(f'w:{arete}')
            e.set(qn('w:val'), 'single'); e.set(qn('w:sz'), str(sz))
            e.set(qn('w:color'), '000000'); e.set(qn('w:space'), '0')
            b.append(e)
        tp.append(b)

    def _marges_cellules(self, t, haut=50, bas=50, gauche=110, droite=110):
        m = OxmlElement('w:tblCellMar')
        for tag, v in (('top', haut), ('bottom', bas), ('left', gauche), ('right', droite)):
            e = OxmlElement(f'w:{tag}')
            e.set(qn('w:w'), str(v)); e.set(qn('w:type'), 'dxa')
            m.append(e)
        t._tbl.tblPr.append(m)

    def tableau(self, entetes, lignes, widths=None, fs=9.5,
                premiere_colonne_a_gauche=True, legende=None, grille=True):
        """Tableau en grille simple. `entetes` peut contenir des chaînes vides
        pour un bloc à deux colonnes sans en-tête visible."""
        t = self.doc.add_table(rows=1, cols=len(entetes))
        t.alignment = WD_TABLE_ALIGNMENT.CENTER
        t.autofit = False
        if grille:
            self._grille(t)
        self._marges_cellules(t)
        for i, h in enumerate(entetes):
            c = t.rows[0].cells[i]
            par = c.paragraphs[0]
            par.paragraph_format.space_before = par.paragraph_format.space_after = Pt(2)
            par.alignment = GAUCHE if (i == 0 and premiere_colonne_a_gauche) else CENTRE
            self._run(par, h, bold=True, size=fs)
        for ligne in lignes:
            cells = t.add_row().cells
            for i, v in enumerate(ligne):
                par = cells[i].paragraphs[0]
                par.paragraph_format.space_before = par.paragraph_format.space_after = Pt(2)
                if not (i == 0 and premiere_colonne_a_gauche):
                    par.alignment = CENTRE
                self._run(par, str(v), size=fs)
        if widths:
            for row in t.rows:
                for i, w in enumerate(widths):
                    row.cells[i].width = Cm(w)
        if legende:
            self.legende(legende)
        else:
            self.doc.add_paragraph().paragraph_format.space_after = Pt(6)
        return t

    def legende(self, texte, prefixe="Tableau"):
        self._n_tableaux += 1
        par = self.doc.add_paragraph()
        par.paragraph_format.space_before = Pt(3)
        par.paragraph_format.space_after = Pt(11)
        self._run(par, f"{prefixe} {self._n_tableaux}. ", bold=True, size=9)
        self._run(par, texte, size=9, italic=True)
        return par

    # -------------------------------------------------------- page de garde
    def bandeau(self, *lignes):
        """Lignes d'identification institutionnelle, la dernière en gras."""
        for i, l in enumerate(lignes):
            dernier = i == len(lignes) - 1
            self.p([(l, dernier)], align=GAUCHE, space=18 if dernier else 1, size=10)

    def titre_note(self, surtitre, intitule, taille=16):
        self.p([(surtitre, True)], align=GAUCHE, space=6, size=10.5)
        self.p([(intitule, True)], align=GAUCHE, space=16, size=taille)

    def bloc_identification(self, couples, largeurs=(4.2, 12.0), fs=10):
        """Tableau à deux colonnes sans en-tête : Destinataire, Objet, Sources."""
        return self.tableau(["", ""], [[k, v] for k, v in couples],
                            widths=list(largeurs), fs=fs)

    # ------------------------------------------------------- en-tête, pied
    def _champ(self, par, instr):
        for typ in ('begin',):
            r = self._run(par, "")
            e = OxmlElement('w:fldChar'); e.set(qn('w:fldCharType'), typ)
            r._element.append(e)
        r = self._run(par, "")
        it = OxmlElement('w:instrText')
        it.set(qn('xml:space'), 'preserve'); it.text = instr
        r._element.append(it)
        r = self._run(par, "")
        e = OxmlElement('w:fldChar'); e.set(qn('w:fldCharType'), 'end')
        r._element.append(e)

    def entete_pied(self, entete=None, pied=None, pagination=True):
        s = self.section
        # sans cette bascule, python-docx ne crée pas les parties header/footer
        s.header.is_linked_to_previous = False
        s.footer.is_linked_to_previous = False
        if entete:
            par = s.header.paragraphs[0]
            par.alignment = WD_ALIGN_PARAGRAPH.RIGHT
            self._run(par, entete, italic=True, size=8.5)
        if pied or pagination:
            par = s.footer.paragraphs[0]
            largeur = (s.page_width - s.left_margin - s.right_margin)
            par.paragraph_format.tab_stops.add_tab_stop(largeur, WD_TAB_ALIGNMENT.RIGHT)
            if pied:
                self._run(par, pied, size=8.5)
            if pagination:
                self._run(par, "\t", size=8.5)
                self._run(par, "Page ", size=8.5)
                self._champ(par, " PAGE ")
                self._run(par, " sur ", size=8.5)
                self._champ(par, " NUMPAGES ")

    # ----------------------------------------------------------- écriture
    def save(self, chemin, verifier=True):
        """Écrit le document. `verifier` relit le fichier produit et refuse les
        tirets cadratins : c'est le seul contrôle qui attrape une ponctuation
        glissée dans une chaîne de données plutôt que dans le texte rédigé."""
        self.doc.save(chemin)
        if verifier:
            controler(chemin)
        return chemin


def pages(chemin):
    """Nombre de pages réel, mesuré par Word (macOS). Renvoie None si Word est
    absent. Compter les caractères donne une estimation qui se trompe d'une page
    entière sur un document à tableaux : quand la longueur est contractuelle,
    mesurer plutôt qu'estimer."""
    import subprocess
    script = f'''tell application "Microsoft Word"
  set wasRunning to running
  open POSIX file "{chemin}"
  delay 3
  set d to active document
  repaginate d
  set n to (compute statistics d statistic statistic pages)
  close d saving no
  if not wasRunning then quit
  return n
end tell'''
    try:
        r = subprocess.run(["osascript", "-e", script], capture_output=True, text=True, timeout=120)
        return int(r.stdout.strip())
    except Exception:
        return None


def controler(chemin):
    """Vérifie qu'un .docx respecte la charte sobre. Lève AssertionError sinon."""
    import zipfile, re
    z = zipfile.ZipFile(chemin)
    parties = [n for n in z.namelist()
               if n.startswith('word/') and n.endswith('.xml')
               and ('document' in n or 'header' in n or 'footer' in n)]
    for partie in parties:
        txt = z.read(partie).decode('utf-8')
        for ch, nom in (('—', 'tiret cadratin'), ('–', 'tiret demi-cadratin')):
            assert ch not in txt, f"{nom} présent dans {partie}"
        assert '<w:shd' not in txt, f"aplat de couleur présent dans {partie}"
        assert '<w:pBdr' not in txt, f"filet de paragraphe présent dans {partie}"
        couleurs = {c.lower() for c in re.findall(r'w:color w:val="([0-9A-Fa-f]{6})"', txt)}
        assert couleurs <= {'000000'}, f"couleurs non noires dans {partie} : {couleurs}"
    return True


if __name__ == "__main__":
    # auto-contrôle : produit un document minimal et vérifie la charte
    import tempfile, os
    chemin = os.path.join(tempfile.mkdtemp(), "autocontrole.docx")
    n = Note(entete="Auto-contrôle", pied="docx_sobre")
    n.bandeau("Organisation", "Direction")
    n.titre_note("NOTE", "Contrôle de la charte sobre")
    n.bloc_identification([("Destinataire", "Monsieur le Directeur"),
                           ("Objet", "Vérification du module")])
    n.titre("Partie unique", 1)
    n.p([("Valeur de contrôle : ", False), (num(0.166438), True),
         (", soit ", False), (pct(0.388229), True), (" de la population.", False)])
    n.puce([("Une puce", True), (", suivie de texte courant.", False)])
    n.tableau(["Région", "Population", "Indice"],
              [["Bounkani", mil(426434), num(0.365384)],
               ["Abidjan", mil(6297765), num(0.006901)]],
              widths=[6, 4, 4], legende="Deux régions extrêmes.")
    n.save(chemin)
    assert pct(0.388229) == "38,8 %" and num(0.166438) == "0,1664" and mil(5616487) == "5 616 487"
    print("auto-contrôle réussi :", chemin)
