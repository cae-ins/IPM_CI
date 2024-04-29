
cls
args Region_data code_region

use "`Region_data'", replace

*********************BASES RGPH 14: DIMENSION IDENTIFICATION***************
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


global list_var_menage I04_SOUSPREF I05_COMMUNE I09_MILIEU I06_ZD  I08_QUARCPT I10_ILOT I10A_BATIMEN I10B_LOGEMEN I11N_MENAGE  DEPARTEMEN REGION DISTRICT
cap drop si vulnerable sev_pauvre poor SP

mpi d1(desco educ mfsa) w1(0.066 0.066 0.066) d2(chom) w2(0.2) d3(paselec paseaup combsale  pasta logement pasequi) w3( 0.033 0.033 0.033 0.033 0.033 0.033)d4(mjuv) w4(0.2) d5(Ident) w5(0.2) [fw=TOTMEN],cutoff(0.3333) by(I04_SOUSPREF)

distinct I04_SOUSPREF
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

proportion I04_SOUSPREF if si!=., over(vulnerable)
mat list r(table)

mat define temp = e(b)'

mat vulnerable = J($nbsp ,1,0)

forvalues k = 1 / $nbsp  {
	scalar define index = 2 * `k'
	mat vulnerable[`k',1] = temp[index,1]
}

proportion I04_SOUSPREF if si!=., over(sev_pauvre)
mat list r(table)
mat define temp = e(b)'
mat sev_pauvre = J($nbsp ,1,0)

forvalues k = 1 / $nbsp  {
	scalar define index = 2 * `k'
	mat sev_pauvre[`k',1] = temp[index,1]
}

// Population
qui tab I04_SOUSPREF if si!=.,matcell(pop)

tab I04_SOUSPREF poor if si!=.& poor==1,matcell(poor)


mat A_reg_`code_region'  = H_Sp,M_Sp,Indicateur_reg, vulnerable,sev_pauvre, pop, poor[1..$nbsp,1]

*decode I04_SOUSPREF,gen(SP)
levelsof I04_SOUSPREF if si!=.,local(SP)
mat rownames A_reg_`code_region' = `SP'

*save "$sortie\Decoupage_REGIONRP14\AjoutIdent\\`Region_data'_treated.dta", replace 

mat colnames A_reg_`code_region' = "H" "MO" "Frequentation scolaire"  "Année de scolarité" "Alphabétisation" "Chomage" "Electricité" "Eau potable" "Energie de cuisson"  "Toilette" "Logement"  "Equipement" "Mortalité juvénile" "Déclaration d'état civil" "Vulnerabilité" "sev_pauvre" "population" "population pauvre mpi"
