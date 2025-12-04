/********************************************
 Master file
********************************************/ 

****** Définition des globals ******
global projet "C:\Users\f.migone\Desktop\projects\IPM_CI"
global data "$projet\data"
global dofile  "$projet\dofilerp21"
global output  "$projet\output"

******installation de ado******
ssc install mpi
ssc install unique
ssc install submatrix 
***** Gestion de l'exécution des Do *****
* Calcul des privations

include "$dofile\rp21_calcul_des_privations.do"


* Calcul IPM au niveau MILIEU + REGION

include "$dofile\rp21_compute_mpi_milieu_region.do"

* Calcul IPM au niveau SP
include "$dofile\rp21_automate_mpi_by_souspref.do"

* Calcul des privations avec pondérations individuelles au niveau SP par milieu de résidence
/* Lancer le code R suivant */
"DofileRP21\privation_by_sep_by_urban.r"