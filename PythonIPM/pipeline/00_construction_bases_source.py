"""Étape 00 du pipeline IPM — construction des 4 bases sources (EHCVM 2021).

Les fichiers bruts de l'EHCVM 2021 (46 fichiers sectionnels + fichiers consolidés) ne sont pas
ceux que l'étape 01 attend : elle lit 4 bases déjà assemblées et nommées —
Base_Menage.dta, Base_Individus.dta, Base_avoirs_du_menage.dta, Base_securite_alimentaire.dta
— dans PythonIPM/EHCVM/ (voir dictionnaire_ehcvm.py : BASES). Cette étape construit ces 4
fichiers à partir des sources brutes, une fois, avant de lancer le reste du pipeline.

Correspondance (vérifiée sur les fichiers réels, colonnes lues sans charger les données) :

    Base_avoirs_du_menage.dta       = s12_me_civ2021.dta                (copie directe)
    Base_securite_alimentaire.dta   = s08a_me_civ2021.dta                (copie directe)
    Base_Individus.dta              = s01_me + s02_me + s03_me + s04a_me (fusion sur la clé
                                       individu grappe+menage+vague+membres__id)
    Base_Menage.dta                 = ehcvm_welfare_civ2021 + s00_me + s11_me (fusion sur la
                                       clé ménage grappe+menage+vague)

`ehcvm_menage_civ2021.dta`, malgré son nom, ne porte pas les variables d'identification et de
pondération (hhid, region, milieu, hhweight, hhsize, hgender, hage, hcsp, dtot, pcexp, zref) :
elles sont dans `ehcvm_welfare_civ2021.dta`.

Usage :
    python 00_construction_bases_source.py
    python 00_construction_bases_source.py --check
"""
import logging
import sys
import time
from pathlib import Path

import pandas as pd

from orchestrateur import DATA, LOGS, configurer_logs

# Dossier des fichiers sectionnels bruts EHCVM 2021 — à adapter si les données sont déplacées.
SOURCE = Path(r"C:\Users\f.migone\OneDrive - GOUVCI\CAE_INS - Fichiers de Cellule d'Analyses "
              r"Economiques ( CAE)\IPM\IPM-CI\Data_results\Data\DataEHCVM2021")

CLE_MENAGE = ["grappe", "menage", "vague"]
CLE_INDIVIDU = CLE_MENAGE + ["membres__id"]

JOURNAL = LOGS / "00_construction_bases_source.log"
logger = logging.getLogger("ipm.construction_bases_source")


def _lire(fichier, colonnes=None):
    debut = time.perf_counter()
    d = pd.read_stata(SOURCE / fichier, columns=colonnes, convert_categoricals=False)
    logger.info("  %-32s %7d lignes x %3d colonnes  (%.1f s)",
                fichier, len(d), d.shape[1], time.perf_counter() - debut)
    return d


def _ecrire(table, nom, value_labels=None):
    chemin = DATA / nom
    table.to_stata(chemin, write_index=False, version=118, value_labels=value_labels)
    logger.info("-> %-32s %7d lignes x %3d colonnes  (%.1f Mo)",
                nom, *table.shape, chemin.stat().st_size / 1e6)


def _labels_categoriels(fichier, colonnes):
    """Recompose {colonne: {code: libellé}} à partir des catégories Stata d'origine.

    dictionnaire_ehcvm.modalites() relit ces libellés depuis Base_Menage.dta (value_labels()
    du fichier Stata) — `pd.read_stata(..., convert_categoricals=False)` ne les transporte
    pas automatiquement, il faut les recapturer et les réinjecter à l'écriture.
    """
    codes = _lire(fichier, colonnes)
    libelles = pd.read_stata(SOURCE / fichier, columns=colonnes, convert_categoricals=True)
    resultat = {}
    for colonne in colonnes:
        paires = (pd.DataFrame({"code": codes[colonne], "libelle": libelles[colonne].astype(str)})
                  .dropna().drop_duplicates())
        resultat[colonne] = dict(zip(paires.code.astype(int), paires.libelle))
    return resultat


