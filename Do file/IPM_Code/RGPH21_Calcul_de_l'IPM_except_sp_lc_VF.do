ren TAILLE_MENAGE TOTMEN
//Nombre moyen privation PNUD
//Quelques stat (Nombre moyen de privation)
tabstat desco educ educ1 mfsa chom Ident paselec paseaup combsale pasta logement mjuv pasequi [fw=TOTMEN],  s(mean sd) col(stat) 
// Nombre moyen selon le seuil Ivoirien
egen NBmis0 = rowmiss(desco educ paselec combsale pasta logement pasequi)
replace NBmis0 = 1 if NBmis !=0
recode NBmis0 (0=1) (1=0)
rename NBmis0 touse0
lab var touse0 "Household without missing value for MPI indicators-PNUD"
egen nbdepr0 = rowtotal( desco educ  paselec paselec combsale  pasta logement pasequi)
lab var nbdepr0 "Number of deprivation PNUD"

tabstat nbdepr0 if touse0, s(mean sd) col(stat), [fw=TOTMEN]

egen NBmis1 = rowmiss(desco educ mfsa paselec paseaup combsale  pasta logement pasequi malnutrition)
replace NBmis1 = 1 if NBmis !=0
recode NBmis1 (0=1) (1=0)
rename NBmis1 touse1
lab var touse1 "Household without missing value for MPI indicators - REFERENCE "
egen nbdeprP = rowtotal(desco educ mfsa paselec paseaup combsale  pasta logement pasequi malnutrition)
lab var nbdeprP "Number of deprivation Reference"

tabstat nbdeprP if touse1, s(mean sd) col(stat), [fw=TOTMEN]


egen NBmis2 = rowmiss(desco educ mfsa paselec paseaup combsale  pasta logement pasequi chom malnutrition mjuv)
replace NBmis2 = 1 if NBmis !=0
recode NBmis2 (0=1) (1=0)
rename NBmis2 touse2
lab var touse2 "Household without missing value for MPI indicators - REFERENCE "
egen nbdeprR = rowtotal( desco educ mfsa paselec paseaup combsale  pasta logement pasequi chom malnutrition mjuv)
lab var nbdeprR "Number of deprivation Reference"

tabstat nbdeprR if touse2, s(mean sd) col(stat), [fw=TOTMEN]


egen NBmis3 = rowmiss(desco educ mfsa paselec paseaup combsale  pasta logement pasequi chom malnutrition mjuv Ident)
replace NBmis3 = 1 if NBmis !=0
recode NBmis3 (0=1) (1=0)
rename NBmis3 touse3
lab var touse3 "Household without missing value for MPI indicators - REFERENCE "
egen nbdeprN = rowtotal( desco educ mfsa paselec paseaup combsale  pasta logement pasequi chom malnutrition mjuv Ident)
lab var nbdeprN "Number of deprivation Reference"

tabstat nbdeprN if touse3, s(mean sd) col(stat), [fw=TOTMEN]

drop nbdepr0 touse0 nbdeprP touse1 nbdeprR touse2 nbdeprN touse3

// Nombre moyen selon le seuil PNUD
egen NBmis0 = rowmiss(desco educ1 paselec combsale pasta logement pasequi)
replace NBmis0 = 1 if NBmis !=0
recode NBmis0 (0=1) (1=0)
rename NBmis0 touse0
lab var touse0 "Household without missing value for MPI indicators-PNUD"
egen nbdepr0 = rowtotal( desco educ  paselec paselec combsale  pasta logement pasequi )
lab var nbdepr0 "Number of deprivation PNUD"

tabstat nbdepr0 if touse0, s(mean sd) col(stat), [fw=TOTMEN]

egen NBmis1 = rowmiss(desco educ1 mfsa paselec paseaup combsale  pasta logement pasequi)
replace NBmis1 = 1 if NBmis !=0
recode NBmis1 (0=1) (1=0)
rename NBmis1 touse1
lab var touse1 "Household without missing value for MPI indicators - REFERENCE "
egen nbdeprP = rowtotal( desco educ1 mfsa paselec paseaup combsale  pasta logement pasequi)
lab var nbdeprP "Number of deprivation Reference"

tabstat nbdeprP if touse1, s(mean sd) col(stat), [fw=TOTMEN]


