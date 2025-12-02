clear all
set more off
/*
cd "C:\Users\Dell\OneDrive\Bureau\PHAS\INPM\RGPH\RGPH 2014\Sortie\Decoupage_REGIONRP14"

local list_de_fichier : dir . files "R*" 

di `list_de_fichier'


****CHEMIN****
global data "C:\Users\Dell\OneDrive\Bureau\PHAS\INPM\RGPH\RGPH 2014\Decoupage_REGIONRP14" 	  
global sortie "C:\Users\Dell\OneDrive\Bureau\PHAS\INPM\RGPH\RGPH 2014\Sortie"
global dofile "C:\Users\Dell\OneDrive\Bureau\PHAS\INPM\RGPH\RGPH 2014\Do file"

global list_var_menage "I04_SOUSPREF I05_COMMUNE I09_MILIEU I06_ZD  I08_QUARCPT I10_ILOT I10A_BATIMEN I10B_LOGEMEN I11N_MENAGE  DEPARTEMEN REGION DISTRICT" 


foreach var in  `list_de_fichier' {
   do "$dofile\AutoIPM_SP" `var'
}
*/

****CHEMIN****
global data "C:\Users\Dell\OneDrive\Bureau\PHAS\IPM-CI\RGPH\RGPH 2014\Bases brutes" 	  
global sortie "C:\Users\Dell\OneDrive\Bureau\PHAS\IPM-CI\RGPH\RGPH 2014\Sortie"
global dofile "C:\Users\Dell\OneDrive\Bureau\PHAS\IPM-CI\RGPH\RGPH 2014\Do-file"

global list_var_menage "SOUSPREFID P04 P08 P05 P07 P09 P09A P09B P10 DEPART REGION" 
cd "C:\Users\Dell\OneDrive\Bureau\PHAS\IPM-CI\RGPH\RGPH 20121\Sortie\Decoupage_REGIONRP21"

local reg = 1
local list_de_fichier : dir . files "reg*" 
di `list_de_fichier'

foreach var of local   list_de_fichier{
   do "$dofile\RGPH21_Calcul_de_l'IPM_VF_SP" `var' `reg'
   local reg = `reg' + 1
}


mat A_glob = A_reg_1

forvalues k = 2/33 {
    // Concaténation verticale avec ///
    mat A_glob ///
        = A_glob \ ///
          A_reg_`k'
}

// Afficher la matrice globale
mat list A_glob

putexcel clear
putexcel set  "C:\Users\Dell\OneDrive\Bureau\PHAS\IPM-CI\RGPH\RGPH 2021\Sortie\IPM-CI_2021", sheet("SOUS-PREFECTURES") modify

/* Mise en forme */
putexcel C6 = matrix(A_glob), colnames  nformat(number_d2)
putexcel A7 = matrix(A_glob), rownames

// Inscrire les noms des sous prefectures dans le fichier excel
clear
import excel "C:\Users\Dell\OneDrive\Bureau\PHAS\IPM-CI\RGPH\RGPH 2021\Sortie\IPM-CI_2021", sheet("SOUS-PREFECTURES") firstrow
gen SPID=real(B)
drop A B 
sort SPID
order SPID
export excel using "C:\Users\Dell\OneDrive\Bureau\PHAS\IPM-CI\RGPH\RGPH 2021\Sortie\IPM-CI_2021_SP.xlsx", replace sheet("SOUS-PREFECTURES") firstrow(variables)  

save "C:\Users\Dell\OneDrive\Bureau\PHAS\IPM-CI\RGPH\RGPH 2021\Sortie\IPM-CI_2021_SP.dta", replace

use "C:\Users\Dell\OneDrive\Bureau\PHAS\IPM-CI\RGPH\RGPH 2021\Sortie\data_results.dta", clear
sort SOUSPREFID
gen SPID = SOUSPREFID
keep SOUSPREFID SPID
duplicates drop SOUSPREFID, force
merge 1:1 SPID using  "C:\Users\Dell\OneDrive\Bureau\PHAS\IPM-CI\RGPH\RGPH 2021\Sortie\IPM-CI_2021_SP.dta"
drop _merge
export excel using "C:\Users\Dell\OneDrive\Bureau\PHAS\IPM-CI\RGPH\RGPH 2021\Sortie\IPM-CI_2021.xlsx", sheet("SOUS-PREFECTURES", modify) cell(B6) firstrow(variables)
save "C:\Users\Dell\OneDrive\Bureau\PHAS\IPM-CI\RGPH\RGPH 2021\Sortie\IPM-CI_2021_SP.dta", replace




