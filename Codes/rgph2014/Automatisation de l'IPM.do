clear all
set more off

cd "C:\Users\Dell\OneDrive\Bureau\PHAS\INPM\RGPH\RGPH 2014\Bases brutes"
// Spécifier le chemin d'accès des fichiers à utiliser

local list_de_fichier : dir . files "REG*" 

****CHEMIN****
global data "C:\Users\Dell\OneDrive\Bureau\PHAS\INPM\RGPH\RGPH 2014\Bases brutes" 	  
global sortie "C:\Users\Dell\OneDrive\Bureau\PHAS\INPM\RGPH\RGPH 2014\Sortie"
global dofile "C:\Users\Dell\OneDrive\Bureau\PHAS\INPM\RGPH\RGPH 2014\Dofile"

global list_var_menage "I04_SOUSPREF I05_COMMUNE I09_MILIEU I06_ZD CODLOC I08_QUARCPT I10_ILOT I10A_BATIMEN I10B_LOGEMEN I11N_MENAGE  DEPARTEMEN REGION DISTRICT "  

foreach var of local list_de_fichier {
   do "$data\Compute_INPM_2014_men" `var'
}

/* Fusion des fichiers */
clear

cd "$bases_reg_treated"

append using `: dir . files "*.dta"'

save "C:\Users\Dell\OneDrive\Bureau\PHAS\INPM\Resultats_INPM_2014\data_results.dta", replace


********************************************************************************
*********************DIMENSION SANTE************************
********************************************************************************
import spss using "C:\Users\Dell\OneDrive\Bureau\PHAS\INPM\RGPH 2014\T_MORTALITE_08072015.sav", clear

by $list_var_menage,  sort : gen decs18 =  D59AD_AGED if  D59AD_AGED <18
collapse (count) decs18, by ($list_var_menage)
save "C:\Users\Dell\OneDrive\Bureau\PHAS\INPM\Données Intermédiaire_INPM_2014\DECES8_RGPH2014.dta", replace


use "C:\Users\Dell\OneDrive\Bureau\PHAS\INPM\Resultats_INPM_2014\data_results.dta"

merge m:1 $list_var_menage using "C:\Users\Dell\OneDrive\Bureau\PHAS\INPM\Données Intermédiaire_INPM_2014\DECES8_RGPH2014.dta" ,keepusing(decs18)

gen mjuv = inlist(DE59_DECES, 1) & decs18 > 0
lab var mjuv "Au moins un décès de moins de 18 ans; 1=oui, 0=non"

gen SANTE = (mjuv)/5
lab var Identification "score de la dimension Sante"
save, replace
********************************************************************************
***********************CALCUL DE L'IPM **************************
********************************************************************************

*INPM_0 premier cutoff
log using "C:\Users\Dell\OneDrive\Bureau\PHAS\INPM\Resultats_INPM_2014\INPM_0.log", replace
mpi d1(desco educ mfsa) w1(0.0667 0.0667 0.0667) d2(chom) w2(0.2) d3(paselec paseaup combsale  pasta logement pasequi) w3( 0.0333 0.0333 0.0333 0.0333 0.0333 0.0333) d4(mjuv) w4(0.2) d5(pasid) w5(0.2),cutoff(0.3333) by (I09_MILIEU) 
/*
putexcel set "C:\Users\Dell\OneDrive\Bureau\PHAS\INPM\Resultats_INPM_2014\I09_MILIEU.xlsx", modify
// Exporter les résultats pour la zone actuelle
putexcel A1=("Nombre d'observations (e(N))") B1=`e(N)'
putexcel A3=("Zone") B3=("H") C3=("M0") D3=("A") 
putexcel A4=("National") B4=mat(e(mpi_main)) D4=mat(e(mpi_add))
putexcel A7=("Dimension") A8=mat(e(dom))
putexcel A10=("INDICATEUR") A11=mat(e(ind))
putexcel A14=("M0") A15=mat(e(by_mpi))
putexcel A20=("CONTRIBUTION PAR MILIEU") A21=mat(e(by_dom))
putexcel close


mean desco educ mfsa chom paselec paseaup combsale  pasta logement pasequi mjuv_prov pasid

mat def = (r(table)[rownumb(r(table),"b"),1..11])'
scalar define coefeduc = 0.07
mat list def
mat RESUEDUC = (.)
mat RESUEDUC = RESUEDUC \ def[1..3,1]
mat COEFEDUC = (.) \ J(3,1,coefeduc)
mat RESUEDUC = COEFEDUC,RESUEDUC
*/
mpi d1(desco educ mfsa) w1(0.0667 0.0667 0.0667) d2(chom) w2(0.2) d3(paselec paseaup combsale  pasta logement pasequi) w3( 0.0333 0.0333 0.0333 0.0333 0.0333 0.0333) d4(mjuv) w4(0.2) d5(pasid) w5(0.2),cutoff(0.3333) by (REGION)


/*
putexcel set "C:\Users\Dell\OneDrive\Bureau\PHAS\INPM\Resultats_INPM_2014\REGION.xlsx", modify
// Exporter les résultats pour la zone actuelle
putexcel A1=("Nombre d'observations (e(N))") B1=`e(N)'
putexcel A3=("Zone") B3=("H") C3=("M0") D3=("A") 
putexcel A4=("National") B4=mat(e(mpi_main)) D4=mat(e(mpi_add))
putexcel A7=("Dimension") A8=mat(e(dom))
putexcel A10=("INDICATEUR") A11=mat(e(ind))
putexcel A14=("M0") A15=mat(e(by_mpi))
putexcel A20=("CONTRIBUTION PAR REGION") A21=mat(e(by_dom))
putexcel close

mpi d1(desco educ mfsa) w1(0.0667 0.0667 0.0667) d2(chom) w2(0.2) d3(paselec paseaup combsale  pasta logement pasequi) w3( 0.0333 0.0333 0.0333 0.0333 0.0333 0.0333) d4(mjuv_prov) w4(0.2) d5(pasid) w5(0.2),cutoff(0.3333) by (DEPARTEMEN)
putexcel set "C:\Users\Dell\OneDrive\Bureau\PHAS\INPM\Resultats_INPM_2014\DEPARTEMEN.xlsx", modify
// Exporter les résultats pour la zone actuelle
putexcel A1=("Nombre d'observations (e(N))") B1=`e(N)'
putexcel A3=("Zone") B3=("H") C3=("M0") D3=("A") 
putexcel A4=("National") B4=mat(e(mpi_main)) D4=mat(e(mpi_add))
putexcel A7=("Dimension") A8=mat(e(dom))
putexcel A10=("INDICATEUR") A11=mat(e(ind))
putexcel A14=("M0") A15=mat(e(by_mpi))
putexcel A20=("CONTRIBUTION PAR DEPARTEMEN") A21=mat(e(by_dom))
putexcel close
*/
mpi d1(desco educ mfsa) w1(0.0667 0.0667 0.0667) d2(chom) w2(0.2) d3(paselec paseaup combsale  pasta logement pasequi) w3( 0.0333 0.0333 0.0333 0.0333 0.0333 0.0333) d4(mjuv) w4(0.2) d5(pasid) w5(0.2),cutoff(0.3333) by (DISTRICT)
/*
putexcel set "C:\Users\Dell\OneDrive\Bureau\PHAS\INPM\Resultats_INPM_2014\DISTRICT.xlsx", modify
// Exporter les résultats pour la zone actuelle
putexcel A1=("Nombre d'observations (e(N))") B1=`e(N)'
putexcel A3=("Zone") B3=("H") C3=("M0") D3=("A") 
putexcel A4=("National") B4=mat(e(mpi_main)) D4=mat(e(mpi_add))
putexcel A7=("Dimension") A8=mat(e(dom))
putexcel A10=("INDICATEUR") A11=mat(e(ind))
putexcel A14=("M0") A15=mat(e(by_mpi))
putexcel A20=("CONTRIBUTION PAR DISTRICT") A21=mat(e(by dom))
putexcel close
*/
log close

/*mpi d1(desco educ  mfsa) w1( 0.07 0.07 0.07) d2(chom) w2(0.2) d3(paselec paseaup combsale  pasta logement pasequi) w3(0.03 0.03 0.03 0.03 0.03 0.03) d4(mjuv) w4(0.21) d5(pasid) w5(0.2),cutoff(0.33333) by(I04_SOUSPREF) 
trop de categories
putexcel A1=("Nombre d'observations (e(N))") B1=`e(N)'
putexcel A3=("Zone") B3=("H") C3=("M0") D3=("A") 
putexcel A4=("National") B4=mat(e(mpi_main)) D4=mat(e(mpi_add))
putexcel A7=("Dimension") A8=mat(e(dom))
putexcel A10=("INDICATEUR") A11=mat(e(ind))
putexcel A14=("M0") A15=mat(e(by_mpi))
putexcel A20=("CONTRIBUTION PAR DISTRICT") A21=mat(e(by dom))
putexcel close

*/

*INPM_0 deuxième cutoff
log using "C:\Users\Dell\OneDrive\Bureau\PHAS\INPM\Resultats_INPM_2014\INPM_1.log", replace
mpi d1(desco educ mfsa) w1(0.0667 0.0667 0.0667) d2(chom) w2(0.2) d3(paselec paseaup combsale  pasta logement pasequi) w3( 0.0333 0.0333 0.0333 0.0333 0.0333 0.0333) d4(mjuv) w4(0.2) d5(pasid) w5(0.2),cutoff(0.6666) by (I09_MILIEU)
/*
putexcel set "C:\Users\Dell\OneDrive\Bureau\PHAS\INPM\Resultats_INPM_2014\I09_MILIEU_1.xlsx", modify
// Exporter les résultats pour la zone actuelle
putexcel A1=("Nombre d'observations (e(N))") B1=`e(N)'
putexcel A3=("Zone") B3=("H") C3=("M0") D3=("A") 
putexcel A4=("National") B4=mat(e(mpi_main)) D4=mat(e(mpi_add))
putexcel A7=("Dimension") A8=mat(e(dom))
putexcel A10=("INDICATEUR") A11=mat(e(ind))
putexcel A14=("M0") A15=mat(e(by_mpi))
putexcel A20=("CONTRIBUTION PAR MILIEU") A21=mat(e(by_dom))
putexcel close
*/
mpi d1(desco educ mfsa) w1(0.0667 0.0667 0.0667) d2(chom) w2(0.2) d3(paselec paseaup combsale  pasta logement pasequi) w3( 0.0333 0.0333 0.0333 0.0333 0.0333 0.0333) d4(mjuv) w4(0.2) d5(pasid) w5(0.2),cutoff(0.6666) by (REGION)

/*
putexcel set "C:\Users\Dell\OneDrive\Bureau\PHAS\INPM\Resultats_INPM_2014\REGION_1.xlsx", modify
// Exporter les résultats pour la zone actuelle
putexcel A1=("Nombre d'observations (e(N))") B1=`e(N)'
putexcel A3=("Zone") B3=("H") C3=("M0") D3=("A") 
putexcel A4=("National") B4=mat(e(mpi_main)) D4=mat(e(mpi_add))
putexcel A7=("Dimension") A8=mat(e(dom))
putexcel A10=("INDICATEUR") A11=mat(e(ind))
putexcel A14=("M0") A15=mat(e(by_mpi))
putexcel A20=("CONTRIBUTION PAR REGION") A21=mat(e(by_dom))
putexcel close
*/

mpi d1(desco educ mfsa) w1(0.0667 0.0667 0.0667) d2(chom) w2(0.2) d3(paselec paseaup combsale  pasta logement pasequi) w3( 0.0333 0.0333 0.0333 0.0333 0.0333 0.0333) d4(mjuv) w4(0.2) d5(pasid) w5(0.2),cutoff(0.6666) by (DEPARTEMEN)
/*
putexcel set "C:\Users\Dell\OneDrive\Bureau\PHAS\INPM\Resultats_INPM_2014\DEPARTEMEN_1.xlsx", modify
// Exporter les résultats pour la zone actuelle
putexcel A1=("Nombre d'observations (e(N))") B1=`e(N)'
putexcel A3=("Zone") B3=("H") C3=("M0") D3=("A") 
putexcel A4=("National") B4=mat(e(mpi_main)) D4=mat(e(mpi_add))
putexcel A7=("Dimension") A8=mat(e(dom))
putexcel A10=("INDICATEUR") A11=mat(e(ind))
putexcel A14=("M0") A15=mat(e(by_mpi))
putexcel A20=("CONTRIBUTION PAR DEPARTEMEN") A21=mat(e(by_dom))
putexcel close
*/
mpi d1(desco educ mfsa) w1(0.0667 0.0667 0.0667) d2(chom) w2(0.2) d3(paselec paseaup combsale  pasta logement pasequi) w3( 0.0333 0.0333 0.0333 0.0333 0.0333 0.0333) d4(mjuv) w4(0.2) d5(pasid) w5(0.2),cutoff(0.6666) by (DISTRICT)

/*
putexcel set "C:\Users\Dell\OneDrive\Bureau\PHAS\INPM\Resultats_INPM_2014\DISTRICT_1.xlsx", modify
// Exporter les résultats pour la zone actuelle
putexcel A1=("Nombre d'observations (e(N))") B1=`e(N)'
putexcel A3=("Zone") B3=("H") C3=("M0") D3=("A") 
putexcel A4=("National") B4=mat(e(mpi_main)) D4=mat(e(mpi_add))
putexcel A7=("Dimension") A8=mat(e(dom))
putexcel A10=("INDICATEUR") A11=mat(e(ind))
putexcel A14=("M0") A15=mat(e(by_mpi))
putexcel A20=("CONTRIBUTION PAR DISTRICT") A21=mat(e(by dom))
putexcel close
*/
log close

/*mpi d1(desco educ  mfsa) w1( 0.07 0.07 0.07) d2(chom) w2(0.2) d3(paselec paseaup combsale  pasta logement pasequi) w3(0.03 0.03 0.03 0.03 0.03 0.03) d4(mjuv) w4(0.21) d5(pasid) w5(0.2),cutoff(0.33333) by(I04_SOUSPREF) 
trop de categories
putexcel A1=("Nombre d'observations (e(N))") B1=`e(N)'
putexcel A3=("Zone") B3=("H") C3=("M0") D3=("A") 
putexcel A4=("National") B4=mat(e(mpi_main)) D4=mat(e(mpi_add))
putexcel A7=("Dimension") A8=mat(e(dom))
putexcel A10=("INDICATEUR") A11=mat(e(ind))
putexcel A14=("M0") A15=mat(e(by_mpi))
putexcel A20=("CONTRIBUTION PAR DISTRICT") A21=mat(e(by dom))
putexcel close

*/


/*2 ème méthode


mpitb set , na(INPM_0) d1(desco educ  mfsa, na(un)) d2(chom, na(dos))  d3(paselec paseaup combsale  pasta logement pasequi, na(tres)) d4(mjuv_prov, na(quat)) d5(pasid, na(cinq)) replace

rename I09_MILIEU MILIEU
rename DEPARTEMEN DEP
mpitb est , na(INPM_0) meas(all) indmeas(all) aux(all) klist(33) weight(equal)  lfr(myresults1, replace) over (MILIEU REGION DEP)
cwf myresults1
d
tab measure loa

ta measure loa
save results/results , replace emptyok
loc flist INPM_00 INPM_11
foreach f in `flist' {
    append using results/`f', nol
}

mpi d1(desco educ  mfsa) w1( 0.07 0.07 0.07) d2(chom) w2(0.2) d3(paselec paseaup combsale  pasta logement pasequi) w3(0.03 0.03 0.03 0.03 0.03 0.03) d4(mjuv) w4(0.21) d5(pasid) w5(0.2),cutoff(0.33333) by(I04_SOUSPREF) 
Il faudrait calculer manuellement, il y a trop de sous préfectures 
*/
misstable summ,  percent
