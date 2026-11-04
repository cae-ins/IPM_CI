"""Étape 01 — préconstruction de la matrice situationnelle, ENEM 2025 (quatre trimestres).

Entrée : Data/ENEM/ — individu et ménage de T1 à T4 2025, et les poids annuels 2025.
Sortie : preconstruction_matrice_situationnelle_enem2025_<bit|su3>   — une ligne par ménage retenu,
         les situations brutes (effectifs, codes) lues par l'étape 02.

Ce que l'ENEM a de particulier
------------------------------
Panel rotatif : un ménage est vu à t, t+1, t+4, t+5, et certaines questions ne sont posées qu'à la
première interrogation (logement, assurance maladie `M24A`, alphabétisation `EF16`). Pour ne
JAMAIS compléter une information par une autre visite, ni de 2024 ni de 2026, un ménage n'est
retenu que si toutes ces informations sont dans sa propre visite de 2025 : en pratique, les
ménages à leur première interrogation. Le chaînage des individus d'une visite à l'autre a été
testé et écarté (sexe différent pour 6 % des paires, âge incohérent pour un tiers).

Pondération
-----------
Chaque personne résidente porte le poids annuel 2025 (`FINAL_WEIGHT` = poids trimestriel / 4,
méthode « pooled-quarter » du manifeste LFS_WEIGHTS_2025). Les entrants ne sont qu'une partie de
l'échantillon : leurs poids sont calés, trimestre par trimestre, sur les totaux de population de
leur cellule direction régionale x milieu. Le ménage porte ensuite `ponderation_menage` tel que
`taille_menage x ponderation_menage` = somme des poids de ses membres, ce qui est exactement ce
que l'étape 02 attend (nᵢ = taille x pondération).

Les indicateurs de l'ENEM sont définis à l'étape 02 ; la présente étape ne seuille rien.
Seuils de cette étape (tranches d'âge, durée du travail) : constantes ci-dessous.

Usage :
    python 01_enem_preconstruction_matrice_situationnelle.py
    python 01_enem_preconstruction_matrice_situationnelle.py --check
"""
import logging
import sys
import time

import numpy as np
import pandas as pd

import dictionnaire_enem as dico
from orchestrateur import LOGS, SOURCE, configurer_logs, exporter_table, nom, part

NOM_SORTIE = nom("preconstruction_matrice_situationnelle")
JOURNAL = LOGS / "01_enem_preconstruction_matrice_situationnelle.log"
logger = logging.getLogger("ipm.enem.preconstruction")

# tranches d'âge des indicateurs (énoncés nationaux, comme dans l'EHCVM et le RGPH)
TRANCHES = {
    "scolarisation": (6, 16),
    "annees_etudes": (17, 95),
    "alphabetisation": (17, 49),
    "chomage": (17, 40),
    "neet": (15, 24),
    "emploi": (15, 120),
}
AGE_MAXIMUM = 120            # au-delà (codes « ne sait pas » : -9998...), l'âge est inconnu
# ponytail: 40 h = durée légale hebdomadaire hors agriculture, à confirmer avec l'INS ; 35 h est
# l'autre seuil courant (sous-emploi de 8,9 % des ménages contre 12,1 % à 40 h, T1 2026).
SEUIL_HEURES = 40
ANNEES_PAR_CLASSE = 3        # années d'études = classe achevée (EF4) - 3 : CP1 = 1 ... 3e = 10
COLONNES_LOGEMENT = ["materiau_mur", "source_eclairage", "source_eau_boisson", "type_sanitaire",
                     "evacuation_ordures", "evacuation_eaux_usees", "nb_pieces"]
COLONNES_DIFFICULTES = ["dif_vue", "dif_ouie", "dif_mains", "dif_communication", "dif_cognition"]


# --------------------------------------------------------------------------- #
# 1. lecture
# --------------------------------------------------------------------------- #
def lire_poids():
    """Poids annuels 2025 : un poids par personne résidente, clé de grappe."""
    logger.info("--- 1. poids annuels 2025 ---")
    W = pd.read_stata(dico.FICHIER_POIDS_ANNUEL, convert_categoricals=False)
    W["trimestre"] = "T" + W.trimestre.str[-1]
    W["membre"] = W.membres_id.astype(int)
    W = W.rename(columns={"FINAL_WEIGHT": "poids", "PSUKEY": "grappe"})
    logger.info("%d personnes pondérées, %d grappes, population annuelle %.1f millions",
                len(W), W.grappe.nunique(), W.poids.sum() / 1e6)
    return W[["trimestre", "interview_key", "membre", "poids", "grappe"]]


