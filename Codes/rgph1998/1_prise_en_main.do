
********************************************************************************
/*
Projet: Construction d'indice national de pauvreté multidimensionnelle
Base: RGPH98

*/

********************************************************************************

********************************************************************************

clear all 
set more off
set maxvar 10000
set mem 500m
cap log close


*** Chemins d'accès des dossiers de travail ***

global data_raw "C:\Users\omen\OneDrive - GOUVCI (1)\INS_JOB\DATABASES"
global data_raw98 "$data_raw\Aboya_bis\rgph98"

global chemin_perso "C:\Users\omen\OneDrive - GOUVCI (1)\CAE_INS\IPM\INPM"

global projet "$chemin_perso\Data_results"
global data_inpm "$projet\Data"
global data_temp98 "$data\Data1998"
global bases_reg_ind98 "$data_temp98\bases_reg_ind98"
global bases_reg_ind98_treated "$bases_reg_ind98 \treated"
global result "$projet\Resultats"
global result98 "$Resultats\res98"

global log_inpm "$projet\Log"


/*global bases_reg_results_dis "$bases_reg_results\INPM_men_0.log"
global dofile "C:\Users\Dell\OneDrive\Bureau\PHAS\INPM\RGPH_98\IPNM_compute_1998"
global list_var_mena "I01_REGI I02_DEPA I03_SPREF I04_MILIEU I09T_TYP I09N_NUM"

*/

*** Log file *** 
log using "$log_inpm/rgph98_dataprep.log", replace	



/**/
***Création des bases régionales niveau "individus"
import spss using "$data_raw98\individu.sav"
save "$data_raw98\rgph98_ind.dta", replace


use "$data_raw98\rgph98_ind.dta", clear
forval k= 1 / 19 {
	preserve
	keep if I01_REGI==`k'
	save "C:\Users\Dell\OneDrive - GOUVCI\CAE_INS\IPM\INPM\Data_results\Data\Data1998\bases_reg_ind98\rgph98_ind_R`k'.dta", replace
	restore
}


clear
import spss using "$data_raw98\menage.sav"
save "$data_raw98\rgph98_men.dta", replace


use "$data_raw98\rgph98_men.dta", clear
duplicates drop //(373,263 observations deleted), 2,279,544 observations résiduelles
isid I01_REGI I02_DEPA I03_SPREF I05_MILIEU I09T_TYP I09N_NUM //Je pense que le numéro de l'ilot manque.


duplicates tag I01_REGI I02_DEPA I03_SPREF I05_MILIEU I09T_TYP I09N_NUM, 

*********************Récupération de la variable décès************************
********************************************************************************
import spss using "C:\Users\Dell\OneDrive\Bureau\PHAS\INPM\RGPH 2014\T_MORTALITE_08072015.sav", clear

by $list_var_menage,  sort : gen decs18 =  D59AD_AGED if  D59AD_AGED <18
collapse (count) decs18, by ($list_var_menage)
save "C:\Users\Dell\OneDrive\Bureau\PHAS\INPM\Données Intermédiaire_INPM_2014\DECES8_RGPH2014.dta", replace

use "C:\Users\Dell\OneDrive\Bureau\PHAS\INPM\Resultats_INPM_2014\data_results.dta"

merge m:1 $list_var_menage using "C:\Users\Dell\OneDrive\Bureau\PHAS\INPM\Données Intermédiaire_INPM_2014\DECES8_RGPH2014.dta" ,keepusing(decs18)

gen mjuv = inlist(DE59_DECES, 1) & decs18 > 0
lab var mjuv "Au moins un décès de moins de 18 ans; 1=oui, 0=non"

gen SANTE = (mjuv)/5
lab var Identification "score de la dimension Sante"
save, replace


*********************BASES 1998: DIMENSION SANTE************************
import spss using "$data_raw98\Deces.sav", clear 
*Je note que le nom des variables différentes d'une base à l'autre.
 rename I05_MILIEU I04_MILIEU
 by $list_var_mena,  sort : gen decs18 = D53AD_AG if D53AD_AG <18
collapse (count) decs18, by ($list_var_mena)
save "C:\Users\Dell\OneDrive\Bureau\PHAS\INPM\RGPH_98\Données intermédiares\DECES8_RGPH1998.dta", replace



***Identification des doublons
duplicates tag I01_REGI I02_DEPA I03_SPREF I05_MILIEU I09T_TYP I09N_NUM, gen (dup_all_temp1)

I01_REGI I02_DEPA I03_SPREF I05_MILIEU I09T_TYP I09N_NUM

*isid I01_REGI I02_DEPA I03_SPREF I05_MILIEU I09T_TYP I09N_NUM //Le type de ménage ne doit normalement pas être un identifiant!
sort I01_REGI I02_DEPA I03_SPREF I05_MILIEU I09N_NUM


