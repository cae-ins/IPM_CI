
***********************************************************************************************
****************CALCUL DES INDICATEURS (VARIABLES DUMMIES) PAR DIMENSIONS**********************
***********************************************************************************************

***************BASES DES INDIVIDUS 1998: DIMENSION EDUCATION********************
********************************************************************************

use "C:\Users\Dell\OneDrive\Bureau\PHAS\INPM\RGPH_98\base_individu_rgph98.dta" , clear

duplicates drop I01_REGI I02_DEPA I03_SPREF I04_MILIEU I09T_TYP I09N_NUM P14_ORDR, force

********FREQUENTATION SCOLAIRE : Le ménage à un enfant de 6-16 qui ne fréquente actuellement pas
codebook P27_NIVE, tabulate(45)
*l'age n'existe pas dans le rgph 98 donc on génère un age fictif 
gen age_fake = rnormal(45,25) 
clonevar P18AG_AGE = age_fake
gen nonsco = inrange( P18AG_AGE,6,16) & P28_TYPA != 5
global list_var_individuel I01_REGI I02_DEPA I03_SPREF I04_MILIEU  I09T_TYP I09N_NUM P14_ORDR
by $list_var_individuel, sort : egen nbnsco1 = total(nonsco)
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
******** ANNEE DE SCOLARITE: Personne de 15 ans (voire plus) et plus n'ayant pas achevé au moins 6 annees d'etudes
codebook P27_NIVE
gen nonedu = (P18AG_AGE>=15 & P18AG_AGE!=.) & inlist(P27_NIVE, ., 98, 10, 11, 12, 13, 14, 15)
by $list_var_individuel, sort : egen nbedu = total(nonedu)
gen educ = nbedu !=0 
drop nonedu nbedu
lab var educ "au moins un individu de 15 ans et plus qui n'a pas acheve 6 annees d'etudes; 1=oui, 0=non"
ta educ
****** RETARD SCOLAIRE : Personne entre 9 et 16 ans ayant un retard scolaire de deux ans ou plus 
codebook P27_NIVE, tabulate(45)
gen ageleg =.
// Primaire
replace ageleg= 6 if P27_NIVE == 11 
replace ageleg= 7 if P27_NIVE == 12
replace ageleg= 8 if P27_NIVE == 13
replace ageleg= 9 if P27_NIVE == 14
replace ageleg=10 if P27_NIVE == 15
replace ageleg=11 if P27_NIVE == 16
// Secondaire g1
replace ageleg=12 if P27_NIVE == 21
replace ageleg=13 if P27_NIVE == 22
replace ageleg=14 if P27_NIVE == 23
replace ageleg=15 if P27_NIVE == 24
// Secondaire technique 1 
*Vérifier si l'age du CAP1 est 16
*Vérifier si l'age du BEP1 est 16
*Vérifier si l'age du BP1 est 16
*Vérifier si l'age du BT1 est 18
*Vérifier si l'age du BT2 est 19
replace ageleg=16 if P27_NIVE == 31
replace ageleg=17 if P27_NIVE == 32
replace ageleg=18 if P27_NIVE == 33
replace ageleg=16 if P27_NIVE == 34
replace ageleg=17 if P27_NIVE == 35
replace ageleg=16 if P27_NIVE == 36
replace ageleg=17 if P27_NIVE == 37
replace ageleg=18 if P27_NIVE == 38
replace ageleg=19 if P27_NIVE == 39
// Secondaire g2
replace ageleg=16 if P27_NIVE == 41
replace ageleg=17 if P27_NIVE == 42
replace ageleg=18 if P27_NIVE == 43
replace ageleg=19 if P27_NIVE == 44
**Vérifier si l'age du Capacité 1ère an est 19
replace ageleg=20 if P27_NIVE == 45
replace ageleg=19 if P27_NIVE == 46
//Supérieur
replace ageleg=20 if P27_NIVE == 61
replace ageleg=21 if P27_NIVE == 62
replace ageleg=22 if P27_NIVE == 63
replace ageleg=23 if P27_NIVE == 64
replace ageleg=24 if P27_NIVE == 65
replace ageleg=25 if P27_NIVE == 66
replace ageleg=26 if P27_NIVE == 67
replace ageleg=27 if P27_NIVE == 68
replace ageleg=. if P27_NIVE == 98


