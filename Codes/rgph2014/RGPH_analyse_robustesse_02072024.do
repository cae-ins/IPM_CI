
global sortie "C:\Users\Dell\OneDrive\Bureau\PHAS\IPM-CI\RGPH\RGPH 2014\Sortie"

* -----------------------------------------------------------------------------
* -----------------------------------------------------------------------------
* 1 DONNEES PERTINENTES
* -----------------------------------------------------------------------------
* -----------------------------------------------------------------------------

global eststore desco educ mfsa chom Ident paselec paseaup combsale pasta logement pasequi mjuv

*** Nous construisons une variable de filtre qui identifie les observations avec des informations pour tous les indicateurs pertinents

gen sample = (desco != . & educ != . & mfsa != . & chom != . & Ident != . & paselec != . & paseaup != . & combsale != . & pasta != . & logement != . & pasequi != . & mjuv != .)
sum $eststore [fw = TOTMEN] if sample==1 


* -----------------------------------------------------------------------------
* -----------------------------------------------------------------------------
* 2 MATRICE DE PRIVATION PONDEREE
* -----------------------------------------------------------------------------
* -----------------------------------------------------------------------------

*1* NOUS CONSERVONS UNIQUEMENT LES OBSERVATIONS CONTENANT DES INFORMATIONS SUR TOUS LES INDICATEURS PERTINENTS.

keep if sample==1 


* Définition du vecteur de pondération 'w'.

// DIMENSION EDUCATION 

foreach var in desco educ mfsa {
capture drop w_`var' 
	gen w_`var' = 0.066
	}
*

// DIMENSION SANTE

foreach var in mjuv {
	capture drop w_`var'
	gen w_`var' = 0.200
	}

// DIMENSION CONDITION DE VIE

foreach var in paselec combsale pasta logement pasequi paseaup {
	
	capture drop w_`var'
	gen w_`var' = 0.033
	}

	
// DIMENSION CHOMAGE
	
	foreach var in chom {
	capture drop w_`var'
	gen w_`var' = 0.200
	}
	
// DIMENSION IDENTIFICATION
	foreach var in Ident {
	capture drop w_`var'
	gen w_`var' = 0.200
	}

*2* LES COMMANDES SUIVANTES MULTIPLIENT LA MATRICE DE PRIVATION PAR LE POIDS DE CHAQUE INDICATEUR. 

foreach var in $eststore {	

	gen	g0_w_`var' = `var' * w_`var'
	lab var g0_w_`var' "Privation pondérée de `var'"
	}

*3* CALCUL DU SCORE DE PRIVATION NON CENSURÉ

* On génère le vecteur du score de privation individuel pondéré, « c »
 
egen	c_vector = rowtotal(g0_w_*)
lab var c_vector "Vecteur de Quantification"
tab	c_vector [fw = TOTMEN], m

*4* CALCUL DU SCORE DE PRIVATION CENSURÉ 

* On Génère le vecteur censuré du score de privation individuel pondéré, « c(k) » 
/// fournissant un score de zéro si une personne n'est pas pauvre

forvalues REGION = 1/33 { 
forvalue k = 13(10)93 {

	gen	cens_c_vector_`k'_`REGION' = c_vector
	replace cens_c_vector_`k'_`REGION' = 0 if multid_poor_`k'_`REGION'==0 
	}
}

* -----------------------------------------------------------------------------
* -----------------------------------------------------------------------------
* 3 IDENTIFICATION 
* -----------------------------------------------------------------------------
* -----------------------------------------------------------------------------

* Utilisation de différents seuils de pauvreté (c'est-à-dire différents k)
forvalues REGION = 1/33 { 
forvalue k = 13(10)93 {

	gen	multid_poor_`k'_`REGION' = (c_vector >= `k'/100) if REGION == `REGION'
	lab var multid_poor_`k'_`REGION' "Identification de la pauvreté avec k=`k'%"
	}
}


* -----------------------------------------------------------------------------
*-----------------------------------------------------------------------------
* 4 TAUX DE PAUVRETÉ MULTIDIMENSIONNELLE (H)
* -----------------------------------------------------------------------------
* -----------------------------------------------------------------------------

forvalues REGION = 1/33 { 
forvalue k = 13(10)93 {

sum	multid_poor_`k'_`REGION' [fw = TOTMEN] if REGION == `REGION'
gen	H_`k'_`REGION' = r(mean)
lab var H_`k'_`REGION' "Taux de pauvreté (H_`k'): Population en situation de pauvreté multidimensionnelle, % "
	}
}

