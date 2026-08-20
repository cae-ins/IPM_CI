"""Outils partagés par les étapes du pipeline IPM (les modules 01_, 02_... commencent par
un chiffre et ne peuvent pas s'importer entre eux : ce qui est commun vit ici)."""
import logging
import sys
from pathlib import Path

RACINE = Path(__file__).resolve().parent.parent   # PythonIPM/
DATA = RACINE / "EHCVM"                           # bases .dta d'origine, en lecture seule
SORTIES = RACINE / "sorties"                      # tables produites par le pipeline
LOGS = RACINE / "logs"                            # un journal par étape
SORTIES.mkdir(exist_ok=True)
LOGS.mkdir(exist_ok=True)

# clé d'un ménage EHCVM
CLE = ["grappe", "menage", "vague"]

# variables de pondération et de désagrégation transportées d'une étape à l'autre
COLONNES_TECHNIQUES = ["id_menage", "ponderation_menage", "taille_menage",
                       "region", "milieu", "sexe_cm"]


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


def part(effectif, total):
    """« 1 204 (2,6 %) » — un effectif ne se lit jamais sans son dénominateur."""
    if not total:
        return f"{effectif:,}".replace(",", " ")
    return f"{effectif:,}".replace(",", " ") + f" ({effectif / total:.1%})"