egen NBmis2 = rowmiss(desco educ1 mfsa paselec paseaup combsale  pasta logement pasequi chom mjuv)
replace NBmis2 = 1 if NBmis !=0
recode NBmis2 (0=1) (1=0)
rename NBmis2 touse2
lab var touse2 "Household without missing value for MPI indicators - REFERENCE "
egen nbdeprR = rowtotal( desco educ1 mfsa paselec paseaup combsale  pasta logement pasequi chom mjuv)
lab var nbdeprR "Number of deprivation Reference"

tabstat nbdeprR if touse2, s(mean sd) col(stat), [fw=TOTMEN]


egen NBmis3 = rowmiss(desco educ1 mfsa paselec paseaup combsale  pasta logement pasequi chom mjuv Ident )
replace NBmis3 = 1 if NBmis !=0
recode NBmis3 (0=1) (1=0)
rename NBmis3 touse3
lab var touse3 "Household without missing value for MPI indicators - REFERENCE "
egen nbdeprN = rowtotal( desco educ1 mfsa paselec paseaup combsale  pasta logement pasequi chom mjuv Ident)
lab var nbdeprN "Number of deprivation Reference"

tabstat nbdeprN if touse3, s(mean sd) col(stat), [fw=TOTMEN]

// PNUD 
// PNUD SEUIL NATIONAL (comporte les indicateurs du PNUD sans nutrition mortalité Eau potable )
mpi d1(desco educ) w1(0.25 0.25) d2(paselec combsale  pasta logement pasequi) w2(0.1 0.1 0.1 0.1 0.1) [fw=TOTMEN] ,cutoff(0.3333) nosummary nodecomposition

// PNUD SEUIL PNUD (comporte les indicateurs du PNUD sans nutrition mortalité Eau potable )
mpi d1(desco educ1) w1(0.25 0.25) d2(paselec combsale  pasta logement pasequi) w2(0.1 0.1 0.1 0.1 0.1) [fw=TOTMEN] ,cutoff(0.3333) nosummary nodecomposition

// PNUD_SEUIL NATIONAL (comporte les indicateurs standards du PNUD )
mpi d1(desco educ) w1(0.1666 0.1666) d2 (mjuv) w2(0.1666 0.1666) d3(paselec combsale paseaup pasta logement pasequi) w3(0.056 0.0556  0.0556 0.0556  0.0556  0.0556)  [fw=TOTMEN]  ,cutoff(0.3333) nosummary nodecomposition

// PNUD_SEUIL PNUD (comporte les indicateurs standards du PNUD )
mpi d1(desco educ1) w1(0.1666 0.1666) d2(mjuv) w2(0.1666 0.1666) d3(paselec combsale paseaup pasta logement pasequi) w3(0.056 0.0556  0.0556 0.0556  0.0556  0.0556)  [fw=TOTMEN]  ,cutoff(0.3333) nosummary nodecomposition

// PNUD_SEUIL NATIONAL (comporte les indicateurs standards auxquels on rajoute l'alphabétisation et le chomage)
mpi d1(desco educ mfsa) w1(0.083 0.083 0.083) d2(mjuv) w2(0.125 0.125) d3(paselec combsale paseaup pasta logement pasequi) w3(0.041 0.041 0.041 0.041 0.041 0.041)  d4(chom) w4(0.25) [fw=TOTMEN] , cutoff (0.3333) nosummary nodecomposition 

// PNUD_SEUIL PNUD (comporte les indicateurs standards auxquels on rajoute l'alphabétisation et le chomage)
mpi d1(desco educ1 mfsa) w1(0.083 0.083 0.083) d2(mjuv) w2(0.125 0.125) d3(paselec combsale paseaup pasta logement pasequi) w3(0.041 0.041 0.041 0.041 0.041 0.041)  d4(chom) w4(0.25) [fw=TOTMEN] , cutoff (0.3333) nosummary nodecomposition 

//PROPOSITION NATIONALE :SEUIL NATIONAL (comporte tous les seuils proposés)
*Sans région
mpi d1(desco educ mfsa) w1(0.066 0.066 0.066) d2(mjuv) w2(0.2) d3(paselec combsale paseaup pasta logement pasequi) w3(0.033 0.033 0.033 0.033 0.033 0.033)  d4(chom) w4(0.2) d5(Ident) w5(0.2) [fw=TOTMEN] , cutoff (0.3333) nosummary nodecomposition 