def lire_trimestre(t, W):
    """Personnes résidentes pondérées du trimestre, avec les attributs de leur ménage."""
    ind = pd.read_stata(dico.fichier_individus(t), convert_categoricals=False,
                        columns=list(dico.INDIVIDUS)).rename(columns=dico.INDIVIDUS)
    biens = {f"L11__{c}": f"bien_{n}" for n, c in dico.BIENS.items()}
    men = pd.read_stata(dico.fichier_menages(t), convert_categoricals=False,
                        columns=list(dico.MENAGES) + list(biens))
    men = men.rename(columns={**dico.MENAGES, **biens})

    ind["membre"] = ind.membre.astype(int)
    ind["age"] = ind.age.where(ind.age.between(0, AGE_MAXIMUM))
    P = ind.merge(W[W.trimestre == t].drop(columns="trimestre"), on=["interview_key", "membre"],
                  how="inner", validate="1:1")
    P = P.merge(men, on="interview_key", how="left", validate="m:1")
    logger.info("%s : %d individus (%d résidents pondérés), %d ménages avec roster, %d ménages "
                "dans le fichier ménage", t, len(ind), len(P), P.interview_key.nunique(), len(men))
    return P


# --------------------------------------------------------------------------- #
# 2. règle d'information complète
# --------------------------------------------------------------------------- #
def information_complete(P):
    """Ménages dont toutes les informations sont dans leur propre visite.

    Un ménage est retenu si : son logement est renseigné, tous ses membres ont répondu à
    l'assurance maladie, tous les 17-49 ans à l'alphabétisation, et aucun âge n'est inconnu.
    """
    a, b = TRANCHES["alphabetisation"]
    manque = pd.DataFrame({
        "logement": P[COLONNES_LOGEMENT].isna().any(axis=1),
        "assurance": P.assurance_maladie.isna(),
        "alphabetisation": P.age.between(a, b) & P.lit_francais.isna(),
        "age": P.age.isna(),
    })
    par_menage = manque.groupby(P.interview_key).any()
    retenus = ~par_menage.any(axis=1)
    return retenus[retenus].index, par_menage


# --------------------------------------------------------------------------- #
# 3. calage des poids des entrants sur la population du trimestre
# --------------------------------------------------------------------------- #
def caler(retenues, toutes, t):
    """Cale le poids des personnes retenues sur les totaux de leur cellule région x milieu.

    `toutes` = toutes les personnes pondérées du trimestre (suivies comprises) : ce sont elles
    qui portent la population à représenter. Un facteur d'échelle est appliqué par cellule.
    """
    cellule = ["direction_regionale", "milieu"]
    cible = toutes.groupby(cellule, observed=True).poids.sum()
    obtenu = retenues.groupby(cellule, observed=True).poids.sum()
    facteur = (cible / obtenu).rename("facteur")
    sans_entrants = cible.index.difference(obtenu.index)
    if len(sans_entrants):
        logger.warning("%s : %d cellules sans aucun entrant, population non représentée : %.2f %%",
                       t, len(sans_entrants), 100 * cible[sans_entrants].sum() / cible.sum())
    R = retenues.join(facteur, on=cellule)
    R["poids"] = R.poids * R.facteur
    logger.info("%s : calage sur %d cellules, facteur de %.2f à %.2f (médiane %.2f) ; population "
                "calée %.2f millions pour %.2f millions de personnes pondérées",
                t, len(facteur), facteur.min(), facteur.max(), facteur.median(),
                R.poids.sum() / 1e6, toutes.poids.sum() / 1e6)
    return R.drop(columns="facteur")