gen rsco= P18AG_AGE - ageleg if inrange( P18AG_AGE,9,16) 
by  $list_var_individuel, sort : egen nbrsco = total(rsco)
gen retsc = nbrsco !=0 
drop rsco nbrsco
lab var retsc "au moins un individu de 9 à 16 ans du menage est en retard scolaire ; 1=oui, 0=non"


******ALPHABETISATION 
***Plus de la moitié des membres du ménage de 15 ans ou plus ne sait pas lire ou écrire en Français 

codebook P26_ALPH
gen membre_15plus = (P18AG_AGE >= 15 & P18AG_AGE !=. )
by $list_var_individuel, sort: egen total_15plus = total(membre_15plus) if (P18AG_AGE >= 15 & P18AG_AGE !=.)
by $list_var_individuel, sort : egen total15 = total(membre_15plus)
by $list_var_individuel, sort: egen total_analph = total((P18AG_AGE >= 15 & P18AG_AGE !=. & P26_ALPH==2 ))
by $list_var_individuel, sort: gen moitie_analph = (total_analph / total_15plus) > 0.5
by $list_var_individuel, sort : egen nbmoitie_analph= total(moitie_analph)
gen mfsa = nbmoitie_analph !=0 
drop moitie_analph nbmoitie_analph
lab var mfsa "plus de la moitié des membres du ménage est analphabète; 1=oui, 0=non"
ta mfsa
********ENSEMBLE DIMENSION "EDUCATION"
gen EDUCATION = (educ + desco + retsc + mfsa)/18
lab var EDUCATION "score de la dimension education"
*******quelques stats
summ desco educ retsc mfsa EDUCATION

*******SAUVEGARDER LA BASE DE DONNEES
by $list_var_individuel, sort : drop if _n!=1
keep $list_var_individuel desco educ retsc mfsa  EDUCATION
save "C:\Users\Dell\OneDrive\Bureau\PHAS\INPM\RGPH_98\RGPH98_Education.dta", replace

***************BASES DES MENAGES 1998: DIMENSION NIVEAU DE VIE********************
********************************************************************************

use "C:\Users\Dell\OneDrive\Bureau\PHAS\INPM\RGPH_98\base_menage_rgph98.dta" , clear
global list_var_men I01_REGI I02_DEPA I03_SPREF  I05_MILIEU I09T_TYP I09N_NUM

***********DIMENSION : NIVEAU DE VIE 

*****ELECTRICITE
codebook M46_MODE
gen paselec = !inlist( M46_MODE,1,4)
lab var paselec "Ne dispose pas d'electricite; 1=pas electricite, 0=electricite"
/*question RGPH: Mode d’éclairage
1.   Electricité
2.   Lampe
3.   Gaz
4.   Electricité + Lampe
5.  Autre à préciser*/

*****EAU POTABLE  
codebook M45_ALIM
gen paseaup = !inlist( M45_ALIM,1,2,3,6)
lab var paseaup "Ne dispose pas d'acces a l'eau potable; 1=pas eau potable, 0=eau potable"
/*question RGPH: Alimentation en eau
1.   Eau courante
2.   Eau courante dans la cour
3.   Eau courante à l’extérieur
4.   Puits dans la cour
5.   Puits public
6.   Pompe villageoise
7.   Eau de surface (marigot, rivière, etc…)
8.   Autre à préciser*/

*****COMBUSTIBLE 
codebook M47_MODE
gen combsale = !inlist( M47_MODE, 3,5,6 )
lab var combsale "Utilise un combustible sale (bois, charbon, autres); 1=oui, 0=non"
/*question RGPH: Mode de cuisson
1.   Bois de chauffe
2.   Charbon de bois
3.   Gaz
4.   Bois+Charbon
5.   Gaz+Charbon
6.   Gaz+Bois
7.   Autre à préciser*/

