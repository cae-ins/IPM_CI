

cls
args region_data

use "`region_data'", replace


******************TRAITEMENT DES VARIABLES INDIVIDUELLES********************
********************************************************************************

******************DIMENSION EDUCATION********************
********************************************************************************

******* Fréquentation scolaire : Le ménage a un enfant de 6-16 ans qui ne fréquente actuellement pas
gen nonsco = inrange(P19_AGE,6,16) & P31_SITOCCUPATION != 5 
by $list_var_menage, sort : egen nbnsco1 = total(nonsco)
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

******** Années de scolarité: Personne de 17 ans et plus n'ayant pas achevé au moins 10 annees d'etudes [Niveau 3ème] 
//Affinement( REPRENDRE en faisant un recode), calculer le nb d'année detude pour tout le monde dans la base. Calculer le nombre d'année d'étude pour tout le monde.
gen nonedu = (P19_AGE>=17) & inlist( P29_INSTRUCTION, ., 98, 10, 11, 12, 13, 14, 15,16,21,22,23,31,32) // regarder le cas des élèves et étudiants dans le statut d'occupation qui n'ont pas renseigné alphabétisation ou niveau d'instruc.
by  $list_var_menage, sort : egen nbedu = total(nonedu)
gen educ = nbedu !=0  
drop nonedu nbedu
lab var educ "Au moins un individu de 17 ans et plus qui n'a pas achevé 10 annees d'etudes; 1=oui, 0=non"

******ALPHABETISATION : 
*** Un  membre du ménage de 17 ans ou plus ne sait pas lire ou écrire (Français) 


* Identifier les membres du ménage de 17 ans ou plus
gen membre_17plus = (P19_AGE >= 17)

* Calculer le nombre total de membres de 17 ans ou plus par ménage 
by $list_var_menage, sort: egen total_17plus = total(membre_17plus)

* Calculer le nombre total de membres analphabètes de 17 ans ou plus par ménage
by $list_var_menage, sort: egen total_analph = total((P19_AGE >= 17 & P28_ALPHABETISATION == 2))
gen mfsa = total_analph !=0 

lab var mfsa "Un  membre du ménage de 17 ans ou plus ne sait pas lire ou écrire (Français) ; 1=oui, 0=non"

gen EDUCATION = (educ + desco  + mfsa)/15
lab var EDUCATION "score de la dimension education"



*************** DIMENSION EMPLOI***********************
********************************************************************************

****** Chomage.Le ménage est privé si un des membres est chômeur ou est en quête d'emploi 

gen chm= inlist(P31_SITOCCUPATION, 2,3)
by  $list_var_menage, sort : egen nchm = total(chm)
gen chom = nchm !=0 
drop chm nchm
lab var chom "Chomeur; 1=oui, 0=non"

gen emploi = (chom)/5
lab var emploi "score de la dimension emploi"


*********************BASES RGPH 1998: DIMENSION IDENTIFICATION***************
********************************************************************************

********Déclaration d'état civil à la naissance
gen pasid = !inlist(P21A_ETATCIVIL , 1, 2,3) 
lab var pasid "pas de déclaration; 1=oui, 0=non"
/*question RGPH: Déclaration d'état civil à la naissance
1.Acte de naissance
2.Jugement supplétif
3.Déclarée sans acte
4.Aucune déclaration
8.Ne sait pas
*/

gen Identification=(pasid)/5
lab var Identification "score de la dimension Identification"


********************************************************************************
*********************DIMENSION SANTE************************
********************************************************************************

*A COMPLETER
**** Mortalité Juvénile 

gen mjuv_prov = !inlist(DE59_DECES , 2) 
lab var mjuv_prov "décès au cours des 12 derniers mois; 1=oui, 0=non"
/*question RGPH: Mortalité
1.   oui
2.   non
*/

gen Sante = (mjuv_prov)/5
lab var Identification "score de la dimension Sante"

***************DIMENSION NIVEAU DE VIE********************
********************************************************************************

*****ELECTRICITE
gen paselec = !inlist( M51_ECLAIRAGE,1,2,3)
lab var paselec "Ne dispose pas d'electricite; 1=pas electricite, 0=electricite"
/*question RGPH14: Mode d'éclairage
1 : Electricité  
2 : Groupe électrogène  
3 : Panneau solaire  
4 : Lampe   
5 : Bois de chauffe  
6 : Torche  
7 : Autre */

*****EAU POTABLE  
gen paseaup = !inlist( M50_EAU,1,2,3,4)
lab var paseaup "Ne dispose pas d'acces a l'eau potable; 1=pas eau potable, 0=eau potable"
/*question RGPH: Alimentation en eau
1 : Eau courante dans le logement  
2 : Eau courante dans la cour  
3 : Eau courante à l'extérieur  
4 : Pompe villageoise  
5 : Puits dans la cour  
6 : Puits public  
7 : Eau de surface  
8 : Autre    */

*****COMBUSTIBLE 
gen combsale = !inlist( M52_CUISSON, 2,4)
lab var combsale "Utilise un combustible sale (bois, charbon, autres); 1=oui, 0=non"
/*question RGPH: Mode de cuisson
1.Bois de chauffe
2.Gaz
3.Charbon
4.Electricité
5.Autres à préciser
*/