# --------------------------------------------------------------------------- #
# 4. situations individuelles puis agrégation par ménage
# --------------------------------------------------------------------------- #
def situations_individuelles(P):
    """Une colonne par situation : effectif concerné ou effectif en situation défavorable."""
    a = P.age
    tranche = lambda nom: a.between(*TRANCHES[nom])
    S = pd.DataFrame(index=P.index)

    # éducation
    S["enfants_6_16"] = tranche("scolarisation")
    jamais = P.deja_alle_ecole == 2
    S["enfants_6_16_non_scolarises"] = S.enfants_6_16 & (
        jamais | ((P.deja_alle_ecole == 1) & (P.frequente_ecole == 2)))
    annees = pd.Series(np.where(jamais, 0, (P.classe_achevee - ANNEES_PAR_CLASSE).clip(lower=0)),
                       index=P.index).where(jamais | P.classe_achevee.notna())
    S["membres_17_95"] = tranche("annees_etudes")
    S["annees"] = annees.where(S.membres_17_95)
    reponse = tranche("alphabetisation") & P.lit_francais.notna()
    S["membres_17_49"] = reponse
    S["membres_17_49_alphabetises"] = reponse & (P.lit_francais == 1) & (P.ecrit_francais == 1)

    # emploi : BIT = sans emploi + a cherché + disponible ; SU3 y ajoute la main-d'œuvre
    # potentielle (cherche sans être disponible, ou disponible sans chercher)
    cherche = (P.a_cherche_emploi == 1) | (P.a_tente_creer_entreprise == 1)
    disponible = P.disponible_deux_semaines == 1
    sans_emploi = P.en_emploi == 0
    S["membres_17_40"] = tranche("chomage")
    S["chomeurs_17_40"] = S.membres_17_40 & sans_emploi & cherche & disponible
    S["chomeurs_su3_17_40"] = S.membres_17_40 & sans_emploi & (cherche | disponible)

    chef = (P.lien_parente_cm == dico.CHEF_DE_MENAGE) | (
        P.lien_parente_cm.isna() & (P.lien_parente_cm_v1 == dico.CHEF_DE_MENAGE))
    occupe = P.en_emploi == 1
    independant = P.statut_emploi.isin(dico.STATUT_INDEPENDANT_FAMILIAL)
    S["est_chef"] = chef
    S["cm_agriculture_subsistance"] = chef & occupe & (
        P.branche_activite == dico.BRANCHE_AGRICULTURE) & independant

    en_age = occupe & tranche("emploi") & P.statut_emploi.notna()
    S["occupes_15_plus"] = en_age
    S["occupes_vulnerables"] = en_age & independant
    salarie = occupe & P.statut_emploi.isin(dico.STATUT_SALARIE) & P.declare_cnps.notna()
    S["salaries"] = salarie
    S["salaries_non_declares"] = salarie & (P.declare_cnps == 2)
    avec_heures = occupe & P.heures_travail.notna()
    S["occupes_heures"] = avec_heures
    S["sous_employes"] = avec_heures & (P.heures_travail < SEUIL_HEURES) & (
        P.veut_travailler_plus == 1) & (P.disponible_travailler_plus == 1)
    S["jeunes_15_24"] = tranche("neet")
    S["jeunes_neet_15_24"] = S.jeunes_15_24 & (P.en_emploi != 1) & (
        P.frequente_ecole != 1) & (P.etat_formation != dico.FORMATION_EN_COURS)

    # santé
    S["membres_assures"] = P.assurance_maladie == 1
    difficultes = P[COLONNES_DIFFICULTES]
    repondant = difficultes.notna().any(axis=1)
    S["membres_repondants_handicap"] = repondant
    S["membres_handicapes"] = ((difficultes >= dico.DIFFICULTE_MINIMUM)
                               & (difficultes <= 4)).any(axis=1)
    return S


def agreger_par_menage(S, P):
    """Somme des situations par ménage ; années d'études du membre le plus instruit."""
    cle = P.interview_key
    X = S.drop(columns=["annees", "est_chef"]).groupby(cle).sum().astype("int32")
    X.insert(0, "annees_etudes_max", S.annees.groupby(cle).max())
    X.insert(0, "taille_menage", cle.groupby(cle).size().astype("int32"))
    return X


def conditions_de_vie(men):
    """Situations de logement lues telles quelles, plus les biens d'équipement agrégés."""
    b = lambda nom: men[f"bien_{nom}"].fillna(0)
    biens = pd.DataFrame({
        "telephone": np.maximum(b("telephone_fixe"), b("telephone_mobile")),
        **{n: b(n) for n in dico.EQUIPEMENTS_PNUD if n != "telephone"}}).sum(axis=1)
    return men[["type_logement", *COLONNES_LOGEMENT, "nb_pieces_dormir"]].assign(
        nb_equipements=biens.astype("int32"),
        possede_voiture=b("voiture").astype("int32"),
        rechaud_gaz=b("rechaud_gaz").astype("int32"),
        internet=np.maximum(b("internet_fixe"), b("internet_mobile")).astype("int32"))