******MODE D'EVACUATION
codebook M49_EVAC
gen pasevac = !inlist( M49_EVAC , 1,2,4 )
lab var pasevac "Pas d'installation adequate d'assainissement (rue, nature, autre); 1=oui, 0=non"
/*question RGPH: Monde d’évacuation des eaux usées
1.   Fosse septique
2.   Réseau d’égout
3.   Dans la rue
4.   Caniveau
5.   Dans la nature
6.   Autre à préciser*/

*******TOILETTES
codebook M44_LIEU
gen pasta = !inlist( M44_LIEU , 1 )
lab var pasta "ne dispose pas de toilettes privées améliorées; 1=oui, 0=non"
/*question RGPH: LIEU D'AISANCE
1.   WC à l'intérieur 
2.   WC à l'extérieur 
3.   Latrines dans la cour 
4.   Latrines hors de la cour 
5.   Dans la nature 
6.   Autre à préciser */
ta pasta 

*****NATURE DU SOL 
codebook M43_NATU
gen solterre = !inlist( M43_NATU , 2,3)
lab var solterre "Sol en terre ou sable, bois, Moquette ou autre; 1=oui, 0=non"
/*question RGPH: Nature du sol
1.   Terre ou sable
2.   Ciment
3.   Carreau / Marbre
4.   Moquette / Tapis
5.   Bois
6.   Autre à préciser*/
ta solterre 

*****NATURE DU TOIT (TOIT EN FIBRE OU AUTRES)
codebook M42_NATU
gen toiture = !inlist( M42_NATU , 2,3,4)
lab var toiture "toit en fibre, toile plastique ou autre; 1=oui, 0=non"
/*qustion RGPH: Nature du toit
1.   Fibre végétale
2.   Tôle
3.   Béton
4.   Tuile/Everite
5.   Toile en plastique
6.   Autre à préciser*/

*****NATURE DU MUR (MUR NON EN DUR)
codebook M41_NATU
gen matmur = !inlist( M41_NATU , 4,5,6)
lab var matmur "mur en bois, tole, banco ou autre; 1=oui, 0=non"
/*question RGPH: Nature du mur
1.   Bois
2.   Tôle
3.   Banco ou terre battue
4.   Semi-dur
5.   Géobéton
6.   Dur
7.   Autres à préciser*/

********CARACTERISTIQUE LOGEMENT 
codebook M39_TYPE
gen logement = !inlist(M39_TYPE, 1,2,3,4,5)
/*question RGPH: Nature du mur
1 : Maison 
2 : Villa simple
3 : Logement en bande 
4 : Appartement dans un immeuble 
5 : Concession 
6 : Case traditionnelle 
7 : Baraque 
8 : Autre à préciser */
lab var logement "logement inadequat ; 1=oui, 0=non"