//PROPOSITION NATIONALE :SEUIL PNUD (comporte tous les seuils proposés)
*Sans région
mpi d1(desco educ1 mfsa) w1(0.066 0.066 0.066) d2(mjuv) w2(0.2) d3(paselec combsale paseaup pasta logement pasequi) w3(0.033 0.033 0.033 0.033 0.033 0.033)  d4(chom) w4(0.2) d5(Ident) w5(0.2) [fw=TOTMEN] , cutoff (0.3333) nosummary nodecomposition 

***************************************************************************** REGION ************************************************************************

label define labelregion 1"ABIDJAN" 2"HAUT-SASSANDRA"  3"PORO"  4"GBEKE" 5"INDENIE-DJUABLIN" 6"TONKPI" 7"YAMOUSSOUKRO" 8"GONTOUGO" 9"SAN-PEDRO" 10"KABADOUGOU" 11" N'ZI" 12"MARAHOUE" 13"SUD-COMOE" 14"WORODOUGOU" 15"LOH-DJIBOUA" 16"AGNEBY-TIASSA" 17"GOH" 18"CAVALLY" 19"BAFING" 20"BAGOUE" 21"BELIER" 22"BERE" 23"BOUNKANI" 24"FOLON" 25"GBOKLE" 26"GRANDS-PONTS" 27"GUEMON" 28"HAMBOL" 29"IFFOU" 30"LA ME" 31"NAWA" 32"TCHOLOGO" 33"MORONOU" 
label values REGION labelregion
codebook REGION, ta(33)

mpi d1(desco educ mfsa) w1(0.066 0.066 0.066) d2(chom) w2(0.2) d3(paselec paseaup combsale  pasta logement pasequi) w3( 0.033 0.033 0.033 0.033 0.033 0.033) d4(mjuv) w4(0.2) d5(Ident) w5(0.2) [fw=TOTMEN],cutoff(0.3333) by(REGION)
*sort REGION
global nb_zone = 33
// zone=region = 33

// M0 et H
mat A = e(by_mpi)
mat list A
mat define A=e(by_mpi)'
submatrix A, rownum(1/33) 
matlist r(mat)
mat define F=r(mat) 
submatrix A, rownum(34/66) 
matlist r(mat)
mat define G=r(mat)


//INDICATEUR 
mat list e(by_ind)
mat define B=e(by_ind)'
mat list B
submatrix B, rownum(1/33) 
matlist r(mat)
mat define BB=r(mat)

submatrix B, rownum(34/66) 
matlist r(mat)
mat define CC=r(mat)

submatrix B, rownum(67/99) 
matlist r(mat)
mat define DD=r(mat)

submatrix B, rownum(100/132) 
matlist r(mat)
mat define EE=r(mat)

submatrix B, rownum(133/165) 
matlist r(mat)
mat define FF=r(mat)

submatrix B, rownum(166/198) 
matlist r(mat)
mat define HH=r(mat)

submatrix B, rownum(199/231) 
matlist r(mat)
mat define II=r(mat)

submatrix B, rownum(232/264) 
matlist r(mat)
mat define JJ=r(mat)

submatrix B, rownum(265/297) 
matlist r(mat)
mat define KK=r(mat)

submatrix B, rownum(298/330) 
matlist r(mat)
mat define LL=r(mat)

submatrix B, rownum(331/363) 
matlist r(mat)
mat define MM=r(mat)

submatrix B, rownum(364/396) 
matlist r(mat)
mat define NN=r(mat)

// Vulnerabilté
gen si = (desco + educ + mfsa)*0.066 + (chom)*0.2 + (paselec + paseaup +combsale + pasta + logement + pasequi)*0.0333 + (mjuv)*0.2 + Ident*0.2

ge vulnerable = (si>1/5) & (si<=1/3) if si!=.

gen sev_pauvre = si >= 1/2 if si!=.

gen poor = si>1/3

proportion REGION if si!=., over(vulnerable)
mat list r(table)

mat define temp = e(b)'

mat vulnerable = J($nb_zone ,1,0)

forvalues k = 1 / $nb_zone  {
	scalar define index = 2 * `k'
	mat vulnerable[`k',1] = temp[index,1]
}

proportion REGION if si!=., over(sev_pauvre)
mat list r(table)
mat define temp = e(b)'
mat sev_pauvre = J($nb_zone ,1,0)

forvalues k = 1 / $nb_zone  {
	scalar define index = 2 * `k'
	mat sev_pauvre[`k',1] = temp[index,1]
}


