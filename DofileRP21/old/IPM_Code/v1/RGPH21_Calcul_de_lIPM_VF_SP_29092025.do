
cls
args Region_data code_region

use "`Region_data'", replace

*********************BASES RGPH 14: DIMENSION IDENTIFICATION********************
********************************************************************************

/*
********Déclaration d'état civil à la naissance

by $list_var_menage, sort : egen Ident = max(pasid)
lab var Ident "pas de déclaration; 1=oui, 0=non"
question RGPH: Déclaration d'état civil à la naissance
1.Acte de naissance
2.Jugement supplétif
3.Déclarée sans acte
4.Aucune déclaration
8.Ne sait pas
*/

// pour eviter les erreurs , on prive les individus sans informations


replace desco = 1 if desco == . 
replace educ = 1 if educ == . 
replace mfsa = 1 if mfsa == . 
replace chom = 1 if chom == . 
replace paselec = 1 if paselec == . 
replace paseaup = 1 if paseaup == . 
replace combsale = 1 if combsale == . 
replace logement = 1 if logement == . 
replace pasequi = 1 if pasequi == . 
replace mjuv = 1 if mjuv == . 
replace Ident = 1 if Ident == . 

// pour eviter les erreurs , on "out" les lignes sans taille de menage
bysort SOUSPREFID: egen total_w = total(TAILLE_MENAGE)
*preserve 
*duplicates drop   SOUSPREFID, force
*br REGION SOUSPREFID total_w TAILLE_MENAGE if total_w == 0
// montre moi les sous prefectures ou la taille du menage est non dispo
drop if missing(TAILLE_MENAGE) | TAILLE_MENAGE == 0

//
egen check_indic = rowtotal(desco educ mfsa chom paselec paseaup combsale logement pasequi mjuv Ident)
drop if missing(check_indic)

cap drop si vulnerable sev_pauvre poor SP

mpi d1(desco educ mfsa) w1(0.066 0.066 0.066) d2(chom) w2(0.2) d3(paselec paseaup combsale  pasta logement pasequi) w3( 0.033 0.033 0.033 0.033 0.033 0.033)d4(mjuv) w4(0.2) d5(Ident) w5(0.2) [fw=TAILLE_MENAGE],cutoff(0.3333) by(SOUSPREFID)

distinct SOUSPREFID
global nbsp = r(ndistinct)
di $nbsp
global nbsp1 = r(ndistinct) + 1
di $nbsp1

// M0 et H
mat A = e(by_mpi)
mat list A
mat define A = e(by_mpi)'
submatrix A, rownum(1/$nbsp) 
matlist r(mat)
mat define H_Sp=r(mat) 
global nbv= rowsof(A)
di $nbv
submatrix A, rownum($nbsp1/$nbv) 
matlist r(mat)
mat define M_Sp=r(mat)


//INDICATEURS

mat list e(by_ind)
mat define B = e(by_ind)'
mat list B
/*global nblign= rowsof(B)
di $nblign
global nbmat=rowsof(B)/$nbsp
di $nbmat
*/

mat Indicateur_reg= J($nbsp,1,.)
forvalues j = 0/11 {
    dis "ok1"
	local index = `j' + 1
	dis "ok2"
	mat ind`index'_Sp = J($nbsp,1,0)
	forvalues k = 1/$nbsp {
		mat ind`index'_Sp[`k',1] = B[`k' + (`j' * $nbsp),1]
		dis "ok3"
	}
	*mat list Indicateur_`code_region'
	*mat list ind`index'_Sp
	mat Indicateur_reg = Indicateur_reg, ind`index'_Sp
	*matselrc A_`code_region' A_`code_region', c(1/12) 
	dis "ok4"
}
mat Indicateur_reg = Indicateur_reg[1..$nbsp,2..13]
mat list Indicateur_reg

// Vulnerabilté
cap drop si vulnerable sev_pauvre poor
gen si = (desco + educ + mfsa)*0.066 + (chom)*0.2 + (paselec + paseaup +combsale + pasta + logement + pasequi)*0.033+ (mjuv)*0.2 + (Ident)*0.2

ge vulnerable = (si>1/5) & (si<=1/3) if si!=.

gen sev_pauvre = si >= 1/2 if si!=.

gen poor = si>1/3

proportion SOUSPREFID if si!=., over(vulnerable)
mat list r(table)

mat define temp = e(b)'

mat vulnerable = J($nbsp ,1,0)

forvalues k = 1 / $nbsp  {
	scalar define index = 2 * `k'
	mat vulnerable[`k',1] = temp[index,1]
}

proportion SOUSPREFID if si!=., over(sev_pauvre)
mat list r(table)
mat define temp = e(b)'
mat sev_pauvre = J($nbsp ,1,0)

forvalues k = 1 / $nbsp  {
	scalar define index = 2 * `k'
	mat sev_pauvre[`k',1] = temp[index,1]
}

// Population
qui tab SOUSPREFID if si!=.,matcell(pop)

tab SOUSPREFID poor if si!=.& poor==1,matcell(poor)


mat A_reg_`code_region'  = H_Sp,M_Sp,Indicateur_reg, vulnerable,sev_pauvre, pop, poor[1..$nbsp,1]

*decode I04_SOUSPREF,gen(SP)
levelsof SOUSPREFID if si!=.,local(SP)
mat rownames A_reg_`code_region' = `SP'

*save "$sortie\Decoupage_REGIONRP14\AjoutIdent\\`Region_data'_treated.dta", replace 

mat colnames A_reg_`code_region' = "H" "MO" "Frequentation scolaire"  "Année de scolarité" "Alphabétisation" "Chomage" "Electricité" "Eau potable" "Energie de cuisson"  "Toilette" "Logement"  "Equipement" "Mortalité juvénile" "Déclaration d'état civil" "Vulnerabilité" "sev_pauvre" "population" "population pauvre mpi"
