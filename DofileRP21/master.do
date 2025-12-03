/********************************************
 Master file
********************************************/ 

****** Définition des globals ******
global projet "C:\Users\f.migone\Desktop\projects\IPM_CI"
global root    "$projet\Data"
global dofile  "$projet\DofileRP21"
**# Bookmark #1
global sortie  "$projet\Sortie"

******installation de ado******
ssc install mpi
ssc install unique
ssc install submatrix 
***** Gestion de l'exécution des Do *****
* Calcul des privations

include "$dofile\RGPH21_Calcul_des_privation_CP_14112025.do"


* Calcul IPM au niveau MILIEU + REGION

include "$dofile\RGPH21_Calcul_de_lIPM_except_sp_lc_VF_13112025.do"

* Calcul IPM au niveau SP
include "$dofile\RGPH21_Automatisation_Calcul_sp_VF_13112025.do"

* Calcul des privations avec pondérations individuelles au niveau SP par milieu de résidence
/* Lancer le code R suivant */
"DofileRP21\privation_by_sep_by_urban.r"