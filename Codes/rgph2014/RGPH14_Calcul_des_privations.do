
cls
args region_data

use "`region_data'", replace


******************TRAITEMENT DES VARIABLES INDIVIDUELLES********************
********************************************************************************

******************DIMENSION EDUCATION********************
********************************************************************************

******* Fréquentation scolaire : Le ménage a un enfant de 6-14 ans qui ne fréquente actuellement pas
gen nonsco = inrange(P19_AGE,6,14) & P31_SITOCCUPATION != 5 
by $list_var_menage, sort : egen nbnsco1 = total(nonsco)
gen desco = nbnsco !=0 
drop nonsco nbnsco
lab var desco "au moins un enfant de 6 a 14 ans hors du systeme educatif; 1=oui, 0=non"
/*question RGPH: type d'activite
1 = occupé
2 = chômeur
3 = En quête du premier emploi
4 = ménagère	
5 = étudiant ou élève
6 = retraité
7 = rentier
8 = autre inactif*
*/


******* Fréquentation scolaire : Le ménage a un enfant de 6-14 ans qui ne fréquente actuellement pas
gen nonsco1 = inrange(P19_AGE,6,14) & P31_SITOCCUPATION4 == 2
by $list_var_menage, sort : egen nbnsco1 = total(nonsco1)
gen desco1 = nbnsco1 !=0 
drop nonsco1 nbnsco1
lab var desco1 "au moins un enfant de 6 a 14 ans hors du systeme educatif; 1=oui, 0=non"
/*question RGPH: type d'activite
1 = occupé
2 = chômeur
3 = En quête du premier emploi
4 = ménagère	
5 = étudiant ou élève
6 = retraité
7 = rentier
8 = autre inactif*
*/

******** Années de scolarité: Personne de 17 ans et plus n'ayant pas achevé au moins 10 annees d'etudes [Niveau 3ème] 

gen nonedu = (P19_AGE>=17 & P19_AGE!=.) & !inlist(P29_INSTRUCTION, .,98,10, 11, 12, 13, 14, 15,16,20,21,22,23,24,30) 
by  $list_var_menage, sort : egen nbedu = max(nonedu)
gen educ = !nbedu  
drop nonedu nbedu
lab var educ "Au moins un individu de 17 ans et plus qui n'a pas achevé 10 annees d'etudes; 1=oui, 0=non"

***Destitution : PNUD 

******** Années de scolarité: Personne de 10 ans et plus n'ayant pas achevé au moins 6 annees d'etudes

gen nonedu1 = (P19_AGE>=10 & P19_AGE!=.) & !inlist( P29_INSTRUCTION, ., 98,10, 11, 12, 13, 14, 15,16) 
by  $list_var_menage, sort : egen nbedu1 =  max(nonedu1)
gen educ1 = !nbedu1 
drop nonedu1 nbedu1
lab var educ1 "Au moins un individu de 10 ans et plus qui n'a pas achevé 6 annees d'etudes; 1=oui, 0=non"

******ALPHABETISATION : 
*** Un  membre du ménage de 17 ans ou plus ne sait pas lire ou écrire (Français) 

* Identifier les membres du ménage de 17 ans ou plus
gen membre_17plus = (P19_AGE >= 17)

* Calculer le nombre total de membres de 17 ans ou plus par ménage 
by $list_var_menage, sort: egen total_17plus = max(membre_17plus)

* Calculer le nombre total de membres analphabètes de 17 ans ou plus par ménage
by $list_var_menage, sort: egen total_analph = max((P19_AGE >= 17 & P19_AGE<=49 & P28_ALPHABETISATION == 2))
gen mfsa = total_analph !=0 

lab var mfsa "Un  membre du ménage de 17 - 49 ans ne sait pas lire ou écrire (Français) ; 1=oui, 0=non"


*************** DIMENSION EMPLOI***********************
********************************************************************************

****** Chomage.Le ménage est privé si un des membres (ayant entre 15 et 24 ans) est chômeur ou est en quête d'emploi 

gen chm= inlist(P31_SITOCCUPATION, 2,3) & (P19_AGE>=15 & P19_AGE<=24)
by  $list_var_menage, sort : egen nchm = total(chm)
gen chom = nchm !=0 
drop chm nchm
lab var chom "Chomeur; 1=oui, 0=non"


*********************BASES RGPH 14: DIMENSION IDENTIFICATION***************
********************************************************************************

********Déclaration d'état civil à la naissance
gen pasid = !inlist(P21A_ETATCIVIL , 1, 2,3) & (P19_AGE>=5 & P19_AGE<=15)
by $list_var_menage, sort : egen Ident = max(pasid)
*replace Ident=. if P21A_ETATCIVIL==.
lab var Ident "pas de déclaration; 1=oui, 0=non"
/*question RGPH: Déclaration d'état civil à la naissance
1.Acte de naissance
2.Jugement supplétif
3.Déclarée sans acte
4.Aucune déclaration
8.Ne sait pas
*/

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
gen paseaup = !inlist( M50_EAU,1,2,3,4,5)
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
gen pasta = !inlist( M49_LIEUAISANCE , 1,2,3 )
/*question RGPH: LIEU D'AISANCE
1.   WC à l'intérieur 
2.   WC à l'extérieur 
3.   Latrines dans la cour 
4.   Latrines hors de la cour 
5.   Dans la nature 
6.   Autre à préciser */

****ENSEMBLE LOGEMENT

*****NATURE DU SOL 
gen solterre = !inlist( M48_SOL , 2,3,4)
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
	
gen velo = (M55A1_VELOBICYCLE !=0)
gen televison = (M55C2_TELEVISION !=0)
gen radio = (M55C1_RADIO!=0)
gen telephone = (M55C4_TELEPHONMOBIL!=0)
gen ordinateur = (M55C5_ORDINATEUR!=0)
gen charette = (M55A6_CHARETTE!=0)
gen refrigerateur = (M55B2_REFRIGERATEUR!=0)
gen motoetbycle = (M55A2_MOTOMOBYLETTE!=0)
gen véhicule = (M55A3_VEHICULE!=0)

egen equi = rowtotal( velo televison radio telephone ordinateur charette refrigerateur motoetbycle ), missing
lab var equi "Household Number of Small Assets Owned- National" 
gen equipement = (véhicule==1 | equi > 1) 
replace equipement = . if véhicule==. & equi==.
lab var equipement "Household Asset Ownership: HH has car or more than 1 small assets incl computer & animal cart"

recode equipement  (0=1)(1=0) , gen(pasequi)

******************CONSTRUCTION DE LA BASE MENAGE********************
********************************************************************************

keep if P16_SITRESIDENCE == 1

keep if P17_LIENPARENTE == 1

keep $list_var_menage desco educ mfsa  chom P17_LIENPARENTE pasid  paselec paseaup  paselec paseaup combsale pasta solterre toiture matmur logement pasequi     Ident educ1 DE59_DECES

save "$sortie\Treated\\`region_data'_treated.dta", replace 
