clear 
set more off

cls
args region_data

use "`region_data'", replace

***********************************************************************************************
****************CALCUL DES INDICATEURS (VARIABLES DUMMIES) PAR DIMENSIONS**********************
***********************************************************************************************

***************BASES DES INDIVIDUS 1998: DIMENSION EDUCATION********************
********************************************************************************

********FREQUENTATION SCOLAIRE : Le ménage à un enfant de 6-16 qui ne fréquente actuellement pas
*codebook P27_NIVEAUINST, tabulate(45)
*codebook P28_TYPA   
gen nonsco = inrange(P18AG_AG,6,16) & P28_TYPA  != 5
by $list_var_mena, sort : egen nbnsco1 = total(nonsco)
gen desco = nbnsco !=0 
drop nonsco nbnsco
lab var desco "au moins un enfant de 6 a 16 ans hors du systeme educatif; 1=oui, 0=non"
/*question RGPH: type d'activite
1 = occupé
2 = chômeur
3 = En quête du premier emploi
4 = ménagère
5 = étudiant ou élève
6 = retraité
7 = rentier
8 = autre inactif*/
ta desco

******** Années de scolarité: Personne de 17 ans et plus n'ayant pas achevé au moins 10 annees d'etudes [Niveau 3ème] 
//Affinement( REPRENDRE en faisant un recode), calculer le nb d'année detude pour tout le monde dans la base. Calculer le nombre d'année d'étude pour tout le monde.
*codebook P27_NIVE
gen nonedu = (P18AG_AG>=17)   & inlist( P27_NIVE, ., 98, 10, 11, 12, 13, 14, 15,16,21,22,23,31,32)
by $list_var_mena, sort : egen nbedu = total(nonedu)
gen educ = nbedu !=0 
drop nonedu nbedu
lab var educ "au moins un individu de 17 ans et plus qui n'a pas acheve 10 annees d'etudes; 1=oui, 0=non"
*ta educ


******ALPHABETISATION : 
*** Un  membre du ménage de 17 ans ou plus ne sait pas lire ou écrire (Français) 

*codebook P26_ALPH
* Identifier les membres du ménage de 17 ans ou plus
gen membre_17plus = (P18AG_AG >= 17)

* Calculer le nombre total de membres de 17 ans ou plus par ménage 
by $list_var_mena, sort: egen total_17plus = total(membre_17plus)

* Calculer le nombre total de membres analphabètes de 17 ans ou plus par ménage
by $list_var_mena, sort: egen total_analph = total((P18AG_AG >= 17 & P26_ALPH == 2))
gen mfsa = total_analph !=0 

lab var mfsa "Un  membre du ménage de 17 ans ou plus ne sait pas lire ou écrire (Français) ; 1=oui, 0=non"

gen EDUCATION = (educ + desco  + mfsa)/15
lab var EDUCATION "score de la dimension education"

summ desco educ mfsa EDUCATION



*************** DIMENSION EMPLOI***********************
********************************************************************************

****** Chomage.Le ménage est privé si un des membres est chômeur ou est en quête d'emploi 
gen chm= inlist(P28_TYPA, 2,3)
by  $list_var_mena, sort : egen nchm = total(chm)
gen chom = nchm !=0 
drop chm nchm
lab var chom "Chomeur; 1=oui, 0=non"

gen emploi = (chom)/5
lab var emploi "score de la dimension emploi"
/*question RGPH: Chomage
1.occupé
2.chomeur
3.Quête 1er emploi
4.Ménagère
5.Etudiant ou élève
6. Retraité
7. Rentier
8.Autre inactif
*/

keep if P16_LIEN == 1


*********************BASES 1998: DIMENSION SANTE************************

***************BASES DES MENAGES 1998: DIMENSION NIVEAU DE VIE********************
********************************************************************************

save "C:\Users\Dell\OneDrive\Bureau\PHAS\INPM\RGPH_98\Treated\\`region_data'_treated.dta", replace 

