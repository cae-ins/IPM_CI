"""Étape 06 (contrôle) — recalcule H, A, M0 et les contributions avec le package `afmpi`.

Le pipeline maison (étapes 03 à 05) et `afmpi` sont deux chemins de calcul indépendants pour
la même méthode Alkire-Foster. Cette étape les confronte sur la matrice de privation g0 de
l'étape 02 : tout écart au-delà de la tolérance arrête le script.

EHCVM  -> SurveyDesign(psu="grappe")  : variance de Taylor « ultimate cluster », la même que
          `ratio_et_ic()` de l'étape 05.
RGPH   -> CensusDesign(...)           : données exhaustives, SE = 0 par construction.

Usage :
    python 06_validation_afmpi.py              # source courante (IPM_SOURCE)
    IPM_SOURCE=rgph python 06_validation_afmpi.py
"""
import sys

import pandas as pd
from afmpi import CensusDesign, Specification, SurveyDesign, estimate

from orchestrateur import SORTIES_CSV, SORTIES_DTA, SOURCE, nom

TOLERANCE = 1e-6


def main():
    g0 = pd.read_stata(SORTIES_DTA / f"{nom('matrice_situationnelle')}.dta")
    z = pd.read_csv(SORTIES_CSV / f"{nom('vecteur_z')}.csv")
    spec = Specification(z.groupby("dimension").colonne.apply(list).to_dict())

    if SOURCE == "ehcvm":
        design = SurveyDesign(weights="ponderation_menage", household_size="taille_menage",
                              psu="grappe")
    else:
        design = CensusDesign(weights="ponderation_menage", household_size="taille_menage")

    res = estimate(g0, spec, design, k=1 / 3, over=["milieu", "region"])
    e = res.estimates()
    afmpi = e[e.measure.isin(["H", "A", "M0"]) & e.subgroup.isna()].set_index("measure")

    maison = pd.read_csv(SORTIES_CSV / f"{nom('indices_ipm_ci')}.csv")
    maison = maison[maison.variable == "Ensemble"].iloc[0]

    print(f"{SOURCE} — national, k = 1/3")
    for mesure, colonne in (("H", "H_incidence"), ("A", "A_intensite"), ("M0", "M0_ipm")):
        a, m = afmpi.est[mesure], maison[colonne]
        print(f"  {mesure:>2} : afmpi {a:.6f} | maison {m:.6f} | écart {a - m:+.2e}")
        assert abs(a - m) < TOLERANCE, f"{mesure} diverge : {a} vs {m}"

    if SOURCE == "ehcvm":
        se_a, se_m = afmpi.se["M0"], maison.M0_erreur_type
        print(f"  SE(M0) : afmpi {se_a:.6f} | maison {se_m:.6f} | écart {se_a - se_m:+.2e}")
        assert abs(se_a - se_m) < TOLERANCE, f"SE(M0) diverge : {se_a} vs {se_m}"

    # contributions : pctb_j d'afmpi == contribution_M0 du pipeline maison
    c = res.contributions()
    c = c[c.subgroup.isna()].set_index("indicator").pctb_j
    maison_c = pd.read_csv(SORTIES_CSV / f"{nom('contributions_ipm_ci')}.csv")
    ecart = (maison_c.set_index("colonne").contribution_M0 - c).abs().max()
    print(f"  contributions : écart max {ecart:.2e} sur {len(c)} indicateurs")
    assert ecart < TOLERANCE, f"contributions divergentes, écart max {ecart}"

    print("OK — les deux chemins de calcul concordent.")


if __name__ == "__main__":
    sys.exit(main())
