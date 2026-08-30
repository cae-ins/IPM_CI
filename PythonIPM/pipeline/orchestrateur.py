"""Orchestrateur du pipeline IPM — chemins, outils partagés et exécution des étapes.

Deux rôles :

1. **socle commun** : chemins du projet, clé de fusion, colonnes transportées d'une étape à
   l'autre, journalisation. Les modules `01_`, `02_`... commencent par un chiffre et ne peuvent
   pas s'importer entre eux : ce qui leur est commun vit ici.
2. **chef d'orchestre** : `python orchestrateur.py` enchaîne les étapes dans l'ordre et écrit un
   journal d'ensemble (`logs/00_pipeline.log`) qui reprend la sortie console de chacune. Chaque
   étape reste exécutable seule et garde son propre journal détaillé.

Les étapes sont lancées en sous-processus : une étape qui échoue arrête la chaîne, et l'import
circulaire (les étapes importent ce module) est évité.

Usage :
    python orchestrateur.py            # tout le pipeline
    python orchestrateur.py --check    # les auto-contrôles de chaque étape
"""
import logging
import subprocess
import sys
import time
from pathlib import Path

RACINE = Path(__file__).resolve().parent.parent   # PythonIPM/
DATA = RACINE / "EHCVM"                           # bases .dta d'origine, en lecture seule
SORTIES = RACINE / "sorties"                      # tables produites par le pipeline
SORTIES_DTA = SORTIES / "dta"                     #   format Stata : ce que lit l'étape suivante
SORTIES_CSV = SORTIES / "csv"                     #   format texte : lecture humaine, R
SORTIES_XLSX = SORTIES / "xlsx"                   #   classeurs de restitution
LOGS = RACINE / "logs"                            # un journal par étape
PIPELINE = Path(__file__).resolve().parent        # les scripts d'étape
for dossier in (SORTIES_DTA, SORTIES_CSV, SORTIES_XLSX, LOGS):
    dossier.mkdir(parents=True, exist_ok=True)

JOURNAL_PIPELINE = LOGS / "00_pipeline.log"

# les étapes, dans l'ordre d'exécution
ETAPES = [
    "01_preconstruction_matrice_situationnelle.py",
    "02_construction_matrice_situationnelle.py",
    "03_matrice_privations_ponderees.py",
    "04_matrice_privations_censuree.py",
    "05_indices_ipm.py",
]

# clé d'un ménage EHCVM
CLE = ["grappe", "menage", "vague"]

# variables de pondération et de désagrégation transportées d'une étape à l'autre
COLONNES_TECHNIQUES = ["id_menage", "ponderation_menage", "taille_menage",
                       "region", "departement", "sous_prefecture", "milieu", "zone", "sexe_cm"]


def configurer_logs(logger, fichier=None, niveau=logging.INFO):
    """Console (niveau demandé) + fichier de log détaillé (DEBUG)."""
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
        logger.debug("journal ouvert : %s", fichier)
    return logger


def exporter_table(table, nom, logger, index=True):
    """Écrit une table dans les deux formats : sorties/dta/<nom>.dta et sorties/csv/<nom>.csv.

    Le .dta est la sortie de travail (types conservés, relu par l'étape suivante) ; le .csv est
    la sortie de lecture. `nom` est donné SANS extension.
    """
    dta = SORTIES_DTA / f"{nom}.dta"
    csv = SORTIES_CSV / f"{nom}.csv"
    table.to_stata(dta, write_index=index, version=118)
    table.to_csv(csv, index=index, encoding="utf8")

    logger.info("%-42s -> dta %.1f Mo | csv %.1f Mo  (%d lignes x %d colonnes)",
                nom, dta.stat().st_size / 1e6, csv.stat().st_size / 1e6, *table.shape)
    return dta, csv


def part(effectif, total):
    """« 1 204 (2,6 %) » — un effectif ne se lit jamais sans son dénominateur."""
    if not total:
        return f"{effectif:,}".replace(",", " ")
    return f"{effectif:,}".replace(",", " ") + f" ({effectif / total:.1%})"


# --------------------------------------------------------------------------- #
# exécution de la chaîne
# --------------------------------------------------------------------------- #
logger = logging.getLogger("ipm.orchestrateur")


def lancer(etape, arguments=()):
    """Exécute une étape en sous-processus et recopie sa sortie dans le journal d'ensemble.

    Renvoie True si l'étape s'est terminée sans erreur. Un fichier d'étape absent est traité
    comme un échec : la chaîne s'arrête plutôt que de produire une sortie incomplète.
    """
    script = PIPELINE / etape
    if not script.exists():
        logger.error("étape introuvable : %s", script)
        return False

    logger.info("")
    logger.info("=" * 78)
    logger.info(">>> %s %s", etape, " ".join(arguments))
    logger.info("=" * 78)

    debut = time.perf_counter()
    resultat = subprocess.run([sys.executable, str(script), *arguments],
                              capture_output=True, text=True, cwd=RACINE)
    duree = time.perf_counter() - debut

    for ligne in resultat.stdout.splitlines():
        logger.info("    %s", ligne)
    if resultat.stderr.strip():
        logger.error("sortie d'erreur :\n%s", resultat.stderr.rstrip())

    if resultat.returncode == 0:
        logger.info("<<< %s : OK (%.1f s)", etape, duree)
        return True
    logger.error("<<< %s : ÉCHEC (code %d, %.1f s)", etape, resultat.returncode, duree)
    return False


def main(arguments=()):
    configurer_logs(logger, JOURNAL_PIPELINE)
    debut = time.perf_counter()
    logger.info("=== pipeline IPM — %d étapes ===", len(ETAPES))

    for numero, etape in enumerate(ETAPES, start=1):
        if not lancer(etape, arguments):
            logger.error("chaîne interrompue à l'étape %d/%d — les étapes suivantes ne sont "
                         "pas exécutées", numero, len(ETAPES))
            return 1

    logger.info("")
    logger.info("=== pipeline terminé : %d étapes en %.1f s ===", len(ETAPES),
                time.perf_counter() - debut)
    logger.info("sorties : %s", ", ".join(sorted(f.stem for f in SORTIES_DTA.glob("*.dta"))))
    logger.info("journal d'ensemble : %s", JOURNAL_PIPELINE)
    return 0


if __name__ == "__main__":
    sys.exit(main(["--check"] if "--check" in sys.argv else []))
