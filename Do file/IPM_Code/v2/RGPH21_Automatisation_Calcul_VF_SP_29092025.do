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
global in "C:\CAE_IPM\Data"
global do "C:\CAE_IPM\Do file\IPM_Code\v2"
global out "C:\CAE_IPM\Sortie"
use "$out\bf.dta", clear
global list_var_menage "SOUSPREFID  P04 P08 P05 P07 P09 P09A P09B P10 DEPART REGION" 


tab REGION, m

forvalues r=1/33 {
	preserve
	keep if REGION==`r'
	save "$in\base_region_`r'.dta", replace
	restore
}


forvalues r=1/33 {
	use "$in\base_region_`r'.dta", clear
	
cd "C:\CAE_IPM\Data"


local reg = 1
local list_de_fichier : dir . files "base*" 
di `list_de_fichier'

foreach var of local   list_de_fichier{
   do "$do\RGPH21_Calcul_de_lIPM_VF_SP_29092025.do" `var' `reg'
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
putexcel set  "$out\IPM-CI_SP_2021", sheet("SOUS-PREFECTURES") modify

/* Mise en forme */
putexcel C6 = matrix(A_glob), colnames  nformat(number_d2)
putexcel A7 = matrix(A_glob), rownames

// Inscrire les noms des sous prefectures dans le fichier excel
clear
import excel "$out\IPM-CI_SP_2021", sheet("SOUS-PREFECTURES") firstrow
gen SPID=real(B)
drop A B 
sort SPID
order SPID
export excel using "$out\IPM-CI_SP_2021", replace sheet("SOUS-PREFECTURES") firstrow(variables)  

save "C:\CAE_IPM\Sortie\IPM-CI_2021_v2", sheet("SOUS-PREFECTURES") firstrow(variables) 

/*use "C:\Users\Dell\OneDrive\Bureau\PHAS\IPM-CI\RGPH\RGPH 2014\Sortie\data_results.dta", clear
sort I04_SOUSPREF
gen SPID = I04_SOUSPREF
keep I04_SOUSPREF SPID
duplicates drop I04_SOUSPREF, force
merge 1:1 SPID using  "C:\Users\Dell\OneDrive\Bureau\PHAS\IPM-CI\RGPH\RGPH 2014\Sortie\IPM-CI_2014_SP.dta"
drop _merge
export excel using "C:\Users\Dell\OneDrive\Bureau\PHAS\IPM-CI\RGPH\RGPH 2014\Sortie\IPM-CI_2014.xlsx", sheet("SOUS-PREFECTURES", modify) cell(B6) firstrow(variables)
save "C:\Users\Dell\OneDrive\Bureau\PHAS\IPM-CI\RGPH\RGPH 2014\Sortie\IPM-CI_2014_SP.dta", replace
*/


}
