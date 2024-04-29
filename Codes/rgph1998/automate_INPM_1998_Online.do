
cd "C:\Users\Dell\OneDrive\Bureau\PHAS\INPM\RGPH_98"
clear

local list_de_fichier : dir . files "REG*" 

global chemin_perso "C:\Users\Dell\OneDrive"
global bases_reg "$chemin_perso\INPM\RGPH_98"
global bases_reg_treated "$bases_reg\Treated"
global bases_reg_results "$chemin_perso\Bureau\PHAS\INPM\RGPH_98\Resultats_INPM_1998"
global bases_reg_results_dis "$bases_reg_results\INPM_men_0.log"
global dofile "C:\Users\Dell\OneDrive\Bureau\PHAS\INPM\RGPH_98\IPNM_compute_1998"
global list_var_mena "I01_REGI I02_DEPA I03_SPREF I04_MILIEU I09T_TYP I09N_NUM"

foreach var of local list_de_fichier {
  do "dofile" `var'
}

/* Fusion des fichiers */

cd $bases_reg_treated
clear
append using `: dir . files "*.dta"'

isid $list_var_mena
duplicates drop  $list_var_mena, force

save "C:\Users\Dell\OneDrive\Bureau\PHAS\INPM\RGPH_98\Resultats_INPM_1998\data_results.dta", replace

********************************************************************************
*********************DIMENSION SANTE************************
********************************************************************************

*********************BASES 1998: DIMENSION SANTE************************
import spss using "C:\Users\Dell\OneDrive\Bureau\PHAS\INPM\RGPH_98\Deces.sav", clear 
*Je note que le nom des variables différentes d'une base à l'autre.
 rename I05_MILIEU I04_MILIEU
 by $list_var_mena,  sort : gen decs18 = D53AD_AG if D53AD_AG <18
collapse (count) decs18, by ($list_var_mena)
save "C:\Users\Dell\OneDrive\Bureau\PHAS\INPM\RGPH_98\Données intermédiares\DECES8_RGPH1998.dta", replace

***************BASES DES MENAGES 1998: DIMENSION NIVEAU DE VIE********************
********************************************************************************

***********DIMENSION : NIVEAU DE VIE 
import spss using "C:\Users\Dell\OneDrive\Bureau\PHAS\INPM\RGPH_98\menage.sav", clear

*****ELECTRICITE
*codebook M46_MODE
gen paselec = !inlist( M46_MODE,1,4)
lab var paselec "Ne dispose pas d'electricite; 1=pas electricite, 0=electricite"
/*question RGPH: Mode d'éclairage
1.   Electricité
2.   Lampe
3.   Gaz
4.   Electricité + Lampe
5.  Autre à préciser*/

*****EAU POTABLE  
*codebook M45_ALIM
gen paseaup = !inlist( M45_ALIM,1,2,3,6)
lab var paseaup "Ne dispose pas d'acces a l'eau potable; 1=pas eau potable, 0=eau potable"
/*question RGPH: Alimentation en eau
1.   Eau courante
2.   Eau courante dans la cour
3.   Eau courante à l'extérieur
4.   Puits dans la cour
5.   Puits public
6.   Pompe villageoise
7.   Eau de surface (marigot, rivière, etc…)
8.   Autre à préciser*/

*****COMBUSTIBLE 
*codebook M47_MODE
gen combsale = !inlist( M47_MODE, 3)
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
*codebook M49_EVAC
gen pasevac = !inlist( M49_EVAC , 1,2,4 )
lab var pasevac "Pas d'installation adequate d'assainissement (rue, nature, autre); 1=oui, 0=non"
/*question RGPH: Monde d'évacuation des eaux usées
1.   Fosse septique
2.   Réseau d'égout
3.   Dans la rue
4.   Caniveau
5.   Dans la nature
6.   Autre à préciser*/

*******TOILETTES
*codebook M44_LIEU
gen pasta = !inlist( M44_LIEU , 1,3 )
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
*codebook M43_NATU
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
*codebook M42_NATU
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
*codebook M41_NATU
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

****ENSEMBLE LOGEMENT
gen logement=solterre| toiture | matmur
lab var logement "logement inadequat ; 1=oui, 0=non"

*****EQUIPEMENT DE (D')
*codebook M50_EQUI

**INFORMATION
gen pasinfo = !inlist( M50_EQUI,1,2,3,4,5,6,7,9,10,11,12,13,14,15)
lab var pasinfo "Pas d'equipement d'info (TV, radio, Telephone); 1=oui, 0=non"
/*question RGPH: Equipements électroménagers
1  Radio
2  Télévision
3  Radio et Télévision
4  Téléphone
5  Radio et téléphone
6  Télévision et téléphone
7  Radio et télévision et téléphone
8  Refrigérateur
9  Radio et refrigérateur
10  Télévision et réfrigérateur
11  Radio et télévision et refrigérateur
12  Téléphone et refrigérateur
13  Radio et téléphone et refrigérateur
4  Télévision et téléphone et refrigérateur
15  Radio et télévision et téléphone et refrigérateur
16  Rien
19  Non Déclaré
*/
	**SUBSISTANCE
gen pasubsi = !inlist( M50_EQUI,8,9,10,11,12,13,14,15 )
lab var pasubsi "Pas d'equipement de susbistance (refrigerateur); 1=oui, 0=non"
/*question RGPH: Equipements électroménagers
1  Radio
2  Télévision
3  Radio et Télévision
4  Téléphone
5  Radio et téléphone
6  Télévision et téléphone
7  Radio et télévision et téléphone
8  Refrigérateur
9  Radio et refrigérateur
10  Télévision et réfrigérateur
11  Radio et télévision et refrigérateur
12  Téléphone et refrigérateur
13  Radio et téléphone et refrigérateur
4  Télévision et téléphone et refrigérateur
15  Radio et télévision et téléphone et refrigérateur
16  Rien
19  Non Déclaré
*/

********EQUIPEMENT
gen equipement = pasinfo | pasubsi
lab var equipement "Pas d'equipement en general (TV, radio, phone, frigo); 1=oui, 0=non"

*************ENSEMBLE DIMENSION "CONDITION DE VIE"
gen condvie = (paselec+paseaup+combsale+pasta+logement+equipement)/50
lab var condvie "score de la dimension condition de vie"
mean condvie
*******quelques stats
summ paselec paseaup combsale  logement equipement condvie
*******SAUVEGARDER LA BASE DE DONNEES
rename I05_MILIEU I04_MILIEU
isid $list_var_mena

save "C:\Users\Dell\OneDrive\Bureau\PHAS\INPM\RGPH_98\Données intermédiares\Conditions_de_vie.dta", replace

/* Fusion des fichiers */
use "C:\Users\Dell\OneDrive\Bureau\PHAS\INPM\RGPH_98\Resultats_INPM_1998\data_results.dta"

merge m:1 $list_var_mena using "C:\Users\Dell\OneDrive\Bureau\PHAS\INPM\RGPH_98\Données intermédiares\DECES8_RGPH1998.dta", keepusing(decs18)
gen mjuv = (decs18 > 0)
lab var mjuv "Au moins un décès de moins de 18 ans; 1=oui, 0=non"
gen SANTE = (mjuv)/5
lab var SANTE "score de la dimension Sante"
drop _merge
merge m:m $list_var_mena using "C:\Users\Dell\OneDrive\Bureau\PHAS\INPM\RGPH_98\Données intermédiares\Conditions_de_vie.dta"

keep $list_var_mena desco educ mfsa EDUCATION chom emploi P16_LIEN mjuv SANTE paselec  paseaup combsale pasta solterre toiture matmur logement pasubsi pasinfo equipement condvie  
save, replace
********************************************************************************
***********************CALCUL DE L'IPM **************************
********************************************************************************

*INPM_0 premier cutoff
log using "C:\Users\Dell\OneDrive\Bureau\PHAS\INPM\RGPH_98\Resultats_INPM_1998\INPM_0.log", replace
mpi d1(desco educ mfsa) w1(0.0833 0.0833 0.0833) d2(chom) w2(0.25) d3(paselec paseaup combsale  pasta logement equipement) w3( 0.0416 0.0416 0.0416 0.0416 0.0416 0.0416) d4(mjuv) w4(0.25),cutoff(0.3333) by (I04_MILIEU)

/*putexcel set "C:\Users\Dell\OneDrive\Bureau\PHAS\INPM\Resultats_INPM_2014\I09_MILIEU.xlsx", modify
// Exporter les résultats pour la zone actuelle
putexcel A1=("Nombre d'observations (e(N))") B1=`e(N)'
putexcel A3=("Zone") B3=("H") C3=("M0") D3=("A") 
putexcel A4=("National") B4=mat(e(mpi_main)) D4=mat(e(mpi_add))
putexcel A7=("Dimension") A8=mat(e(dom))
putexcel A10=("INDICATEUR") A11=mat(e(ind))
putexcel A14=("M0") A15=mat(e(by_mpi))
putexcel A20=("CONTRIBUTION PAR MILIEU") A21=mat(e(by_dom))
putexcel close


mean desco educ mfsa chom paselec paseaup combsale  pasta logement pasequi mjuv_prov pasid

mat def = (r(table)[rownumb(r(table),"b"),1..11])'
scalar define coefeduc = 0.07
mat list def
mat RESUEDUC = (.)
mat RESUEDUC = RESUEDUC \ def[1..3,1]
mat COEFEDUC = (.) \ J(3,1,coefeduc)
mat RESUEDUC = COEFEDUC,RESUEDUC
*/
mpi d1(desco educ mfsa) w1(0.0833 0.0833 0.0833) d2(chom) w2(0.25) d3(paselec paseaup combsale  pasta logement equipement) w3( 0.0416 0.0416 0.0416 0.0416 0.0416 0.0416) d4(mjuv) w4(0.25),cutoff(0.3333) by (I01_REGI)



/*putexcel set "C:\Users\Dell\OneDrive\Bureau\PHAS\INPM\Resultats_INPM_2014\REGION.xlsx", modify
// Exporter les résultats pour la zone actuelle
putexcel A1=("Nombre d'observations (e(N))") B1=`e(N)'
putexcel A3=("Zone") B3=("H") C3=("M0") D3=("A") 
putexcel A4=("National") B4=mat(e(mpi_main)) D4=mat(e(mpi_add))
putexcel A7=("Dimension") A8=mat(e(dom))
putexcel A10=("INDICATEUR") A11=mat(e(ind))
putexcel A14=("M0") A15=mat(e(by_mpi))
putexcel A20=("CONTRIBUTION PAR REGION") A21=mat(e(by_dom))
putexcel close
*/
mpi d1(desco educ mfsa) w1(0.0833 0.0833 0.0833) d2(chom) w2(0.25) d3(paselec paseaup combsale  pasta logement equipement) w3( 0.0416 0.0416 0.0416 0.0416 0.0416 0.0416) d4(mjuv) w4(0.25),cutoff(0.3333) by (I02_DEPA)
/*
putexcel set "C:\Users\Dell\OneDrive\Bureau\PHAS\INPM\Resultats_INPM_2014\DEPARTEMEN.xlsx", modify
// Exporter les résultats pour la zone actuelle
putexcel A1=("Nombre d'observations (e(N))") B1=`e(N)'
putexcel A3=("Zone") B3=("H") C3=("M0") D3=("A") 
putexcel A4=("National") B4=mat(e(mpi_main)) D4=mat(e(mpi_add))
putexcel A7=("Dimension") A8=mat(e(dom))
putexcel A10=("INDICATEUR") A11=mat(e(ind))
putexcel A14=("M0") A15=mat(e(by_mpi))
putexcel A20=("CONTRIBUTION PAR DEPARTEMEN") A21=mat(e(by_dom))
putexcel close
*/
/*
mpi d1(desco educ mfsa) w1((0.0833 0.0833 0.0833) d2(chom) w2(0.25) d3(paselec paseaup combsale  pasta logement equipement) w3( 0.0416 0.0416 0.0416 0.0416 0.0416 0.0416) d4(mjuv) w4(0.25),cutoff(0.3333) by (DISTRICT)
log close
/*putexcel set "C:\Users\Dell\OneDrive\Bureau\PHAS\INPM\Resultats_INPM_2014\DISTRICT.xlsx", modify
// Exporter les résultats pour la zone actuelle
putexcel A1=("Nombre d'observations (e(N))") B1=`e(N)'
putexcel A3=("Zone") B3=("H") C3=("M0") D3=("A") 
putexcel A4=("National") B4=mat(e(mpi_main)) D4=mat(e(mpi_add))
putexcel A7=("Dimension") A8=mat(e(dom))
putexcel A10=("INDICATEUR") A11=mat(e(ind))
putexcel A14=("M0") A15=mat(e(by_mpi))
putexcel A20=("CONTRIBUTION PAR DISTRICT") A21=mat(e(by dom))
putexcel close



/*mpi d1(desco educ  mfsa) w1( 0.07 0.07 0.07) d2(chom) w2(0.2) d3(paselec paseaup combsale  pasta logement pasequi) w3(0.03 0.03 0.03 0.03 0.03 0.03) d4(mjuv) w4(0.21) d5(pasid) w5(0.2),cutoff(0.33333) by(I04_SOUSPREF) 
trop de categories
putexcel A1=("Nombre d'observations (e(N))") B1=`e(N)'
putexcel A3=("Zone") B3=("H") C3=("M0") D3=("A") 
putexcel A4=("National") B4=mat(e(mpi_main)) D4=mat(e(mpi_add))
putexcel A7=("Dimension") A8=mat(e(dom))
putexcel A10=("INDICATEUR") A11=mat(e(ind))
putexcel A14=("M0") A15=mat(e(by_mpi))
putexcel A20=("CONTRIBUTION PAR DISTRICT") A21=mat(e(by dom))
putexcel close

*/

*INPM_0 deuxième cutoff
log using "C:\Users\Dell\OneDrive\Bureau\PHAS\INPM\Resultats_INPM_2014\INPM_1.log", replace
mpi d1(desco educ mfsa) w1(0.0667 0.0667 0.0667) d2(chom) w2(0.2) d3(paselec paseaup combsale  pasta logement pasequi) w3( 0.0333 0.0333 0.0333 0.0333 0.0333 0.0333) d4(mjuv_prov) w4(0.2) d5(pasid) w5(0.2),cutoff(0.6666) by (I09_MILIEU)

putexcel set "C:\Users\Dell\OneDrive\Bureau\PHAS\INPM\Resultats_INPM_2014\I09_MILIEU_1.xlsx", modify
// Exporter les résultats pour la zone actuelle
putexcel A1=("Nombre d'observations (e(N))") B1=`e(N)'
putexcel A3=("Zone") B3=("H") C3=("M0") D3=("A") 
putexcel A4=("National") B4=mat(e(mpi_main)) D4=mat(e(mpi_add))
putexcel A7=("Dimension") A8=mat(e(dom))
putexcel A10=("INDICATEUR") A11=mat(e(ind))
putexcel A14=("M0") A15=mat(e(by_mpi))
putexcel A20=("CONTRIBUTION PAR MILIEU") A21=mat(e(by_dom))
putexcel close

mpi d1(desco educ mfsa) w1(0.0667 0.0667 0.0667) d2(chom) w2(0.2) d3(paselec paseaup combsale  pasta logement pasequi) w3( 0.0333 0.0333 0.0333 0.0333 0.0333 0.0333) d4(mjuv_prov) w4(0.2) d5(pasid) w5(0.2),cutoff(0.6666) by (REGION)

putexcel set "C:\Users\Dell\OneDrive\Bureau\PHAS\INPM\Resultats_INPM_2014\REGION_1.xlsx", modify
// Exporter les résultats pour la zone actuelle
putexcel A1=("Nombre d'observations (e(N))") B1=`e(N)'
putexcel A3=("Zone") B3=("H") C3=("M0") D3=("A") 
putexcel A4=("National") B4=mat(e(mpi_main)) D4=mat(e(mpi_add))
putexcel A7=("Dimension") A8=mat(e(dom))
putexcel A10=("INDICATEUR") A11=mat(e(ind))
putexcel A14=("M0") A15=mat(e(by_mpi))
putexcel A20=("CONTRIBUTION PAR REGION") A21=mat(e(by_dom))
putexcel close

mpi d1(desco educ mfsa) w1(0.0667 0.0667 0.0667) d2(chom) w2(0.2) d3(paselec paseaup combsale  pasta logement pasequi) w3( 0.0333 0.0333 0.0333 0.0333 0.0333 0.0333) d4(mjuv_prov) w4(0.2) d5(pasid) w5(0.2),cutoff(0.6666) by (DEPARTEMEN)
putexcel set "C:\Users\Dell\OneDrive\Bureau\PHAS\INPM\Resultats_INPM_2014\DEPARTEMEN_1.xlsx", modify
// Exporter les résultats pour la zone actuelle
putexcel A1=("Nombre d'observations (e(N))") B1=`e(N)'
putexcel A3=("Zone") B3=("H") C3=("M0") D3=("A") 
putexcel A4=("National") B4=mat(e(mpi_main)) D4=mat(e(mpi_add))
putexcel A7=("Dimension") A8=mat(e(dom))
putexcel A10=("INDICATEUR") A11=mat(e(ind))
putexcel A14=("M0") A15=mat(e(by_mpi))
putexcel A20=("CONTRIBUTION PAR DEPARTEMEN") A21=mat(e(by_dom))
putexcel close

mpi d1(desco educ mfsa) w1(0.0667 0.0667 0.0667) d2(chom) w2(0.2) d3(paselec paseaup combsale  pasta logement pasequi) w3( 0.0333 0.0333 0.0333 0.0333 0.0333 0.0333) d4(mjuv_prov) w4(0.2) d5(pasid) w5(0.2),cutoff(0.6666) by (DISTRICT)
putexcel set "C:\Users\Dell\OneDrive\Bureau\PHAS\INPM\Resultats_INPM_2014\DISTRICT_1.xlsx", modify
// Exporter les résultats pour la zone actuelle
putexcel A1=("Nombre d'observations (e(N))") B1=`e(N)'
putexcel A3=("Zone") B3=("H") C3=("M0") D3=("A") 
putexcel A4=("National") B4=mat(e(mpi_main)) D4=mat(e(mpi_add))
putexcel A7=("Dimension") A8=mat(e(dom))
putexcel A10=("INDICATEUR") A11=mat(e(ind))
putexcel A14=("M0") A15=mat(e(by_mpi))
putexcel A20=("CONTRIBUTION PAR DISTRICT") A21=mat(e(by dom))
putexcel close

log close

/*mpi d1(desco educ  mfsa) w1( 0.07 0.07 0.07) d2(chom) w2(0.2) d3(paselec paseaup combsale  pasta logement pasequi) w3(0.03 0.03 0.03 0.03 0.03 0.03) d4(mjuv) w4(0.21) d5(pasid) w5(0.2),cutoff(0.33333) by(I04_SOUSPREF) 
trop de categories
putexcel A1=("Nombre d'observations (e(N))") B1=`e(N)'
putexcel A3=("Zone") B3=("H") C3=("M0") D3=("A") 
putexcel A4=("National") B4=mat(e(mpi_main)) D4=mat(e(mpi_add))
putexcel A7=("Dimension") A8=mat(e(dom))
putexcel A10=("INDICATEUR") A11=mat(e(ind))
putexcel A14=("M0") A15=mat(e(by_mpi))
putexcel A20=("CONTRIBUTION PAR DISTRICT") A21=mat(e(by dom))
putexcel close

*/

*2 ème méthode
mpitb set , na(INPM_0) d1(desco educ  mfsa, na(un)) d2(chom, na(dos))  d3(paselec paseaup combsale  pasta logement pasequi, na(tres)) d4(mjuv_prov, na(quat)) d5(pasid, na(cinq)) replace

rename I09_MILIEU MILIEU
rename DEPARTEMEN DEP
mpitb est , na(INPM_0) meas(all) indmeas(all) aux(all) klist(33) weight(equal)  lfr(myresults1, replace) over (MILIEU REGION DEP)
cwf myresults1
d
tab measure loa

ta measure loa
save results/results , replace emptyok
loc flist INPM_00 INPM_11
foreach f in `flist' {
    append using results/`f', nol
}

/*mpi d1(desco educ  mfsa) w1( 0.07 0.07 0.07) d2(chom) w2(0.2) d3(paselec paseaup combsale  pasta logement pasequi) w3(0.03 0.03 0.03 0.03 0.03 0.03) d4(mjuv) w4(0.21) d5(pasid) w5(0.2),cutoff(0.33333) by(I04_SOUSPREF) 
Il faudrait calculer manuellement, il y a trop de sous préfectures 
*/
