
*Decoupage de la base finale par région

use "C:\Users\Dell\OneDrive\Bureau\PHAS\INPM\RGPH\RGPH 2014\Sortie\data_results1.dta" 
levelsof REGION, local(val)
preserve 
 foreach  val in  `val' {
         keep if REGION == `val'
         save "C:\Users\Dell\Desktop\Decoupage_REGIONRP14\Region`val'.dta"
		 
		 
		 
         restore, preserve 
 }
 

*Decoupage de la base finale par SP

 
use "C:\Users\Dell\OneDrive\Bureau\PHAS\INPM\RGPH\RGPH 2014\Sortie\data_results1.dta" , clear

encode I07_NOMVILLAG, gen(VILLAGE)
order VILLAGE
levelsof I04_SOUSPREF, local(val)
preserve 
 foreach  val in  `val' {
         keep if I04_SOUSPREF == `val'
         save "C:\Users\Dell\OneDrive\Bureau\PHAS\INPM\RGPH\RGPH 2014\Sortie\Decoupage_SouprefRP14\I04_SOUSPREF`val'.dta"
		 	 
      restore, preserve   
 }
 

