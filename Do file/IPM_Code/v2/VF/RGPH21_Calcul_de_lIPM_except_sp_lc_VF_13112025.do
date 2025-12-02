// La base utilisée provient du bureau des demographes (Voir Aminata et Doyen Toure)
clear all
global in "D:\CAE_IPM\Data"
global do "D:\CAE_IPM\Do file\IPM_Code\v2"
global out "D:\CAE_IPM\Sortie"

use "$out\bf_13112025.dta", clear

di"**********************TRAITEMENT DE LA ZONE MILIEU**************************"
di"****************************************************************************"

* Nettoyage 
capture drop si si_mpi poor poor_mpi vulnerable sev_pauvre

** privé les personnes ou les infos sont manquantes

* Remplacer les manquants par privation = 1
foreach var in desco educ mfsa chom paselec paseaup combsale pasta logement pasequi mjuv Ident {
    replace `var' = 1 if missing(`var')
}
 save, replace

***********************************************************************
* 1. MPI
***********************************************************************
gen TOTMEN_w = EW * TOTMEN

mpi d1(desco educ mfsa) w1(0.066 0.066 0.066) d2(chom) w2(0.2) d3(paselec paseaup combsale  pasta logement pasequi) w3( 0.033 0.033 0.033 0.033 0.033 0.0333) d4(mjuv) w4(0.2) d5(Ident) w5(0.2) [pw=TOTMEN_w],cutoff(.3333) by(milieu)  deprivedscore(si_mpi) depriveddummy(poor_mpi)


/**********************************************************************
* 2. Récupération de H et M0 par MILIEU (milieu)
***********************************************************************/

* Matrice des résultats par groupe (milieu)
mat A = e(by_mpi)
mat list A

