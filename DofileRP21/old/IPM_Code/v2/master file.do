/********************************************
 Master file
********************************************/ 

****** Définition des globals ******
global projet "F:\IPM"
global root    "$projet\Bases brutes"
global dofile  "$projet\Do file"
global sortie  "$projet\Sortie"

***** Gestion de l'exécution des Do *****
* Calcul des privations
include "$dofile\RGPH21_Calcul_des_privation_CP_23092025.do"


* Calcul IPM au niveau SP
include "$dofile\RGPH21_Calcul_de_lIPM_VF_SP_23092025.do"

* Calcul IPM au niveau LC
include "$dofile\RGPH21_Calcul_de_lIPM_VF_LC_23092025.do"
