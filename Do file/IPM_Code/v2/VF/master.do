/********************************************
 Master file
********************************************/ 

****** Définition des globals ******
global projet "C:\Users\f.migone\Desktop\projects\cae_ipm"
global root    "$projet\Data"
global dofile  "$projet\Do file\IPM_Code\v2\VF"
**# Bookmark #1
global sortie  "$projet\Sortie"

***** Gestion de l'exécution des Do *****
* Calcul des privations

include "$dofile\RGPH21_Calcul_des_privation_CP_14112025.do"


* Calcul IPM au niveau MILIEU + REGION

include "$dofile\RGPH21_Calcul_de_lIPM_except_sp_lc_VF_13112025.do"

* Calcul IPM au niveau SP
include "$dofile\RGPH21_Automatisation_Calcul_sp_VF_13112025.do"


* Ajout  privation SP
include "$dofile\taux_privation_sp_v2.do"

* Ajout  privation SPxMILIEU
include "$dofile\taux_privation_spxmilieu_v2.do"