*****EQUIPEMENT DE (D')
codebook M50_EQUI

	**INFORMATION
gen pasinfo = !inlist( M50_EQUI,1,2,3,4,5,6,7,9,10,11,12,13,14,15 )
lab var pasinfo "Pas d'equipement d'info (TV, radio, Telephone); 1=oui, 0=non"
	**SUBSISTANCE
gen pasubsi = !inlist( M50_EQUI,8,9,10,11,12,13,14,15 )
lab var pasubsi "Pas d'equipement de susbistance (refrigerateur); 1=oui, 0=non"
/*question RGPH: Equipements électroménagers
1. Radio
2. Télévision
4. Téléphone
8. Réfrigérateur
16.Rien*/

********EQUIPEMENT
gen equipement = pasinfo | pasubsi
lab var equipement "Pas d'equipement en general (TV, radio, phone, frigo); 1=oui, 0=non"

*************ENSEMBLE DIMENSION "CONDITION DE VIE"
gen condvie = (paselec+paseaup+combsale+pasevac+pasta+solterre+toiture+matmur+logement+equipement)/50
lab var condvie "score de la dimension condition de vie"
mean condvie
*******quelques stats
summ paselec paseaup combsale pasevac logement equipement condvie
*******SAUVEGARDER LA BASE DE DONNEES
keep $list_var_men paselec paseaup combsale pasevac logement equipement condvie 
duplicates drop $list_var_men, force
save "C:\Users\Dell\OneDrive\Bureau\PHAS\INPM\RGPH_98\RGPH98_Conditions_de_vie.dta", replace

*********************BASES DES ??? 1998: DIMENSION SANTE************************
********************************************************************************
******* HANDICAP
use "C:\Users\Dell\OneDrive\Bureau\PHAS\INPM\RGPH_98\base_individu_rgph98.dta" , clear
codebook P23_HAND, tabulate(35)
ta P23_HAND
gen hand = !inlist(P23_HAND ,33,.)
lab var hand "Un membre du ménage souffre d'un handicap physique ou mental; 1=oui, 0=non"
/*question RGPH: Handicaps physiques
1= non voyant
2= sourd
4= muet
8= handicap des membres inférieurs
16= handicap des membres supérieurs
32= autres handicaps
0= sans handicap
*/
ta hand 

**** Mortalité Juvénile : Pas de variable sur la mortalité dans la base des individus
use "C:\Users\Dell\OneDrive\Bureau\PHAS\INPM\RGPH_98\base_menage_rgph98.dta", clear

**** Mortalité Juvénile : Pas de variable sur la mortalité dans la base des ménages


***************BASES DES INDIVIDUS 1998: DIMENSION EMPLOI***********************
********************************************************************************

****** Chomage. Le nombre de chômeurs est supérieur à la moitié des actifs du ménage 

use "C:\Users\Dell\OneDrive\Bureau\PHAS\INPM\RGPH_98\base_individu_rgph98.dta" , clear
codebook P28_TYPA
ta P28_TYPA
gen chm = (P28_TYPA == 2 & P28_TYPA !=. )
global list_var_men "list_var_men I01_REGI I02_DEPA I03_SPREF  I05_MILIEU I09T_TYP I09N_NUM"
by $list_var_men, sort : egen totalchm = total(chm)
by $list_var_men, sort: egen total_actif = total(P28_TYPA)
by $list_var_men, sort: gen moitie_chm = (totalchm / total_actif) > 0.5
by $ist_var_men, sort : egen nbmoitie_chm= total(moitie_chm)
gen mchm = nbmoitie_chm !=0 
drop moitie_chm nbmoitie_chm
lab var mchm "plus de la moitié des membres du ménage au chomage; 1=oui, 0=non"

use "C:\Users\Dell\OneDrive\Bureau\PHAS\INPM\RGPH_98\base_individu_rgph98.dta" , clear
codebook P28_TYPA
global list_var_individuel "I01_REGI I02_DEPA I03_SPREF  I04_MILIEU I09T_TYP I09N_NUM"
// Compter le nombre de chômeurs et d'occupés par ménage
by $list_var_individuel, sort: egen nb_chm= total(inlist(P28_TYPA, 2,3))
by $list_var_individuel, sort: egen nb_actif = total(inlist(P28_TYPA, 1,4,5))

// Vérifier si le nombre de chômeurs est supérieur à la moitié des occupés
gen mchm = (nb_chm > nb_actif / 2)
/*question RGPH: Chomage
1.occupé
2.chomeur
3.Ménagère
4.Etudiant ou élève
8.Autre inactif
*/
lab var mchm "le nombre de chomeur est supérieur à la moitié des actifs du ménage; 1=oui, 0=non"
gen emploi = mchm/5
mean emploi
duplicates drop $list_var_individuel, force
keep $list_var_menage nb_chm nb_actif mchm emploi

save "C:\Users\Dell\OneDrive\Bureau\PHAS\INPM\RGPH_98\RGPH98_Emploi.dta", replace

********************************************************************************
*********************BASES RGPH 1998: DIMENSION IDENTIFICATION***************
********************************************************************************

***********Déclaration d'état civil à la naissance



/* Fusion des fichiers */






********************************************************************************
***********************CALCUL DE L'IPM **************************
********************************************************************************

