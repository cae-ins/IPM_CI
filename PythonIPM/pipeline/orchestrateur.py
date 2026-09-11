"""Orchestrateur du pipeline IPM — chemins, outils partagés et exécution des étapes.

Le pipeline tourne sur DEUX sources, avec le même enchaînement d'étapes et la même méthode
Alkire-Foster : l'EHCVM 2021 (enquête, 12 965 ménages) et le RGPH 2021 (recensement,
5,6 millions de ménages). La source est portée par la variable d'environnement `IPM_SOURCE`
(`ehcvm` par défaut) ; elle détermine le dossier de données, la clé du ménage, les variables
de désagrégation disponibles et le SUFFIXE de tous les fichiers produits. Les sorties des deux
sources cohabitent donc sans se marcher dessus.

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
    python orchestrateur.py                    # les deux sources, tout le pipeline
    python orchestrateur.py --source rgph      # le RGPH seul
    python orchestrateur.py --check            # les auto-contrôles de chaque étape
"""
import logging
import os
import subprocess
import sys
import time
from pathlib import Path

import pandas as pd

# source courante : « ehcvm » (enquête) ou « rgph » (recensement)
SOURCE = os.environ.get("IPM_SOURCE", "ehcvm")
SOURCES = ("ehcvm", "rgph")
assert SOURCE in SOURCES, f"IPM_SOURCE doit valoir {' ou '.join(SOURCES)}, reçu {SOURCE!r}"

RACINE = Path(__file__).resolve().parent.parent   # PythonIPM/
DATA_EHCVM = RACINE / "Data" / "EHCVM"            # bases .dta d'origine, en lecture seule
DATA_RGPH = RACINE / "Data" / "RGPH_IPM"
DATA = DATA_EHCVM if SOURCE == "ehcvm" else DATA_RGPH
SORTIES = RACINE / "sorties"                      # tables produites par le pipeline
SORTIES_DTA = SORTIES / "dta"                     #   format Stata : ce que lit l'étape suivante
SORTIES_CSV = SORTIES / "csv"                     #   format texte : lecture humaine, R
SORTIES_XLSX = SORTIES / "xlsx"                   #   classeurs de restitution
LOGS = RACINE / "logs"                            # un journal par étape
PIPELINE = Path(__file__).resolve().parent        # les scripts d'étape
for dossier in (SORTIES_DTA, SORTIES_CSV, SORTIES_XLSX, LOGS):
    dossier.mkdir(parents=True, exist_ok=True)

JOURNAL_PIPELINE = LOGS / "00_pipeline.log"

# les étapes, dans l'ordre d'exécution — seule la préconstruction diffère d'une source à
# l'autre : elle lit des bases sans rapport. À partir de l'étape 02 le code est commun, il ne
# travaille plus que sur des colonnes de situation normalisées.
ETAPES_PAR_SOURCE = {
    "ehcvm": ["01_preconstruction_matrice_situationnelle.py"],
    "rgph": ["01_rgph_preconstruction_matrice_situationnelle.py"],
}
ETAPES_COMMUNES = [
    "02_construction_matrice_situationnelle.py",
    "03_matrice_privations_ponderees.py",
    "04_matrice_privations_censuree.py",
    "05_indices_ipm.py",
]
ETAPES = ETAPES_PAR_SOURCE[SOURCE] + ETAPES_COMMUNES

# suffixe de tous les fichiers produits : c'est lui qui fait cohabiter les deux IPM
SUFFIXE = {"ehcvm": "ehcvm2021", "rgph": "rgph2021"}[SOURCE]

# clé d'un ménage : grappe/ménage/vague dans l'EHCVM, identifiant national dans le RGPH
CLE = {"ehcvm": ["grappe", "menage", "vague"], "rgph": ["id_menage"]}[SOURCE]

# Variables de pondération et de désagrégation transportées d'une étape à l'autre.
# RGPH : `id_menage` est la clé (donc l'index) et n'est pas reprise ici ; le sexe du chef n'est
# pas dans l'extrait de recensement ; `grappe` (la zone de dénombrement) est une colonne, alors
# qu'elle fait partie de la clé dans l'EHCVM.
COLONNES_TECHNIQUES = {
    "ehcvm": ["id_menage", "ponderation_menage", "taille_menage",
              "region", "departement", "sous_prefecture", "milieu", "sexe_cm"],
    "rgph": ["ponderation_menage", "taille_menage",
             "region", "departement", "sous_prefecture", "milieu", "grappe"],
}[SOURCE]


def nom(base):
    """« matrice_situationnelle » -> « matrice_situationnelle_rgph2021 »."""
    return f"{base}_{SUFFIXE}"


# Socle commun aux deux sources : les indicateurs que l'EHCVM ET le RGPH savent mesurer. Il
# sert à la variante « harmonisée » de l'étape 05, seule comparable en niveau d'une source à
# l'autre — les IPM complets ne le sont pas, puisque chacun exploite ce que sa source mesure.
# Sont hors socle : côté EHCVM l'assurance maladie, l'insécurité alimentaire, le renoncement
# aux soins et la promiscuité ; côté RGPH la mortalité. La dimension Santé n'a donc aucun
# indicateur commun : la variante harmonisée compte 3 dimensions et 12 indicateurs.
SOCLE_COMMUN = [
    "frequentation_scolaire", "annee_scolarite", "alphabetisation", "etat_civil",
    "chomage", "emploi_subsistance",
    "electricite", "logement", "eau_potable", "energie_cuisson", "toilette",
    "biens_equipement",
]


