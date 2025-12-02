clear all
set more off

/*cd "C:\Users\Dell\OneDrive\Bureau\PHAS\INPM\RGPH\RGPH 2014\Sortie\Decoupage_SousprefRP14"

local list_de_fichier : dir . files "s*" 

di `list_de_fichier'


****CHEMIN****
global data "C:\Users\Dell\OneDrive\Bureau\PHAS\INPM\RGPH\RGPH 2014\Decoupage_SousprefRP14" 	  
global sortie "C:\Users\Dell\OneDrive\Bureau\PHAS\INPM\RGPH\RGPH 2014\Sortie"
global dofile "C:\Users\Dell\OneDrive\Bureau\PHAS\INPM\RGPH\RGPH 2014\Do file"

global list_var_menage "I04_SOUSPREF I05_COMMUNE I09_MILIEU I06_ZD  I08_QUARCPT I10_ILOT I10A_BATIMEN I10B_LOGEMEN I11N_MENAGE  DEPARTEMEN REGION DISTRICT" 


foreach var in  `list_de_fichier' {
   do "$dofile\Extraction_par_Localité" `var'
}
*/

****CHEMIN****
global data "C:\Users\Dell\OneDrive\Bureau\PHAS\IPM-CI\RGPH\RGPH 2014\Bases brutes" 	  
global sortie "C:\Users\Dell\OneDrive\Bureau\PHAS\IPM-CI\RGPH\RGPH 2014\Sortie"
global dofile "C:\Users\Dell\OneDrive\Bureau\PHAS\IPM-CI\RGPH\RGPH 2014\Do-file"

global list_var_menage "SOUSPREFID P04 P08 P05 P07 P09 P09A P09B P10 DEPART REGION" 
cd "C:\Users\Dell\OneDrive\Bureau\PHAS\IPM-CI\RGPH\RGPH 2014\Sortie\Decoup_SousprefRP14"

**** Automatisation du calcul et de l'exportation ******
local Sp = 1
local list_de_fichier : dir . files "I04*" 
di `list_de_fichier'

foreach var of local list_de_fichier {
   do "$dofile\RGPH14_Calcul_de_l'IPM_VF_lc"  `var' `Sp'
   local Sp = `Sp' + 1
}



***** Concaténation des résultats par localités ******** 

mat A_glob = A_Sp_1

forvalues k = 2/509 {
    // Concaténation verticale avec ///
    mat A_glob ///
        = A_glob \ ///
          A_Sp_`k'
}

// Afficher la matrice globale
mat list A_glob 


putexcel clear
putexcel set  "C:\Users\Dell\OneDrive\Bureau\PHAS\IPM-CI\RGPH\RGPH 2014\Sortie\IPM-CI_2014", sheet("LOCALITE") modify

/* Mise en forme */
putexcel C6 = matrix(A_glob), colnames  nformat(number_d2)
putexcel A7 = matrix(A_glob), rownames

// Inscrire les noms des sous prefectures dans le fichier excel
clear
import excel "C:\Users\Dell\OneDrive\Bureau\PHAS\IPM-CI\RGPH\RGPH 2014\Sortie\IPM-CI_2014.xlsx", sheet("LOCALITE") firstrow
gen LCID=real(A)
drop A
sort LCID
export excel using "C:\Users\Dell\OneDrive\Bureau\PHAS\IPM-CI\RGPH\RGPH 2014\Sortie\IPM-CI_2014_LC.xlsx", replace sheet("LOCALITE") firstrow(variables)  

*Il y'a des doublons dans les localités, on les supprime
duplicates report LCID
duplicates drop LCID, force
order LCID
sort LCID
save "C:\Users\Dell\OneDrive\Bureau\PHAS\IPM-CI\RGPH\RGPH 2014\Sortie\IPM-CI_2014_LC.dta", replace

use  "C:\Users\Dell\OneDrive\Bureau\PHAS\IPM-CI\RGPH\RGPH 2014\Sortie\data_results.dta",  clear
sort VILLAGE
gen LCID = VILLAGE
keep VILLAGE LCID
duplicates drop VILLAGE, force
sort LCID
merge 1:1 LCID  using  "C:\Users\Dell\OneDrive\Bureau\PHAS\IPM-CI\RGPH\RGPH 2014\Sortie\IPM-CI_2014_LC.dta"
drop if _merge !=3
drop _merge
format H MO Frequentationscolaire Annéedescolarité Alphabétisation Chomage Electricité Eaupotable Energiedecuisson Toilette Logement Equipement Mortalitéjuvénile Déclarationdétatcivil Vulnerabilité sev_pauvre %9.2f
export excel using "C:\Users\Dell\OneDrive\Bureau\PHAS\IPM-CI\RGPH\RGPH 2014\Sortie\IPM-CI_2014.xlsx", sheet("LOCALITE", modify) cell(B6) firstrow(variables)
save "C:\Users\Dell\OneDrive\Bureau\PHAS\IPM-CI\RGPH\RGPH 2014\Sortie\IPM-CI_2014_LC.dta", replace


