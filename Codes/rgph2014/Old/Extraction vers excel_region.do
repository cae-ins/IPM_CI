log using "$sortie\INPM_0.log", replace

sort REGION 

mpi d1(desco educ mfsa) w1(0.0667 0.0667 0.0667) d2(chom) w2(0.2) d3(paselec paseaup combsale  pasta logement pasequi) w3( 0.0333 0.0333 0.0333 0.0333 0.0333 0.0333) d4(mjuv) w4(0.2) d5(pasid) w5(0.2) [weight=w],cutoff(0.3333) by (REGION) 

log close

*cap drop si vulnerable sev_pauvre poor sp


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
gen si = (desco + educ + mfsa)*0.0667 + (chom)*0.2 + (paselec + paseaup +combsale + pasta + logement + pasequi)*0.0416 + (mjuv)*0.0333

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

tab REGION poor if si!=.,matcell(poor)

mat A = F,G,BB,CC,DD,EE,FF,GG,HH,II,JJ,KK,LL,MM,NN, vulnerable,sev_pauvre, pop, poor[1..$nb_zone,1]


mat colnames A = "H" "MO" "Frequentation scolaire"  "Année de scolarité" "Alphabétisation" "Chomage" "Electricité" "Eau potable" "Energie de cuisson"  "Toilette" "Logement"  "Equipement" "Mortalité juvénile" "Déclaration d'état civil" "Vulnerabilité" "sev_pauvre" "population" "population pauvre mpi"

/*
decode REGION,gen(R)
levelsof R if si!=.,local(R)
mat rownames A = `R' 

IL Y A UNE INCOHERENCE : les régions listées ne sont pas en ordre avec les données, comme on a "sort" au début , on dupplicate drop en terme de région, 
on copie et colle dans le fichier excel.
*/

/* Exportation sur Excel dans le dossier Resultats_Tab*/
putexcel clear
putexcel set  "$sortie\INPM 2014 byREGION2.xlsx", replace

/* Mise en forme */
putexcel B6 = matrix(A), colnames  nformat(number_d2)
/*
putexcel A7 = matrix(A), rownames
*/


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
