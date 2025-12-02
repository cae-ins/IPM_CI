use "C:/CAE_IPM/Data/IPM_Data_110924.dta", clear
global list_var_menage "SOUSPREFID P04 P08 P05 P07 P09 P09A P09B P10 DEPART REGION P06" 
keep if P15D == 1
// garder les résidents présents

keep if P16 == 1
save "C:\Users\Dell\OneDrive - GOUVCI\Bureau\IPM_Data_110924_men.dta", replace
// Chef de ménage (CM)

********************  Calcul du taux d'alphabétisation 2021 *************

****** pour 15 ans et plus

keep if P18BCONTROL_New >= 15
recode P29A (1=1 "Sait lire") (2=0 "Ne sait pas lire")  (.=.), gen(alpha) 
preserve 
bysort SOUSPREFID : egen alpha_15etplus = mean(alpha)
bysort SOUSPREFID : keep if _n == 1
keep DEPART  SOUSPREFID alpha_15etplus
tempfile alpha15p
save `alpha15p', replace
restore

****** pour 15 ans et plus

preserve 
keep if inrange(P18BCONTROL_New,15,24)
bysort SOUSPREFID : egen alpha_1524 = mean(alpha)
bysort SOUSPREFID : keep if _n == 1
keep DEPART  SOUSPREFID alpha_1524
tempfile alpha1524
save `alpha1524', replace
restore

******* fusion

use  `alpha15p', clear
merge 1:1 DEPART  SOUSPREFID using `alpha1524', nogen
gen taux_alph15p= alpha_15etplus*100
gen taux_alph1524= alpha_1524*100
export excel using "C:\CAE_IPM\Sortie\IPM-CI_2021.xlsx", sheet(Taux_alphabetisation) firstrow(variables) sheetmodify
