use "$projet\Data\IPM_Data_110924.dta", clear
global list_var_menage "SOUSPREFID P04 P08 P05 P07 P09 P09A P09B P10 DEPART REGION P06" 
keep if P15D == 1
// garder les résidents présents

keep if P16 == 1
save "$projet\Sortie\IPM_Data_110924_men.dta", replace
// Chef de ménage (CM)

********************  Calcul de privation   fréquentation scolaire  *************
gen nonsco = inrange(P18BCONTROL_New,6,14) & P30A != 1 
bysort SOUSPREFID : egen priv_freqsco_sp = mean(nonsco)  

******** Années de scolarité: Personne de 17 ans et plus n'ayant pas achevé au moins 10 annees d'etudes [Niveau 3ème] 

gen nonedu = (P18BCONTROL_New>=17 & P18BCONTROL_New!=.) & !inlist(P32, .,23,1,2,3) 
bysort SOUSPREFID : egen priv_ansco = mean(nonedu) 

********************  Calcul de privation  alphabétisation  *************

*** Un  membre du ménage de 15 ans ou plus ne sait pas lire ou écrire en francais

gen alphab = 1 if (P29_BA == 1) & inrange(P18BCONTROL_New, 15,49)
bysort SOUSPREFID : egen priv_alpha = mean(alphab)

*********************** Calcul de privation  emploi ****************************************************************************

gen chm= inlist(P34B,8,9,10,11,12, 13,18) & p34C == 1  & (P18BCONTROL_New>=15 & P18BCONTROL_New<=24)
bysort SOUSPREFID : egen priv_chm = mean(chm)

***************Déclaration de naissance à l'état civil

gen pasid = !inlist(P20 , 1, 2) & (P18BCONTROL_New>=5 & P18BCONTROL_New<=15)
bysort SOUSPREFID : egen priv_ident = mean(pasid)

*****ELECTRICITE
gen paselec = !inlist(P51,1,2,3)
bysort SOUSPREFID : egen priv_elect = mean(paselec)


*****EAU POTABLE  
gen paseaup = !inlist(P49,1,2,3,4,5,7,10)
bysort SOUSPREFID : egen priv_eau = mean(paseaup)

*****COMBUSTIBLE 
gen combsale = !inlist(P52, 2,4)
bysort SOUSPREFID : egen priv_combsale = mean(combsale)

*******TOILETTES
gen pasta = !inlist(P48, 1,2,5,7)
bysort SOUSPREFID : egen priv_toilt = mean(combsale)


** Logement
*****NATURE DU SOL 
gen solterre = !inlist( P47, 2,3,4)
bysort SOUSPREFID : egen priv_sol = mean(solterre)

*****NATURE DU TOIT (TOIT EN FIBRE OU AUTRES)
gen toiture = !inlist(P46, 2,3,4)
bysort SOUSPREFID : egen priv_toi = mean(toiture)

*****NATURE DU MUR (MUR NON EN DUR)
gen matmur = !inlist( P45, 4,5,6)
bysort SOUSPREFID : egen priv_mur = mean(matmur)


gen logement=solterre| toiture | matmur
bysort SOUSPREFID : egen priv_log = mean(logement)


*****EQUIPEMENT 
	
gen velo = (P55A !=0)
gen televison = (P57B !=0)
gen radio = (P57A !=0)
gen telephone = (P57D !=0)
gen ordinateur = (P57E !=0)
gen charette = (P55F !=0)
gen refrigerateur = (P56B !=0)
gen motoetbycle = (P55B !=0)
gen véhicule = (P55C !=0)

egen equi = rowtotal( velo televison radio telephone ordinateur charette refrigerateur motoetbycle ), missing
bysort SOUSPREFID : egen priv_equi = mean(equi)
/*
*** renommer proporement  
 Fréquentation scolaire
 Année de scolarité
 Alphabétisation
Chômage
Electricité
 Eau potable
Energie de cuisson
Toilette
Logement
Equipement
Déclaration d'état civil
*/

**** faire en sorte d'avoir une ligne par sp
**** sauvergarder



use "$projet\MORTALITE_RP2021_TRAITEMENT.dta", clear

by SOUSPREFID,  sort : gen decs18 =  M61A2_AGE if  M61A2_AGE <18
collapse (count) decs18, by (SOUSPREFID)
save "$projet\Sortie\DECESSP_RGPH2021.dta"

use "$projet\Sortie\bf.dta", clear

merge m:1 SOUSPREFID using "$projet\Sortie\DECESSP_RGPH2021.dta" ,keepusing(decs18)

gen mjuv = decs18 > 0 if decs18 !=.
replace mjuv = 0 if decs18==.
bysort SOUSPREFID : egen priv_mjuv = mean(mjuv)

**** faire en sorte d'avoir une ligne par sp
**** sauvergarder
*** merge avec la base precedente