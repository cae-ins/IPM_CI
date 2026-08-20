"""Compile les documents LaTeX de documentation/ et les dépose dans sorties/.

    documentation/*.tex  --(tectonic)-->  sorties/pdf/*.pdf
                          --(copie)---->  sorties/tex/*.tex

Les .tex restent la source, versionnée dans documentation/ ; sorties/ reçoit à la fois le PDF
livrable et sa source, pour qu'un dossier de sorties soit auto-suffisant.

Usage :
    python documentation/generer_documents.py
"""
import shutil
import subprocess
import sys
from pathlib import Path

DOCUMENTATION = Path(__file__).resolve().parent
RACINE = DOCUMENTATION.parent
SORTIES_PDF = RACINE / "sorties" / "pdf"
SORTIES_TEX = RACINE / "sorties" / "tex"

# le préambule est inclus par les autres, il ne se compile pas seul
PREAMBULE = "preambule.tex"

# fichiers auxiliaires de LaTeX, à ne pas laisser traîner dans documentation/
AUXILIAIRES = [".aux", ".log", ".out", ".toc"]


def documents():
    return sorted(f for f in DOCUMENTATION.glob("*.tex") if f.name != PREAMBULE)


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

    SORTIES_PDF.mkdir(parents=True, exist_ok=True)
    SORTIES_TEX.mkdir(parents=True, exist_ok=True)

    echecs = 0
    for source in documents():
        pdf = compiler(source)
        if pdf is None:
            echecs += 1
            continue

        shutil.copy2(pdf, SORTIES_PDF / pdf.name)
        shutil.copy2(source, SORTIES_TEX / source.name)
        print(f"OK     {source.name:<28} -> sorties/pdf/{pdf.name} "
              f"({pdf.stat().st_size / 1024:.0f} Ko)")

    # le préambule accompagne les sources : sans lui elles ne recompilent pas
    shutil.copy2(DOCUMENTATION / PREAMBULE, SORTIES_TEX / PREAMBULE)

    for source in documents():
        for extension in AUXILIAIRES:
            source.with_suffix(extension).unlink(missing_ok=True)

    print(f"\n{len(documents()) - echecs}/{len(documents())} documents générés dans "
          f"{SORTIES_PDF.relative_to(RACINE)} et {SORTIES_TEX.relative_to(RACINE)}")
    return 1 if echecs else 0


if __name__ == "__main__":
    sys.exit(main())