*******TOILETTES
gen pasta = !inlist( M49_LIEUAISANCE , 1,3 )
/*question RGPH: LIEU D'AISANCE
1.   WC à l'intérieur 
2.   WC à l'extérieur 
3.   Latrines dans la cour 
4.   Latrines hors de la cour 
5.   Dans la nature 
6.   Autre à préciser */

****ENSEMBLE LOGEMENT

*****NATURE DU SOL 
gen solterre = !inlist( M48_SOL , 2,3)
lab var solterre "Sol en terre ou sable, bois, Moquette ou autre; 1=oui, 0=non"
/*question RGPH: Nature du sol
1.   Terre ou sable
2.   Ciment
3.   Carreau / Marbre
4.   Moquette / Tapis
5.   Bois
6.   Autre à préciser*/

*****NATURE DU TOIT (TOIT EN FIBRE OU AUTRES)
gen toiture = !inlist(M47_TOIT , 2,3,4)
lab var toiture "toit en fibre, toile plastique ou autre; 1=oui, 0=non"
/*qustion RGPH: Nature du toit
1.   Fibre végétale
2.   Tôle
3.   Béton
4.   Tuile/Everite
5.   Toile en plastique
6.   Autre à préciser*/

*****NATURE DU MUR (MUR NON EN DUR)
gen matmur = !inlist( M46_MUR, 4,5,6)
lab var matmur "mur en bois, tole, banco ou autre; 1=oui, 0=non"
/*question RGPH: Nature du mur
1.   Bois
2.   Tôle
3.   Banco ou terre battue
4.   Semi-dur
5.   Géobéton
6.   Dur
7.   Autres à préciser*/

gen logement=solterre| toiture | matmur
lab var logement "logement inadequat ; 1=oui, 0=non"

*****EQUIPEMENT 

* create new variables that sum existing variables 
gen Deplacement =  M55A3_VEHICULE 
label define Deplacement 0 "Aucun moyen de déplacement" 1 "1 moyen de déplacement" ///
2 "2 moyens de déplacement" 3 "3 moyens de déplacement" 4 "4 moyens de déplacement" ///
5 "5 moyens de déplacement" 6 "6 moyens de déplacement" 7 "7 moyens de déplacement" 8 ///
"8 moyens de déplacement" 9 "9 moyens de déplacement" 10 "10 moyens de déplacement" ///
11 "11 moyens de déplacement" 12 "12 moyens de déplacement" 13 "13 moyens de déplacement" ///
14 "14 moyens de déplacement" 15 "15 moyens de déplacement" 16 "16 moyens de déplacement" ///
17 "17 moyens de déplacement" 18 "18 moyens de déplacement"
label values Deplacement deplacement
replace Deplacement=0 if Deplacement==.

gen electroetaudio = M55B1_VENTILATEUR + M55B2_REFRIGERATEUR + M55B5_CLIMATISEUR + M55C1_RADIO + M55C3_TELEPHONFIXE +M55C4_TELEPHONMOBIL + M55A2_MOTOMOBYLETTE + M55A1_VELOBICYCLETTE 
label define bienmixte 0 "Aucun electroetaudio" 1 "1 electroetaudio" 2 "2 electroetaudio " 3 "3 electroetaudio" 4 "4 electroetaudio" ///
5 "5 electroetaudio" 6 "6 electroetaudio"  7 "7 electroetaudio" 8 "8 electroetaudio" 9 "9 electroetaudio" 10 "10 electroetaudio" 11 "11 electroetaudio" ///
12 "electroetaudio" 13 "13 electroetaudio" 14 "14 electroetaudio" 15 "15 electroetaudio" 16 "16 electroetaudio" 17 "17 electroetaudio " 18 "18 electroetaudio" ///
19 "19 electroetaudio" 20 "20 electroetaudio"  21 "21 electroetaudio" 22 "22 electroetaudio" 23 "23 electroetaudio" 24 "24 electroetaudio" 25 "25 electroetaudio" ///
26 "26 electroetaudio" 27 "27 electroetaudio" 28 "28 electroetaudio" 29 "29 electroetaudio" 30 "30 electroetaudio" 31 "31 electroetaudio" 32 "32 electroetaudio"  ///
33 "33 electroetaudio" 34 "34 electroetaudio" 
label values electroetaudio bienmixte
replace electroetaudio=0 if electroetaudio==.

gen pasequi = inlist(electroetaudio,0 ,1) & inlist(Deplacement,0)
lab var pasequi "Pas plus d'un equipement; 1=oui, 0=non"

gen condvie = (paselec+paseaup+combsale+pasta+logement+pasequi)/30
lab var condvie "score de la dimension condition de vie"

******************CONSTRUCTION DE LA BASE REGIONALE********************
********************************************************************************

keep if P17_LIENPARENTE == 1

keep $list_var_menage desco educ mfsa  chom P17_LIENPARENTE pasid  paselec paseaup mjuv_prov paselec paseaup combsale pasta solterre toiture matmur logement Deplacement electroetaudio pasequi EDUCATION condvie Sante Identification emploi DE59_DECES

save "C:\Users\Dell\OneDrive\Bureau\PHAS\INPM\RGPH 2014\Treated\\`region_data'_treated.dta", replace 
