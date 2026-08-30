"""Compile les documents LaTeX de documentation/ et les dépose dans sorties/.

    documentation/*.tex  --(tectonic, ou xelatex en repli)-->  sorties/pdf/*.pdf
                          --(copie)------------------------->  sorties/tex/*.tex

Les .tex restent la source, versionnée dans documentation/ ; sorties/ reçoit à la fois le PDF
livrable et sa source, pour qu'un dossier de sorties soit auto-suffisant.

Deux moteurs supportés : `tectonic` (autonome, télécharge ses paquets — pratique sur Mac/Linux,
`brew install tectonic`) en priorité, sinon `xelatex` (MiKTeX, souvent déjà présent sur les
machines Windows de l'équipe) en repli automatique — le préambule exige XeTeX de toute façon
(UTF-8 natif, pas d'inputenc/fontenc), donc pdflatex n'est pas une option.

Usage :
    python documentation/generer_documents.py
"""
import os
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

# xelatex fait 3 passes pour résoudre la table des matières (tectonic le fait tout seul)
PASSES_XELATEX = 3


def documents():
    return sorted(f for f in DOCUMENTATION.glob("*.tex") if f.name != PREAMBULE)


def _environnement_sans_path_corrompu():
    """PATH peut contenir un exécutable au lieu d'un dossier (constaté avec un installeur Stata,
    `...\\Stata17\\StataMP-64.exe`) : certains outils Windows s'y étranglent en énumérant PATH.
    On filtre ces entrées avant de lancer un sous-processus."""
    env = os.environ.copy()
    dossiers = [p for p in env.get("PATH", "").split(os.pathsep) if p and Path(p).is_dir()]
    env["PATH"] = os.pathsep.join(dossiers)
    return env


def compiler_tectonic(source):
    resultat = subprocess.run(["tectonic", "-k", source.name],
                              cwd=DOCUMENTATION, capture_output=True, text=True)
    if resultat.returncode != 0:
        print(f"ÉCHEC  {source.name} (tectonic)")
        print(resultat.stderr.strip()[-1500:])
        return None
    return source.with_suffix(".pdf")


def compiler_xelatex(source):
    env = _environnement_sans_path_corrompu()
    for passe in range(1, PASSES_XELATEX + 1):
        resultat = subprocess.run(
            ["xelatex", "-interaction=nonstopmode", "-halt-on-error", source.name],
            cwd=DOCUMENTATION, capture_output=True, text=True, env=env)
        if resultat.returncode != 0:
            print(f"ÉCHEC  {source.name} (xelatex, passe {passe}/{PASSES_XELATEX})")
            print(resultat.stdout.strip()[-1500:])
            return None
    return source.with_suffix(".pdf")


def compiler(source, moteur):
    """`moteur` = "tectonic" ou "xelatex", choisi une fois dans main() selon ce qui est présent."""
    return compiler_tectonic(source) if moteur == "tectonic" else compiler_xelatex(source)


def main():
    if shutil.which("tectonic") is not None:
        moteur = "tectonic"
    elif shutil.which("xelatex") is not None:
        moteur = "xelatex"
        print("tectonic introuvable, compilation avec xelatex (MiKTeX) à la place.\n")
    else:
        sys.exit("ni tectonic ni xelatex trouvés — installation : brew install tectonic "
                  "(Mac/Linux) ou MiKTeX (Windows, https://miktex.org)")

    SORTIES_PDF.mkdir(parents=True, exist_ok=True)
    SORTIES_TEX.mkdir(parents=True, exist_ok=True)

    echecs = 0
    for source in documents():
        pdf = compiler(source, moteur)
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