* Nombre de groupes de milieu (Urbain / Rural, etc.)
local nb_zone = colsof(A) / 2      // 2 colonnes par groupe : H et M0
global nb_zone = `nb_zone'         // si tu veux réutiliser $nb_zone plus loin

* On transpose pour avoir une valeur par ligne
mat A = A'
mat list A

* --- H (taux de pauvreté) : lignes 1 à nb_zone ---
submatrix A, rownum(1/$nb_zone)
mat define H_mil = r(mat)
mat list H_mil

* --- M0 (headcount ajusté) : lignes nb_zone+1 à 2*nb_zone ---
global start = $nb_zone + 1
global stop  = 2 * $nb_zone
submatrix A, rownum($start / $stop)
mat define M0_mil = r(mat)
mat list M0_mil


***********************************************************************
* 3. Contributions des indicateurs (e(by_ind))
*    On reconstruit une matrice nb_zone x 12 indicateurs
***********************************************************************

mat list e(by_ind)
mat define B = e(by_ind)'
mat list B

mat Indicateur_mil= J($nb_zone,1,.)
forvalues j = 0/11 {
   
	local idx = `j' + 1
	
	mat ind`idx' = J($nb_zone,1,0)
	forvalues k = 1/$nb_zone {
		mat ind`idx'[`k',1] = B[`k' + (`j' * $nb_zone),1]
		
	}
	
	mat Indicateur_mil = Indicateur_mil, ind`idx'
}

mat Indicateur_mil = Indicateur_mil[1..$nb_zone,2..13]
mat list Indicateur_mil


/*
Ordre attendu des colonnes de Indicateur_mil :
 1  = desco   : Fréquentation scolaire
 2  = educ    : Année de scolarité
 3  = mfsa    : Alphabétisation
 4  = chom    : Chômage
 5  = paselec : Electricité
 6  = paseaup : Eau potable
 7  = combsale :  Energie de cuisson
 8  = pasta   : Toilette
 9  = logement: Logement
 10 = pasequi : Equipement
 11 = mjuv    : Mortalité juvénile
 12 = Ident   : Déclaration d'état civil
*/

***********************************************************************
* 4. Vulnérabilité et pauvreté sévère à partir du score MPI officiel
***********************************************************************


gen vulnerable = (si_mpi > 1/5  & si_mpi <= 1/3) if si_mpi < .
gen sev_pauvre = (si_mpi >= 1/2)                 if si_mpi < .
gen poor       = poor_mpi                        if si_mpi < .


* Population totale
gen one =1 if si_mpi < .

preserve
collapse (sum) pop_mil = one[pw=TOTMEN_w], by(milieu)
sort milieu
mkmat pop_mil, matrix(pop_mil)
submatrix pop_mil, rownum(1/3)
mat define pop_mil = r(mat)
restore


* Population pauvre
preserve
collapse (sum) poor_pop_mil = poor[pw=TOTMEN_w], by(milieu)
sort milieu
mkmat poor_pop_mil, matrix(poor_pop_mil)
submatrix poor_pop_mil, rownum(1/3)
mat define poor_pop_mil = r(mat)
restore


* Population vulnérable
preserve
collapse (sum) vul_pop_mil = vulnerable*[pw=TOTMEN_w], by(milieu)
sort milieu
mkmat vul_pop_mil, matrix(vul_pop_mil)
submatrix vul_pop_mil, rownum(1/3)
mat define vul_pop_mil = r(mat)
restore

* Population sévère

preserve
collapse (sum) sev_pop_mil = sev_pauvre*[pw=TOTMEN_w], by(milieu)
sort milieu
mkmat sev_pop_mil, matrix(sev_pop_mil)
submatrix sev_pop_mil, rownum(1/3)
mat define sev_pop_mil = r(mat)
restore


/***********************************************************************
* 5. MATRICE FINALE 
***********************************************************************/
mat A = H_mil, M0_mil, Indicateur_mil, pop_mil, poor_pop_mil, vul_pop_mil, sev_pop_mil

mat colnames A = ///
    "H" "M0" ///
    "Frequentation scolaire" ///
    "Année de scolarité" ///
    "Alphabétisation" ///
    "Chomage" ///
    "Electricité" ///
    "Eau potable" ///
    "Energie de cuisson" ///
    "Toilette" ///
    "Logement" ///
    "Equipement" ///
    "Mortalité juvénile" ///
    "Déclaration état civil" ///
    "Population" ///
    "Population pauvre" ///
    "Population vulnérable" ///
    "Population sévère"

mat list A	
	
* Rownames = codes de milieu (ex : 1 = Urbain, 2 = Rural)

use "$out\bf_13112025.dta", clear

keep milieu 
duplicates drop milieu , force
sort milieu
keep in 1/3
decode  milieu, gen(NAME_milieu)

* 1. Nettoyer nom des zones
gen MIL = NAME_milieu
replace NAME_milieu = subinstr(MIL, " ", "_", .)
replace NAME_milieu = subinstr(MIL, "-", "_", .)

* 2. Garder l'ordre des SP
sort NAME_milieu

* 3. Construire la liste des rownames dans l'ordre
local names ""
quietly {
    forvalues i = 1/`=_N' {
        local names `names' `=MIL[`i']'
    }
}

* 4. Appliquer à la matrice A
mat rownames A = `names'



***********************************************************************
* 7. Export vers Excel – Feuille MILIEU
***********************************************************************
putexcel clear
putexcel set ///
    "$out\IPM-CI_2021_vf_13112025", ///
    sheet("MILIEU") replace

* Export avec noms de colonnes en ligne 6, données à partir de C6
putexcel C6 = matrix(A), colnames nformat(number_d2)

* Si tu veux aussi afficher les rownames en colonne A :
putexcel A7 = matrix(A), rownames


di"**********************TRAITEMENT DE LA ZONE REGION**************************"
di"****************************************************************************"
use "$out\bf_13112025.dta", clear

label define region_lbll ///
1 "Abidjan" ///
2 "Haut-Sassandra" ///
3 "Poro" ///
4 "Gbeke" ///
5 "Indenie-Djuablin" ///
6 "Tonkpi" ///
7 "Yamoussoukro" ///
8 "Gontougo" ///
9 "San-Pedro" ///
10 "Kabadougou" ///
11 "Nzi" ///
12 "Marahoue" ///
13 "Sud-comoe" ///
14 "Worodougou" ///
15 "Loh-Djiboua" ///
16 "Agneby-Tiassa" ///
17 "Goh" ///
18 "Cavally" ///
19 "Bafing" ///
20 "Bagoue" ///
21 "Belier" ///
22 "Bere" ///
23 "Bounkani" ///
24 "Folon" ///
25 "Gbokle" ///
26 "Grands-Ponts" ///
27 "Guemon" ///
28 "Hambol" ///
29 "Iffou" ///
30 "La-Me" ///
31 "Nawa" ///
32 "Tchologo" ///
33 "Moronou"

label values REGION region_lbll
*/
* Nettoyage 
capture drop  si_mpi  poor_mpi vulnerable sev_pauvre

***********************************************************************
* 1. MPI
***********************************************************************
gen TOTMEN_w = EW * TOTMEN

mpi d1(desco educ mfsa) w1(0.066 0.066 0.066) d2(chom) w2(0.2) d3(paselec paseaup combsale  pasta logement pasequi) w3( 0.033 0.033 0.033 0.033 0.033 0.0333) d4(mjuv) w4(0.2) d5(Ident) w5(0.2) [pw=TOTMEN_w],cutoff(.3333) by(REGION)  deprivedscore(si_mpi) depriveddummy(poor_mpi)


/**********************************************************************
* 2. Récupération de H et M0 par REGION 
***********************************************************************/

* Matrice des résultats par groupe (REGION)
mat A = e(by_mpi)
mat list A

* Nombre de groupes de REGION 
local nb_zone = colsof(A) / 2      
global nb_zone = `nb_zone'         

* On transpose pour avoir une valeur par ligne
mat A = A'
mat list A

* --- H (taux de pauvreté) : lignes 1 à nb_zone ---
submatrix A, rownum(1/$nb_zone)
mat define H_REG = r(mat)
mat list H_REG

* --- M0 (headcount ajusté) : lignes nb_zone+1 à 2*nb_zone ---
global start = $nb_zone + 1
global stop  = 2 * $nb_zone
submatrix A, rownum($start / $stop)
mat define MO_REG = r(mat)
mat list MO_REG


***********************************************************************
* 3. Contributions des indicateurs (e(by_ind))
*    On reconstruit une matrice nb_zone x 12 indicateurs
***********************************************************************

mat list e(by_ind)
mat define B = e(by_ind)'
mat list B

mat Indicateur_REG= J($nb_zone,1,.)
forvalues j = 0/11 {
   
	local idx = `j' + 1
	
	mat ind`idx' = J($nb_zone,1,0)
	forvalues k = 1/$nb_zone {
		mat ind`idx'[`k',1] = B[`k' + (`j' * $nb_zone),1]
		
	}
	
	mat Indicateur_REG = Indicateur_REG, ind`idx'
}

mat Indicateur_REG = Indicateur_REG[1..$nb_zone,2..13]
mat list Indicateur_REG


/*
Ordre attendu des colonnes de Indicateur_mil :
 1  = desco   : Fréquentation scolaire
 2  = educ    : Année de scolarité
 3  = mfsa    : Alphabétisation
 4  = chom    : Chômage
 5  = paselec : Electricité
 6  = paseaup : Eau potable
 7  = combsale :  Energie de cuisson
 8  = pasta   : Toilette
 9  = logement: Logement
 10 = pasequi : Equipement
 11 = mjuv    : Mortalité juvénile
 12 = Ident   : Déclaration d'état civil
*/

***********************************************************************
* 4. Vulnérabilité et pauvreté sévère à partir du score MPI officiel
***********************************************************************

gen vulnerable = (si_mpi > 1/5  & si_mpi <= 1/3) if si_mpi < .
gen sev_pauvre = (si_mpi >= 1/2)                 if si_mpi < .
gen poor       = poor_mpi                        if si_mpi < .


* Population totale
gen one =1 if si_mpi < .

preserve
collapse (sum) pop_REG = one [pw=TOTMEN_w], by(REGION)
sort REGION
mkmat pop_REG, matrix(pop_REG)
restore


* Population pauvre
preserve
collapse (sum) poor_pop_REG = poor [pw=TOTMEN_w], by(REGION)
sort REGION
mkmat poor_pop_REG, matrix(poor_pop_REG)
restore


* Population vulnérable
preserve
collapse (sum) vul_pop_REG = vulnerable [pw=TOTMEN_w], by(REGION)
sort REGION
mkmat vul_pop_REG, matrix(vul_pop_REG)
restore

* Population sévère

preserve
collapse (sum) sev_pop_REG = sev_pauvre [pw=TOTMEN_w], by(REGION)
sort REGION
mkmat sev_pop_REG, matrix(sev_pop_REG)
restore


/***********************************************************************
* 5. MATRICE FINALE 
***********************************************************************/
keep REGION
duplicates drop
sort REGION
mkmat REGION, mat(REG)
mat A = REG,H_REG, MO_REG, Indicateur_REG, pop_REG, poor_pop_REG, vul_pop_REG, sev_pop_REG


mat colnames A = ///
    "cd_REG ""H" "M0" ///
    "Frequentation scolaire" ///
    "Année de scolarité" ///
    "Alphabétisation" ///
    "Chomage" ///
    "Electricité" ///
    "Eau potable" ///
    "Energie de cuisson" ///
    "Toilette" ///
    "Logement" ///
    "Equipement" ///
    "Mortalité juvénile" ///
    "Déclaration état civil" ///
    "Population" ///
    "Population pauvre" ///
    "Population vulnérable" ///
    "Population sévère"


use "$out\bf_13112025.dta", clear
label define region_lbll ///
1 "Abidjan" ///
2 "Haut-Sassandra" ///
3 "Poro" ///
4 "Gbeke" ///
5 "Indenie-Djuablin" ///
6 "Tonkpi" ///
7 "Yamoussoukro" ///
8 "Gontougo" ///
9 "San-Pedro" ///
10 "Kabadougou" ///
11 "Nzi" ///
12 "Marahoue" ///
13 "Sud-comoe" ///
14 "Worodougou" ///
15 "Loh-Djiboua" ///
16 "Agneby-Tiassa" ///
17 "Goh" ///
18 "Cavally" ///
19 "Bafing" ///
20 "Bagoue" ///
21 "Belier" ///
22 "Bere" ///
23 "Bounkani" ///
24 "Folon" ///
25 "Gbokle" ///
26 "Grands-Ponts" ///
27 "Guemon" ///
28 "Hambol" ///
29 "Iffou" ///
30 "La-Me" ///
31 "Nawa" ///
32 "Tchologo" ///
33 "Moronou"

label values REGION region_lbll
keep REGION 
duplicates drop REGION , force
sort REGION
decode  REGION, gen(NAME_REG)

* 1. Nettoyer nom des zones
gen REG = NAME_REG
replace NAME_REG = subinstr(REG, " ", "_", .)
replace NAME_REG = subinstr(REG, "-", "_", .)

* 2. Garder l'ordre des SP
sort REGION

* 3. Construire la liste des rownames dans l'ordre
local names ""
quietly {
    forvalues i = 1/`=_N' {
        local names `names' `=REG[`i']'
    }
}



* 4. Appliquer à la matrice A
mat rownames A = `names'



***********************************************************************
* 7. Export vers Excel – Feuille REGION
***********************************************************************
putexcel clear
putexcel set ///
    "$out\IPM-CI_2021_vf_13112025", ///
    sheet("REGION") modify

* Export avec noms de colonnes en ligne 6, données à partir de C6
putexcel C6 = matrix(A), colnames nformat(number_d2)

*afficher les rownames en colonne A :
putexcel A7 = matrix(A), rownames


