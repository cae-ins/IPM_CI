"""Compile les documents LaTeX de documentation/ et les dépose dans sorties/.

    documentation/*.tex  --(tectonic)-->  sorties/pdf/*.pdf
                          --(pandoc)---->  sorties/docx/*.docx
                          --(copie)---->  sorties/tex/*.tex

Les .tex restent la source, versionnée dans documentation/ ; sorties/ reçoit le PDF livrable, sa
version Word modifiable et sa source, pour qu'un dossier de sorties soit auto-suffisant.

Le PDF fait foi : c'est lui qui est mis en page. Le .docx est là pour être retouché — il perd la
mise en page fine (encadrés colorés, filets des tableaux) mais garde tout le contenu, les tableaux,
les titres et la table des matières.

Usage :
    python documentation/generer_documents.py
"""
import re
import shutil
import subprocess
import sys
from pathlib import Path

DOCUMENTATION = Path(__file__).resolve().parent
RACINE = DOCUMENTATION.parent
SORTIES_PDF = RACINE / "sorties" / "pdf"
SORTIES_TEX = RACINE / "sorties" / "tex"
SORTIES_DOCX = RACINE / "sorties" / "docx"

# le préambule est inclus par les autres, il ne se compile pas seul
PREAMBULE = "preambule.tex"

# fichiers auxiliaires de LaTeX, à ne pas laisser traîner dans documentation/
AUXILIAIRES = [".aux", ".log", ".out", ".toc"]

# Encadrés tcolorbox : pandoc lit bien leur contenu mais JETTE leur titre, qui est un argument
# optionnel d'environnement. On le réinjecte en gras dans le corps, et l'encadré devient une
# citation — le seul équivalent Word qui reste modifiable sans styles maison.
ENCADRES = {"retenir": "", "attention": "Attention --- "}

# Régions mathématiques du document. \ipm vaut \ensuremath{M_{0}} : pandoc le traduit très bien
# dans le texte courant (« M₀ »), mais son moteur de formules ne connaît pas \ensuremath et
# abandonne la formule entière dès qu'il l'y rencontre. À l'intérieur des formules seulement, la
# macro est donc remplacée par ce qu'elle vaut en mode mathématique.
MATHEMATIQUES = re.compile(r"\$[^$]*\$|\\\[.*?\\\]|\\begin\{align\}.*?\\end\{align\}",
                           re.DOTALL)

# Seconde limite du moteur de formules de pandoc : une commande de police à l'intérieur d'un
# \text{} mathématique — « \text{\emph{incidence} : ... } » — lui fait abandonner la formule
# entière. L'italique y est décoratif : on le retire, dans les formules seulement.
POLICE_EN_FORMULE = re.compile(r"\\(?:emph|textit|textbf|textsf)\{([^{}]*)\}")


def documents():
    return sorted(f for f in DOCUMENTATION.glob("*.tex") if f.name != PREAMBULE)


def pour_pandoc(source):
    """Réécrit le .tex en une variante que pandoc traduit sans rien perdre.

    Renvoie le chemin du fichier temporaire, déposé dans documentation/ pour que
    `\input{preambule}` continue de se résoudre.
    """
    texte = source.read_text(encoding="utf8")
    def simplifier_formule(trouve):
        formule = trouve.group(0).replace(r"\ipm{}", "M_{0}").replace(r"\ipm", "M_{0}")
        return POLICE_EN_FORMULE.sub(r"\1", formule)

    texte = MATHEMATIQUES.sub(simplifier_formule, texte)

    for encadre, prefixe in ENCADRES.items():
        texte = re.sub(rf"\\begin{{{encadre}}}\[(.*?)\]",
                       lambda m, p=prefixe: f"\\begin{{quote}}\n\\textbf{{{p}{m.group(1)}}}\n",
                       texte, flags=re.S)
        texte = texte.replace(f"\\begin{{{encadre}}}", "\\begin{quote}")
        texte = texte.replace(f"\\end{{{encadre}}}", "\\end{quote}")

    temporaire = source.with_name(f"_pandoc_{source.name}")
    temporaire.write_text(texte, encoding="utf8")
    return temporaire


def convertir_docx(source):
    """documentation/<nom>.tex -> sorties/docx/<nom>.docx, via pandoc."""
    cible = SORTIES_DOCX / f"{source.stem}.docx"
    temporaire = pour_pandoc(source)
    try:
        resultat = subprocess.run(
            # `lang` évite que Word prenne le document pour de l'anglais et souligne tout
            ["pandoc", temporaire.name, "--standalone", "--toc", "--toc-depth=2",
             "--variable", "lang=fr-FR", "--output", str(cible)],
            cwd=DOCUMENTATION, capture_output=True, text=True)
    finally:
        temporaire.unlink(missing_ok=True)

    if resultat.returncode != 0:
        print(f"       docx : ÉCHEC — {resultat.stderr.strip()[-400:]}")
        return None
    for ligne in resultat.stderr.splitlines():
        if "WARNING" in ligne:
            print(f"       docx : {ligne.strip()}")
    return cible


def compiler(source):
    """tectonic télécharge ce dont il a besoin au premier passage : soyons patients."""
    resultat = subprocess.run(["tectonic", "-k", source.name],
                              cwd=DOCUMENTATION, capture_output=True, text=True)
    if resultat.returncode != 0:
        print(f"ÉCHEC  {source.name}")
        print(resultat.stderr.strip()[-1500:])
        return None
    return source.with_suffix(".pdf")


def main():
    if shutil.which("tectonic") is None:
        sys.exit("tectonic est introuvable — installation : brew install tectonic")
    pandoc = shutil.which("pandoc") is not None
    if not pandoc:
        print("pandoc est introuvable — les .docx ne seront pas produits "
              "(installation : brew install pandoc)\n")

    for dossier in (SORTIES_PDF, SORTIES_TEX, SORTIES_DOCX):
        dossier.mkdir(parents=True, exist_ok=True)

    echecs = 0
    for source in documents():
        pdf = compiler(source)
        if pdf is None:
            echecs += 1
            continue

        shutil.copy2(pdf, SORTIES_PDF / pdf.name)
        shutil.copy2(source, SORTIES_TEX / source.name)
        docx = convertir_docx(source) if pandoc else None
        print(f"OK     {source.name:<28} -> sorties/pdf/{pdf.name} "
              f"({pdf.stat().st_size / 1024:.0f} Ko)"
              + (f" + docx ({docx.stat().st_size / 1024:.0f} Ko)" if docx else ""))

    # le préambule accompagne les sources : sans lui elles ne recompilent pas
    shutil.copy2(DOCUMENTATION / PREAMBULE, SORTIES_TEX / PREAMBULE)

    for source in documents():
        for extension in AUXILIAIRES:
            source.with_suffix(extension).unlink(missing_ok=True)

    print(f"\n{len(documents()) - echecs}/{len(documents())} documents générés dans "
          f"{SORTIES_PDF.relative_to(RACINE)}, {SORTIES_DOCX.relative_to(RACINE)} et "
          f"{SORTIES_TEX.relative_to(RACINE)}")
    return 1 if echecs else 0


if __name__ == "__main__":
    sys.exit(main())
