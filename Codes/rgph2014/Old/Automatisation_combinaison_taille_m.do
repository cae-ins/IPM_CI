global data "C:\Users\Dell\OneDrive\Bureau\PHAS\INPM\RGPH\RGPH 2014\Bases brutes"
global dofile "C:\Users\Dell\OneDrive\Bureau\PHAS\INPM\RGPH\RGPH 2014\Do file"
global sortie "C:\Users\Dell\OneDrive\Bureau\PHAS\INPM\RGPH\RGPH 2014\Sortie"

global list_var_menage "I04_SOUSPREF I05_COMMUNE I09_MILIEU I06_ZD I08_QUARCPT I10_ILOT I10A_BATIMEN I10B_LOGEMEN I11N_MENAGE I07_NOMVILLAG DEPARTEMEN REGION DISTRICT" 

cd "C:\Users\Dell\OneDrive\Bureau\PHAS\INPM\RGPH\RGPH 2014\Bases brutes"
local list_de_fichier : dir . files "REG*" 


foreach var of local list_de_fichier {
   do "$dofile\Combinaison_taille_m.do" `var'
}

/* Fusion des fichiers */
clear

cd "C:\Users\Dell\OneDrive\Bureau\PHAS\INPM\RGPH\RGPH 2014\Sortie\Treated_1"
append using `: dir . files "*.dta"'


save "$sortie\Treated_1\taille du menage.dta", replace


use "$sortie\data_results.dta", clear


merge m:m $list_var_menage using "$sortie\Treated_1\taille du menage.dta" , keepusing(w TOTMEN DE59_DECES)

save "$sortie\data_results.dta1", replace

//Appeler la base décès

import spss using "C:\Users\Dell\OneDrive\Bureau\PHAS\INPM\RGPH\RGPH 2014\Bases brutes\T_MORTALITE_08072015", clear
global list_var_morta "I04_SOUSPREF I05_COMMUNE I09_MILIEU I06_ZD I08_QUARCPT I10_ILOT I10A_BATIMEN I10B_LOGEMEN I11N_MENAGE I09_MILIEU DEPARTEMEN DISTRICT REGION"
by $list_var_morta,  sort : gen decs18 =  D59AD_AGED if  D59AD_AGED <18 
collapse (count) decs18, by ($list_var_morta)
save "C:\Users\Dell\OneDrive\Bureau\PHAS\INPM\RGPH\RGPH 2014\Sortie\DECES8_RGPH2014.dta", replace

use "C:\Users\Dell\OneDrive\Bureau\PHAS\INPM\RGPH\RGPH 2014\Sortie\data_results.dta1", clear

merge m:1 $list_var_morta using "C:\Users\Dell\OneDrive\Bureau\PHAS\INPM\RGPH\RGPH 2014\Sortie\DECES8_RGPH2014.dta",keepusing(decs18)
gen mjuv = inlist(DE59_DECES, 1) & decs18 > 0
lab var mjuv "Au moins un décès de moins de 18 ans; 1=oui, 0=non"
// A revoir, le calcul de la santé

save, replace