// Population
qui tab REGION if si!=.,matcell(pop)

tab REGION poor if si! =. & poor==1,matcell(poor)

mat A = F,G,BB,CC,DD,EE,FF,HH,II,JJ,KK,LL,MM,NN, vulnerable,sev_pauvre, pop, poor[1..$nb_zone,1]


mat colnames A = "H" "MO" "Frequentation scolaire"  "Année de scolarité" "Alphabétisation" "Chomage" "Electricité" "Eau potable" "Energie de cuisson"  "Toilette" "Logement"  "Equipement" "Mortalité juvénile" "Déclaration d'état civil" "Vulnerabilité" "sev_pauvre" "population" "population pauvre mpi"


// Retenir le nom des régions
/*sort REGION
decode REGION,gen(R)
levelsof R if si!=.,local(R)
mat rownames A = `R'
*/

/* L'ordre des régions dans la base n'est pas le meme que l'ordre des régions dans la matrice de résultats crée, c'est un problème.
Pour contourner temporairement cela, on récupère manuellement les régions selon le bon ordre.
*/

/* Exportation sur Excel dans le dossier Resultats_Tab*/
putexcel clear
putexcel set  "$sortie\IPM-CI_2021", sheet("REGION") modify

/* Mise en forme */
putexcel C6 = matrix(A), colnames  nformat(number_d2)
putexcel A7 = matrix(A), rownames

/*preserve
duplicates drop REGION, force

restore
*/

**************************************************************************** DISTRICT ********************************************************************
/*sort DISTRICT
drop si vulnerable sev_pauvre poor sp
mpi d1(desco educ mfsa) w1(0.066 0.066 0.066) d2(chom) w2(0.2) d3(paselec paseaup combsale  pasta logement pasequi) w3(0.033 0.033 0.033 0.033 0.033 0.033) d4(mjuv) w4(0.2) d5(Ident) w5(0.2) [fw=TOTMEN],cutoff(0.3333) by (DISTRICT)  nosummary

global nb_zone = 14
// zone=region = 14

// M0 et H
mat A = e(by_mpi)
mat list A
mat define A=e(by_mpi)'
submatrix A, rownum(1/14) 
matlist r(mat)
mat define F=r(mat) 
submatrix A, rownum(15/28) 
matlist r(mat)
mat define G=r(mat)


//INDICATEUR 
mat list e(by_ind)
mat define B=e(by_ind)'
mat list B
submatrix B, rownum(1/14) 
matlist r(mat)
mat define BB=r(mat)

submatrix B, rownum(15/28) 
matlist r(mat)
mat define CC=r(mat)

submatrix B, rownum(29/42) 
matlist r(mat)
mat define DD=r(mat)

submatrix B, rownum(43/56) 
matlist r(mat)
mat define EE=r(mat)

submatrix B, rownum(57/70) 
matlist r(mat)
mat define FF=r(mat)

submatrix B, rownum(71/84) 
matlist r(mat)
mat define HH=r(mat)

submatrix B, rownum(85/98) 
matlist r(mat)
mat define II=r(mat)

submatrix B, rownum(99/112) 
matlist r(mat)
mat define JJ=r(mat)

submatrix B, rownum(113/126) 
matlist r(mat)
mat define KK=r(mat)

submatrix B, rownum(127/140) 
matlist r(mat)
mat define LL=r(mat)

submatrix B, rownum(141/154) 
matlist r(mat)
mat define MM=r(mat)

submatrix B, rownum(155/168) 
matlist r(mat)
mat define NN=r(mat)

// Vulnerabilté
gen si = (desco + educ + mfsa)*0.0667 + (chom)*0.2 + (paselec + paseaup +combsale + pasta + logement + pasequi)*0.0333 + (mjuv)*0.2 + Ident*0.2

ge vulnerable = (si>1/5) & (si<=1/3) if si!=.

gen sev_pauvre = si >= 1/2 if si!=.

gen poor = si>1/3

proportion DISTRICT if si!=., over(vulnerable)
mat list r(table)

mat define temp = e(b)'

mat vulnerable = J($nb_zone ,1,0)

forvalues k = 1 / $nb_zone  {
	scalar define index = 2 * `k'
	mat vulnerable[`k',1] = temp[index,1]
}

proportion DISTRICT if si!=., over(sev_pauvre)
mat list r(table)
mat define temp = e(b)'
mat sev_pauvre = J($nb_zone ,1,0)

forvalues k = 1 / $nb_zone  {
	scalar define index = 2 * `k'
	mat sev_pauvre[`k',1] = temp[index,1]
}


// Population
qui tab DISTRICT if si!=.,matcell(pop)

tab DISTRICT poor if si! =. & poor==1,matcell(poor) 

mat A = F,G,BB,CC,DD,EE,FF,HH,II,JJ,KK,LL,MM,NN, vulnerable,sev_pauvre, pop, poor[1..$nb_zone,1]


mat colnames A = "H" "MO" "Frequentation scolaire"  "Année de scolarité" "Alphabétisation" "Chomage" "Electricité" "Eau potable" "Energie de cuisson"  "Toilette" "Logement"  "Equipement" "Mortalité juvénile" "Déclaration d'état civil" "Vulnerabilité" "sev_pauvre" "population" "population pauvre mpi"

// Retenir le nom des districts
decode DISTRICT,gen(D)
levelsof D if si!=.,local(D)
mat rownames A = `D' 


/* Exportation sur Excel */
putexcel clear
putexcel set  "C:\Users\Dell\OneDrive\Bureau\PHAS\IPM-CI\RGPH\RGPH 2021\Sortie\IPM-CI_2021", sheet("DISTRICT") modify

