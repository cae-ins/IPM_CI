
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

mpi d1(desco educ mfsa) w1(0.066 0.066 0.066) d2(chom) w2(0.2) d3(paselec paseaup combsale  pasta logement pasequi) w3( 0.033 0.033 0.033 0.033 0.033 0.0333) d4(mjuv) w4(0.2) d5(Ident) w5(0.2) [fw=TOTMEN],cutoff(0.3333) by (REGION) nosummary
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
gen si = (desco + educ + mfsa)*1/15 + (chom)*1/5 + (paselec + paseaup +combsale + pasta + logement + pasequi)*1/24 + (mjuv)*1/5 + Ident*1/5

ge vulnerable = (si>1/5) & (si<1/3) if si!=.

gen sev_pauvre = si >= 1/2 if si!=.

gen poor = si >= 1/3  if si!=.

proportion REGION [fw=TOTMEN] if si!=., over(vulnerable)
mat list r(table)

mat define temp = e(b)'

mat vulnerable = J($nb_zone ,1,0)

forvalues k = 1 / $nb_zone  {
	scalar define index = 2 * `k'
	mat vulnerable[`k',1] = temp[index,1]
}

proportion REGION [fw=TOTMEN] if si!=., over(sev_pauvre)
mat list r(table)
mat define temp = e(b)'
mat sev_pauvre = J($nb_zone ,1,0)

forvalues k = 1 / $nb_zone  {
	scalar define index = 2 * `k'
	mat sev_pauvre[`k',1] = temp[index,1]
}


// Population
qui tab REGION [fw=TOTMEN] if si!=.,matcell(pop)

tab REGION poor [fw=TOTMEN] if si! =. & poor==1,matcell(poor)

mat A = F,G,BB,CC,DD,EE,FF,HH,II,JJ,KK,LL,MM,NN, vulnerable,sev_pauvre, pop, poor[1..$nb_zone,1]


mat colnames A = "H" "MO" "Frequentation scolaire"  "Année de scolarité" "Alphabétisation" "Chomage" "Electricité" "Eau potable" "Energie de cuisson"  "Toilette" "Logement"  "Equipement" "Mortalité juvénile" "Déclaration d'état civil" "Vulnerabilité" "sev_pauvre" "population" "population pauvre mpi"

putexcel clear
putexcel set  "C:\CAE_IPM\Sortie\IPM-CI_2021_v2", sheet("REGION") modify

/* Mise en forme */


/* Exportation sur Excel */
putexcel C6 = matrix(A), colnames  nformat(number_d2)
putexcel A7 = matrix(A), rownames


********************************************************************* MILIEU ******************************************************************************
sort P08
drop si vulnerable sev_pauvre poor

mpi d1(desco educ mfsa) w1(0.066 0.066 0.066) d2(chom) w2(0.2) d3(paselec paseaup combsale  pasta logement pasequi) w3( 0.033 0.033 0.033 0.033 0.033 0.0333) d4(mjuv) w4(0.2) d5(Ident) w5(0.2) [fw=TOTMEN],cutoff(0.3333) by (P08) nosummary

global nb_zone = 3
// zone=milieu = 3

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

ge vulnerable = (si>1/5) & (si<1/3) if si!=.

gen sev_pauvre = si >= 1/2 if si!=.

gen poor = si >= 0.3333  if si!=.

proportion P08 [fw=TOTMEN] if si!=., over(vulnerable)
mat list r(table)

mat define temp = e(b)'

mat vulnerable = J($nb_zone ,1,0)

forvalues k = 1 / $nb_zone  {
	scalar define index = 2 * `k'
	mat vulnerable[`k',1] = temp[index,1]
}

proportion P08 [fw=TOTMEN] if si!=., over(sev_pauvre)
mat list r(table)
mat define temp = e(b)'
mat sev_pauvre = J($nb_zone ,1,0)

forvalues k = 1 / $nb_zone  {
	scalar define index = 2 * `k'
	mat sev_pauvre[`k',1] = temp[index,1]
}


// Population
qui tab P08 [fw=TOTMEN] if si!=.,matcell(pop)

tab P08 poor [fw=TOTMEN] if si! =. & poor==1,matcell(poor)

mat A = F,G,BB,CC,DD,EE,FF,HH,II,JJ,KK,LL,MM,NN, vulnerable,sev_pauvre, pop, poor[1..$nb_zone,1]


mat colnames A = "H" "MO" "Frequentation scolaire"  "Année de scolarité" "Alphabétisation" "Chomage" "Electricité" "Eau potable" "Energie de cuisson"  "Toilette" "Logement"  "Equipement" "Mortalité juvénile" "Déclaration d'état civil" "Vulnerabilité" "sev_pauvre" "population" "population pauvre mpi"

putexcel clear
putexcel set  "C:\CAE_IPM\Sortie\IPM-CI_2021_v2", sheet("MILIEU") modify

/* Mise en forme */


/* Exportation sur Excel */
putexcel C6 = matrix(A), colnames  nformat(number_d2)
putexcel A7 = matrix(A), rownames
