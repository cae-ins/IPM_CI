*==================================================*
* Calcul IPM par localité (village)
*==================================================*

cap drop si vulnerable sev_pauvre poor SP

* --- Calcul MPI par village ---
mpi d1(desco educ mfsa) w1(0.066 0.066 0.066) ///
    d2(chom) w2(0.2) ///
    d3(paselec paseaup combsale pasta logement pasequi) w3(0.033 0.033 0.033 0.033 0.033 0.033) ///
    d4(mjuv) w4(0.2) ///
    d5(Ident) w5(0.2) [fw=TOTMEN], cutoff(0.3333) by(P06)

* --- Nombre de localités ---
distinct P06
global nblc = r(ndistinct)
di "Nombre de villages: " $nblc
global nblc1 = r(ndistinct) + 1
di "Index début M0: " $nblc1

*==================================================*
* Extraction H et M0
*==================================================*
mat A = e(by_mpi)
mat define A = e(by_mpi)'

* H (Headcount)
submatrix A, rownum(1/$nblc) 
mat define H_Lc = r(mat)

* M0 (intensité)
global nbv = rowsof(A)
submatrix A, rownum($nblc1/$nbv) 
mat define M_Lc = r(mat)

*==================================================*
* Extraction des indicateurs
*==================================================*
mat define B = e(by_ind)'

mat Indicateur_reg = J($nblc,1,.)

forvalues j = 0/11 {
    local index = `j' + 1
    mat ind`index'_Lc = J($nblc,1,0)
    forvalues k = 1/$nblc {
        mat ind`index'_Lc[`k',1] = B[`k' + (`j' * $nblc),1]
    }
    mat Indicateur_reg = Indicateur_reg, ind`index'_Lc
}
mat Indicateur_reg = Indicateur_reg[1..$nblc,2..13]

*==================================================*
* Vulnérabilité et pauvreté
*==================================================*
gen si = (desco + educ + mfsa)*0.066 ///
       + (chom)*0.2 ///
       + (paselec + paseaup + combsale + pasta + logement + pasequi)*0.033 ///
       + (mjuv)*0.2 + (Ident)*0.2

gen vulnerable = (si > 1/5) & (si <= 1/3) if si != .
gen sev_pauvre = (si >= 1/2) if si != .
gen poor       = (si > 1/3) if si != .

* --- Proportion vulnérables ---
proportion VILLAGE if si!=., over(vulnerable)
mat define temp = e(b)'
mat vulnerable = J($nblc ,1,0)
forvalues k = 1 / $nblc {
    scalar define index = 2 * `k'
    mat vulnerable[`k',1] = temp[index,1]
}

* --- Proportion pauvres sévères ---
proportion VILLAGE if si!=., over(sev_pauvre)
mat define temp = e(b)'
mat sev_pauvre = J($nblc ,1,0)
forvalues k = 1 / $nblc {
    scalar define index = 2 * `k'
    mat sev_pauvre[`k',1] = temp[index,1]
}

*==================================================*
* Population
*==================================================*
qui tab VILLAGE if si!=., matcell(pop)
tab VILLAGE poor if si!=.& poor==1, matcell(poor)

*==================================================*
* Matrice finale
*==================================================*
levelsof VILLAGE if si!=., local(LC)

mat A_lc = H_Lc, M_Lc, Indicateur_reg, vulnerable, sev_pauvre, pop, poor[1..$nblc,1]
mat rownames A_lc = `LC'
mat colnames A_lc = "H" "M0" "Frequentation scolaire" "Année de scolarité" "Alphabétisation" ///
                    "Chomage" "Electricité" "Eau potable" "Energie de cuisson" "Toilette" "Logement" "Equipement" ///
                    "Mortalité juvénile" "Déclaration d'état civil" "Vulnerabilité" "Pauvreté sévère" "Population" "Population pauvre MPI"

*==================================================*
* Export Excel
*==================================================*
putexcel set "D:\IPM\Sortie\Resultats_IPM_SPLC.xlsx", sheet("Localité") sheetmodify
putexcel A1=matrix(A_lc), names