/* Mise en forme */
putexcel C6 = matrix(A), colnames  nformat(number_d2)
putexcel A7 = matrix(A), rownames
*/
********************************************************************* MILIEU ******************************************************************************
sort P08
drop si vulnerable sev_pauvre poor

mpi d1(desco educ mfsa) w1(0.066 0.066 0.066) d2(chom) w2(0.2) d3(paselec paseaup combsale  pasta logement pasequi) w3( 0.033 0.033 0.033 0.033 0.033 0.0333) d4(mjuv) w4(0.2) d5(Ident) w5(0.2) [fw=TOTMEN],cutoff(0.3333) by (P08) nosummary

global nb_zone = 3
// zone=region = 3

// M0 et H
mat A = e(by_mpi)
mat list A
mat define A=A'
submatrix A, rownum(1/3) 
matlist r(mat)
mat define F=r(mat)
submatrix A, rownum(4/6) 
matlist r(mat)
mat define G=r(mat)


//INDICATEUR 
mat list e(by_ind)
mat define B=e(by_ind)'
mat list B

submatrix B, rownum(1/3) 
matlist r(mat)
mat define BB=r(mat)

submatrix B, rownum(4/6) 
matlist r(mat)
mat define CC=r(mat)

submatrix B, rownum(7/9) 
matlist r(mat)
mat define DD=r(mat)

submatrix B, rownum(10/12) 
matlist r(mat)
mat define EE=r(mat)

submatrix B, rownum(13/15) 
matlist r(mat)
mat define FF=r(mat)

submatrix B, rownum(16/18) 
matlist r(mat)
mat define HH=r(mat)

submatrix B, rownum(19/21) 
matlist r(mat)
mat define II=r(mat)

submatrix B, rownum(22/24) 
matlist r(mat)
mat define JJ=r(mat)

submatrix B, rownum(25/27) 
matlist r(mat)
mat define KK=r(mat)

submatrix B, rownum(28/30) 
matlist r(mat)
mat define LL=r(mat)

submatrix B, rownum(31/33) 
matlist r(mat)
mat define MM=r(mat)

submatrix B, rownum(34/36) 
matlist r(mat)
mat define NN=r(mat)

// Vulnerabilté
gen si = (desco + educ + mfsa)*0.0667 + (chom)*0.2 + (paselec + paseaup +combsale + pasta + logement + pasequi)*0.0416 + (mjuv)*0.2 + Ident*0.2

ge vulnerable = (si>1/5) & (si<=1/3) if si!=.

gen sev_pauvre = si >= 1/2 if si!=.

gen poor = si>1/3

proportion P08 if si!=., over(vulnerable)
mat list r(table)

mat define temp = e(b)'

mat vulnerable = J($nb_zone ,1,0)

forvalues k = 1 / $nb_zone  {
	scalar define index = 2 * `k'
	mat vulnerable[`k',1] = temp[index,1]
}

proportion P08 if si!=., over(sev_pauvre)
mat list r(table)
mat define temp = e(b)'
mat sev_pauvre = J($nb_zone ,1,0)

