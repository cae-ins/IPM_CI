
clear all 
set more off

*** Chemin ***
global data "C:\Users\Dell\OneDrive\Bureau\PHAS\INPM\EHCVM 2018\Bases brutes" 	  
global sortie "C:\Users\Dell\OneDrive\Bureau\PHAS\INPM\EHCVM 2018\Sortie"
global dofile "C:\Users\Dell\OneDrive\Bureau\PHAS\INPM\EHCVM 2018\Dofile"

********************************************************************************
*** EHCVM-2018 ***
********************************************************************************

use "$data/ehcvm_individu_CIV2018.dta"


******************TRAITEMENT DES VARIABLES INDIVIDUELLES********************
********************************************************************************

******************DIMENSION EDUCATION********************
********************************************************************************

******* Fréquentation scolaire : Le ménage a un enfant de 6-16 ans qui ne fréquente actuellement pas
/*
gen nonsco = inrange(age,6,16) & activ12m  != 5 
by $list_var_menage, sort : egen nbnsco1 = total(nonsco)
gen desco = nbnsco !=0 
drop nonsco nbnsco
lab var desco "au moins un enfant de 6 a 16 ans hors du systeme educatif; 1=oui, 0=non"
Pas de variable qui identifie si l'individu est à l'école ou non
*/

******** Années de scolarité: Personne de 17 ans et plus n'ayant pas achevé au moins 10 annees d'etudes [Niveau 3ème] 
gen nonedu = (age>=17) & inlist(educ_hi,0,1,2,3,4,5) 
by  $list_var_menage, sort : egen nbedu = total(nonedu)
gen educ = nbedu !=0  
drop nonedu nbedu
lab var educ "Au moins un individu de 17 ans et plus qui n'a pas achevé 10 annees d'etudes; 1=oui, 0=non"

******ALPHABETISATION : 
*** Un  membre du ménage de 17 ans ou plus ne sait pas lire ou écrire (Français) 


* Identifier les membres du ménage de 17 ans ou plus
gen membre_17plus = (age >= 17)

* Calculer le nombre total de membres de 17 ans ou plus par ménage 
by $list_var_menage, sort: egen total_17plus = total(membre_17plus)

* Calculer le nombre total de membres analphabètes de 17 ans ou plus par ménage
by $list_var_menage, sort: egen total_analph = total((age >= 17 & alfab  == 0))
gen mfsa = total_analph !=0 

lab var mfsa "Un  membre du ménage de 17 ans ou plus ne sait pas lire ou écrire (Français) ; 1=oui, 0=non"

gen EDUCATION = (educ + desco  + mfsa)/15
lab var EDUCATION "score de la dimension education"

*************** DIMENSION EMPLOI***********************
********************************************************************************

****** Chomage.Le ménage est privé si un des membres est chômeur ou est en quête d'emploi 

gen chm= inlist(activ12m,3) & P19_AGE >= 16
by  $list_var_menage, sort : egen nchm = total(chm)
gen chom = nchm !=0 
drop chm nchm
lab var chom "Chomeur; 1=oui, 0=non"
gen emploi = (chom)/5
lab var emploi "score de la dimension emploi"


********************* DIMENSION IDENTIFICATION***************
********************************************************************************

******************TRAITEMENT DES VARIABLES MENAGES********************
********************************************************************************

********************* DIMENSION NIVEAU DE VIE***************
********************************************************************************
use "$data/datain/Menage/s11_me_CIV2018.dta" 

*****ELECTRICITE
gen paselec = !inlist( s11q38 ,1,2,6)
lab var paselec "Ne dispose pas d'electricite; 1=pas electricite, 0=electricite"
/*
1  Electricité réseau
2  Electricité (générateur)
3  Lampe à pétrole
4  Lampe à pile, grosse torche
5  Paraffine/Bois/Planche
6  Plaque solaire
7  Autre
 */
*****EAU POTABLE  
gen paseaup = !inlist( s11q22 ,1)
lab var paseaup "Ne dispose pas d'acces a l'eau potable; 1=pas eau potable, 0=eau potable"
/*Le ménage est-il connecté à un réseau d'eau courante?
1: oui
2: Non*/

*****COMBUSTIBLE 
/*gen combsale = !inlist()
lab var combsale "Utilise un combustible sale (bois, charbon, autres); 1=oui, 0=non"
*/

*******TOILETTES
gen pasta = !inlist( s11q55 , 1,3,5,6,7,8)
lab var pasta "Ne dispose pas de toilette privée améliorée; 1=pas toilette privée, 0=toilette privée"
/* question: 11.55. Quel type de sanitaire votre ménage utilise-t-il?
1  W.C. intérieur avec chasse d'eau
2  W.C. extérieur avec chasse d'eau
3  W.C. intérieur chasse d'eau manuelle
4  W.C. extérieur chasse d'eau manuelle
5  Latrines VIP (dallées,ventillées)
6  Latrines ECOSAN (dallées,couvertes)
7  Latrines SANPLAT (dallées, non couvertes)
8  Latrines dallées simplement
9  Fosse rudimentaire/trou ouvert
10  Toilettes publiques
11  Aucune toilette (dans la nature)
12  Autre
*/
****ENSEMBLE LOGEMENT

*****NATURE DU SOL 
gen solterre = !inlist( s11q21  , 1,2)
/*Quel est le principal matériau de revêtement du sol du logement?
1  Carreaux/Marbre
2  Ciment/Béton
3  Terre battue/Sable
4  Bouse d'animaux
5  Autre
.a  
*/
la var solterre "sol en terre battue, bouse ou autre; 1=oui, 0=non"

****NATURE DU TOIT (TOIT EN FIBRE OU AUTRES)
gen toiture = !inlist(s11q20  , 2,3,1)
lab var toiture "toit en paille, toile nattes, etc ou autre; 1=oui, 0=non"
/*Quel est le principal matériau du toit?
1  Dalle en ciment
2  Tuile
3  Tôles
4  Paille
5  Banco
6  Chaume
7  Nattes
8  Autre

*/

*****NATURE DU MUR (MUR NON EN DUR)
gen matmur = !inlist( s11q19, 1,2,4)
lab var matmur "mur en bois, tole, banco ou autre; 1=oui, 0=non"

/* Quel est le principal matériau de construction des murs extérieurs ?

1  Ciment/Béton/Pierres de taille
2  Briques cuites
3  Bac alu, vitres, etc
4  Banco amélioré/ semi-dur
5  Matériaux de récupération
(planches, toles,…)
6  Pierres simples (Traditionnelles)
7  Paille, Banco, motte de terre
8  Autre

*/

gen logement=solterre| toiture | matmur
lab var logement "logement inadequat ; 1=oui, 0=non"

use "$data/datain/Menage/s12_me_CIV2018.dta.dta" 

********************************************************************************
*********************DIMENSION SANTE************************
********************************************************************************

******************CONSTRUCTION DE LA BASE REGIONALE********************
********************************************************************************
 
keep if P17_LIENPARENTE == 1



