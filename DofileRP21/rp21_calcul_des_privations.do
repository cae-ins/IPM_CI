// La base utilisée provient du bureau des demographes (Voir Aminata et Doyen Toure)
clear all
global in "$projet\data\data_in"
global do "$projet\dofilerp21"
global out "$projet\data\data_out"
use "$in\IPM_Data_191125.dta", clear
global list_var_menage "SOUSPREFID  P04 milieu P05 P07 P09 P09A P09B P10 DEPART REGION" 
global list_var_menage1 "SOUSPREFID  P04 P08 P05 P07 P09 P09A P09B P10 DEPART REGION" 

foreach var in SOUSPREFID  P04 P08 P05 P07 P09 P09A P09B P10 DEPART REGION {
    count if missing(`var')
}

******************TRAITEMENT DES VARIABLES INDIVIDUELLES************************
********************************************************************************

******************DIMENSION EDUCATION*******************************************
********************************************************************************

******* Fréquentation scolaire : Le ménage a un enfant de 6-14 ans qui ne fréquente actuellement pas
gen nonsco = inrange(P18A_AGE,6,16) & P30A != 1 
by $list_var_menage, sort : egen nbnsco1 = total(nonsco)
gen desco = nbnsco1 !=0 
drop nonsco nbnsco1
lab var desco "au moins un enfant de 6 a 16 ans hors du systeme educatif; 1=oui, 0=non"

/*question RGPH: type d'activite
Value=1;Oui, fréquente l'école actuellement
Value=2;Non ne fréquente pas actuellement, mais a dejà fréquenté l'école
Value=3;Non, n'a jamais fréquenté l'école
Value=8;Ne sait pas
*/

******** Années de scolarité: Personne de 17 ans et plus n'ayant pas achevé au moins 10 annees d'etudes [Niveau 3ème] 

gen nonedu = (P18A_AGE>=17 & P18A_AGE!=.) & !inlist(P32, .,23,1,2,3) 
by  $list_var_menage, sort : egen nbedu = max(nonedu)
gen educ = !nbedu  
drop nonedu nbedu
lab var educ "Au moins un individu de 17 ans et plus qui n'a pas achevé 10 annees d'etudes; 1=oui, 0=non"

/*
Value=1;Aucun diplôme
Value=2;CEPE
Value=3;Certificat de Qualification Professionnelle (CQP)
Value=4;BEPC
Value=5;CAP
Value=6;BEP
Value=7;BP
Value=8;BT
Value=9;BAC
Value=10;BTS
Value=11;DUT
Value=12;DEUG1 / LICENCE 1
Value=13;DEUG2 / LICENCE 2
Value=14;LICENCE / LICENCE 3
Value=15;MAITRISE / MASTER 1
Value=16;DEA / MASTER 2
Value=17;Ingénieur
Value=18;MBA/Master
Value=19;DESS
Value=20;DOCTORAT
Value=21;PHD
Value=22;Autres à préciser
Value=23;Ne sait pas
*/

***Destitution : PNUD 

******** Années de scolarité: Personne de 10 ans et plus n'ayant pas achevé au moins 6 annees d'etudes

gen nonedu1 = (P18A_AGE>=10 & P18A_AGE!=.) & !inlist(P32, ., 23,1) 
by  $list_var_menage, sort : egen nbedu1 =  max(nonedu1)
gen educ1 = !nbedu1 
drop nonedu1 nbedu1
lab var educ1 "Au moins un individu de 10 ans et plus qui n'a pas achevé 6 annees d'etudes; 1=oui, 0=non"

/*
Value=1;Aucun diplôme
Value=2;CEPE
Value=3;Certificat de Qualification Professionnelle (CQP)
Value=4;BEPC
Value=5;CAP
Value=6;BEP
Value=7;BP
Value=8;BT
Value=9;BAC
Value=10;BTS
Value=11;DUT
Value=12;DEUG1 / LICENCE 1
Value=13;DEUG2 / LICENCE 2
Value=14;LICENCE / LICENCE 3
Value=15;MAITRISE / MASTER 1
Value=16;DEA / MASTER 2
Value=17;Ingénieur
Value=18;MBA/Master
Value=19;DESS
Value=20;DOCTORAT
Value=21;PHD
Value=22;Autres à préciser
Value=23;Ne sait pas
*/


******ALPHABETISATION : 
*** Un  membre du ménage de 16 ans ou plus ne sait pas lire ou écrire en francais

gen alphab = 1 if (P29_BA == 1) & inrange(P18A_AGE, 16,49)
replace alphab = 0 if !(P29_BA == 1)  & inrange(P18A_AGE, 16,49)
replace alphab=. if P29_BA ==.
by $list_var_menage, sort: egen total_analph = max(alphab)
gen cas1 = inrange(P18A_AGE, 16,49)
by $list_var_menage, sort: egen cas = total(cas1)
drop cas1
replace total_analph=1 if cas ==0
drop cas
recode total_analph (0=1) (1=0), gen(mfsa)
lab var mfsa "Un  membre du ménage de 16 - 49 ans ne sait pas lire ou écrire (Français) ; 1=oui, 0=non"
/*
Label=Peut-il/elle lire, écrire et comprendre dans cette langue/ces langues : En Français
Value=1;Oui
Value=0;Non
*/


*************************************************************** DIMENSION EMPLOI A REVOIR VRAIMENT POUR ETRE SUR QU'ON MESURE L'EMPLOI****************************************************************************

**** Chomage. Le ménage est privé si un des membres (ayant entre 15 et 24 ans) est chômeur ou est en quête d'emploi 
codebook P34B, tab(100)
gen chm= inlist(P34B,8,9,10,11,12, 13,18) & P34CNEWtbB == 1  & (P18A_AGE>=16 & P18A_AGE<=35)
by  $list_var_menage, sort : egen nchm = total(chm)
gen chom = nchm !=0 
drop chm nchm
lab var chom "Chomeur; 1=oui, 0=non"
/*Pourquoi n'a-t-il/elle pas travaillé pendant les 7 derniers jours
Value=1;Congés/Vacances ou assimilés
Value=2;Maladie ou Accident prise en charge par l'employeur
Value=3;Grève
Value=4;Fin de campagne/saison ou Travail saisonnier
Value=5;Congé de maternité
Value=6;Travail en rotation ou Arrêt provisoire du travail
Value=7;En attente d'une prise de fonction/Vient d'être récruté
Value=8;Réduction temporaire des effectifs
Value=9;Mise à pied temporaire
Value=10;Mauvaises conditions climatiques
Value=11;Licenciement ou Fin de contrat
Value=12;Handicap de longue durée
Value=13;En quête du premier emploi
Value=14;Travaux de domestiques non rémunérés
Value=15;Etudiant ou Elève
Value=16;Retraité/Vieillard
Value=17;Rentier
Value=18;A la recherche d'emploi*
  
  
Value=96;Autres raisons (à préciser)
*/

**********************************************DIMENSION EMPLOI MODIFIE***************************************
*--- Recode des variables ---
recode P34ANEWtb (0/10 = 1) (11 = 2), gen(p34aa)
recode P34B (1 2 3 4 5 6 7 96 = 1) (8/18 = 2) (else = .), gen(p34bb)
recode P34CNEWtbB (1 = 1) (2 8 = 2) (else = .), gen(p34cc)
recode P34DNEWtbB (1 = 1) (2 8 = 2) (else = .), gen(p34dd)
recode P34ENEWtbB (1 = 1) (2 8 = 2) (else = .), gen(p34ee)

  
*--- Variable Statut_OQP ---
gen Statut_OQP = .

replace Statut_OQP = 0 if p34aa == 1 | (p34aa == 2 & p34bb == 1)

replace Statut_OQP = 1 if p34aa == 2 ///
    & p34bb == 2 ///
    & p34cc == 1 ///
    & p34dd == 1

replace Statut_OQP = 2 if p34aa == 2 ///
    & p34bb == 2 ///
    & p34cc == 2 ///
    & p34dd == 2 ///
    & p34ee == 2

replace Statut_OQP = 3 if p34aa == 2 & ( ///
      (p34cc == 2 & p34dd == 1) ///
   |  (p34cc == 1 & p34dd == 2) ///
   |  (p34cc == 2 & p34dd == 2 & p34ee == 1) )

*--- Labels ---
label variable Statut_OQP "Statut d'occupation"

label define statut_lbl ///
    0 "En emploi" ///
    1 "En chômage" ///
    2 "Autre HMO" ///
    3 "Main d'oeuvre potentielle"

label values Statut_OQP statut_lbl

gen chm2= (Statut_OQP== 1)  & (P18A_AGE>=16 & P18A_AGE<=35)
by  $list_var_menage, sort : egen nchm2 = total(chm2)
gen chom2 = nchm2 !=0 
drop chom
gen chom = chom2
drop chm2 nchm2 chom2

***IDENTIFICATION*****************************************************************************************

********Déclaration de naissance à l'état civil

gen pasid = !inlist(P20 , 1, 2) & (P18A_AGE>=5 & P18A_AGE<=15)
by $list_var_menage, sort : egen Ident = max(pasid)
*replace Ident=. if P21A_ETATCIVIL==.
lab var Ident "pas de déclaration; 1=oui, 0=non"
/*question RGPH: Déclaration d'état civil à la naissance
Value=1;Oui déclaré, avec extrait d'acte de naissance/jugement supplétif
Value=2;Oui déclaré, sans acte de naissance
Value=3;Non, pas déclaré à l'état civil
Value=8;Ne sait pas
*/


keep if P15A == 1
// garder les résidents présents

keep if P16 == 1
// Chef de ménage (CM)
drop _merge
sort INDIV_ID
save "$out\data_out_ind_men.dta", replace
***************DIMENSION NIVEAU DE VIE***************************************************************************************************

use "$in\IPM_Data_110924_men.dta", clear
*****ELECTRICITE
gen paselec = !inlist(P51,1,2,3) 
lab var paselec "Ne dispose pas d'electricite; 1=pas electricite, 0=electricite"
/*question RGPH: Mode d'éclairage
Value=1;Electricité (CIE)
Value=2;Groupe électrogène
Value=3;Panneau solaire
Value=4;Lampe (à pétrole, à gaz, à huile)
Value=5;Bois de chauffe
Value=6;Torche
Value=8;Autre à préciser
*/

*****EAU POTABLE  
gen paseaup = !inlist(P49,1,2,3,4,5,7,10)
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
gen solterre = !inlist( P47, 2,3,4)
lab var solterre "Sol en terre ou sable, bois, Moquette ou autre; 1=oui, 0=non"
/*question RGPH: Nature du sol
Value=1;Terre ou sable
Value=2;Ciment
Value=3;Carreau/marbre
Value=4;Moquette/gerflex
Value=5;Bois
Value=8;Autre à préciser*/

*****NATURE DU TOIT (TOIT EN FIBRE OU AUTRES)
gen toiture = !inlist(P46, 2,3,4)
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
	
gen velo = . 
///Problème ici, la variable P55A est tjrs vide soit vide, soit point.

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


gen vehicule = .
replace vehicule = 1 if P55C == 1
replace vehicule = 0 if P55C == .
ta vehicule , m

egen equi = rowtotal( velo televison radio telephone ordinateur charette refrigerateur motoetbycle ), missing
lab var equi "Household Number of Small Assets Owned- National" 
gen equipement = (vehicule==1 | equi > 1) 
replace equipement = . if vehicule==. & equi==.
lab var equipement "Household Asset Ownership: HH has car or more than 1 small assets"

recode equipement  (0=1)(1=0) , gen(pasequi)
lab var pasequi "Household privated : HH has neither car neither more than 1 small assets"

sort INDIV_ID
cap drop _merge
merge 1:1 INDIV_ID using "$out\data_out_ind_men.dta"
keep if _merge==3
cap drop _merge
keep $list_var_menage INDIV_ID EW milieu Milieu2 P08 desco educ mfsa  chom  P16  Ident educ1 paselec paseaup paselec paseaup combsale pasta solterre toiture matmur logement pasequi TAILLE_MENAGE 

save "$out\final_data.dta", replace

********************************************************************************
*********************DIMENSION SANTE************************
********************************************************************************
use "$in\MORTALITE_RP2021_TRAITEMENT.dta", clear

by $list_var_menage1,  sort : gen decs18 =  M61A2_AGE if  M61A2_AGE <18
collapse (count) decs18, by ($list_var_menage1)
save "$out\DECES8_RGPH2021.dta", replace

use "$out\final_data.dta"

merge m:1 $list_var_menage1 using "$out\DECES8_RGPH2021.dta" ,keepusing(decs18)
drop if _merge==2
gen mjuv = decs18 > 0 if decs18 !=.
replace mjuv = 0 if decs18==. 

lab var mjuv "Au moins un décès de moins de 18 ans; 1=oui, 0=non"
drop _merge 
ren TAILLE_MENAGE TOTMEN
save "$out\final_data.dta", replace