forvalues k = 1 / $nb_zone  {
	scalar define index = 2 * `k'
	mat sev_pauvre[`k',1] = temp[index,1]
}


// Population
qui tab P08 if si!=.,matcell(pop)

tab P08 poor if si! =. & poor==1,matcell(poor)

mat A = F,G,BB,CC,DD,EE,FF,HH,II,JJ,KK,LL,MM,NN,vulnerable,sev_pauvre, pop, poor[1..$nb_zone,1]


mat colnames A = "H" "MO" "Frequentation scolaire"  "Année de scolarité" "Alphabétisation" "Chomage" "Electricité" "Eau potable" "Energie de cuisson"  "Toilette" "Logement"  "Equipement" "Mortalité juvénile" "Déclaration d'état civil" "Vulnerabilité" "sev_pauvre" "population" "population pauvre mpi"

putexcel clear
putexcel set  "$sortie\IPM-CI_2021", sheet("MILIEU") modify

/* Mise en forme */

/* Exportation sur Excel */
putexcel C6 = matrix(A), colnames  nformat(number_d2)
putexcel A7 = matrix(A), rownames

********************************************************************** DEPARTEMENT **************************************************************************
//PROPOSITION NATIONALE
log using "$sortie\Departement.log", replace

mpi d1(desco educ mfsa) w1(0.066 0.066 0.066) d2(chom) w2(0.2) d3(paselec paseaup combsale  pasta logement pasequi) w3( 0.033 0.033 0.033 0.033 0.033 0.033) d4(mjuv) w4(0.2) d5(Ident) w5(0.2) [fw=TOTMEN],cutoff(0.3333) by(DEPART) nosummary


global nb_zone = 109
// zone=DEPARTEMEN = 108

// M0 et H

mat list e(by_mpi)
mat A = e(by_mpi)'
mat list A
submatrix A , rownum(1/109) 
matlist r(mat)
mat define H_Dept =r(mat)

*submatrix A , rownum(109/216)