* -----------------------------------------------------------------------------
*------------------------------------------------------------------------------
* 5 INDICE DE PAUVRETE (M0)
* -----------------------------------------------------------------------------
* -----------------------------------------------------------------------------

forvalues REGION = 1/33 { 
    forvalues k = 13(10)93 {
// Calcul de la somme pondérée pour la région actuelle
sum cens_c_vector_`k'_`REGION' [fw = TOTMEN] if REGION == `REGION'
// Génération de la variable M0 pour la région actuelle
gen M0_`k'_`REGION' = r(mean)
// Étiquetage de la variable M0
lab var M0_`k'_`REGION' "Indice de pauvreté multidimensionnel (M0 = H*A) : compris de 0 à 1"
    }
}

* -----------------------------------------------------------------------------
*------------------------------------------------------------------------------
* 6 ARRANGEMENT ET EXPORTATION 
* -----------------------------------------------------------------------------
* -----------------------------------------------------------------------------
*1* ON GARDE SEULEMENT H ET M0 POUR LES TESTS DE ROBUSTESSE.

keep  H_* M0_*  
keep in 1

*2* ON ORGANISE LES VARIABLES PAR RÉGION ET PAR SEUIL

// On Définit une liste de variables
local varlist1 ""

// Boucle pour construire la liste des variables dans l'ordre désiré
forvalues k = 13(10)93 {
    forvalues REGION = 1/33 {
        local varlist1 `varlist1' H_`k'_`REGION'
    }
}

forvalues k = 13(10)93 {
    forvalues REGION = 1/33 {
        local varlist1 `varlist1' M0_`k'_`REGION'
    }
}

*3* ON CRÉE UN ENSEMBLE DE MATRICES

// Réorganiser les variables dans la base en utilisant la liste construite
order `varlist1'


//On construit une matrice qui contient le code des régions.

mat REGION = J(33, 1, .)
forval i = 1/33 {
    mat REGION[`i', 1] = `i' 
}

// On construit une matrice qui contient les données dans la base

mkmat H_* M0_*, matrix(data)

// On transpose verticalement les données 

mat data1 = data'

// On crée des matrices pour chaque variable

forvalues k = 13(10)93 {
mat H_`k' = J(33,1,0)
mat  M0_`k' = J(33,1,0)
}

// Remplissage des matrices

// Séquence pour H_13
submatrix data1, rownum(1/33)
mat define H_13 = r(mat)

// Séquence pour H_23
submatrix data1, rownum(34/66)
mat define H_23 = r(mat)

// Séquence pour H_33
submatrix data1, rownum(67/99)
mat define H_33 = r(mat)

// Séquence pour H_43
submatrix data1, rownum(100/132)
mat define H_43 = r(mat)

// Séquence pour H_53
submatrix data1, rownum(133/165)
mat define H_53 = r(mat)

// Séquence pour H_63
submatrix data1, rownum(166/198)
mat define H_63 = r(mat)

// Séquence pour H_73
submatrix data1, rownum(199/231)
mat define H_73 = r(mat)

// Séquence pour H_83
submatrix data1, rownum(232/264)
mat define H_83 = r(mat)

// Séquence pour H_93
submatrix data1, rownum(265/297)
mat define H_93 = r(mat)

// Séquence pour M0_13
submatrix data1, rownum(298/330)
mat define M0_13 = r(mat)

// Séquence pour M0_23
submatrix data1, rownum(331/363)
mat define M0_23 = r(mat)

// Séquence pour M0_33
submatrix data1, rownum(364/396)
mat define M0_33 = r(mat)

// Séquence pour M0_43
submatrix data1, rownum(397/429)
mat define M0_43 = r(mat)

// Séquence pour M0_53
submatrix data1, rownum(430/462)
mat define M0_53 = r(mat)

