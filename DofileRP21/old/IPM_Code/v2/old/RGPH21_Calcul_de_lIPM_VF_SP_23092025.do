global in "C:\CAE_IPM\Data"
global do "F:\IPM\Do file"
global out "F:\IPM\Sortie"
use "$out\bf.dta", clear
global list_var_menage "SOUSPREFID  P04 P08 P05 P07 P09 P09A P09B P10 DEPART REGION" 



tab REGION, m

forvalues r=1/33 {
	preserve
	keep if REGION==`r'
	save "$in\base_region_`r'.dta", replace
	restore
}


forvalues r=1/33 {
	use "$in\base_region_`r'.dta", clear

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


mat A_sp = H_Sp,M_Sp,Indicateur_reg, vulnerable,sev_pauvre, pop, poor[1..$nbsp,1]
mat rownames A_sp = `SP'
mat colnames A_sp = "H" "M0" "Frequentation scolaire" "Année de scolarité" "Alphabétisation" "Chomage" "Electricité" "Eau potable" "Energie de cuisson" "Toilette" "Logement" "Equipement" "Mortalité juvénile" "Déclaration d'état civil" "Vulnerabilité" "Pauvreté sévère" "Population" "Population pauvre MPI"



* --- Export vers Excel ---
putexcel set "$out\Resultats_IPM_SPLC_`r'.xlsx", replace
putexcel A1=matrix(A_sp), names
}