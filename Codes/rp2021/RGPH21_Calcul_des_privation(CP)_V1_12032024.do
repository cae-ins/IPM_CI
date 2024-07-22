cls
args region_data

use "`region_data'", replace

******************TRAITEMENT DES VARIABLES INDIVIDUELLES********************
********************************************************************************

******************DIMENSION EDUCATION********************
********************************************************************************

******* Fréquentation scolaire : Le ménage a un enfant de 6-14 ans qui ne fréquente actuellement pas
gen nonsco = inrange(P18A_AGE,6,14) & P30A != 1 
by $list_var_menage, sort : egen nbnsco1 = total(nonsco)
gen desco = nbnsco !=0 
drop nonsco nbnsco
lab var desco "au moins un enfant de 6 a 14 ans hors du systeme educatif; 1=oui, 0=non"

/*question RGPH: type d'activite
Value=1;Oui, fréquente l'école actuellement
Value=2;Non ne fréquente pas actuellement, mais a dejà fréquenté l'école
Value=3;Non, n'a jamais fréquenté l'école
Value=8;Ne sait pas
*/

******** Années de scolarité: Personne de 17 ans et plus n'ayant pas achevé au moins 10 annees d'etudes [Niveau 3ème] 

gen nonedu = (P18_AGE>=17 & P18_AGE!=.) & !inlist(P32, .,23,1,2,3) 
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
*** Un  membre du ménage de 17 - 49 ans ne sait pas lire , écrire et comprendre en francais

gen alphab = 1 if (P29_BA == 0) | !inlist(P32,.,23,1,2,3,4) & inrange(P18A_AGE, 17,49)
replace alphab = 0 if !(P29_BA == 0) | inlist(P32,., 23,1,2,3,4) & inrange(P18A_AGE, 17,49)
by $list_var_menage, sort: egen total_analph = max(alphab)
recode total_analph (0=1) (1=0), gen(mfsa)
drop alphab total_analph
*replace mfsa=. if P32==.
lab var mfsa "Un  membre du ménage de 17 - 49 ans ne sait pas lire ou écrire (Français) ; 1=oui, 0=non"
/*
Label=Peut-il/elle lire, écrire et comprendre dans cette langue/ces langues : En Français
Value=1;Oui
Value=0;Non
*/


*************************************************************** DIMENSION EMPLOI ****************************************************************************

**** Chomage. Le ménage est privé si un des membres (ayant entre 15 et 24 ans) est chômeur ou est en quête d'emploi 

gen chm= inlist(P34B, 13,18) & (P18A_AGE>=15 & P18A_AGE<=24)
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
Value=18;A la recherche d'emploi
Value=96;Autres raisons (à préciser)
*/

****************************BASES RGPH 14: DIMENSION IDENTIFICATION*****************************************************************************************

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


******************CONSTRUCTION DE LA BASE MENAGE********************
********************************************************************************

keep if P16 == 1

keep if P17 == 1

keep $list_var_menage desco educ mfsa  chom P17 pasid  paselec paseaup  paselec paseaup combsale pasta solterre toiture matmur logement pasequi Ident educ1 

save "$sortie\Treated\\`region_data'_treated.dta", replace 

