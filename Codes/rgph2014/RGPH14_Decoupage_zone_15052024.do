
*Decoupage de la base finale par région

use "C:\Users\Dell\OneDrive\Bureau\PHAS\IPM-CI\RGPH\RGPH 2014\Sortie\data_results.dta" 


levelsof REGION, local(val)
preserve 
 foreach  val in  `val' {
         keep if REGION == `val'
         save "C:\Users\Dell\OneDrive\Bureau\PHAS\IPM-CI\RGPH\RGPH 2014\Sortie\Decoupage_REGIONRP14\Region`val'.dta", replace
		 
		 
		 
         restore, preserve 
 }
 

*Decoupage de la base finale par SP

 
use "C:\Users\Dell\OneDrive\Bureau\PHAS\IPM-CI\RGPH\RGPH 2014\Sortie\data_results.dta" , clear

*Renommer le nom des villages mal orthographiés en raison des caractères spéciaux présents dans les noms de villages, tels que les parenthèses, les espaces et les points.
gen VILLAGE_clean = trim(itrim(I07_NOMVILLAG)) 
replace VILLAGE_clean = subinstr(VILLAGE_clean, " ", "_", .) 
replace VILLAGE_clean = subinstr(VILLAGE_clean, "(", "", .) 
replace VILLAGE_clean = subinstr(VILLAGE_clean, ")", "", .)
replace VILLAGE_clean = subinstr(VILLAGE_clean, ".", "", .) 
encode VILLAGE_clean, gen(VILLAGE)
drop VILLAGE_clean
order VILLAGE
save, replace
levelsof I04_SOUSPREF, local(val)
preserve 
 foreach  val in  `val' {
         keep if I04_SOUSPREF == `val'
         save "C:\Users\Dell\OneDrive\Bureau\PHAS\IPM-CI\RGPH\RGPH 2014\Sortie\Decoup_SousprefRP14\I04_SOUSPREF`val'.dta", replace
		 	 
      restore, preserve   
 }
 
 

