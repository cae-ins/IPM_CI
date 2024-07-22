clear all
set more off

cd "C:\Users\Dell\OneDrive\Bureau\PHAS\IPMC\RGPH\RGPH 2014\Bases brutes"
// Spécifier le chemin d'accès des fichiers à utiliser

local list_de_fichier : dir . files "REG*" 

****CHEMIN****
global data "C:\Users\Dell\OneDrive\Bureau\PHAS\IPMC\RGPH\RGPH 2014\Bases brutes" 	  
global sortie "C:\Users\Dell\OneDrive\Bureau\PHAS\IPMC\RGPH\RGPH 2014\Sortie"
global dofile "C:\Users\Dell\OneDrive\Bureau\PHAS\IPMC\RGPH\RGPH 2014\Do file"

global list_var_menage "I04_SOUSPREF I05_COMMUNE I09_MILIEU I06_ZD  I08_QUARCPT I10_ILOT I10A_BATIMEN I10B_LOGEMEN I11N_MENAGE  DEPARTEMEN REGION DISTRICT" 

foreach var of local list_de_fichier {
   do "$dofile\RGPH14_Calcul_des_privation(CP)_VF_11032024.do" `var'
}

/* Fusion des fichiers */
clear

cd "$sortie\Treated"

append using `: dir . files "*.dta"'

save "$sortie\data_results.dta", replace


********************************************************************************
*********************DIMENSION SANTE************************
********************************************************************************
import spss using "$data\T_MORTALITE_08072015.sav", clear

by $list_var_menage,  sort : gen decs18 =  D59AD_AGED if  D59AD_AGED <18
collapse (count) decs18, by ($list_var_menage)
save "$sortie\DECES8_RGPH2014.dta", replace


use "$sortie\data_results.dta"

merge m:1 $list_var_menage using "$sortie\DECES8_RGPH2014.dta" ,keepusing(decs18)

gen mjuv = inlist(DE59_DECES, 1) & decs18 > 0
lab var mjuv "Au moins un décès de moins de 18 ans; 1=oui, 0=non"
drop _merge
save, replace
********************************************************************************
***********************CALCUL DE L'IPM **************************
********************************************************************************


