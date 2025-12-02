************************************************************
* 0. INITIALISATION
************************************************************
clear all
set more off

global in  "$projet\Data"
global do  "$projet\DofileRP21"
global out "$projet\Sortie"


global list_var_menage "SOUSPREFID P04 milieu  P05 P07 P09 P09A P09B P10 DEPART REGION P06" 


/************************************************************************
    1. PRIVATIONS INDIVIDUELLES (calculées pour chaque individu)
************************************************************************/

use "$out\baseind.dta", clear
gen TOTMEN_w = TAILLE_MENAGE*EW
* ---- Collapse INDIVIDUEL ----
collapse (mean) desco educ mfsa  chom   Ident [pw=TOTMEN_w],by(SOUSPREFID milieu) 
/*	
bysort SOUSPREFID : egen frequent = mean(freq_scol)
bysort SOUSPREFID : egen scolarite = mean(annees_scol)
bysort SOUSPREFID : egen alphabetisation = mean(alphabet)
bysort SOUSPREFID : egen chômage = mean(chomage)
bysort SOUSPREFID : egen Identification = mean(etat_civil)
duplicates drop SOUSPREFID, force 
keep    SOUSPREFID    frequent scolarite alphabetisation Identification chômage
*/


save "$out\priv_indiv_spxmilieu.dta", replace



/**********************************************************************
    2. PRIVATIONS MÉNAGES (UNE LIGNE PAR MÉNAGE)
**********************************************************************/
use "$in\IPM_Data_191125", clear
keep if P16==1
keep if P15B==1
save "$out\var_mil", replace
use "$in\IPM_Data_110924_men", clear
merge 1:1 INDIV_ID using "$out\var_mil", keepusing(milieu)
drop _merge

*** ----- ELECTRICITÉ ----- ***
gen electricite = !inlist(P51,1,2,3)

*** ----- EAU POTABLE ----- ***
gen eau_potable = !inlist(P49,1,2,3,4,5,7,10)

*** ----- ENERGIE DE CUISSON ----- ***
gen energie_cuisson = !inlist(P52,2,4)

*** ----- TOILETTE ----- ***
gen toilette = !inlist(P48,1,2,5,7)

*** ----- LOGEMENT (SOL + TOIT + MUR) ----- ***
gen sol_terre  = !inlist(P47,2,3,4)
gen toit_fibre = !inlist(P46,2,3,4)
gen mur_nondur = !inlist(P45,4,5,6)
gen logement   = sol_terre | toit_fibre | mur_nondur


/************************************************************************
    ÉQUIPEMENT — méthode correcte ménage
************************************************************************/
gen velo = .
replace velo = 1 if P55A == 1
replace velo = 0 if P55A == .
ta velo , m

gen televison = .
replace televison = 1 if P57B == 1
replace televison = 0 if P57B == .
ta televison , m

gen radio = .
replace radio = 1 if P57A == 1
replace radio = 0 if P57A == .
ta radio , m

gen telephone = .
replace telephone = 1 if P57D == 1
replace telephone = 0 if P57D == .
ta telephone , m

gen ordinateur = .
replace ordinateur = 1 if P57E == 1
replace ordinateur = 0 if P57E == .
ta ordinateur , m

gen charette = .
replace charette = 1 if P55F == 1
replace charette = 0 if P55F == .
ta charette , m

gen motoetbycle = .
replace motoetbycle = 1 if P55B == 1
replace motoetbycle = 0 if P55B == .
ta motoetbycle , m

gen refrigerateur = .
replace refrigerateur = 1 if P56B == 1
replace refrigerateur = 0 if P56B == .
ta refrigerateur , m


gen véhicule = .
replace véhicule = 1 if P55C == 1
replace véhicule = 0 if P55C == .
ta véhicule , m

egen equi = rowtotal( velo televison radio telephone ordinateur charette refrigerateur motoetbycle ), missing
lab var equi "Household Number of Small Assets Owned- National" 
gen equipement = (véhicule==1 | equi > 1) 
replace equipement = . if véhicule==. & equi==.
lab var equipement "Household Asset Ownership: HH has car or more than 1 small assets"

recode equipement  (0=1)(1=0) , gen(pasequi)

ren SOUSPREFID_NEW  SOUSPREFID
ren DEPART_NEW  DEPART
ren REGION_NEW REGION
sort INDIV_ID
/*
gen velo           = (P55A != 0)
gen moto           = (P55B != 0)
gen vehicule       = (P55C != 0)
gen televiseur     = (P57B != 0)
gen radio          = (P57A != 0)
gen telephone      = (P57D != 0)
gen ordinateur     = (P57E != 0)
gen charette       = (P55F != 0)
gen refrigerateur  = (P56B != 0)

* Total équipements (hors véhicule)
egen total_biens = rowtotal(velo moto televiseur radio telephone ///
                            ordinateur charette refrigerateur), missing

* Règle :
* NON PRIVÉ = véhicule == 1  OU total_biens > 1
gen equip_nonprive = (vehicule==1 | total_biens>1)

* PRIVATION = complément
gen equipement = (equip_nonprive==0)
replace equipement = . if missing(vehicule) & missing(total_biens)
*/

global list_var_menage "SOUSPREFID  P04 P08 P05 P07 P09 P09A P09B P10 DEPART REGION" 


************************************************************************/
global list_var_menage1 "SOUSPREFID  P04 P08 P05 P07 P09 P09A P09B P10 DEPART REGION" 


/***************** MORTALITÉ (merge avec base décès) *******************/
preserve

use "$in\MORTALITE_RP2021_TRAITEMENT.dta", clear
 

by $list_var_menage1,  sort : gen decs18 =  M61A2_AGE if  M61A2_AGE <18
collapse (count) decs18, by ($list_var_menage)
save "$out\deces_sp.dta", replace


restore
merge m:1 $list_var_menage1 using "$out\deces_sp.dta" ,keepusing(decs18)
drop _merge
gen mjuv = decs18 > 0 if decs18 !=.
replace mjuv = 0 if decs18==. 

/**********************************************************************
   Collapse MENAGE -> SP
**********************************************************************/
ta milieu,m
drop if milieu ==.
collapse (mean) electricite eau_potable energie_cuisson toilette logement equipement mjuv, by(SOUSPREFID milieu)

save "$out\priv_menage_spxmilieu.dta", replace

/*
/**********************************************************************
    4. LABELS P
**********************************************************************/
label variable freq_scol        "Fréquentation scolaire"
label variable annees_scol      "Années de scolarité"
label variable alphabet         "Alphabétisation"
label variable chomage          "Chômage"
label variable etat_civil       "État civil (déclaration naissance)"

label variable electricite      "Électricité"
label variable eau_potable      "Eau potable"
label variable energie_cuisson  "Énergie de cuisson"
label variable toilette         "Toilette"
label variable logement         "Logement"
label variable equipement       "Équipement"
label variable mjuv             "Mortalité juvénile (<18 ans)"
*/

/**********************************************************************
    4. MERGE INDIVIDUEL + MENAGE
**********************************************************************/
use "$out\priv_indiv_spxmilieu.dta", clear
merge 1:1 SOUSPREFID milieu using "$out\priv_menage_spxmilieu.dta"
drop _merge

save "$out\privations_SPxMIL_final.dta", replace

export excel using "$out\IPM-CI_2021_vf_13112025.xlsx" ,  ///
    sheet("PRIVATION_SPxMIL") sheetmodify firstrow(variable)
