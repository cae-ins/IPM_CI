
* -----------------------------------------------------------------------------
* -----------------------------------------------------------------------------
* ANALYSE DE ROBUSTESSE
* -----------------------------------------------------------------------------
* -----------------------------------------------------------------------------


global sortie "C:\Users\Dell\OneDrive\Bureau\PHAS\IPM-CI\EDS 1112\Sortie"

use "$sortie\base_travail_EDS12.dta"


* Calculer et stocker les résultats pour chaque cutoff

*1* IPM AVEC UN SEUIL DE 0.13

mpi d1(d_educ1 d_satt d_lit) w1(0.066 0.066 0.066)  d2(d_cm1) w2(0.2) ///
d3(d_elct d_wtr1 d_sani_1  d_hsg d_ckfl  d_asst1) w3(0.033 0.033 0.033 0.033 0.033 0.033) ///
d4(d_unemp) w4(0.2) d5(Ident) w5(0.2) [pweight=weight], cutoff(0.13) by(region)
matrix A = e(by_mpi)
mat define A = A'
submatrix A, rownum(1/11)
mat define H_013 = r(mat)
submatrix A, rownum(12/22)
mat define M0_013 = r(mat)

*2* IPM AVEC UN SEUIL DE 0.23

mpi d1(d_educ1 d_satt d_lit) w1(0.066 0.066 0.066)  d2(d_cm1) w2(0.2) ///
d3(d_elct d_wtr1 d_sani_1  d_hsg d_ckfl  d_asst1) w3(0.033 0.033 0.033 0.033 0.033 0.033) ///
d4(d_unemp) w4(0.2) d5(Ident) w5(0.2) [pweight=weight], cutoff(0.23) by(region)
matrix A = e(by_mpi)
mat define A = A'
submatrix A, rownum(1/11)
mat define H_023 = r(mat)
submatrix A, rownum(12/22)
mat define M0_023 = r(mat)

*3* IPM AVEC UN SEUIL DE 0.33

mpi d1(d_educ1 d_satt d_lit) w1(0.066 0.066 0.066)  d2(d_cm1) w2(0.2) ///
d3(d_elct d_wtr1 d_sani_1  d_hsg d_ckfl  d_asst1) w3(0.033 0.033 0.033 0.033 0.033 0.033) ///
d4(d_unemp) w4(0.2) d5(Ident) w5(0.2) [pweight=weight], cutoff(0.33) by(region)
matrix A = e(by_mpi)
mat define A = A'
submatrix A, rownum(1/11)
mat define H_033 = r(mat)
submatrix A, rownum(12/22)
mat define M0_033 = r(mat)

*4* IPM AVEC UN SEUIL DE 0.43

mpi d1(d_educ1 d_satt d_lit) w1(0.066 0.066 0.066)  d2(d_cm1) w2(0.2) ///
d3(d_elct d_wtr1 d_sani_1  d_hsg d_ckfl  d_asst1) w3(0.033 0.033 0.033 0.033 0.033 0.033) ///
d4(d_unemp) w4(0.2) d5(Ident) w5(0.2) [pweight=weight], cutoff(0.43) by(region)
matrix A = e(by_mpi)
mat define A = A'
submatrix A, rownum(1/11)
mat define H_043 = r(mat)
submatrix A, rownum(12/22)
mat define M0_043 = r(mat)

*5* IPM AVEC UN SEUIL DE 0.53

mpi d1(d_educ1 d_satt d_lit) w1(0.066 0.066 0.066)  d2(d_cm1) w2(0.2) ///
d3(d_elct d_wtr1 d_sani_1  d_hsg d_ckfl  d_asst1) w3(0.033 0.033 0.033 0.033 0.033 0.033) ///
d4(d_unemp) w4(0.2) d5(Ident) w5(0.2) [pweight=weight], cutoff(0.53) by(region)
matrix A = e(by_mpi)
mat define A = A'
submatrix A, rownum(1/11)
mat define H_053 = r(mat)
submatrix A, rownum(12/22)
mat define M0_053 = r(mat)

*6* IPM AVEC UN SEUIL DE 0.63

mpi d1(d_educ1 d_satt d_lit) w1(0.066 0.066 0.066)  d2(d_cm1) w2(0.2) ///
d3(d_elct d_wtr1 d_sani_1  d_hsg d_ckfl  d_asst1) w3(0.033 0.033 0.033 0.033 0.033 0.033) ///
d4(d_unemp) w4(0.2) d5(Ident) w5(0.2) [pweight=weight], cutoff(0.63) by(region)
matrix A = e(by_mpi)
mat define A = A'
submatrix A, rownum(1/11)
mat define H_063 = r(mat)
submatrix A, rownum(12/22)
mat define M0_063 = r(mat)

*7* IPM AVEC UN SEUIL DE 0.73