# Indicateurs produits par l'étape 02 mais HORS de l'IPM national : ils existent dans la
# matrice de privation et dans le vecteur z, et seules les variantes qui les nomment les
# emploient. `chomage_su3` (sous-utilisation SU3, EHCVM) est dans ce cas : il englobe le
# chômage BIT, les additionner compterait deux fois les mêmes chômeurs.
HORS_IPM_NATIONAL = ["chomage_su3"]


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


# Au-delà de ce nombre de lignes, le doublon CSV n'est plus écrit : sur les 5,6 millions de
# ménages du RGPH une matrice de travail pèse plusieurs gigaoctets en texte, que personne ne
# lit. Le .dta, lui, reste écrit — c'est l'entrée de l'étape suivante.
LIGNES_MAXIMUM_CSV = 1_000_000


def compacter(table):
    """Réduit les colonnes ENTIÈRES au plus petit type qui les contient, sans toucher aux
    flottants.

    Sur le RGPH la plupart des colonnes sont des effectifs (nombre d'enfants non scolarisés,
    de biens possédés...) qui tiennent dans un octet, et un indicateur vaut 0 ou 1 : les
    stocker en int64 quadruple à octuple la taille des fichiers de travail, pour cinq millions
    et demi de lignes.

    Une colonne flottante n'est réduite que si toutes ses valeurs sont des ENTIERS — cas des
    codes de nomenclature et des effectifs qu'un manquant force en flottant : jusqu'à 2^24, un
    float32 les représente exactement, la conversion ne perd donc rien. Les vrais flottants
    (scores cᵢ, pondérations) restent en float64 : ils sont comparés d'une étape à l'autre à
    1e-9 près, ce qu'un float32 ne tiendrait pas.
    """
    reduites = {c: pd.to_numeric(table[c], downcast="integer")
                for c in table.select_dtypes("integer").columns}

    for c in table.select_dtypes("floating").columns:
        valeurs = table[c].dropna()
        if valeurs.empty or (valeurs.eq(valeurs.round()).all()
                             and valeurs.abs().max() < 2 ** 24):
            reduites[c] = table[c].astype("float32")

    return table.assign(**reduites) if reduites else table


def exporter_table(table, nom, logger, index=True):
    """Écrit une table dans les deux formats : sorties/dta/<nom>.dta et sorties/csv/<nom>.csv.

    Le .dta est la sortie de travail (types conservés, relu par l'étape suivante) ; le .csv est
    la sortie de lecture. `nom` est donné SANS extension.
    """
    dta = SORTIES_DTA / f"{nom}.dta"
    csv = SORTIES_CSV / f"{nom}.csv"
    compacter(table).to_stata(dta, write_index=index, version=118)
    if len(table) <= LIGNES_MAXIMUM_CSV:
        table.to_csv(csv, index=index, encoding="utf8")
        taille_csv = f"csv {csv.stat().st_size / 1e6:.1f} Mo"
    else:
        csv = None
        taille_csv = f"csv non écrit (> {LIGNES_MAXIMUM_CSV:,} lignes)".replace(",", " ")

    logger.info("%-42s -> dta %.1f Mo | %s  (%d lignes x %d colonnes)",
                nom, dta.stat().st_size / 1e6, taille_csv, *table.shape)
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
                              capture_output=True, text=True, cwd=RACINE,
                              env={**os.environ, "IPM_SOURCE": SOURCE})
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
    logger.info("=== pipeline IPM — source %s, %d étapes ===", SOURCE, len(ETAPES))

    for numero, etape in enumerate(ETAPES, start=1):
        if not lancer(etape, arguments):
            logger.error("chaîne interrompue à l'étape %d/%d — les étapes suivantes ne sont "
                         "pas exécutées", numero, len(ETAPES))
            return 1

    logger.info("")
    logger.info("=== pipeline %s terminé : %d étapes en %.1f s ===", SOURCE, len(ETAPES),
                time.perf_counter() - debut)
    logger.info("sorties : %s", ", ".join(sorted(f.stem for f in SORTIES_DTA.glob("*.dta"))))
    logger.info("journal d'ensemble : %s", JOURNAL_PIPELINE)
    return 0


def lancer_source(source, arguments=()):
    """Relance cet orchestrateur pour UNE source, dans un sous-processus à `IPM_SOURCE` fixé.

    Un sous-processus et non un appel direct : SOURCE est lu à l'import et fige la clé, le
    suffixe et les chemins de tous les modules du pipeline. Changer de source en cours de
    processus ne rechargerait pas ces constantes.
    """
    resultat = subprocess.run([sys.executable, str(Path(__file__).resolve()), *arguments],
                              cwd=RACINE, env={**os.environ, "IPM_SOURCE": source})
    return resultat.returncode


if __name__ == "__main__":
    options = ["--check"] if "--check" in sys.argv else []

    if "--source" in sys.argv:
        # une source précise : on est (ou on devient) le processus de cette source
        demandee = sys.argv[sys.argv.index("--source") + 1]
        sys.exit(main(options) if demandee == SOURCE else lancer_source(demandee, options))

    if os.environ.get("IPM_SOURCE"):
        sys.exit(main(options))      # appelé par lancer_source : on exécute la chaîne

    # appel nu : les deux IPM, l'un après l'autre
    for source in SOURCES:
        print(f"\n{'#' * 78}\n### source {source}\n{'#' * 78}")
        if lancer_source(source, options):
            sys.exit(f"pipeline interrompu sur la source {source}")
    sys.exit(0)
