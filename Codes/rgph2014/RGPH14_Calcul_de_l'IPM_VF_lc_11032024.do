
cls
args Region_data code_sp

use "`Region_data'", replace

*********************BASES RGPH 14: DIMENSION IDENTIFICATION***************
********************************************************************************

*drop _merge

********Déclaration d'état civil à la naissance
/*
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
// remplacer les localité non labélisées par autre à préciser : modalité 643
replace VILLAGE=643 if VILLAGE==.

//note: dans la plupart des bases de données, il y'a des villages "non privé ou multidimensionnellement non privés", on les exclut de l'analyse

egen NBmis = rowmiss(desco educ mfsa chom paselec paseaup combsale pasta logement pasequi mjuv Ident TOTMEN)
replace NBmis = 1 if NBmis !=0
recode NBmis (0=1) (1=0)
rename NBmis touse

gen si = (desco + educ + mfsa)*0.066 + (chom)*0.2 + (paselec + paseaup +combsale + pasta + logement + pasequi)*0.033+ (mjuv)*0.2 + (Ident)*0.2
egen msi=max(si), by(VILLAGE)
gen has_deprived = (msi > 1/3)
mpi d1(desco educ mfsa) w1(0.066 0.066 0.066) d2(chom) w2(0.2) d3(paselec paseaup combsale  pasta logement pasequi) w3( 0.033 0.033 0.033 0.033 0.033 0.033)d4(mjuv) w4(0.2) d5(Ident) w5(0.2) [fw=TOTMEN] if has_deprived==1 & touse , cutoff(0.3333) by(VILLAGE)
distinct VILLAGE if has_deprived==1 & touse
global nblc = r(ndistinct)
di $nblc
global nblc1 = r(ndistinct) + 1
di $nblc1

// M0 et H
mat A = e(by_mpi)
mat list A
mat define A = e(by_mpi)'
global nbv= rowsof(A)
di $nbv

mat define H_Lc = J($nblc ,1,0)
forvalues k = 1/$nblc {
mat H_Lc[`k',1] = A[`k'  ,1]
}

mat define M_Lc = J($nblc, 1, 0)
forvalues k =1 / $nblc {
    mat M_Lc[`k', 1] = A[`k' + $nblc , 1]
}


//INDICATEURS
mat list e(by_ind)
mat define B = e(by_ind)'
mat list B
/*global nblign= rowsof(B)
di $nblign
global nbmat=rowsof(B)/$nbsp
di $nbmat
*/

mat Indicateur_Sp= J($nblc,1,.)
forvalues j = 0/11 {
    dis "ok1"
	local index = `j' + 1
	dis "ok2"
	mat ind`index'_Lc = J($nblc,1,0)
	forvalues k = 1/$nblc {
		mat ind`index'_Lc[`k',1] = B[`k' + (`j' * $nblc),1]
		dis "ok3"
	}
	*mat list Indicateur_`code_sp'
	*mat list ind`index'_Sp
	mat Indicateur_Sp = Indicateur_Sp, ind`index'_Lc
	*matselrc A_`code_region' A_`code_region', c(1/12) 
	dis "ok4"
}
mat Indicateur_Sp = Indicateur_Sp[1..$nblc,2..13]
mat list Indicateur_Sp


// Vulnerabilté

ge vulnerable = (si>1/5) & (si<=1/3) if si!=. & has_deprived==1

gen sev_pauvre = si >= 1/2 if si!=. & has_deprived==1


gen poor = si>1/3 & has_deprived==1


proportion VILLAGE if si!=. & has_deprived==1 & touse, over(vulnerable)
mat list r(table)

mat define temp = e(b)'

mat vulnerable = J($nblc ,1,0)

forvalues k = 1 / $nblc  {
	scalar define index = 2 * `k'
	mat vulnerable[`k',1] = temp[index,1]
}

proportion VILLAGE if si!=.  & has_deprived==1 & touse, over(sev_pauvre)
mat list r(table)
mat define temp = e(b)'
mat sev_pauvre = J($nblc ,1,0)

forvalues k = 1 / $nblc  {
	scalar define index = 2 * `k'
	mat sev_pauvre[`k',1] = temp[index,1]
}


// Population
qui tab VILLAGE if si!=. & has_deprived==1 & touse,matcell(pop)  

tab VILLAGE poor if si!=.& poor==1 &  has_deprived==1 & touse ,matcell(poor) 


mat A_Sp_`code_sp'  = H_Lc,M_Lc,Indicateur_Sp, vulnerable,sev_pauvre, pop, poor[1..$nblc,1]


*decode VILLAGE,gen(SP)
levelsof VILLAGE if si!=. & has_deprived==1 & touse ,local(VLG)
mat rownames A_Sp_`code_sp' = `VLG' 

*save "$sortie\Decoupage_REGIONRP14\AjoutIdent\\`Region_data'_treated.dta", replace 


mat colnames A_Sp_`code_sp' = "H" "MO" "Frequentation scolaire"  "Année de scolarité" "Alphabétisation" "Chomage" "Electricité" "Eau potable" "Energie de cuisson"  "Toilette" "Logement"  "Equipement" "Mortalité juvénile" "Déclaration d'état civil" "Vulnerabilité" "sev_pauvre" "population" "population pauvre mpi"


*save "$sortie\Decoupage_SousprefRP14\AjoutIdent\\`Region_data'_treated.dta", replace 