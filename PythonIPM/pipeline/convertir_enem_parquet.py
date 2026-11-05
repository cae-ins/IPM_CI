"""Convertit les bases ENEM (.dta) de Data/ENEM en fichiers parquet, à côté des .dta.

Pourquoi : un parquet est 5 à 10 fois plus léger qu'un .dta et se lit beaucoup plus vite. Rien n'est
perdu : les valeurs sont conservées telles quelles (codes numériques, pas de catégories), et les
étiquettes Stata (libellés de variables et de modalités) sont rangées dans les métadonnées du fichier.

Lire un parquet avec ses étiquettes :
    from convertir_enem_parquet import lire_etiquettes
    df = pd.read_parquet(chemin)
    libelles_variables, libelles_modalites = lire_etiquettes(chemin)

Usage :
    python convertir_enem_parquet.py            # convertit les .dta qui n'ont pas encore de parquet
    python convertir_enem_parquet.py --force    # reconvertit tout
    python convertir_enem_parquet.py --check    # auto-contrôle sur un petit cas
Les parquet sont ignorés par git (voir .gitignore). Les .dta restent en place : le pipeline les lit.
"""
import json
import sys
import tempfile
import time
from pathlib import Path

import pandas as pd
import pyarrow as pa
import pyarrow.parquet as pq

RACINE = Path(__file__).resolve().parent.parent
DATA_ENEM = RACINE / "Data" / "ENEM"
CLE_VARIABLES = b"stata_variable_labels"
CLE_MODALITES = b"stata_value_labels"


def convertir(dta, parquet=None):
    """Écrit `parquet` (par défaut à côté de `dta`) et renvoie (lignes, colonnes, taille en octets)."""
    parquet = Path(parquet) if parquet else Path(dta).with_suffix(".parquet")
    lecteur = pd.io.stata.StataReader(dta)
    df = lecteur.read(convert_categoricals=False)      # les codes restent des codes
    libelles_variables = lecteur.variable_labels()
    jeux = lecteur.value_labels()
    modalites = {variable: {str(int(code)): str(libelle) for code, libelle in jeux[jeu].items()}
                 for variable, jeu in zip(lecteur._varlist, lecteur._lbllist) if jeu in jeux}

    table = pa.Table.from_pandas(df, preserve_index=False)
    meta = dict(table.schema.metadata or {})
    meta[CLE_VARIABLES] = json.dumps(libelles_variables, ensure_ascii=False).encode()
    meta[CLE_MODALITES] = json.dumps(modalites, ensure_ascii=False).encode()
    pq.write_table(table.replace_schema_metadata(meta), parquet, compression="zstd", compression_level=3)
    return len(df), df.shape[1], parquet.stat().st_size


def lire_etiquettes(parquet):
    """(libellés des variables, libellés des modalités par variable) rangés dans un parquet converti."""
    meta = pq.read_schema(parquet).metadata or {}
    return (json.loads(meta.get(CLE_VARIABLES, b"{}")), json.loads(meta.get(CLE_MODALITES, b"{}")))


def verifier_fichier(dta, parquet):
    """Relit le parquet et le compare au .dta : mêmes dimensions, mêmes noms, mêmes valeurs."""
    df = pd.read_stata(dta, convert_categoricals=False)
    retour = pd.read_parquet(parquet)
    assert df.shape == retour.shape, f"{Path(dta).name} : {df.shape} contre {retour.shape}"
    assert list(df.columns) == list(retour.columns), "noms de colonnes différents"
    # une date garde le même instant mais change d'unité entre les deux lectures (secondes, millisecondes)
    for colonne in df.columns:
        if pd.api.types.is_datetime64_any_dtype(df[colonne]):
            df[colonne] = df[colonne].astype("datetime64[ns]")
            retour[colonne] = retour[colonne].astype("datetime64[ns]")
    pd.testing.assert_frame_equal(df, retour, check_dtype=False, check_exact=False, rtol=1e-12)
    return True


def main(force=False):
    dtas = sorted(DATA_ENEM.rglob("*.dta"))
    assert dtas, f"aucun .dta dans {DATA_ENEM}"
    total_dta = total_pq = 0
    for dta in dtas:
        parquet = dta.with_suffix(".parquet")
        nom = dta.relative_to(DATA_ENEM)
        if parquet.exists() and not force:
            print(f"  déjà converti  {nom}")
            continue
        debut = time.perf_counter()
        lignes, colonnes, taille = convertir(dta)
        verifier_fichier(dta, parquet)
        total_dta += dta.stat().st_size
        total_pq += taille
        print(f"  {str(nom):62} {lignes:>7} x {colonnes:<4} {dta.stat().st_size / 1e6:7.1f} Mo -> "
              f"{taille / 1e6:6.1f} Mo ({time.perf_counter() - debut:.1f} s)")
    if total_dta:
        print(f"\ntotal : {total_dta / 1e6:.0f} Mo (.dta) -> {total_pq / 1e6:.0f} Mo (.parquet), "
              f"soit {total_dta / total_pq:.1f} fois plus léger")


def verifier():
    """Cas construit à la main : valeurs, étiquettes de variables et de modalités survivent à l'aller-retour."""
    with tempfile.TemporaryDirectory() as dossier:
        dta, pqt = Path(dossier) / "t.dta", Path(dossier) / "t.parquet"
        df = pd.DataFrame({"sexe": [1, 2, 1], "age": [10.5, None, 3.0], "nom": ["a", "", "c"]})
        df.to_stata(dta, variable_labels={"sexe": "Sexe de la personne"}, value_labels={"sexe": {1: "Homme", 2: "Femme"}},
                    write_index=False)
        lignes, colonnes, _ = convertir(dta, pqt)
        assert (lignes, colonnes) == (3, 3)
        assert verifier_fichier(dta, pqt)
        libelles, modalites = lire_etiquettes(pqt)
        assert libelles["sexe"] == "Sexe de la personne", libelles
        assert modalites["sexe"] == {"1": "Homme", "2": "Femme"}, modalites
        assert pd.read_parquet(pqt).sexe.tolist() == [1, 2, 1]          # des codes, pas des textes
    print("auto-contrôle conversion parquet : OK")


if __name__ == "__main__":
    if "--check" in sys.argv:
        verifier()
    else:
        main(force="--force" in sys.argv)