mpi d1(d_educ1 d_satt d_lit) w1(0.066 0.066 0.066)  d2(d_cm1) w2(0.2) ///
d3(d_elct d_wtr1 d_sani_1  d_hsg d_ckfl  d_asst1) w3(0.033 0.033 0.033 0.033 0.033 0.033) ///
d4(d_unemp) w4(0.2) d5(Ident) w5(0.2) [pweight=weight], cutoff(0.73) by(region)
matrix A = e(by_mpi)
mat define A = A'
submatrix A, rownum(1/11)
mat define H_073 = r(mat)
submatrix A, rownum(12/22)
mat define M0_073 = r(mat)

*8* IPM AVEC UN SEUIL DE 0.83

mpi d1(d_educ1 d_satt d_lit) w1(0.066 0.066 0.066)  d2(d_cm1) w2(0.2) ///
d3(d_elct d_wtr1 d_sani_1  d_hsg d_ckfl  d_asst1) w3(0.033 0.033 0.033 0.033 0.033 0.033) ///
d4(d_unemp) w4(0.2) d5(Ident) w5(0.2) [pweight=weight], cutoff(0.83) by(region)
matrix A = e(by_mpi)
mat define A = A'
submatrix A, rownum(1/11)
mat define H_083 = r(mat)
submatrix A, rownum(12/22)
mat define M0_083 = r(mat)

*9* IPM AVEC UN SEUIL DE 0.93

mpi d1(d_educ1 d_satt d_lit) w1(0.066 0.066 0.066)  d2(d_cm1) w2(0.2) ///
d3(d_elct d_wtr1 d_sani_1  d_hsg d_ckfl  d_asst1) w3(0.033 0.033 0.033 0.033 0.033 0.033) ///
d4(d_unemp) w4(0.2) d5(Ident) w5(0.2) [pweight=weight], cutoff(0.93) by(region)
matrix A = e(by_mpi)
mat define A = A'
submatrix A, rownum(1/11)
mat define H_093 = r(mat)
submatrix A, rownum(12/22)
mat define M0_093 = r(mat)

*10* CONCATÉNER LES RÉSULTATS DANS DES MATRICES GLOBALES

matrix H_results = H_013,  H_023,  H_033,  H_043,  H_053,  H_063,  H_073, H_083, H_093
matrix M0_results = M0_013, M0_023, M0_033, M0_043, M0_053, M0_063, M0_073, M0_083, M0_093

*11* CRÉER UNE MATRICE GLOBALE CONTENANT H ET M0

matrix Global_results = H_results , M0_results

*12* AFFICHER LES RÉSULTATS FINAUX
matrix list Global_results

mat colnames Global_results = "H_013" "H_023" "H_033" "H_043" "H_053" "H_063"  "H_073" "H_083" "H_093" "M0_013"  "M0_023"  "M0_033" "M0_043" "M0_053"  "M0_063" "M0_073" "M0_083" "M0_093"

*13* AFFICHER LES RÉSULTATS FINAUX

matrix list Global_results

decode region,gen(R)
levelsof R ,local(R)
mat rownames Global_results = `R' 

*14* AFFICHER LES RÉSULTATS FINAUX

matrix list Global_results


*15* EXPORTER LES RÉSULTATS

putexcel clear
putexcel set  "$sortie\IPM-CI_robustness", sheet("k=alpha") replace

*16* MISE EN FORME

putexcel C6 = matrix(Global_results), colnames  nformat(number_d4)
putexcel A7 = matrix(Global_results), rownames


import excel "C:\Users\Dell\OneDrive\Bureau\PHAS\IPM-CI\EDS 1112\Sortie\IPM-CI_robustness.xlsx", sheet("k=alpha") firstrow clear

*17* ANALYSE DE ROBUSTESSE

ktau H_013 H_023 H_033 H_043 H_053 H_063 H_073 H_083 H_093, stats(taub score se p)
matrix Kendall = r(Score)
matrix tau_b = r(Tau_b)
matrix sterror = r(Se_Score)
matrix sig_level = r(P)   
       
*18* EXPORTER LES RÉSULTATS

putexcel clear
putexcel set  "$sortie\IPM-CI_robustness", sheet("Le_test_de_Kendall") modify

*19* MISE EN FORME

putexcel A5 = "Coefficient de correlation tau_b"
putexcel B6 = matrix(tau_b), colnames nformat(number_d4)
putexcel A7 = matrix(tau_b), rownames

putexcel A21 = "Score de Kendall"
putexcel B22 = matrix(Kendall), colnames
putexcel A23 = matrix(Kendall), rownames

putexcel A37 = "Erreur type du score"
putexcel B38 = matrix(sterror), colnames nformat(number_d4)
putexcel A39 = matrix(sterror), rownames

putexcel A53 = "Niveau de significativité"
putexcel B54 = matrix(sig_level), colnames nformat(number_d4)
putexcel A55 = matrix(sig_level), rownames

