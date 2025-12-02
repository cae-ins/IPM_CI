
clear all
set more off

****CHEMIN****
global data "C:/CAE_IPM/Data" 	  
global sortie "C:/CAE_IPM/Sortie"
global dofile "C:/CAE_IPM/Do file"


global list_var_menage "SOUSPREFID P04 P08 P05 P07 P09 P09A P09B P10 DEPART REGION P06" 


/*
foreach var of local list_de_fichier {
   do "$dofile/RGPH21_Calcul_des_privation(CP)_VF.do" `var'
}

/* Fusion des fichiers */
clear

cd "$sortie/Treated"

append using `: dir . files "*.dta"'

save "$sortie/data_results_nf.dta", replace


******************TRAITEMENT DES VARIABLES MENAGES********************
********************************************************************************
use "$data/base_menage_rp_non_def (1).dta", clear
*/

use "C:/CAE_IPM/Data/IPM_Data_120924.dta", clear

keep if P15D == 1
// garder les résidents présents

bysort $list_var_menage : keep if P16 == 1
// Chef de ménage (CM)




***************DIMENSION NIVEAU DE VIE***************************************************************************************************

*****ELECTRICITE
gen paselec = !inlist( P51,1,2,3)
lab var paselec "Ne dispose pas d'electricite; 1=pas electricite, 0=electricite"
/*question RGPH14: Mode d'éclairage
Value=1;Electricité (CIE)
Value=2;Groupe électrogène
Value=3;Panneau solaire
Value=4;Lampe (à pétrole, à gaz, à huile)
Value=5;Bois de chauffe
Value=6;Torche
Value=8;Autre à préciser
*/

*****EAU POTABLE  
gen paseaup = !inlist( P49,1,2,3,4,5,7,10)
lab var paseaup "Ne dispose pas d'acces a l'eau potable; 1=pas eau potable, 0=eau potable"
/*question RGPH: Principale Source d'alimentation en eau de boisson
Value=1;Eau de robinet dans le logement
Value=2;Eau de robinet dans la cour
Value=3;Robinet public / borne fontaine
Value=4;Puit à pompe / forage
Value=5;Puit creusé protégé
Value=6;Puit creusé pas protégé
Value=7;Source d'eau protégée
Value=8;Source d'eau non protégée
Value=9;Eau de surface
Value=10;Eau conditionnée en bouteille ou en sachet
Value=96;Autre à préciser
  */

*****COMBUSTIBLE 
gen combsale = !inlist(P52, 2,4)
lab var combsale "Utilise un combustible sale (bois, charbon, autres); 1=oui, 0=non"
/*question RGPH: Mode de cuisson
Value=1;Bois de chauffe
Value=2;Gaz
Value=3;Charbon
Value=4;Electricité
Value=8;Autre à préciser
*/

*******TOILETTES
gen pasta = !inlist(P48, 1,2,5,7)
lab var pasta "n'a pas de toilette privée améliorée"
/*question RGPH: Principal lieu d'aisance
Value=1;Chasse d'eau reliée à un système d'égouts
Value=2;Chasse d'eau reliée à une fosse septique
Value=3;Chasse d'eau reliée à l'air libre
Value=4;Chasse d'eau reliée à un lieu inconnu
Value=5;Latrine a fosse améliorée ventilée
Value=6;Latrine a fosse non ventilée
Value=7;Toilette a compostage
Value=8;Toilettes suspendues / latrines suspendues
Value=9;Pas de toilettes / nature / champs
Value=96;Autre à préciser
 */

****ENSEMBLE LOGEMENT

*****NATURE DU SOL 
gen solterre = !inlist( P46, 2,3,4)
lab var solterre "Sol en terre ou sable, bois, Moquette ou autre; 1=oui, 0=non"
/*question RGPH: Nature du sol
Value=1;Terre ou sable
Value=2;Ciment
Value=3;Carreau/marbre
Value=4;Moquette/gerflex
Value=5;Bois
Value=8;Autre à préciser*/

*****NATURE DU TOIT (TOIT EN FIBRE OU AUTRES)
gen toiture = !inlist(P47, 2,3,4)
lab var toiture "toit en fibre, toile plastique ou autre; 1=oui, 0=non"
/*qustion RGPH: Nature du toit
Value=1;Fibre végétale (paille, papot...)
Value=2;Tôle
Value=3;Béton (ciment, dale)
Value=4;Tuile/éverite
Value=5;Toit en plastique (bâche..)
Value=8;Autre à préciser*/

*****NATURE DU MUR (MUR NON EN DUR)
gen matmur = !inlist( P45, 4,5,6)
lab var matmur "mur en bois, tole, banco ou autre; 1=oui, 0=non"
/*question RGPH: Nature du mur
Value=1;Bois
Value=2;Tôle
Value=3;Banco ou terre battue
Value=4;Sémi-dur
Value=5;Géobéton
Value=6;Dur (ciment, brique)
Value=7;Plastique  (bâche..)
Value=8;Autre à préciser*/

gen logement=solterre| toiture | matmur
lab var logement "logement inadequat ; 1=oui, 0=non"


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
lab var equi "Household Number of Small Assets Owned- National" 
gen equipement = (véhicule==1 | equi > 1) 
replace equipement = . if véhicule==. & equi==.
lab var equipement "Household Asset Ownership: HH has car or more than 1 small assets incl computer & animal cart"

recode equipement  (0=1)(1=0) , gen(pasequi)

keep $list_var_menage   paselec paseaup  paselec paseaup combsale pasta solterre toiture matmur logement pasequi



********************************************************************************
***********************CALCUL DE L'IPM **************************
********************************************************************************