# --------------------------------------------------------------------------- #
# 5. chaîne
# --------------------------------------------------------------------------- #
def preconstruire_trimestre(t, W):
    P = lire_trimestre(t, W)
    retenus, ecartes = information_complete(P)
    logger.info("%s : %d ménages retenus sur %d (écartés pour : %s)", t, len(retenus),
                P.interview_key.nunique(),
                ", ".join(f"{c} {n}" for c, n in ecartes.sum().items()))
    R = caler(P[P.interview_key.isin(retenus)], P, t)

    S = situations_individuelles(R)
    X = agreger_par_menage(S, R)
    poids = R.groupby("interview_key").poids.sum()
    men = R.drop_duplicates("interview_key").set_index("interview_key")
    sexe = R[S.est_chef].drop_duplicates("interview_key").set_index("interview_key").sexe

    X = X.join(conditions_de_vie(men))
    X["ponderation_menage"] = poids / X.taille_menage
    # 2,3 % des ménages n'ont aucun membre déclaré chef de ménage (chef non résident) : code 9
    X["sexe_cm"] = sexe.reindex(X.index).fillna(dico.CHEF_NON_IDENTIFIE).astype("int64")
    for c in ("direction_regionale", "region", "departement", "sous_prefecture", "milieu",
              "grappe", "rang_interrogation"):
        X[c] = men[c].reindex(X.index)
    for c in ("region", "departement", "sous_prefecture", "milieu"):
        X[c] = X[c].astype("int64")
    X.insert(0, "trimestre", t)
    X.index = t + "|" + X.index.astype(str)
    X.index.name = "id_menage"
    return X


def preconstruire():
    W = lire_poids()
    return pd.concat([preconstruire_trimestre(t, W) for t in dico.TRIMESTRES])


def controler(X):
    logger.info("--- 6. contrôles ---")
    assert X.index.is_unique, "id_menage doit être unique"
    assert (X.taille_menage > 0).all() and (X.ponderation_menage > 0).all()
    assert X.grappe.notna().all(), "grappe manquante"
    poids = X.taille_menage * X.ponderation_menage
    logger.info("%d ménages, %d personnes, population représentée %.2f millions (poids annuel)",
                len(X), X.taille_menage.sum(), poids.sum() / 1e6)
    for t, g in X.groupby("trimestre"):
        p = g.taille_menage * g.ponderation_menage
        logger.info("  %s : %s ménages, taille moyenne %.2f, population %.2f M, %% urbain %.1f",
                    t, f"{len(g):,}".replace(",", " "), g.taille_menage.mean(), p.sum() / 1e6,
                    100 * np.average(g.milieu == 1, weights=p))
    assert X[COLONNES_LOGEMENT].notna().all().all(), "logement incomplet pour un ménage retenu"
    logger.info("rang d'interrogation 1 : %s des ménages retenus",
                part(int((X.rang_interrogation == 1).sum()), len(X)))
    return X


