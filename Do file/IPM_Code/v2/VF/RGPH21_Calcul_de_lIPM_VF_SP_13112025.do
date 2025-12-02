
cls
args Region_data code_region

use "`Region_data'", replace


***********************************************************************
**SOUSPREFID
***********************************************************************


replace TOTMEN = 0 if missing(TOTMEN)


* Nettoyage 
capture drop  si_mpi  poor_mpi vulnerable sev_pauvre

***********************************************************************
* 1. MPI
***********************************************************************
gen TOTMEN_w = EW * TOTMEN

mpi d1(desco educ mfsa) w1(0.066 0.066 0.066) d2(chom) w2(0.2) d3(paselec paseaup combsale  pasta logement pasequi) w3( 0.033 0.033 0.033 0.033 0.033 0.0333) d4(mjuv) w4(0.2) d5(Ident) w5(0.2) [pw=TOTMEN_w],cutoff(.3333) by(SOUSPREFID)  deprivedscore(si_mpi) depriveddummy(poor_mpi)


/**********************************************************************
* 2. Récupération de H et M0 par SOUSPREFID 
***********************************************************************/

* Matrice des résultats par groupe (SOUSPREFID)
mat A = e(by_mpi)
mat list A

* Nombre de groupes de SOUSPREFID 
local nb_zone = colsof(A) / 2      
global nb_zone = `nb_zone'         

* On transpose pour avoir une valeur par ligne
mat A = A'
mat list A

* --- H (taux de pauvreté) : lignes 1 à nb_zone ---
submatrix A, rownum(1/$nb_zone)
mat define H_SP = r(mat)
mat list H_SP

* --- M0 (headcount ajusté) : lignes nb_zone+1 à 2*nb_zone ---
global start = $nb_zone + 1
global stop  = 2 * $nb_zone
submatrix A, rownum($start / $stop)
mat define MO_SP = r(mat)
mat list MO_SP


***********************************************************************
* 3. Contributions des indicateurs (e(by_ind))
*    On reconstruit une matrice nb_zone x 12 indicateurs
***********************************************************************

mat list e(by_ind)
mat define B = e(by_ind)'
mat list B

mat Indicateur_SP= J($nb_zone,1,.)
forvalues j = 0/11 {
   
	local idx = `j' + 1
	
	mat ind`idx' = J($nb_zone,1,0)
	forvalues k = 1/$nb_zone {
		mat ind`idx'[`k',1] = B[`k' + (`j' * $nb_zone),1]
		
	}
	
	mat Indicateur_SP = Indicateur_SP, ind`idx'
}

mat Indicateur_SP = Indicateur_SP[1..$nb_zone,2..13]
mat list Indicateur_SP

/*
Ordre attendu des colonnes de Indicateur_SP :
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

/***********************************************************************
* 4. Vulnérabilité et pauvreté sévère à partir du score MPI officiel
***********************************************************************/

gen poor       = poor_mpi                        if si_mpi < .
gen vulnerable = (si_mpi > 1/5  & si_mpi <= 1/3) if si_mpi < .
gen sev_pauvre = (si_mpi >= 1/2)                 if si_mpi < .
gen one = 1 if si_mpi < .

* Breakdown par milieu : 1=Abidjan ville ; 2=Autre villes ; 3=Rural
gen poor_Abidjan  = poor       * (milieu == 1)
gen poor_Autre  = poor       * (milieu == 2)
gen poor_rural = poor       * (milieu == 3)

/*gen vul_Abidjan   = vulnerable * (milieu == 1)
gen vul_Autre  = vulnerable * (milieu == 2)
gen vul_rural  = vulnerable * (milieu == 3)

gen sev_Abidjan  = sev_pauvre * (milieu == 1)
gen sev_Autre   = sev_pauvre * (milieu == 2)
gen sev_rural  = sev_pauvre * (milieu == 3)
*/

/***********************************************************************
* POPULATION TOTALE SP
***********************************************************************/
preserve
collapse (sum) pop_SP = one [pw=TOTMEN_w], by(SOUSPREFID)
sort SOUSPREFID
mkmat pop_SP, matrix(pop_SP)
restore


/***********************************************************************
* POPULATION PAUVRE (Toutes zones)
***********************************************************************/
preserve
collapse (sum) poor_pop_SP = poor [pw=TOTMEN_w], by(SOUSPREFID)
sort SOUSPREFID
mkmat poor_pop_SP, matrix(poor_pop_SP)
restore


/***********************************************************************
* POPULATION PAUVRE – Abidjan villes / Autres villes / rural
***********************************************************************/

preserve


* 2. Remplacer les manquants par 0 avant collapse
replace poor_Abidjan = 0 if missing(poor_Abidjan)
replace poor_Autre  = 0 if missing(poor_Autre)
replace poor_rural   = 0 if missing(poor_rural)

* 3. Collapse groupé : une seule opération propre et rapide
collapse (sum) poor_Abidjan_SP = poor_Abidjan ///
               poor_Autre  = poor_Autre  ///
               poor_rural     = poor_rural  ///
               [pw = TOTMEN_w], by(SOUSPREFID)
mkmat poor_Abidjan, matrix(poor_Abidjan_SP)
mkmat poor_Autre, matrix(poor_Autre_SP)
mkmat poor_rural, matrix(poor_rur_SP)



restore


/*
/***********************************************************************
* POPULATION VULNÉRABLE – Total / Urbain / Rural / Semi
***********************************************************************/
preserve
collapse (sum) vul_pop_SP = vulnerable [pw=TOTMEN_w], by(SOUSPREFID)
sort SOUSPREFID
mkmat vul_pop_SP, matrix(vul_pop_SP)
restore

preserve
collapse (sum) vul_urb_SP = vul_urb [pw=TOTMEN_w], by(SOUSPREFID)
sort SOUSPREFID
mkmat vul_urb_SP, matrix(vul_urb_SP)
restore

preserve
collapse (sum) vul_rur_SP = vul_rur [pw=TOTMEN_w], by(SOUSPREFID)
sort SOUSPREFID
mkmat vul_rur_SP, matrix(vul_rur_SP)
restore

preserve
collapse (sum) vul_semi_SP = vul_semi [pw=TOTMEN_w], by(SOUSPREFID)
sort SOUSPREFID
mkmat vul_semi_SP, matrix(vul_semi_SP)
restore


/***********************************************************************
* POPULATION SÉVÈRE – Total / Urbain / Rural / Semi
***********************************************************************/
preserve
collapse (sum) sev_pop_SP = sev_pauvre [pw=TOTMEN_w], by(SOUSPREFID)
sort SOUSPREFID
mkmat sev_pop_SP, matrix(sev_pop_SP)
restore

preserve
collapse (sum) sev_urb_SP = sev_urb [pw=TOTMEN_w], by(SOUSPREFID)
sort SOUSPREFID
mkmat sev_urb_SP, matrix(sev_urb_SP)
restore

preserve
collapse (sum) sev_rur_SP = sev_rur [pw=TOTMEN_w], by(SOUSPREFID)
sort SOUSPREFID
mkmat sev_rur_SP, matrix(sev_rur_SP)
restore

preserve
collapse (sum) sev_semi_SP = sev_semi [pw=TOTMEN_w], by(SOUSPREFID)
sort SOUSPREFID
mkmat sev_semi_SP, matrix(sev_semi_SP)
restore

*/



**********************************************************************
* 6. Construction de la matrice finale A pour export Excel
***********************************************************************
preserve 
keep  if !missing(si_mpi)
keep SOUSPREFID
duplicates drop
sort SOUSPREFID
gen Code_SP = SOUSPREFID
mkmat Code_SP, matrix(Code_SP)
restore

mat A_reg_`code_region'  = Code_SP , H_SP, MO_SP, Indicateur_SP, pop_SP, poor_Abidjan_SP, poor_Autre_SP, poor_rur_SP
   

mat colnames A_reg_`code_region' = ///
	"Code_SP" ///
   "H" ///
    "M0" ///
    "Frequentation_scolaire" ///
    "Annee_scolarite" ///
    "Alphabetisation" ///
    "Chomage" ///
    "Electricite" ///
    "Eau_potable" ///
    "Energie_cuisson" ///
    "Toilette" ///
    "Logement" ///
    "Equipement" ///
    "Mortalite_juv" ///
    "Declaration_etat_civil" ///
    "Pop_SP" ///
    "poor_Abidjan_SP" ///
	"poor_autres_SP" ///
	"poor_rur_SP"
