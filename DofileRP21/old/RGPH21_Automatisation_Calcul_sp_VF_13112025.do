************************************************************
* 0. INITIALISATION
************************************************************
clear all
set more off

global in "$projet\data\data_in"
global do "$projet\dofilerp21"
global out "$projet\data\data_out"

************************************************************
* 1. CHARGER LA BASE PRINCIPALE ET CREER LES 33 MINI-BASES
************************************************************
use "$out\final_data.dta", clear

forvalues r = 1/33 {
    preserve
        keep if REGION == `r'
        save "$in\base_region_`r'.dta", replace
    restore
}

************************************************************
* 2. TRAITER CHAQUE MINI-BASE AVEC LE DO-FILE MPI
************************************************************
forvalues r = 1/33 {
    di "-------------------------------------------------------------"
    di ">>> TRAITEMENT DE LA REGION `r'"
    di "-------------------------------------------------------------"

    * Envoi du fichier régional + du numéro de région
    do "$do\RGPH21_Calcul_de_lIPM_VF_SP_13112025.do" ///
        "$in\base_region_`r'.dta" ///
        `r'
}

************************************************************
* 3. AGREGER TOUTES LES MATRICES REGIONALES EN UNE MATRICE NATIONALE
************************************************************
* Initialisation avec la région 1
mat A_glob = A_reg_1

* Ajout des 32 autres régions
forvalues r = 2/33 {
    mat A_glob = A_glob \ A_reg_`r'
}

mat list A_glob

/*
************************************************************
* 4. AJOUT DES NOMS DES SOUS-PREFECTURES
************************************************************

use "$out\bf_13112025.dta", clear

keep SOUSPREFID 
duplicates drop SOUSPREFID , force
sort SOUSPREFID
tostring  SOUSPREFID, gen(SP_text)



/

* 1. Nettoyer nom des zones
gen SP = NAME_SP
replace NAME_SP = subinstr(SP, " ", "_", .)
replace NAME_SP = subinstr(SP, "-", "_", .)

* 2. Garder l'ordre des SP
sort SOUSPREFID

* 3. Construire la liste des rownames dans l'ordre
local names ""
quietly {
    forvalues i = 1/`=_N' {
        local names `names' `=SP[`i']'
    }
}

* 4. Appliquer à la matrice A
*mat rownames A_glob = `names'
*/

************************************************************
* 5. EXPORT EXCEL (SOUS-PREFECTURES)
************************************************************
putexcel clear
putexcel set "$output\ipm_rp21.xlsx", ///
    sheet("SP") modify

* Écriture de la matrice globale
putexcel C6 = matrix(A_glob), colnames nformat(number_d2)
putexcel A7 = matrix(A_glob), rownames

************************************************************
* 5. AJOUT DES NOMS DES SOUS-PREFECTURES
************************************************************
use "$in\IPM_Data_191125.dta", clear
keep SOUSPREFID
duplicates drop
sort SOUSPREFID
decode SOUSPREFID, gen(SP)
* On trie ensuite dans excel, on copie la colonne SP dans stata puis la colle dans Excel
************************************************************
* 6. SAUVEGARDE FINALE
************************************************************