// Séquence pour M0_63
submatrix data1, rownum(463/495)
mat define M0_63 = r(mat)

// Séquence pour M0_73
submatrix data1, rownum(496/528)
mat define M0_73 = r(mat)

// Séquence pour M0_83
submatrix data1, rownum(529/561)
mat define M0_83 = r(mat)

// Séquence pour M0_93
submatrix data1, rownum(562/594)
mat define M0_93 = r(mat)

// Affichage des matrices créées

mat list H_33
mat list M0_33

// Concaténation
mat IPM_global = REGION, H_13,H_23,H_33, H_43, H_53, H_63, H_73, H_83, H_93, M0_13,M0_23,M0_33, M0_43, M0_53, M0_63, M0_73, M0_83, M0_93

// Nom des matrices
mat colnames IPM_global = "CODE_REGION" "H_13" "H_23" "H_33" "H_43" "H_53" "H_63" "H_73" "H_83" "H_93" "M0_13" "M0_23" "M0_33" "M0_43" "M0_53" "M0_63" "M0_73" "M0_83" "M0_93"

// Affichage 

matlist IPM_global

*4* Exportation
 
putexcel clear
putexcel set  "$sortie\IPM-CI_robustness", sheet("k=alpha") replace

// Mise en forme 

putexcel C6 = matrix(IPM_global), colnames  nformat(number_d4)
import excel "$sortie\IPM-CI_robustness.xlsx", sheet("k=alpha") firstrow clear

save "$sortie\IPM-CI_robustness", replace

use "$sortie\IPM-CI_robustness", clear

* -----------------------------------------------------------------------------
*------------------------------------------------------------------------------
* 7 ROBUSTESSE  
* -----------------------------------------------------------------------------
* -----------------------------------------------------------------------------

 *1*TEST DE KENDALL

ktau H_13 H_23 H_33 H_43 H_53 H_63 H_73 H_83 H_93, stats(taub score se p)
matrix Kendall = r(Score)
matrix tau_b = r(Tau_b)
matrix sterror = r(Se_Score)
matrix sig_level = r(P)   
       
//Exportation

putexcel clear
putexcel set  "$sortie\IPM-CI_robustness", sheet("Le_test_de_Kendall") modify

// Mise en forme

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


*2*TEST DE SPEARMAN

spearman H_13 H_23 H_33 H_43 H_53 H_63 H_73 H_83 H_93, pw star(.05)
matrix Spearman = r(Rho)
matrix sig_level = r(P)

// Exporation

putexcel clear
putexcel set  "$sortie\IPM-CI_robustness", sheet("Le_test_de_Spearman") modify

// Mise en forme 

putexcel A5 = "Coefficient de correlation"
putexcel B6 = matrix(Spearman), colnames nformat(number_d4)
putexcel A7 = matrix(Spearman), rownames

putexcel A21 = "Niveau de significativité"
putexcel B22 = matrix(sig_level), colnames
putexcel A23 = matrix(sig_level), rownames

//Interprétation

*On applique différents seuils de pauvreté multidimensionnelle et obtient différents taux de pauvreté. Par exemple, le coefficient de corrélation entre H_13 et H_23 est élevé et très proche de 1 (0,98). H_23 représente le taux de pauvreté obtenu en ayant appliqué un seuil multidimensionnel de 23 % ou 2,76, ce qui identifie comme pauvre tout ménage ayant deux privations ou plus.En général, les corrélations de Spearman sont élevées pour tous les IPM calculés après avoir appliqué des seuils multidimensionnels intermédiaires.Cependant, le coefficient de corrélation des IPM avec des seuils supérieurs à 73 sont moins élevées que celui des IPM avec des seuils inférieurs à 73.Cette divergence ne devrait pas inquiéter car des seuils multidimensionnels élevés rapprochent l'IPM de la méthode d'identification par intersection,où un individu doit être pauvre dans toutes les dimensions pour être considéré comme pauvre; ce qui est très strict. La pluparts des résultats obtenus sont statistiquements significatif au seuil de 5%, exceptés quelques résultats pour les seuils 83 et 93. En conclusion, les relations entre les résultats pour de légères variations sont monotones; indiquant que les résultats sont robustes et ne changent pas radicalement.*