def construire_avoirs():
    logger.info("--- Base_avoirs_du_menage.dta = s12_me_civ2021.dta ---")
    avoirs = _lire("s12_me_civ2021.dta")
    _ecrire(avoirs, "Base_avoirs_du_menage.dta")


def construire_securite_alimentaire():
    logger.info("--- Base_securite_alimentaire.dta = s08a_me_civ2021.dta ---")
    fies = _lire("s08a_me_civ2021.dta")
    _ecrire(fies, "Base_securite_alimentaire.dta")


def construire_individus():
    logger.info("--- Base_Individus.dta = s01_me + s02_me + s03_me + s04a_me ---")
    s01 = _lire("s01_me_civ2021.dta")
    s02 = _lire("s02_me_civ2021.dta")
    s03 = _lire("s03_me_civ2021.dta")
    s04a = _lire("s04a_me_civ2021.dta")

    individus = s01
    for nom, section in [("s02_me", s02), ("s03_me", s03), ("s04a_me", s04a)]:
        avant = len(individus)
        individus = individus.merge(section, on=CLE_INDIVIDU, how="left", validate="1:1")
        logger.info("  fusion %-8s : %d -> %d lignes", nom, avant, len(individus))

    _ecrire(individus, "Base_Individus.dta")


def construire_menage():
    logger.info("--- Base_Menage.dta = ehcvm_welfare + s00_me + s11_me ---")
    welfare = _lire("ehcvm_welfare_civ2021.dta")
    s00 = _lire("s00_me_civ2021.dta")
    s11 = _lire("s11_me_civ2021.dta")

    menage = welfare
    for nom, section in [("s00_me", s00), ("s11_me", s11)]:
        avant = len(menage)
        menage = menage.merge(section, on=CLE_MENAGE, how="left", validate="1:1")
        logger.info("  fusion %-8s : %d -> %d lignes", nom, avant, len(menage))

    # dictionnaire_ehcvm.modalites() relit les libellés de département/sous-préfecture
    # (s00q02, s00q03) depuis les value labels de Base_Menage.dta : à recapturer ici, sinon
    # l'étape 05 échoue en cherchant un value label absent (les codes bruts n'en portent pas).
    logger.info("  recapture des libellés département/sous-préfecture (s00q02, s00q03)")
    labels = _labels_categoriels("s00_me_civ2021.dta", ["s00q02", "s00q03"])

    _ecrire(menage, "Base_Menage.dta", value_labels=labels)


def construire():
    logger.info("=== étape 00 : construction des 4 bases sources (EHCVM 2021) ===")
    logger.info("source : %s", SOURCE)
    assert SOURCE.exists(), f"dossier source introuvable : {SOURCE}"

    construire_avoirs()
    construire_securite_alimentaire()
    construire_individus()
    construire_menage()


# --------------------------------------------------------------------------- #
# auto-contrôle
# --------------------------------------------------------------------------- #
def verifier():
    """Vérifie que le dossier source existe et que les fichiers attendus s'y trouvent."""
    configurer_logs(logger, niveau=logging.WARNING)

    attendus = ["s12_me_civ2021.dta", "s08a_me_civ2021.dta",
                "s01_me_civ2021.dta", "s02_me_civ2021.dta", "s03_me_civ2021.dta",
                "s04a_me_civ2021.dta", "ehcvm_welfare_civ2021.dta",
                "s00_me_civ2021.dta", "s11_me_civ2021.dta"]
    assert SOURCE.exists(), f"dossier source introuvable : {SOURCE}"
    manquants = [f for f in attendus if not (SOURCE / f).exists()]
    assert not manquants, f"fichiers sources manquants : {manquants}"

    print("auto-contrôle 00 : OK")


def main():
    configurer_logs(logger, JOURNAL)
    debut = time.perf_counter()

    construire()

    logger.info("=== terminé en %.1f s ===", time.perf_counter() - debut)


if __name__ == "__main__":
    if "--check" in sys.argv:
        verifier()
    else:
        main()