# --------------------------------------------------------------------------- #
# auto-contrôle
# --------------------------------------------------------------------------- #
def verifier():
    """Rejoue les règles individuelles sur des cas construits à la main, aux résultats connus."""
    configurer_logs(logger, niveau=logging.WARNING)
    nan = np.nan
    # 6 personnes d'un même ménage
    P = pd.DataFrame({
        "interview_key": ["m"] * 6, "membre": range(1, 7),
        #        chef 38   conjoint 30    enfant 11   jeune 20   jeune 20   adulte 45
        "age": [38, 30, 11, 20, 20, 45],
        "lien_parente_cm": [1, 2, 3, 3, 3, nan], "lien_parente_cm_v1": [nan] * 6,
        "deja_alle_ecole": [1, 1, 1, 1, 1, 2], "classe_achevee": [13, 8, 6, 14, 5, nan],
        "frequente_ecole": [2, 2, 2, 2, 2, nan],
        "lit_francais": [1, 1, nan, 1, 0, 0], "ecrit_francais": [1, 0, nan, 1, 0, 0],
        # chef occupé agricole à son compte ; conjoint sans emploi qui cherche et est disponible ;
        # jeune 4 sans emploi qui ne cherche pas mais est disponible (potentiel) ; jeune 5 salarié
        "en_emploi": [1, 0, nan, 0, 1, 0], "a_cherche_emploi": [nan, 1, nan, 2, nan, 2],
        "a_tente_creer_entreprise": [nan] * 6,
        "disponible_deux_semaines": [nan, 1, nan, 1, nan, 2],
        "statut_emploi": [3, nan, nan, nan, 1, nan], "declare_cnps": [nan, nan, nan, nan, 2, nan],
        "branche_activite": [1, nan, nan, nan, 3, nan], "heures_travail": [30, nan, nan, nan, 45, nan],
        "veut_travailler_plus": [1, nan, nan, nan, 2, nan],
        "disponible_travailler_plus": [1, nan, nan, nan, nan, nan],
        "etat_formation": [nan] * 6, "assurance_maladie": [1, 2, 2, 2, 2, 2],
        "dif_vue": [1, 1, 1, 3, 1, 1], "dif_ouie": [1, 1, 1, 1, 1, 1], "dif_mains": [nan] * 6,
        "dif_communication": [nan] * 6, "dif_cognition": [nan] * 6, "sexe": [1, 2, 1, 1, 2, 1],
        "poids": [10.0] * 6,
    })
    S = situations_individuelles(P)
    assert S.enfants_6_16.tolist() == [False, False, True, False, False, False]
    assert S.enfants_6_16_non_scolarises.sum() == 1
    # années d'études : 3e = 10, CM1 (8) = 5 ; le dernier n'a jamais été à l'école = 0
    assert S.annees.tolist()[:2] == [10.0, 5.0] and S.annees.iloc[5] == 0
    assert S.membres_17_49.tolist() == [True, True, False, True, True, True]
    assert S.membres_17_49_alphabetises.tolist() == [True, False, False, True, False, False]
    # chômage BIT : le conjoint seul ; SU3 y ajoute le jeune disponible qui ne cherche pas
    assert S.chomeurs_17_40.tolist() == [False, True, False, False, False, False]
    assert S.chomeurs_su3_17_40.tolist() == [False, True, False, True, False, False]
    assert S.cm_agriculture_subsistance.tolist() == [True, False, False, False, False, False]
    assert S.occupes_vulnerables.tolist() == [True, False, False, False, False, False]
    assert S.salaries_non_declares.tolist() == [False] * 4 + [True, False]
    # sous-emploi : le chef travaille 30 h, veut plus et est disponible
    assert S.sous_employes.tolist() == [True] + [False] * 5
    assert S.jeunes_neet_15_24.tolist() == [False, False, False, True, False, False]
    assert S.membres_handicapes.tolist() == [False, False, False, True, False, False]
    X = agreger_par_menage(S, P)
    assert X.loc["m", "taille_menage"] == 6 and X.loc["m", "annees_etudes_max"] == 11
    assert X.loc["m", "membres_assures"] == 1 and X.loc["m", "membres_repondants_handicap"] == 6
    # règle d'information complète : un membre sans réponse à l'assurance écarte le ménage
    P2 = P.assign(nb_pieces=2, materiau_mur=1, source_eclairage=1, source_eau_boisson=1,
                  type_sanitaire=1, evacuation_ordures=1, evacuation_eaux_usees=1)
    assert len(information_complete(P2)[0]) == 1
    P3 = P2.assign(assurance_maladie=[1, 2, 2, 2, 2, nan])
    assert len(information_complete(P3)[0]) == 0
    print("auto-contrôle 01 ENEM : OK")


def main():
    configurer_logs(logger, JOURNAL)
    debut = time.perf_counter()
    logger.info("=== étape 01 : préconstruction de la matrice situationnelle (ENEM 2025) ===")
    X = controler(preconstruire())
    logger.info("--- 7. export (Stata + CSV) ---")
    exporter_table(X, NOM_SORTIE, logger)
    logger.info("=== terminé en %.1f s ===", time.perf_counter() - debut)
    return X


if __name__ == "__main__":
    assert SOURCE == "enem", "cette étape ne tourne que sur la source enem (IPM_SOURCE=enem)"
    if "--check" in sys.argv:
        verifier()
    else:
        main()