mat define M_Dept = J(109,1,0)
forvalues k = 1/109 {
mat M_Dept[`k',1] = A[`k' + 109,1]
}


//INDICATEUR 

mat define B = e(by_ind)'
submatrix B  , rownum(1/109)
mat list r(mat)
mat define Ind1_Dept=r(mat)


mat define Ind2_Dept = J(109,1,0)
forvalues k = 1/108 {
mat Ind2_Dept[`k',1] = B[`k' + 109,1]
}

mat define Ind3_Dept = J(109,1,0)
forvalues k = 1/108 {
mat Ind3_Dept[`k',1] = B[`k' + 217,1]
}

mat define Ind4_Dept = J(109,1,0)
forvalues k = 1/108 {
mat Ind4_Dept[`k',1] = B[`k' + 327,1]
}

mat define Ind4_Dept = J(109,1,0)
forvalues k = 1/108 {
mat Ind4_Dept[`k',1] = B[`k' + 434,1]
}

mat define Ind5_Dept = J(109,1,0)
forvalues k = 1/108 {
mat Ind5_Dept[`k',1] = B[`k' + 542,1]
}

mat define Ind6_Dept = J(109,1,0)
forvalues k = 1/108 {
mat Ind6_Dept[`k',1] = B[`k' + 650,1]
}

mat define Ind7_Dept = J(109,1,0)
forvalues k = 1/108 {
mat Ind7_Dept[`k',1] = B[`k' + 758,1]
}

mat define Ind8_Dept = J(109,1,0)
forvalues k = 1/108 {
mat Ind8_Dept[`k',1] = B[`k' + 866,1]
}

mat define Ind9_Dept = J(109,1,0)
forvalues k = 1/108 {
mat Ind9_Dept[`k',1] = B[`k' + 974,1]
}

mat define Ind10_Dept = J(109,1,0)
forvalues k = 1/108 {
mat Ind10_Dept[`k',1] = B[`k' + 1082,1]
}

mat define Ind11_Dept = J(109,1,0)
forvalues k = 1/108 {
mat Ind11_Dept[`k',1] = B[`k' + 1190,1]
}

mat define Ind12_Dept = J(109,1,0)
forvalues k = 1/108 {
mat Ind12_Dept[`k',1] = B[`k' + 1297,1]
}


// Vulnerabilté
gen si = (desco + educ + mfsa)*0.0667 + (chom)*0.2 + (paselec + paseaup +combsale + pasta + logement + pasequi)*0.0416 + (mjuv)*0.2 + Ident*0.2

ge vulnerable = (si>1/5) & (si<=1/3) if si!=.

gen sev_pauvre = si >= 1/2 if si!=.

gen poor = si>1/3

proportion DEPART if si!=., over(vulnerable)
mat list r(table)

mat define temp = e(b)'

mat vulnerable = J($nb_zone ,1,0)

forvalues k = 1 / $nb_zone  {
	scalar define index = 2 * `k'
	mat vulnerable[`k',1] = temp[index,1]
}

proportion DEPART if si!=., over(sev_pauvre)
mat list r(table)
mat define temp = e(b)'
mat sev_pauvre = J($nb_zone ,1,0)

forvalues k = 1 / $nb_zone  {
	scalar define index = 2 * `k'
	mat sev_pauvre[`k',1] = temp[index,1]
}


// Population
qui tab DEPART if si!=.,matcell(pop)

tab DEPART poor if si! =. & poor==1,matcell(poor)

mat A = H_Dept, M_Dept, Ind1_Dept, Ind2_Dept, Ind3_Dept, Ind4_Dept, Ind5_Dept, Ind6_Dept, Ind7_Dept, Ind8_Dept, Ind9_Dept, Ind10_Dept, Ind11_Dept, Ind12_Dept, vulnerable,sev_pauvre, pop, poor[1..$nb_zone,1]

mat colnames A = "H" "MO" "Frequentation scolaire"  "Année de scolarité" "Alphabétisation" "Chomage" "Electricité" "Eau potable" "Energie de cuisson"  "Toilette" "Logement"  "Equipement" "Mortalité juvénile" "Déclaration d'état civil" "Vulnerabilité" "sev_pauvre" "population" "population pauvre IPM"

// Retenir le nom des Departements
*decode DEPARTEMEN,gen(D)
decode DEPART, gen(DEPARTEMENT)
preserve
duplicates drop DEPARTEMENT
mat rownames A = `DEPARTEMENT' 
*restore
levelsof DEPART if si!=.,local(D)



/* Exportation sur Excel dans le dossier Resultats_Tab*/
putexcel clear
putexcel set  "C:\Users\Dell\OneDrive\Bureau\PHAS\IPM-CI\RGPH\RGPH 2021\Sortie\IPM-CI_2021", sheet("DEPARTEMEN") modify

/* Mise en forme */
putexcel C6 = matrix(A), colnames  nformat(number_d2)

putexcel A7 = matrix(A), rownames


/*
/* Titre du tableau */
putexcel A1 = "Tableau 1  : INPM Global par REGION"
putexcel A1, bold border(bottom)
putexcel (A1:B1), merge 

*En tête colonne du Tableau
putexcel A5 = "REGION"
*putexcel (A2:A4), merge
putexcel B5 = "% de la population"
putexcel C5 = "Borné entre O et 1"
putexcel D5 = "Contribution %"
putexcel E5:P5 = "Contribution %"
putexcel Q5:R5 = "% de la population"
putexcel T5:U5 = "Milliers"

putexcel C4 = "INDICE DE PAUVRETE MULTIDIMENSIONEL, (IPM=H*A)"
putexcel B4 = "Taux d'effectif : Population en situation de pauvreté multidimensionnelle (H)"

putexcel (E4:G4)="EDUCATION", merge
putexcel H4="EMPLOI"
putexcel (I4:N4)="CONDITIONS DE VIE", merge 
putexcel O4="MORTALITE"
putexcel P4="IDENTIFICATION"
putexcel Q4="Vulnérables à la pauvreté (qui connaissent une intensité de privations de 20 à 33,33 %)"
putexcel R4="En situation de pauvreté extrême (avec une intensité supérieure à 50 %)"
putexcel T4="POPULATION TOTALE"
putexcel U4="POPULATION MULTIDIMENSIONELLEMENT PAUVRE"

putexcel (B3:R3)="PAUVRETE MULTIDIMENSIONELLE", merge
putexcel (B3:R3), bold border(bottom)
putexcel (B4:R4), bold border(bottom)

putexcel (T3:U3)="POPULATION TOTALE", merge
putexcel (T4:U4), bold border(bottom)

putexcel (A2:U2), bold border(bottom)
putexcel (A40:U40), bold border(bottom)

putexcel (S3:T3), bold border(bottom)

*Sauvegarde définitive du Tableau
putexcel save

*Fermeture du fichier
putexcel close


