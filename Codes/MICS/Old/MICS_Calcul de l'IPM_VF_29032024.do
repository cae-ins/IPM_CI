********************************************************************************
/*
Citation:
Oxford Poverty and Human Development Initiative (OPHI), University of Oxford. 
2021 Global Multidimensional Poverty Index - Cote d'Ivoire MICS 2016 
[STATA do-file]. Available from OPHI website: http://ophi.org.uk/  

For further queries, contact: ophi@qeh.ox.ac.uk
*/
********************************************************************************

clear all 
set more off
set maxvar 10000



*** Working Folder Path ***

global data "C:\Users\Dell\OneDrive\Bureau\PHAS\IPMC\MICS\MICS 2016\Bases brutes" 	  
global sortie "C:\Users\Dell\OneDrive\Bureau\PHAS\IPMC\MICS\MICS 2016\Sortie"
global dofile "C:\Users\Dell\OneDrive\Bureau\PHAS\IPMC\MICS\MICS 2016\Dofile"


********************************************************************************
*** COTE D'IVOIRE MICS 2016 ***
********************************************************************************


********************************************************************************
*** Step 1: Data preparation 
*** Selecting main variables from CH, WM, HH & MN recode & merging with HL recode 
********************************************************************************

********************************************************************************
*** Step 1.1 CH - CHILDREN's RECODE (under 5)
********************************************************************************	

import spss using "$data\ch.sav", clear 

rename _all, lower	

*** Generate individual unique key variable required for data merging
*** hh1=cluster number; 
*** hh2=household number; 
*** ln=child's line number in household
gen double ind_id = hh1*100000 + hh2*100 + ln 
format ind_id %20.0g
label var ind_id "Individual ID"

duplicates report ind_id 
	// obs, no duplicates
	
gen child_CH=1 
	//Generate identification variable for observations in CH recode

*** Next, indicate to STATA where the igrowup_restricted.ado file is stored:
	***Source of ado file: http://www.who.int/childgrowth/software/en/
adopath + "$data\igrowup_update-master"

*** We will now proceed to create three nutritional variables: 
	*** weight-for-age (underweight),  
	*** weight-for-height (wasting) 
	*** height-for-age (stunting)

/* We use 'reflib' to specify the package directory where the .dta files 
containing the WHO Child Growth Standards are stored. Note that we use 
strX to specify the length of the path in string. If the path is long, 
you may specify str55 or more, so it will run. */	
gen str100 reflib = "$data\igrowup_update-master"
lab var reflib "Directory of reference tables"

/* We use datalib to specify the working directory where the input STATA 
dataset containing the anthropometric measurement is stored. 
anthropometric:Elles fournissent des informations précieuses sur la taille, la forme et la composition du corps humain*/
gen str100 datalib = "$data" 
lab var datalib "Directory for datafiles"

/* We use datalab to specify the name that will prefix the output files that 
will be produced from using this ado file (datalab_z_r_rc and datalab_prev_rc)*/
gen str30 datalab = "children_nutri_civ" 
lab var datalab "Working file"


*** Next check the variables that WHO ado needs to calculate the z-scores:
*** sex, age, weight, height, measurement, oedema & child sampling weight


*** Variable: SEX ***
tab hl4, miss 
	//"1" for male ;"2" for female
tab hl4, nol 
clonevar gender = hl4
desc gender
tab gender


*** Variable: AGE ***
codebook ag2 cage, tab (30)
tab cage, miss 
codebook cage 
clonevar age_months = cage
desc age_months
replace age_months = . if cage==9999 
replace age_months = . if cage < 0  
summ age_months
gen str6 ageunit = "months"
lab var ageunit "Months"


*** Variable: BODY WEIGHT (KILOGRAMS) ***
codebook an3, tab (10000)
clonevar weight = an3	
replace weight = . if an3>=99 
tab	an2 an3 if an3>=99 | an3==., miss 
	//an2: result of the measurement
tab uf9 if an2==. & an3==.	
desc weight 
summ weight	


*** Variable: HEIGHT (CENTIMETERS)
codebook an4, tab (10000)
clonevar height = an4
replace height = . if an4>=999 
tab	an2 an4 if an4>=999 | an4==., miss
desc height 
summ height

	
*** Variable: MEASURED STANDING/LYING DOWN	
codebook an4a
gen measure = "l" if an4a==1 
	//Child measured lying down
replace measure = "h" if an4a==2 
	//Child measured standing up
replace measure = " " if an4a==9 | an4a==0 | an4a==. 
	//Replace with " " if unknown
desc measure
tab measure
		
	
*** Variable: OEDEMA ***
gen str1 oedema = "n"  


*** Variable: INDIVIDUAL CHILD SAMPLING WEIGHT ***
gen sw = chweight

	
	
/*We now run the command to calculate the z-scores with the adofile */
igrowup_restricted reflib datalib datalab gender age_months ageunit weight height measure oedema sw


/*We now turn to using the dta file that was created and that contains 
the calculated z-scores */
use "$data/children_nutri_civ_z_rc.dta", clear 


*** Standard MPI indicator ***	
gen	underweight = (_zwei < -2.0) 
replace underweight = . if _zwei == . | _fwei==1
lab var underweight  "Child is undernourished (weight-for-age) 2sd - WHO"
tab underweight [aw=chweight], miss  


gen stunting = (_zlen < -2.0)
replace stunting = . if _zlen == . | _flen==1
lab var stunting "Child is stunted (length/height-for-age) 2sd - WHO"
tab stunting [aw=chweight], miss 


gen wasting = (_zwfl < - 2.0)
replace wasting = . if _zwfl == . | _fwfl == 1
lab var wasting  "Child is wasted (weight-for-length/height) 2sd - WHO"
tab wasting [aw=chweight], miss 


*** Destitution indicator  ***	
gen	underweight_u = (_zwei < -3.0) 
replace underweight_u = . if _zwei == . | _fwei==1
lab var underweight_u  "Child is undernourished (weight-for-age) 3sd - WHO"


gen stunting_u = (_zlen < -3.0)
replace stunting_u = . if _zlen == . | _flen==1
lab var stunting_u "Child is stunted (length/height-for-age) 3sd - WHO"


gen wasting_u = (_zwfl < - 3.0)
replace wasting_u = . if _zwfl == . | _fwfl == 1
lab var wasting_u  "Child is wasted (weight-for-length/height) 3sd - WHO"


clonevar weight_ch = chweight
label var weight_ch "sample weight child under 5"
 
 
	//Retain relevant variables:
keep ind_id child_CH weight_ch ln underweight* stunting* wasting*  
order ind_id child_CH weight_ch ln underweight* stunting* wasting*
sort ind_id
save "$sortie/CIV16_CH.dta", replace


	//Erase files from folder:
erase "$data/children_nutri_civ_z_rc.xls"
erase "$data/children_nutri_civ_prev_rc.xls"
erase "$data/children_nutri_civ_z_rc.dta"

	
********************************************************************************
*** Step 1.2  BR - BIRTH RECODE 
*** (All females 15-49 years who ever gave birth)  
********************************************************************************
/*The purpose of step 1.2 is to identify children of any age who died in 
the last 5 years prior to the survey date.*/

import spss using "$data/bh.sav", clear

rename _all, lower	

*** Generate individual unique key variable required for data merging using:
	*** hh1=cluster number; 
	*** hh2=household number; 
	*** ln=women's line number.
gen double ind_id = hh1*100000 + hh2*100 + ln
format ind_id %20.0g
label var ind_id "Individual ID"

		
desc bh4c bh9c	
gen date_death = bh4c + bh9c	
	//Date of death = date of birth (bh4c) + age at death (bh9c)	
gen mdead_survey = wdoi-date_death	
	//Months dead from survey = Date of interview (wdoi) - date of death	
replace mdead_survey = . if (bh9c==0 | bh9c==.) & bh5==1	
	/*Replace children who are alive as '.' to distinguish them from children 
	who died at 0 months */ 
gen ydead_survey = mdead_survey/12
	//Years dead from survey
	

gen age_death = bh9c if bh5==2
label var age_death "Age at death in months"	
tab age_death, miss
	//Check whether the age is in months	
	
	
codebook bh5, tab (10)	
gen child_died = 1 if bh5==2
replace child_died = 0 if bh5==1
replace child_died = . if bh5==.
label define lab_died 0"child is alive" 1"child has died"
label values child_died lab_died
tab bh5 child_died, miss
	
	
bysort ind_id: egen tot_child_died = sum(child_died) 
	//For each woman, sum the number of children who died
		
	
	//Identify child under 18 mortality in the last 5 years
gen child18_died = child_died 
replace child18_died=0 if age_death>=216 & age_death<.
label values child18_died lab_died
tab child18_died, miss	
	
bysort ind_id: egen tot_child18_died_5y=sum(child18_died) if ydead_survey<=5
	/*Total number of children under 18 who died in the past 5 years 
	prior to the interview date */	
	
replace tot_child18_died_5y=0 if tot_child18_died_5y==. & tot_child_died>=0 & tot_child_died<.
	/*All children who are alive or who died longer than 5 years from the 
	interview date are replaced as '0'*/
	
replace tot_child18_died_5y=. if child18_died==1 & ydead_survey==.
	//Replace as '.' if there is no information on when the child died  

tab tot_child_died tot_child18_died_5y, miss

bysort ind_id: egen childu18_died_per_wom_5y = max(tot_child18_died_5y)
lab var childu18_died_per_wom_5y "Total child under 18 death for each women in the last 5 years (birth recode)"


	//Identify child under 18 mortality in the last 1 year
bysort ind_id: egen tot_child18_died_1y=sum(child18_died) if ydead_survey<=1
	/*Total number of children under 18 who died in the past 1 year 
	prior to the interview date */	
	
replace tot_child18_died_1y=0 if tot_child18_died_1y==. & tot_child_died>=0 & tot_child_died<.
	/*All children who are alive or who died longer than 1 year from the 
	interview date are replaced as '0'*/
	
replace tot_child18_died_1y=. if child18_died==1 & ydead_survey==.
	//Replace as '.' if there is no information on when the child died  

tab tot_child_died tot_child18_died_1y, miss

bysort ind_id: egen childu18_died_per_wom_1y = max(tot_child18_died_1y)
lab var childu18_died_per_wom_1y "Total child under 18 death for each women in the last 1 year (birth recode)"

	//Keep one observation per women
bysort ind_id: gen id=1 if _n==1
keep if id==1
drop id
duplicates report ind_id 

gen women_BH = 1 
	//Identification variable for observations in BH recode

	
	//Retain relevant variables
keep ind_id women_BH childu18_died_per_wom_5y childu18_died_per_wom_1y
order ind_id women_BH childu18_died_per_wom_5y childu18_died_per_wom_1y
sort ind_id
save "$sortie/CIV16_BH.dta", replace	

********************************************************************************
*** Step 1.3  WM - WOMEN's RECODE  
*** (All eligible females 15-49 years in the household)
********************************************************************************
import spss using "$data/wm.sav", clear 
	
rename _all, lower	

	
*** Generate individual unique key variable required for data merging
*** hh1=cluster number;  
*** hh2=household number; 
*** ln=respondent's line number
gen double ind_id = hh1*100000 + hh2*100 + ln
format ind_id %20.0g
label var ind_id "Individual ID"

duplicates report ind_id 
	// obs, no duplicates

gen women_WM =1 
	//Identification variable for observations in WM recode

	

	
	//Retain relevant variables:	
keep wm7 cm1 cm8 cm9a cm9b wan2 wan3 wan4 ind_id women_WM 
order wm7 cm1 cm8 cm9a cm9b wan2 wan3 wan4 ind_id women_WM 
sort ind_id
save "$sortie/CIV16_WM.dta", replace


********************************************************************************
*** Step 1.4  IR - WOMEN'S RECODE  
*** (Girls 15-19 years in the household)
********************************************************************************

import spss using "$data/wm.sav", clear
	
rename _all, lower	

		
*** Generate individual unique key variable required for data merging
*** hh1=cluster number;  
*** hh2=household number; 
*** ln=respondent's line number
gen double ind_id = hh1*100000 + hh2*100 + ln
format ind_id %20.0g
label var ind_id "Individual ID"

duplicates report ind_id	
	
	
***Variables required to calculate the z-scores to produce BMI-for-age:

*** Variable: SEX ***
gen gender=2 
	//Assign all observations as "2" for all women, 15-49 years

	
*** Variable: AGE IN MONTHS ***
replace wb1m = . if wb1m==2
	//month of birth
replace wb1y = . if wb1y==9998
	//year of birth

gen imonth = mdy(wm6m, 1, wm6y)
	//month of interview (wm6m); year of interview (wm6y)
gen bmonth = mdy(wb1m, 1, wb1y) 
	//month of birth (wb1m); year of birth (wb1y)

gen age_month = (imonth-bmonth)/30.4375 
	//Calculate age in months 
lab var age_month "Age in months, individuals 15-19 years"	

	
*** Variable: AGE UNIT ***
gen str6 ageunit = "months" 
lab var ageunit "Months"

		
*** Variable: BODY WEIGHT (KILOGRAMS) ***
codebook wan3, tab (1000)
clonevar weight = wan3
summ weight


*** Variable: HEIGHT (CENTIMETERS)
codebook wan4, tab (1000)
clonevar height = wan4
replace height = . if wan4>=999 
	/*All missing values or out of range are replaced as "."
	 There are two observations with above 190 cm of height. This is a 16-years-
	 old and a 22-years-old girl. The 22 years old will be dropped below as 
	 we are computing 15-19. We keep the 16 years old. This would not change the 
	 results and it could be a real value */
summ height


*** Variable: OEDEMA
gen oedema = "n"  
tab oedema	


*** Variable: SAMPLING WEIGHT ***
gen sw = wmweight 
summ sw	


*** Keep only relevant sample: teenagers 15 - 19 years ***		
count if wb2>=15 & wb2<=19
	//Total number of girls 15-19 years: 2,260	
keep if wb2>=15 & wb2<=19	
	//Keep only girls between age 15-19 years to compute BMI-for-age		
		
		
*** Next, indicate to STATA where the who ado file is stored:
	***Source of ado file: https://www.who.int/growthref/tools/en/		
adopath + "C:\Users\Dell\OneDrive\Bureau\PHAS\IPMC\MICS\who2007_update"


/* We use 'reflib' to specify the package directory where the .dta files 
containing the WHO Growth reference are stored. Note that we use strX to specify 
the length of the path in string. */		
gen str100 reflib = "C:\Users\Dell\OneDrive\Bureau\PHAS\IPMC\MICS\who2007_update"
lab var reflib "Directory of reference tables"


/* We use datalib to specify the working directory where the input STATA data
set containing the anthropometric measurement is stored. */
gen str100 datalib = "C:\Users\Dell\OneDrive\Bureau\PHAS\IPMC\MICS\who2007_update" 
lab var datalib "Directory for datafiles"


/* We use datalab to specify the name that will prefix the output files that 
will be produced from using this ado file*/
gen str30 datalab = "girl_nutri_civ" 
lab var datalab "Working file"
	

/*We now run the command to calculate the z-scores with the adofile */
who2007 reflib datalib datalab gender age_month ageunit weight height oedema sw


/*We now turn to using the dta file that was created and that contains 
the calculated z-scores to compute BMI-for-age*/
use "C:\Users\Dell\OneDrive\Bureau\PHAS\IPMC\MICS\who2007_update/girl_nutri_civ_z.dta", clear 

		
gen	z_bmi = _zbfa
replace z_bmi = . if _fbfa==1 
lab var z_bmi "z-score bmi-for-age WHO"


*** Standard MPI indicator ***
gen	low_bmiage = (z_bmi < -2.0) 
replace low_bmiage = . if z_bmi==.
lab var low_bmiage "Teenage low bmi 2sd - WHO"


*** Destitution indicator ***
gen	low_bmiage_u = (z_bmi < -3.0)
replace low_bmiage_u = . if z_bmi==.
lab var low_bmiage_u "Teenage very low bmi 3sd - WHO"


tab low_bmiage, miss
tab low_bmiage_u, miss


gen teen_IR=1 
	//Identification variable for observations 15-19 years


	//Retain relevant variables:	
keep ind_id teen_IR age_month low_bmiage*
order ind_id teen_IR age_month low_bmiage*
sort ind_id
save "$sortie/CIV16_WM_girls.dta", replace


	//Erase files from folder:
erase "C:\Users\Dell\OneDrive\Bureau\PHAS\IPMC\MICS\who2007_update//girl_nutri_civ_z.xls"
erase "C:\Users\Dell\OneDrive\Bureau\PHAS\IPMC\MICS\who2007_update//girl_nutri_civ_prev.xls"
erase "C:\Users\Dell\OneDrive\Bureau\PHAS\IPMC\MICS\who2007_update//girl_nutri_civ_z.dta"


********************************************************************************
*** Step 1.5  MN - MEN'S RECODE 
***(All eligible man: 15-49 years in the household) 
********************************************************************************

import spss using  "$data/mn.sav", clear 

rename _all, lower

	
*** Generate individual unique key variable required for data merging
*** hh1=cluster number;  
*** hh2=household number; 
*** ln=respondent's line number
gen double ind_id = hh1*100000 + hh2*100 + ln
format ind_id %20.0g
label var ind_id "Individual ID"

duplicates report ind_id 

gen men_MN=1 	
	//Identification variable for observations in MR recode



	//Retain relevant variables:	   
keep mceb mcsurv mcdead ind_id men_MN 
order mceb mcsurv mcdead ind_id men_MN 
sort ind_id
save "$sortie/CIV16_MN.dta", replace



********************************************************************************
*** Step 1.6 HH - HOUSEHOLD RECODE 
***(All households interviewed) 
********************************************************************************

import spss using "$data/hh.sav", clear 
	
rename _all, lower	


*** Generate individual unique key variable required for data merging
*** hh1=cluster number;  
*** hh2=household number; 
gen	double hh_id = hh1*100 + hh2 
format	hh_id %20.0g
lab var hh_id "Household ID"

save "$sortie/CIV16_HH.dta", replace



********************************************************************************
*** Step 1.7 HL - HOUSEHOLD MEMBER  
********************************************************************************


import spss using "$data/hl.sav", clear 

rename _all, lower


*** Generate a household unique key variable at the household level using: 
	***hh1=cluster number 
	***hh2=household number
gen double hh_id = hh1*100 + hh2 
format hh_id %20.0g
label var hh_id "Household ID"


*** Generate individual unique key variable required for data merging using:
	*** hh1=cluster number; 
	*** hh2=household number; 
	*** hl1=respondent's line number.
gen double ind_id = hh1*100000 + hh2*100 + hl1 
format ind_id %20.0g
label var ind_id "Individual ID"

	
sort ind_id
	
********************************************************************************
*** Step 1.8 DATA MERGING 
******************************************************************************** 
 
 
*** Merging BR Recode 
*****************************************
merge 1:1 ind_id using "$sortie/CIV16_BH.dta"
drop _merge
 
*** Merging WM Recode 
*****************************************
merge 1:1 ind_id using "$sortie/CIV16_WM.dta"
drop _merge

*** Merging WM Recode: 15-19 years girls 
*****************************************
merge 1:1 ind_id using "$sortie/CIV16_WM_girls.dta"
drop _merge


*** Merging MN Recode 
*****************************************
merge 1:1 ind_id using "$sortie/CIV16_MN.dta"
drop _merge


*** Merging CH Recode 
*****************************************
merge 1:1 ind_id using "$sortie/CIV16_CH.dta"
drop _merge

sort ind_id


*** Merging HH Recode 
*****************************************
merge m:1 hh1 hh2 using "$sortie/CIV16_HH.dta"
tab hh9 if _m==2
drop  if _merge==2
	//Drop households that were not interviewed 
drop _merge

save "$sortie\base_travail_mics2016", replace

clear all
set more off

use "$sortie\base_travail_mics2016"

********************************************************************************
*** Step 1.9 CONTROL VARIABLES
********************************************************************************

*** No eligible women 15-49 years 
*** for adult nutrition indicator
***********************************************
gen fem_nutri_eligible = (women_WM==1 & wan2>=1 & wan2<=6)
tab fem_nutri_eligible, miss
bysort hh_id: egen hh_n_fem_nutri_eligible = sum(fem_nutri_eligible) 	
gen	no_fem_nutri_eligible = (hh_n_fem_nutri_eligible==0)
lab var no_fem_nutri_eligible "Household has no eligible women for anthropometric"	
drop hh_n_fem_nutri_eligible
tab no_fem_nutri_eligible, miss


*** No Eligible Women 15-49 years
*** for child mortality indicator
*****************************************
gen	fem_eligible = (hl7>0) if hl7!=.
bys	hh_id: egen hh_n_fem_eligible = sum(fem_eligible) 	
	//Number of eligible women for interview in the hh
gen	no_fem_eligible = (hh_n_fem_eligible==0) 									
	//Takes value 1 if the household had no eligible females for an interview
lab var no_fem_eligible "Household has no eligible women"
drop hh_n_fem_eligible
tab no_fem_eligible, miss


*** No Eligible Men 15-49 years
*****************************************
gen	male_eligible = (hl7a>0) if hl7a!=.
bys	hh_id: egen hh_n_male_eligible = sum(male_eligible)  
	//Number of eligible men for interview in the hh
gen	no_male_eligible = (hh_n_male_eligible==0) 	
	//Takes value 1 if the household had no eligible males for an interview
lab var no_male_eligible "Household has no eligible man"
drop hh_n_male_eligible
tab no_male_eligible, miss


*** No Eligible Children 0-5 years
***************************************** 
gen	child_eligible = (hl7b>0 | child_CH==1) 
bys	hh_id: egen hh_n_children_eligible = sum(child_eligible)  
	//Number of eligible children for anthropometrics
gen	no_child_eligible = (hh_n_children_eligible==0) 
	//Takes value 1 if there were no eligible children for anthropometrics
lab var no_child_eligible "Household has no children eligible"
drop hh_n_children_eligible 	
tab no_child_eligible, miss
	
		
*** No eligible women and men 
*** for adult nutrition indicator
***********************************************
gen no_adults_eligible = (no_fem_nutri_eligible==1)
lab var no_adults_eligible "Household has no eligible women or men for anthropometrics"
tab no_adults_eligible, miss 


*** No Eligible Children and Women
*** for child and women nutrition indicator 
***********************************************
gen	no_child_fem_eligible = (no_child_eligible==1 & no_fem_nutri_eligible==1)
lab var no_child_fem_eligible "Household has no children or women eligible for anthropometric"
tab no_child_fem_eligible, miss 

*** No Eligible Women, Men or Children 
*** for nutrition indicator 
***********************************************
gen no_eligibles = (no_fem_nutri_eligible==1 & no_child_eligible==1)
lab var no_eligibles "Household has no eligible women, men, or children"
tab no_eligibles, miss


sort hh_id


********************************************************************************
*** Step 1.10 RENAMING DEMOGRAPHIC VARIABLES ***
********************************************************************************

//Sample weight
clonevar weight = hhweight 
label var weight "Sample weight"


//Type of place of residency: urban or rural		
desc hh6	
clonevar urban = hh6  
replace urban=0 if urban==2  
label define lab_urban 1 "urban" 0 "rural"
label values urban lab_urban
label var urban "Urban area"


//Area: urban or rural		
desc hh6	
clonevar area = hh6  
replace area=0 if area==2  
label define lab_area 1 "urban" 0 "rural"
label values area lab_area
label var area "Area: urban-rural"


//Relationship to the head of household
desc hl3
clonevar relationship = hl3 
codebook relationship, tab (20)
recode relationship (1=1)(2=2)(3 13=3)(4/12=4)(96=5)(14=6)(97=.)(98=.)
label define lab_rel 1"head" 2"spouse" 3"child" 4"extended family" ///
					 5"not related" 6"maid"
label values relationship lab_rel
label var relationship "Relationship to the head of household"
tab hl3 relationship, miss	


//Sex of household member
codebook hl4
clonevar sex = hl4 
label var sex "Sex of household member"


//Household headship
bys	hh_id: egen missing_hhead = min(relationship)
tab missing_hhead,m 
gen household_head=.
replace household_head=1 if relationship==1 & sex==1 
replace household_head=2 if relationship==1 & sex==2
bysort hh_id: egen headship = sum(household_head)
replace headship = 1 if (missing_hhead==2 & sex==1)
replace headship = 2 if (missing_hhead==2 & sex==2)
replace headship = . if missing_hhead>2
label define head 1"male-headed" 2"female-headed"
label values headship head
label var headship "Household headship"
tab headship, miss


//Age of household member
codebook hl6, tab (999)
clonevar age = hl6  
replace age = . if age>=98
label var age "Age of household member"


//Age group 
recode age (0/4 = 1 "0-4")(5/9 = 2 "5-9")(10/14 = 3 "10-14") ///
		   (15/17 = 4 "15-17")(18/59 = 5 "18-59")(60/max=6 "60+"), gen(agec7)
lab var agec7 "age groups (7 groups)"	
	   
recode age (0/9 = 1 "0-9") (10/17 = 2 "10-17")(18/59 = 3 "18-59") ///
		   (60/max=4 "60+"), gen(agec4)
lab var agec4 "age groups (4 groups)"

recode age (0/17 = 1 "0-17") (18/max = 2 "18+"), gen(agec2)		 		   
lab var agec2 "age groups (2 groups)"


//Total number of de jure hh members in the household
gen member = 1
bysort hh_id: egen hhsize = sum(member)
label var hhsize "Household size"
tab hhsize, miss
compare hhsize hh11
drop member



//Subnational region
	/*The sample for the Côte d'Ivoire MICS 2016 was designed to provide 
	  estimates for a large number of indicators on the situation of children 
	  and women at the national level, urban and rural areas, and for each of 
	  the eleven areas: Center, Center-East, Center-North, Center-West, North, 
	  North-East, North-West, West, South, South-West and City of Abidjan.*/
	  
codebook hh7, tab (99)
clonevar region = hh7
lab var region "Region for subnational decomposition"
tab hh7 region, miss 
label define lab_reg ///
1 "Centre" ///
2 "Centre-Est" ///
3 "Centre-Nord" ///
4 "Centre-Ouest" ///
5 "Nord" ///
6 "Nord-Est" ///
7 "Nord-Ouest" ///
8 "Ouest" ///
9 "Sud (ex. Ville d'Abidjan)" ///
10 "Sud-Ouest" ///
11 "Ville d'Abidjan"
label values region lab_reg
codebook region, tab (99)						 

						 
********************************************************************************
***  Step 2 Data preparation  ***
***  Standardization of the 10 Global MPI indicators 
***  Identification of non-deprived & deprived individuals  
********************************************************************************


********************************************************************************
*** Step 2.1 Years of Schooling ***
********************************************************************************

	/*Note: The education model in Cote D'Ivoire consists of 13 years of basic 
	education with 6 years of compulsory primary, 4 years of compulsory lower 
	secondary, and 3 years of upper secondary. The admission age to compulsory 
	education is 6 years. Preschool education takes place from age 3. Primary 
	education takes place from age 6-11 (grades 1-6). Lower secondary education 
	takes place from age 12-15 (grades 7-10). Upper secondary education takes 
	place from age 16-18 (grades 11-13).

References: 
http://uis.unesco.org/country/CI
https://www.epdc.org/sites/default/files/documents/EPDC%20NEP_Cote%20d%20Ivoire.pdf
*/

codebook ed4a, tab (999)
clonevar edulevel = ed4a 
	//Highest educational level attended
replace edulevel = . if ed4a==. | ed4a==8 | ed4a==9  
	//ed4a=8/98/99 are missing values 
replace edulevel = 0 if ed3==2 
	//Those who never attended school are replaced as '0'
label var edulevel "Highest educational level attended"

codebook ed4b, tab (99)
clonevar eduhighyear = ed4b 
	//Highest grade of education completed
replace eduhighyear = . if ed4b==. | ed4b==97 | ed4b==98 | ed4b==99 
	//ed4b=97/98/99 are missing values
replace eduhighyear = 0 if ed3==2 
	//Those who never attended school are replaced as '0'
lab var eduhighyear "Highest year of education completed"


*** Cleaning inconsistencies 
replace eduhighyear = 0 if age<10 
	/*The variable "eduhighyear" was replaced with a '0' given that the criteria 
	for this indicator is household member aged 10 years or older */ 
replace eduhighyear = 0 if edulevel<1

*** Now we create the years of schooling
tab eduhighyear edulevel, miss
gen	eduyears = eduhighyear
replace eduyears = 0 if edulevel<2 & eduhighyear==.   
	/*Assuming 0 year if they only attend preschool or primary but the last year 
	is unknown*/
replace eduyears = eduhighyear + 6 if edulevel==2
	/* Secondary school assumed to start after 6 years of primary education */
replace eduyears = eduhighyear + 13 if edulevel==3   
	/*Higher education assumed to start after 13 years of general 
	education (6 years of primary + 7 years of secondary) */
replace eduyears = 0 if edulevel==0 & eduyears==. 
replace eduyears = . if edulevel==. & eduhighyear==. 
	//Replaced as missing value when level of education is missing


*** Checking for further inconsistencies 
replace eduyears = . if age<=eduyears & age>0 
	/*There are cases in which the years of schooling are greater than the 
	age of the individual. This is clearly a mistake in the data.*/
replace eduyears = 0 if age<10 
	/*The variable "eduyears" was replaced with a '0' given that the criteria 
	for this indicator is household member aged 10 years or older */
lab var eduyears "Total number of years of education accomplished"


	/*A control variable is created on whether there is information on 
	years of education for at least 2/3 of the household members aged 10 years 
	and older */	
gen temp = 1 if eduyears!=. & age>=10 & age!=.
bysort	hh_id: egen no_missing_edu = sum(temp)
	/*Total household members who are 10 years and older with no missing 
	years of education */
gen temp2 = 1 if age>=10 & age!=.
bysort hh_id: egen hhs = sum(temp2)
	/*Total number of household members who are 10 years and older */
replace no_missing_edu = no_missing_edu/hhs
replace no_missing_edu = (no_missing_edu>=2/3)
	/*Identify whether there is information on years of education for at 
	least 2/3 of the household members aged 10 years and older */
tab no_missing_edu, miss
label var no_missing_edu "No missing edu for at least 2/3 of the HH members aged 10 years & older"	
drop temp temp2 hhs

*********** Standard MPI *******
/*The entire household is considered deprived if no eligible 
household member has completed SIX years of schooling. */
******************************************************************* 
gen	 years_edu6 = (eduyears>=6) & inrange(age,10,95)
replace years_edu6 = . if eduyears==.
bysort hh_id: egen hh_years_edu6_1 = max(years_edu6)
gen	hh_years_edu6 = (hh_years_edu6_1==1)
replace hh_years_edu6 = . if hh_years_edu6_1==.
replace hh_years_edu6 = . if hh_years_edu6==0 & no_missing_edu==0 
lab var hh_years_edu6 "Household has at least one member with 6 years of edu"
	
*** Destitution MPI ***
/*The entire household is considered deprived if no eligible 
household member has completed at least one year of schooling. */
*******************************************************************
gen	years_edu1 = (eduyears>=1)
replace years_edu1 = . if eduyears==.
bysort	hh_id: egen hh_years_edu_u = max(years_edu1)
replace hh_years_edu_u = . if hh_years_edu_u==0 & no_missing_edu==0
lab var hh_years_edu_u "Household has at least one member with 1 year of edu"



**** Cleaning inconsistencies for national MPI
replace eduhighyear = 0 if age<17
	/*The variable "eduhighyear" was replaced with a '0' given that the criteria 
	for this indicator is household member aged 17 years or older */ 
replace eduhighyear = 0 if edulevel<1

*** Checking for further inconsistencies 
replace eduyears = . if age<=eduyears & age>0 
	/*There are cases in which the years of schooling are greater than the 
	age of the individual. This is clearly a mistake in the data.*/
replace eduyears = 0 if age<17 
	/*The variable "eduyears" was replaced with a '0' given that the criteria 
	for this indicator is household member aged 10 years or older */
lab var eduyears "Total number of years of education accomplished"

	/*A control variable is created on whether there is information on 
	years of education for at least 2/3 of the household members aged 17 years 
	and older */	
gen temp = 1 if eduyears!=. & age>=17 & age!=.
bysort	hh_id: egen no_missing_edu10 = sum(temp)
	/*Total household members who are 17 years and older with no missing 
	years of education */
gen temp2 = 1 if age>=17 & age!=.
bysort hh_id: egen hhs = sum(temp2)
	/*Total number of household members who are 17 years and older */
replace no_missing_edu10 = no_missing_edu/hhs
replace no_missing_edu10 = (no_missing_edu>=2/3)
	/*Identify whether there is information on years of education for at 
	least 2/3 of the household members aged 17 years and older */
tab no_missing_edu10, miss
label var no_missing_edu10 "No missing edu for at least 2/3 of the HH members aged 17 years & older"	
drop temp temp2 hhs

*** National MPI ***
/*The entire household is considered deprived if no eligible 
household member has completed at least 10 year of schooling. */
*******************************************************************
gen	years_edu10 = (eduyears>=10) & inrange(age,17,95)
replace years_edu10 = . if eduyears==.
bysort	hh_id: egen hh_years_edu_10 = max(years_edu10)
replace hh_years_edu_10 = . if hh_years_edu_10==0 & no_missing_edu==0
lab var hh_years_edu_10 "Household has at least one member with 10 year of edu"


********************************************************************************
*** Step 2.2 Child School Attendance ***
********************************************************************************

codebook ed5, tab (10)
gen	attendance = .
replace attendance = 1 if ed5==1 
	//Replace attendance with '1' if currently attending school
replace attendance = 0 if ed5==2 
	//Replace attendance with '0' if currently not attending school
replace attendance = 0 if ed3==2
	//Replace attendance with '0' if never ever attended school		
replace attendance = 0 if age<5 | age>24 
	//Replace attendance with '0' for individuals who are not of school age 		
label define lab_attend 1 "currently attending" 0 "not currently attending"
label values attendance lab_attend
label var attendance "Attended school during current school year"
tab attendance, miss
	
	
*** Standard MPI ***
/*The entire household is considered deprived if any school-aged 
child is not attending school up to class 8. */ 
******************************************************************* 
gen	child_schoolage = (age>=6 & age<=14)
	/*In Cote d'Ivoire, the official school entrance age is 6 years. 
	  So, age range is 6-14 (=6+8). 
	  Source: http://data.uis.unesco.org/?ReportId=163 */

	
	/*A control variable is created on whether there is no information on 
	school attendance for at least 2/3 of the school age children */
count if child_schoolage==1 & attendance==.
	//Understand how many eligible school aged children are not attending school 	
gen temp = 1 if child_schoolage==1 & attendance!=.
bysort hh_id: egen no_missing_atten = sum(temp)	
	/*Total school age children with no missing information on school 
	attendance */
gen temp2 = 1 if child_schoolage==1	
bysort hh_id: egen hhs = sum(temp2)
	//Total number of household members who are of school age
replace no_missing_atten = no_missing_atten/hhs 
replace no_missing_atten = (no_missing_atten>=2/3)
	/*Identify whether there is missing information on school attendance for 
	more than 2/3 of the school age children */		
tab no_missing_atten, miss
label var no_missing_atten "No missing school attendance for at least 2/3 of the school aged children"		
drop temp temp2 hhs
	
	
bysort	hh_id: egen hh_children_schoolage = sum(child_schoolage)
replace hh_children_schoolage = (hh_children_schoolage>0) 
lab var hh_children_schoolage "Household has children in school age"


gen	child_not_atten = (attendance==0) if child_schoolage==1
replace child_not_atten = . if attendance==. & child_schoolage==1
bysort	hh_id: egen any_child_not_atten = max(child_not_atten)
gen	hh_child_atten = (any_child_not_atten==0) 
replace hh_child_atten = . if any_child_not_atten==.
replace hh_child_atten = 1 if hh_children_schoolage==0
replace hh_child_atten = . if hh_child_atten==1 & no_missing_atten==0 
lab var hh_child_atten "Household has all school age children up to class 8 in school"
tab hh_child_atten, miss


*** Destitution MPI ***
/*The entire household is considered deprived if any school-aged 
child is not attending school up to class 6. */ 
******************************************************************* 

gen	child_schoolage_6 = (age>=6 & age<=12) 
	/*In Cote d'Ivoire, the official school entrance age is 6 years.  
	  So, age range for destitution measure is 6-12 (=6+6). */
	
	
	/*A control variable is created on whether there is no information on 
	school attendance for at least 2/3 of the children attending school up to 
	class 6 */	
gen temp = 1 if child_schoolage_6==1 & attendance!=.
bysort hh_id: egen no_missing_atten_u = sum(temp)	
	/*Total school age children attending up to class 6 with no missing 
	information on school attendance */
gen temp2 = 1 if child_schoolage_6==1	
bysort hh_id: egen hhs = sum(temp2)
	/*Total number of household members who are of school age attending up to 
	class 6 */
replace no_missing_atten_u = no_missing_atten_u/hhs 
replace no_missing_atten_u = (no_missing_atten_u>=2/3)
	/*Identify whether there is missing information on school attendance for 
	more than 2/3 of the school age children attending up to class 6 */			
tab no_missing_atten_u, miss
label var no_missing_atten_u "No missing school attendance for at least 2/3 of the school aged children"		
drop temp temp2 hhs		
	
	
bysort	hh_id: egen hh_children_schoolage_6 = sum(child_schoolage_6)
replace hh_children_schoolage_6 = (hh_children_schoolage_6>0) 
lab var hh_children_schoolage_6 "Household has children in school age (6 years of school)"

gen	child_atten_6 = (attendance==1) if child_schoolage_6==1
replace child_atten_6 = . if attendance==. & child_schoolage_6==1
bysort	hh_id: egen any_child_atten_6 = max(child_atten_6)
gen	hh_child_atten_u = (any_child_atten_6==1) 
replace hh_child_atten_u = . if any_child_atten_6==.
replace hh_child_atten_u = 1 if hh_children_schoolage_6==0
replace hh_child_atten_u = . if hh_child_atten_u==0 & no_missing_atten_u==0 
lab var hh_child_atten_u "Household has at least one school age children up to class 6 in school"
tab hh_child_atten_u, miss

*** Standard MPI ***
*same as standard

********************************************************************************
*** Step 2.3 Nutrition ***
********************************************************************************

	/*Nutrition data is available for all women living in half of the 
	households in the sample, as well as for all children under 5. 
	There is  no anthropometric data for men. */
	
	
********************************************************************************
*** Step 2.3a Adult Nutrition ***
********************************************************************************

codebook wan3 wan4, tab(9999)
	//wan3 weight (in kg); wan4 height (in cm)


*** Standard MPI: BMI Indicator for Women 15-49 years ***
******************************************************************* 

gen	f_bmi = wan3/((wan4/100)^2)
	//Low BMI of women 15-49 years	
lab var f_bmi "Women's BMI"

gen	f_low_bmi = (f_bmi<18.5)
replace f_low_bmi = . if f_bmi==. | f_bmi>=99.97
lab var f_low_bmi "BMI of women < 18.5"

bysort hh_id: egen low_bmi = max(f_low_bmi)

gen	hh_no_low_bmi = (low_bmi==0)
	/*Under this section, households take a value of '1' if no women in the 
	household has low bmi */
	
replace hh_no_low_bmi = . if low_bmi==.
	/*Under this section, households take a value of '.' if there is no 
	information from eligible women*/
	
replace hh_no_low_bmi = 1 if no_fem_nutri_eligible==1
	/*Under this section, households that don't have eligible female population 
	is identified as non-deprived in nutrition. */	
	
drop low_bmi
lab var hh_no_low_bmi "Household has no adult with low BMI"

tab hh_no_low_bmi, miss
	/*Figures are exclusively based on information from eligible adult 
	women (15-49 years) */


*** New Standard MPI: BMI-for-age for individuals 15-19 years 
*** and BMI for individuals 20-49 years ***
******************************************************************* 

gen low_bmi_byage = 0
lab var low_bmi_byage "Individuals with low BMI or BMI-for-age"

replace low_bmi_byage = 1 if f_low_bmi==1
	//Replace variable "low_bmi_byage = 1" if eligible women have low BMI

	
	/*Note: The following command replaces BMI with BMI-for-age for those 
	between the age group of 15-19 by their age in months where information is 
	available */
	
replace low_bmi_byage = 1 if low_bmiage==1 & age_month!=.
	//Replace variable "low_bmi_byage = 1" if eligible teenagers have low BMI
replace low_bmi_byage = 0 if low_bmiage==0 & age_month!=.
	/*Replace variable "low_bmi_byage = 0" if teenagers are identified as 
	having low BMI but normal BMI-for-age */ 	

	
	/*Note: The following control variable is applied when there is BMI 
	information for women and BMI-for-age for teenagers. */
replace low_bmi_byage = . if f_low_bmi==. & low_bmiage==.

bysort hh_id: egen low_bmi = max(low_bmi_byage)

gen	hh_no_low_bmiage = (low_bmi==0)
	/*Households take a value of '1' if all eligible adults and teenagers in the 
	household has normal bmi or bmi-for-age */
	
replace hh_no_low_bmiage = . if low_bmi==.
	/*Households take a value of '.' if there is no information from eligible 
	individuals in the household */
	
replace hh_no_low_bmiage = 1 if no_fem_nutri_eligible==1
	//Households take a value of '1' if there is no eligible population. 

drop low_bmi
lab var hh_no_low_bmiage "Household has no adult with low BMI or BMI-for-age"

tab hh_no_low_bmi, miss	
tab hh_no_low_bmiage, miss	

	
*** Destitute MPI: BMI Indicator Women 15-49 years ***
//The BMI threshold applied for destitution is 17 instead of 18.5
******************************************************************* 

gen	f_low_bmi_u = (f_bmi<17)
replace f_low_bmi_u = . if f_bmi==. | f_bmi>=99.97
lab var f_low_bmi_u "BMI of women <17"

bysort hh_id: egen low_bmi = max(f_low_bmi_u)

gen	hh_no_low_bmi_u = (low_bmi==0) 
	/*Under this section, households take a value of '1' if no women in the 
	household has low bmi (destitute cutoff) */

replace hh_no_low_bmi_u = . if low_bmi==.
	/*Under this section, households take a value of '.' if there is no 
	information from eligible women*/

replace hh_no_low_bmi_u = 1 if no_fem_nutri_eligible==1
	/*Under this section, households that don't have eligible female population 
	is identified as non-deprived in nutrition. */
	
drop low_bmi
lab var hh_no_low_bmi_u "Household has no adult with low BMI (<17)"	

tab hh_no_low_bmi_u, miss
	/*Figures are exclusively based on information from eligible women 
	(15-49 years) (destitute cutoff) */


*** New Destitute MPI: BMI-for-age for individuals 15-19 years 
*** and BMI for individuals 20-49 years ***
********************************************************************************

gen low_bmi_byage_u = 0

replace low_bmi_byage_u = 1 if f_low_bmi_u==1
	/*Replace variable "low_bmi_byage_u = 1" if eligible women have low 
	BMI (destitute cutoff)*/
	
	
	/*Note: The following command replaces BMI with BMI-for-age for those 
	between the age group of 15-19 by their age in months where information is 
	available */
	
replace low_bmi_byage_u = 1 if low_bmiage_u==1 & age_month!=.
	/*Replace variable "low_bmi_byage_u = 1" if eligible teenagers have low 
	BMI (destitute cutoff) */
replace low_bmi_byage_u = 0 if low_bmiage_u==0 & age_month!=.
	/*Replace variable "low_bmi_byage_u = 0" if teenagers are identified as 
	having low BMI but normal BMI-for-age (destitute cutoff) */  	

	
	/*Note: The following control variable is applied when there is BMI 
	information for women and BMI-for-age for teenagers. */	
replace low_bmi_byage_u = . if f_low_bmi_u==. & low_bmiage_u==.
	
bysort hh_id: egen low_bmi = max(low_bmi_byage_u)

gen	hh_no_low_bmiage_u = (low_bmi==0)
	/*Households take a value of '1' if all eligible adults and teenagers in the 
	household has normal bmi or bmi-for-age (destitute cutoff) */

replace hh_no_low_bmiage_u = . if low_bmi==.
	/*Households take a value of '.' if there is no information from eligible 
	individuals in the household */

replace hh_no_low_bmiage_u = 1 if no_fem_nutri_eligible==1
	//Households take a value of '1' if there is no eligible population.

drop low_bmi
lab var hh_no_low_bmiage_u "Household has no adult with low BMI or BMI-for-age(<17/-3sd)"

tab hh_no_low_bmi_u, miss
tab hh_no_low_bmiage_u, miss	


********************************************************************************
*** Step 2.3b Child Nutrition ***
********************************************************************************

*** Child Underweight Indicator ***
************************************************************************

*** Standard MPI ***
bysort hh_id: egen temp = max(underweight)
gen	hh_no_underweight = (temp==0) 
	//Takes value 1 if no child in the hh is underweight 
replace hh_no_underweight = . if temp==.
replace hh_no_underweight = 1 if no_child_eligible==1 
	//Households with no eligible children will receive a value of 1
lab var hh_no_underweight "Household has no child underweight - 2 stdev"
drop temp


*** Destitution MPI  ***
bysort hh_id: egen temp = max(underweight_u)
gen	hh_no_underweight_u = (temp==0) 
replace hh_no_underweight_u = . if temp==.
replace hh_no_underweight_u = 1 if no_child_eligible==1 
lab var hh_no_underweight_u "Destitute: Household has no child underweight"
drop temp


*** Child Stunting Indicator ***
************************************************************************

*** Standard MPI ***
bysort hh_id: egen temp = max(stunting)
gen	hh_no_stunting = (temp==0) 
	//Takes value 1 if no child in the hh is stunted
replace hh_no_stunting = . if temp==.
replace hh_no_stunting = 1 if no_child_eligible==1 
	//Households with no eligible children will receive a value of 1
lab var hh_no_stunting "Household has no child stunted - 2 stdev"
drop temp


*** Destitution MPI  ***
bysort hh_id: egen temp = max(stunting_u)
gen	hh_no_stunting_u = (temp==0) 
replace hh_no_stunting_u = . if temp==.
replace hh_no_stunting_u = 1 if no_child_eligible==1 
lab var hh_no_stunting_u "Destitute: Household has no child stunted"
drop temp


*** Child Wasting Indicator ***
************************************************************************

*** Standard MPI ***
bysort hh_id: egen temp = max(wasting)
gen	hh_no_wasting = (temp==0) 
	//Takes value 1 if no child in the hh is wasted
replace hh_no_wasting = . if temp==.
replace hh_no_wasting = 1 if no_child_eligible==1 
	//Households with no eligible children will receive a value of 1
lab var hh_no_wasting "Household has no child wasted - 2 stdev"
drop temp


*** Destitution MPI  ***
bysort hh_id: egen temp = max(wasting_u)
gen	hh_no_wasting_u = (temp==0) 
replace hh_no_wasting_u = . if temp==.
replace hh_no_wasting_u = 1 if no_child_eligible==1 
lab var hh_no_wasting_u "Destitute: Household has no child wasted"
drop temp


*** Child Either Underweight or Stunted Indicator ***
************************************************************************

*** Standard MPI ***
gen uw_st = 1 if stunting==1 | underweight==1
replace uw_st = 0 if stunting==0 & underweight==0
replace uw_st = . if stunting==. & underweight==.

bysort hh_id: egen temp = max(uw_st)
gen	hh_no_uw_st = (temp==0) 
	//Takes value 1 if no child in the hh is underweight or stunted
replace hh_no_uw_st = . if temp==.
replace hh_no_uw_st = 1 if no_child_eligible==1
	//Households with no eligible children will receive a value of 1 
lab var hh_no_uw_st "Household has no child underweight or stunted"
drop temp


*** Destitution MPI  ***
gen uw_st_u = 1 if stunting_u==1 | underweight_u==1
replace uw_st_u = 0 if stunting_u==0 & underweight_u==0
replace uw_st_u = . if stunting_u==. & underweight_u==.

bysort hh_id: egen temp = max(uw_st_u)
gen	hh_no_uw_st_u = (temp==0) 
	//Takes value 1 if no child in the hh is underweight or stunted
replace hh_no_uw_st_u = . if temp==.
replace hh_no_uw_st_u = 1 if no_child_eligible==1 
	//Households with no eligible children will receive a value of 1 
lab var hh_no_uw_st_u "Destitute: Household has no child underweight or stunted"
drop temp


********************************************************************************
*** Step 2.3c Household Nutrition Indicator ***
********************************************************************************

*** Standard MPI ***
/* Members of the household are considered deprived if the household 
has a child under 5 whose height-for-age or weight-for-age is under 
two standard deviation below the median, or has teenager with 
BMI-for-age that is under two standard deviation below the median, 
or has adults with BMI threshold that is below 18.5 kg/m2.*/
************************************************************************
gen	hh_nutrition_uw_st = 1
replace hh_nutrition_uw_st = 0 if hh_no_low_bmiage==0 | hh_no_uw_st==0
replace hh_nutrition_uw_st = . if hh_no_low_bmiage==. & hh_no_uw_st==.
replace hh_nutrition_uw_st = 1 if no_child_fem_eligible==1   
lab var hh_nutrition_uw_st "Household has no child underweight/stunted or adult deprived by BMI/BMI-for-age"



*** Destitution MPI ***
/* Members of the household are considered deprived if the household 
has a child under 5 whose height-for-age or weight-for-age is under 
three standard deviation below the median, or has teenager with 
BMI-for-age that is under three standard deviation below the median, 
or has adults with BMI threshold that is below 17.0 kg/m2.*/
************************************************************************
gen	hh_nutrition_uw_st_u = 1
replace hh_nutrition_uw_st_u = 0 if hh_no_low_bmiage_u==0 | hh_no_uw_st_u==0
replace hh_nutrition_uw_st_u = . if hh_no_low_bmiage_u==. & hh_no_uw_st_u==.
replace hh_nutrition_uw_st_u = 1 if no_child_fem_eligible==1   
lab var hh_nutrition_uw_st_u "Household has no child underweight/stunted or adult deprived by BMI/BMI-for-age (destitute)"


********************************************************************************
*** Step 2.4 Child Mortality ***
********************************************************************************

codebook cm9a cm9b
	  
egen temp_f = rowtotal(cm9a cm9b), missing
	//Total child mortality reported by eligible women
replace temp_f = 0 if cm1==1 & cm8==2 | cm1==2 
	/*Assign a value of "0" for:
	- all eligible women who have ever gave birth but reported no child death 
	- all eligible women who never ever gave birth */
replace temp_f = 0 if no_fem_eligible==1	
	/*Assign a value of "0" for:
	- individuals living in households that have non-eligible women */
bysort	hh_id: egen child_mortality_f = sum(temp_f), missing
lab var child_mortality_f "Occurrence of child mortality reported by women"
tab child_mortality_f, miss
drop temp_f
	

	/* In the case of Cote D'Ivoire, this variable takes missing value because 
	the survey did not collect information on child mortality from men */	
gen child_mortality_m = .
lab var child_mortality_m "Occurrence of child mortality reported by men"
tab child_mortality_m, miss

egen child_mortality = rowmax(child_mortality_f)
lab var child_mortality "Total child mortality within household reported by women & men"
tab child_mortality, miss

	
*** Standard MPI *** 
/* The standard MPI indicator takes a value of "0" if 
women in the household reported mortality among children
under 18 in the last 5 years from the survey year.*/
************************************************************************

tab childu18_died_per_wom_5y, miss
		
replace childu18_died_per_wom_5y = 0 if cm1==2 															   
	/*Assign a value of "0" for:
	- all eligible women who never ever gave birth */
replace childu18_died_per_wom_5y = 0 if no_fem_eligible==1	
	/*Assign a value of "0" for:
	- individuals living in households that have non-eligible women */
	
bysort hh_id: egen childu18_mortality_5y = sum(childu18_died_per_wom_5y), missing
replace childu18_mortality_5y = 0 if childu18_mortality_5y==. & child_mortality==0
	/*Replace all households as 0 death if women has missing value and men 
	reported no death in those households */
label var childu18_mortality_5y "Under 18 child mortality within household past 5 years reported by women"
tab childu18_mortality_5y, miss		
	
gen hh_mortality_u18_5y = (childu18_mortality_5y==0)
replace hh_mortality_u18_5y = . if childu18_mortality_5y==.
lab var hh_mortality_u18_5y "Household had no under 18 child mortality in the last 5 years"
tab hh_mortality_u18_5y, miss 


*** Destitution MPI *** 
*** (same as standard MPI) ***
************************************************************************
clonevar hh_mortality_u = hh_mortality_u18_5y	


*** INPM MPI *** 
/* The national MPI indicator takes a value of "0" if 
women in the household reported mortality among children
under 18 in the last 1 year from the survey year.*/
************************************************************************

bysort hh_id: egen childu18_mortality_1y = sum(childu18_died_per_wom_1y), missing
replace childu18_mortality_1y = 0 if childu18_mortality_1y==. & child_mortality==0
	/*Replace all households as 0 death if women has missing value and men 
	reported no death in those households */
label var childu18_mortality_1y "Under 18 child mortality within household past 1 year reported by women"
tab childu18_mortality_1y, miss		
	
gen hh_mortality_u18_1y = (childu18_mortality_1y==0)
replace hh_mortality_u18_1y = . if childu18_mortality_1y==.
lab var hh_mortality_u18_1y "Household had no under 18 child mortality in the last 1 year"
tab hh_mortality_u18_1y, miss 



********************************************************************************
*** Step 2.5 Electricity ***
********************************************************************************


*** Standard MPI ***
/*Members of the household are considered 
deprived if the household has no electricity */
***************************************************
clonevar electricity = hc8a 
codebook electricity, tab (10)
replace electricity = 0 if electricity==2 
replace electricity = . if electricity==9 
label var electricity "Household has electricity"


*** Destitution MPI  ***
*** (same as standard MPI) ***
***************************************************
gen electricity_u = electricity
label var electricity_u "Household has electricity"


********************************************************************************
*** Step 2.6 Sanitation ***
********************************************************************************

/*
Improved sanitation facilities include flush or pour flush toilets to sewer 
systems, septic tanks or pit latrines, ventilated improved pit latrines, pit 
latrines with a slab, and composting toilets. These facilities are only 
considered improved if it is private, that is, it is not shared with other 
households.
Source: https://unstats.un.org/sdgs/metadata/files/Metadata-06-02-01.pdf

Note: In cases of mismatch between the country report and the internationally 
agreed guideline, we followed the report.
*/


clonevar toilet = ws8  
codebook toilet, tab(99) 

codebook ws9, tab(30)  
clonevar shared_toilet = ws9 
recode shared_toilet (2=0) (9=.)
tab ws9 shared_toilet, miss nol
	//0=no;1=yes;.=missing
	

	
*** Standard MPI ***
/*Members of the household are considered deprived if the household's 
sanitation facility is not improved (according to the SDG guideline) 
or it is improved but shared with other households*/
********************************************************************

gen	toilet_mdg     = (toilet<23 | toilet==31) & shared_toilet!=1	
replace toilet_mdg = 0 if toilet==14 
replace toilet_mdg = 0 if (toilet<23 | toilet==31) & shared_toilet==1 	
replace toilet_mdg = . if toilet==.  | toilet==99
lab var toilet_mdg "Household has improved sanitation with MDG Standards"
tab toilet toilet_mdg, miss

	
*** Destitution MPI ***
/*Members of the household are considered deprived if household practises 
open defecation or uses other unidentifiable sanitation practises */
********************************************************************
gen	toilet_u = .
replace toilet_u = 0 if toilet==95 | toilet==96 
replace toilet_u = 1 if toilet!=95 & toilet!=96 & toilet!=. & toilet!=99
lab var toilet_u "Household does not practise open defecation or others"
tab toilet toilet_u, miss

*** Standard MPI ***
gen	toilet_mdg_1    = .
replace toilet_mdg_1 = 0 if (toilet<23 | toilet==31)  
replace toilet_mdg_1 = 1 if toilet==14 
replace toilet_mdg_1 = 1 if !(toilet<23 | toilet==31) 
replace toilet_mdg_1 = . if toilet==. | toilet==99	
lab var toilet_mdg_1 "Household has improved sanitation"
tab toilet toilet_mdg_1, miss

********************************************************************************
*** Step 2.7 Drinking Water  ***
********************************************************************************
/*
Improved drinking water sources include the following: piped water into 
dwelling, yard or plot; public taps or standpipes; boreholes or tubewells; 
protected dug wells; protected springs; packaged water; delivered water and 
rainwater which is located on premises or is less than a 30-minute walk from 
home roundtrip. 
Source: https://unstats.un.org/sdgs/metadata/files/Metadata-06-01-01.pdf

Note: In cases of mismatch between the country report and the internationally 
agreed guideline, we followed the report.
*/

clonevar water = ws1  
clonevar timetowater = ws4  
codebook water, tab(99)	
clonevar ndwater = ws2  
	
*** Standard MPI ***
/* Members of the household are considered deprived if the household 
does not have access to improved drinking water (according to the SDG 
guideline) or safe drinking water is at least a 30-minute walk from 
home, roundtrip */
********************************************************************

gen	water_mdg = 1 if water==11 | water==12 | water==13 | water==14 | ///
					 water==31 | water==41 | water==51 | water==91 | ///
					 water==21 
	
replace water_mdg = 0 if water==32 | water==42 | water==71 | ///
						 water==81 | water==92 | water==96 | water==61
	
replace water_mdg = 0 if water_mdg==1 & timetowater>=30 & timetowater!=. & ///
						 timetowater!=998 & timetowater!=999
 
replace water_mdg = . if water==. | water==99
replace water_mdg = 0 if water==91 & ///
						(ndwater==32 | ndwater==42 | ndwater==71 | ///
						 ndwater==81 | ndwater==96 | ndwater==61 | ndwater==92) 

lab var water_mdg "Household has drinking water with MDG standards (considering distance)"
tab water water_mdg, miss


*** Destitution MPI ***
/* Members of the household is identified as destitute if household 
does not have access to safe drinking water, or safe water is more 
than 45 minute walk from home, round trip.*/
********************************************************************
gen	water_u = .
replace water_u = 1 if water==11 | water==12 | water==13 | water==14 | ///
					   water==31 | water==41 | water==51 | water==91 | ///
					   water==21 
replace water_u = 0 if water==32 | water==42 | water==71 | ///
					   water==81 | water==92 | water==96 | water==61

replace water_u = 0 if water_u==1 & timetowater>45 & timetowater!=. & ///
					   timetowater!=998 & timetowater!=999				   
replace water_u = . if water==99 | water==.


replace water_u = 0 if water==91 & ///
						(ndwater==32 | ndwater==42 | ndwater==71 | ///
						 ndwater==81 | ndwater==96 | ndwater==61 | ndwater==92) 
lab var water_u "Household has drinking water with MDG standards (45 minutes distance)"
tab water water_u, miss


*** Harmonised MPI ***
//Bottled water improved.
********************************************************************

gen	water_mdg_c     = 1 if water==11 | water==12 | water==13 | water==14 | ///
					       water==31 | water==41 | water==51 | water==91 | ///
					       water==21 	
replace water_mdg_c = 0 if water==32 | water==42 | water==71 | ///
						   water==81 | water==92 | water==96 | water==61

	
replace water_mdg_c = 0 if water_mdg_c==1 & timetowater>=30 & timetowater!=. & ///
						   timetowater!=998 & timetowater!=999

replace water_mdg_c = . if water==. | water==99
lab var water_mdg_c "HOT:HH has safe drinking water"
tab water water_mdg_c, miss



gen	water_u_c = .

replace water_u_c = 1 if water==11 | water==12 | water==13 | water==14 | ///
					     water==31 | water==41 | water==51 | water==91 | ///
					     water==21 
replace water_u_c = 0 if water==32 | water==42 | water==71 | ///
					     water==81 | water==92 | water==96 | water==61

replace water_u_c = 0 if  water_u==1 & timetowater>45 & timetowater!=. ///
						  & timetowater!=998 & timetowater!=999	
						  
replace water_u_c = . if water==99 | water==. 
lab var water_u_c "DST-HOT: HH has safe drinking water"
tab water water_u_c, miss



*** National MPI ***
g water_mdgN=.

replace water_mdgN = 1 if water==11 | water==12 | water==13 | water==14 | ///
					    water==41 | water==51 | water==91 | ///
					   water==21 | water==31 
replace water_mdgN = 0 if water==32 | water==42 | water==71 | ///
					   water==81 | water==92 | water==96 | water==61 
 
replace water_mdgN = . if water==. | water==99 
replace water_mdgN = 0 if water==91 & ///
						(ndwater==32 | ndwater==42 | ndwater==71 | ///
						 ndwater==81 | ndwater==96 | ndwater==61 | ndwater==92) 

lab var water_mdgN "Household has safe drinking water"
tab water water_mdgN, miss



********************************************************************************
*** Step 2.8 Housing ***
********************************************************************************

/* Members of the household are considered deprived if the household 
has a dirt, sand or dung floor */
clonevar floor = hc3
codebook floor, tab(99)
gen	floor_imp = 1
replace floor_imp = 0 if floor==11 | floor==12 | floor==96 	
replace floor_imp = . if floor==.	
lab var floor_imp "Household has floor that it is not earth/sand/dung"
tab floor floor_imp, miss	


/* Members of the household are considered deprived if the household has wall 
made of natural or rudimentary materials */
clonevar wall = hc5
codebook wall, tab(99)
gen	wall_imp = 1 
replace wall_imp = 0 if wall<=26 | wall==96 
replace wall_imp = . if wall==. 
lab var wall_imp "Household has wall that it is not of low quality materials"
tab wall wall_imp, miss	
	

	
/* Members of the household are considered deprived if the household has roof 
made of natural or rudimentary materials */
clonevar roof = hc4
codebook roof, tab(99)	
gen	roof_imp = 1 
replace roof_imp = 0 if roof<=24 | roof==96	
replace roof_imp = . if roof==. 
lab var roof_imp "Household has roof that it is not of low quality materials"
tab roof roof_imp, miss


*** Standard MPI ***
/* Members of the household is deprived in housing if the roof, 
floor OR walls are constructed from low quality materials.*/
**************************************************************
gen housing_1 = 1
replace housing_1 = 0 if floor_imp==0 | wall_imp==0 | roof_imp==0
replace housing_1 = . if floor_imp==. & wall_imp==. & roof_imp==.
lab var housing_1 "Household has roof, floor & walls that it is not low quality material"
tab housing_1, miss


*** Destitution MPI ***
/* Members of the household is deprived in housing if two out 
of three components (roof and walls; OR floor and walls; OR 
roof and floor) the are constructed from low quality materials. */
**************************************************************
gen housing_u = 1
replace housing_u = 0 if (floor_imp==0 & wall_imp==0 & roof_imp==1) | ///
						 (floor_imp==0 & wall_imp==1 & roof_imp==0) | ///
						 (floor_imp==1 & wall_imp==0 & roof_imp==0) | ///
						 (floor_imp==0 & wall_imp==0 & roof_imp==0)
replace housing_u = . if floor_imp==. & wall_imp==. & roof_imp==.
lab var housing_u "Household has one of three aspects(either roof,floor/walls) that is not low quality material"
tab housing_u, miss

***National: same as standard.


********************************************************************************
*** Step 2.9 Cooking Fuel ***
********************************************************************************

/*
Solid fuel are solid materials burned as fuels, which includes coal as well as 
solid biomass fuels (wood, animal dung, crop wastes and charcoal). 

Source: 
https://apps.who.int/iris/bitstream/handle/10665/141496/9789241548885_eng.pdf
*/

clonevar cookingfuel = hc6  


*** Standard MPI ***
/* Members of the household are considered deprived if the 
household uses solid fuels and solid biomass fuels for cooking. */
*****************************************************************
codebook cookingfuel, tab(99)


gen	cooking_mdg = 1
replace cooking_mdg = 0 if cookingfuel>5 & cookingfuel<95 
replace cooking_mdg = . if cookingfuel==. | cookingfuel==99
lab var cooking_mdg "Household has cooking fuel according to MDG standards"			 
tab cookingfuel cooking_mdg, miss	


*** Destitution MPI ***
*** (same as standard MPI) ***
****************************************
gen	cooking_u = cooking_mdg
lab var cooking_u "Household uses clean fuels for cooking"



********************************************************************************
*** Step 2.10 Assets ownership ***
********************************************************************************


codebook hc8c hc8b hc8d hc9b hc8e hc9c hc11

clonevar television = hc8c
gen bw_television   = .
clonevar radio = hc8b 

clonevar telephone =  hc8d
clonevar mobiletelephone = hc9b 
replace mobiletelephone = 1 if hc9n==1
	//hc9n = smartphone

clonevar refrigerator = hc8e
clonevar car = hc9f  	
clonevar bicycle = hc9c
clonevar motorbike = hc9d

clonevar computer = hc9l
replace computer = 1 if hc9m==1
	//hc9m = tablet

clonevar ventilator=hc8g

clonevar aircond=hc8h
replace  aircond=1 if hc8h==1
// 

clonevar animal_cart = hc9e

clonevar internet=hc8k

foreach var in television radio telephone mobiletelephone refrigerator ///
			   car bicycle motorbike computer animal_cart aircond internet ventilator  {
replace `var' = 0 if `var'==2 
	//Please ensure that 0=no; 1=yes
replace `var' = . if `var'==9 | `var'==99 | `var'==8 | `var'==98 
}
	//9 , 99 and 8, 98 are missing
	


	//Combine telephone and mobilephone 
replace telephone=1 if telephone==0 & mobiletelephone==1
replace telephone=1 if telephone==. & mobiletelephone==1


	//Label indicators
lab var television "Household has television"
lab var radio "Household has radio"	
lab var telephone "Household has telephone (landline/mobilephone)"	
lab var refrigerator "Household has refrigerator"
lab var car "Household has car"
lab var bicycle "Household has bicycle"	
lab var motorbike "Household has motorbike"
lab var computer "Household has computer"
lab var animal_cart "Household has animal cart"
lab var internet "Household has internet"
lab var aircond "Household has air conditioner"
lab var ventilator "Household has ventilator"


*** Standard MPI ***
/* Members of the household are considered deprived in assets if the household 
does not own more than one of: radio, TV, telephone, bike, motorbike, 
refrigerator, computer or animal cart and does not own a car or truck.*/
*****************************************************************************
egen n_small_assets2 = rowtotal(television radio telephone refrigerator bicycle motorbike computer animal_cart), missing
lab var n_small_assets2 "Household Number of Small Assets Owned" 
   
gen hh_assets2 = (car==1 | n_small_assets2 > 1) 
replace hh_assets2 = . if car==. & n_small_assets2==.
lab var hh_assets2 "Household Asset Ownership: HH has car or more than 1 small assets incl computer & animal cart"


*** Destitution MPI ***
/* Members of the household are considered deprived in assets if the household 
does not own any assets.*/
*****************************************************************************	
gen	hh_assets2_u = (car==1 | n_small_assets2>0)
replace hh_assets2_u = . if car==. & n_small_assets2==.
lab var hh_assets2_u "Household Asset Ownership: HH has car or at least 1 small assets incl computer & animal cart"


********************************************************************************
*** Step 2.10 Identification***
********************************************************************************
/* The household is deprived if  a child whose age is between 5 and 17 does not have a birth certificate,
 supplementary judgment or is not declared */
codebook hl15a  
replace hl15a=0 if hl15a==. & !(age>17)
gen Identification = !inlist(hl15a, 1,2,3) & (hl6>=5 & hl6<=15)
by hh_id , sort : egen Ident = max(Identification)
*replace Ident=. if hl15a==.
lab var Ident "Household has a child who has no a birth certificate, jugment or is not declared"
drop Identification

save "$sortie\base_travail_mics2016.dta", replace
********************************************************************************

*** Step 2.11 Employment & Literacy***
********************************************************************************
import spss using "$data\mn.sav", clear 
rename _all, lower
ta mls7, m
ta mls7 if inrange(mls5, 15, 24) , m
codebook mls5
ta mls7 if mls5!=1, m
codebook mls5
gen dpH = mls7 == 0

ta mwb7, m
codebook mwb7
ta mwb7 if mwb2>=17,m
tab mwb2 mwb7 if mwb2>=17
gen double ind_id = hh1 *100000 + hh2 *100 + ln
keep hh1 hh2 ln  mls5 dpH mwb7 mwb2 mwb4 mls7 mls5 
gen literacy= 1 if (mwb7==3|mwb4==2|mwb4==3) & (mwb2>=17 & mwb2 <= 49)
replace literacy=0 if !(mwb7==3|mwb4==2|mwb4==3) & (mwb2>=17 & mwb2 <= 49)
bysort hh1 hh2: egen lit= max(literacy) 
recode lit (0=1)(1=0), gen(d_lit)
gen double ind_id = hh1 *100000 + hh2 *100 + ln


save "$sortie\MN.dta", replace

import spss using "$data\wm.sav", clear
rename _all, lower
gen dpH = ls7 == 0
codebook wb7
ta wb7 if wb2>=17,m

keep hh1 hh2 ln ls5 dpH wb7 wb2 wb4 ls7 ls5
ren wb7 mwb7
ren wb2 mwb2
ren ls5 mls5
ren wb4 mwb4
ren ls7 mls7

// Literacy
/* The member is considered literate if he has a secondary or higher level, if he can read entirely a sentence */

gen literacy= 1 if (mwb7==3|mwb4==2|mwb4==3) & (mwb2>=17 & mwb2 <= 49)
replace literacy=0 if !(mwb7==3|mwb4==2|mwb4==3) & (mwb2>=17 & mwb2 <= 49)
bysort hh1 hh2: egen lit= max(literacy) 
recode lit (0=1)(1=0), gen(d_lit)

gen double ind_id = hh1 *100000 + hh2 *100 + ln
lab var d_lit "A household member aged 17 or over does not know how to read (French); 1=yes, 0=no"
append using "$sortie\MN.dta"

gen cas= inrange(mwb2, 15, 24) & mls5!=1
by hh1 hh2, sort : egen touse = max(cas)
drop cas
gen cas = dpH & inrange(mwb2,15,24) & mls5 !=1
by hh1 hh2, sort : egen tunemp = max(cas)
compare tunemp touse
gen d_unemp = tunemp==touse & tunemp!=0
sum d_unemp
drop touse cas tunemp dpH
sort hh1 hh2 ln


save "$sortie/employment&Literacy.dta", replace


*** Merging
use "$sortie\base_travail_mics2016.dta"
merge 1:1 ind_id using "$sortie\employment&Literacy.dta"
drop _merge
replace d_unemp=0 if d_unemp==.
save "$sortie\base_travail_mics2016.dta", replace


********************************************************************************
*** Step 2.11 Rename and keep variables for MPI calculation 
********************************************************************************
	
	/*Retain data on sampling design:
	According to the MICS survey methodology, each of the 11 regions is 
	subdivided into two strata (urban stratum and rural stratum). Only the 
	city of Abidjan has a stratum (urban stratum). Thus, 21 strata were formed.
	Some 25 households were clustered in each strata, leading to a total of 512 
	clusters being formed. */	
gen psu = hh1
rename stratum strata
label var psu "Primary sampling unit"
label var strata "Sample strata"


	//Retain year, month & date of interview:
desc hh5y hh5m hh5d 
clonevar year_interview = hh5y 	
clonevar month_interview = hh5m 
clonevar date_interview = hh5d 
 

*** Rename key global MPI indicators for estimation ***
recode hh_mortality_u18_5y  (0=1)(1=0) , gen(d_cm)
recode hh_mortality_u18_1y  (0=1)(1=0) , gen(d_cm1)
recode hh_nutrition_uw_st 	(0=1)(1=0) , gen(d_nutr)
recode hh_child_atten 		(0=1)(1=0) , gen(d_satt)
recode hh_years_edu6 		(0=1)(1=0) , gen(d_educ)
recode hh_years_edu_10      (0=1)(1=0) , gen(d_educ10)
recode electricity 			(0=1)(1=0) , gen(d_elct)
recode water_mdg 			(0=1)(1=0) , gen(d_wtr)
recode water_mdgN 			(0=1)(1=0) , gen(d_wtrN)
recode toilet_mdg 			(0=1)(1=0) , gen(d_sani)
recode housing_1 			(0=1)(1=0) , gen(d_hsg)
recode cooking_mdg 			(0=1)(1=0) , gen(d_ckfl)
recode hh_assets2 			(0=1)(1=0) , gen(d_asst)
recode toilet_mdg_1         (0=1)(1=0) , gen(d_sani_1)
*** Generate coutry and survey details for estimation ***
char _dta[cty] "Côte d'Ivoire"
char _dta[ccty] "CIV"
char _dta[year] "2016" 	
char _dta[survey] "MICS"
char _dta[ccnum] "384"
char _dta[type] "micro"
char _dta[class] "old_survey"


*** Sort, compress and save data for estimation ***
sort ind_id
compress
la da "Micro data for `_dta[ccty]' (`_dta[ccnum]') from `c(current_date)' (`c(current_time)')."
save "$sortie\base_travail_mics2016.dta", replace 


// some statistics before MPI

// Number of deprivation according to Cote d'Ivoire threshold
svyset psu[pweight=weight], strata(strata)
svy:mean d_satt             
svy:mean d_educ1
svy:mean d_elct
svy:mean d_ckfl
svy:mean d_sani_1
svy:mean d_hsg
svy:mean d_asst
svy:mean d_cm1
svy:mean d_nutr
svy:mean d_wtrN
svy:mean d_lit
svy:mean d_unemp
svy:mean Ident

egen NBmis0 = rowmiss(d_satt d_educ1 d_elct  d_ckfl d_sani d_hsg d_asst )
replace NBmis0 = 1 if NBmis !=0
recode NBmis0 (0=1) (1=0)
rename NBmis0 touse0
lab var touse0 "Household without missing value for MPI indicators- PNUD"
egen nbdepr0 = rowtotal( d_satt d_educ1  d_elct  d_ckfl  d_sani d_hsg d_asst  )
lab var nbdepr0 "Number of deprivation PNUD"

egen NBmis1 = rowmiss(d_satt d_educ1 d_elct d_wtr1 d_ckfl d_sani d_hsg d_asst d_cm1 d_nutr)
replace NBmis1 = 1 if NBmis !=0
recode NBmis1 (0=1) (1=0)
rename NBmis1 touse1
lab var touse1 "Household without missing value for MPI indicators- PNUD"
egen nbdeprP = rowtotal( d_satt d_educ1  d_elct d_wtr1 d_ckfl  d_sani d_hsg d_asst d_cm1 d_nutr )
lab var nbdeprP "Number of deprivation PNUD"

egen NBmis2 = rowmiss(d_satt d_educ1 d_elct d_wtr1 d_ckfl d_sani d_hsg d_asst d_cm1 d_nutr d_unemp)
replace NBmis2 = 1 if NBmis !=0
recode NBmis2 (0=1) (1=0)
rename NBmis2 touse2
lab var touse2 "Household without missing value for MPI indicators - REFERENCE "
egen nbdeprR = rowtotal(d_satt d_educ1 d_elct d_wtr1 d_ckfl d_sani d_hsg d_asst d_cm1 d_nutr d_unemp)
lab var nbdeprR "Number of deprivation Reference"

egen NBmis3 = rowmiss(d_satt d_educ1 d_lit d_elct d_wtrN d_ckfl d_sani_1 d_hsg d_asst d_cm1 d_unemp Ident)
replace NBmis3 = 1 if NBmis !=0
recode NBmis3 (0=1) (1=0)
rename NBmis3 touse3
egen nbdeprN = rowtotal(d_satt d_educ1 d_lit d_elct d_wtrN d_ckfl d_sani_1 d_hsg d_asst d_cm1 d_unemp Ident)
lab var nbdeprN "Number of deprivation Nat"

svy:mean nbdepr0  if touse0
svy:mean nbdeprP if touse1 
svy:mean nbdeprR if touse2 
svy:mean nbdeprN if touse3

drop nbdepr0 touse0 nbdeprP touse1  nbdeprR touse2  nbdeprN touse3

// Number of deprivation according to PNUD threshold
svyset  psu[pweight=weight], strata(strata)
svy:mean d_satt             
svy:mean d_educ
svy:mean d_elct
svy:mean d_ckfl
svy:mean d_sani
svy:mean d_hsg
svy:mean d_asst
svy:mean d_cm
svy:mean d_nutr
svy:mean d_wtr
svy:mean d_lit

egen NBmis0 = rowmiss(d_satt d_educ d_elct  d_ckfl d_sani d_hsg d_asst)
replace NBmis0 = 1 if NBmis !=0
recode NBmis0 (0=1) (1=0)
rename NBmis0 touse0
lab var touse0 "Household without missing value for MPI indicators- PNUD"
egen nbdepr0 = rowtotal( d_satt d_educ1  d_elct  d_ckfl  d_sani d_hsg d_asst  d_nutr )
lab var nbdepr0 "Number of deprivation PNUD"

egen NBmis1 = rowmiss(d_satt d_educ d_elct d_wtr d_ckfl d_sani d_hsg d_asst d_cm d_nutr)
replace NBmis1 = 1 if NBmis !=0
recode NBmis1 (0=1) (1=0)
rename NBmis1 touse1
lab var touse1 "Household without missing value for MPI indicators- PNUD"
egen nbdeprP = rowtotal( d_satt d_educ  d_elct d_wtr d_ckfl  d_sani d_hsg d_asst d_cm d_nutr )
lab var nbdeprP "Number of deprivation PNUD"

egen NBmis2 = rowmiss(d_satt d_educ d_lit d_elct d_wtr d_ckfl d_sani d_hsg d_asst d_cm d_nutr d_unemp)
replace NBmis2 = 1 if NBmis !=0
recode NBmis2 (0=1) (1=0)
rename NBmis2 touse2
lab var touse2 "Household without missing value for MPI indicators - REFERENCE"
egen nbdeprR = rowtotal(d_satt d_educ d_lit d_elct d_wtr d_ckfl d_sani d_hsg d_asst d_cm d_nutr d_unemp)
lab var nbdeprR "Number of deprivation Reference"

egen NBmis3 = rowmiss(d_satt d_educ d_lit d_elct d_wtr d_ckfl d_sani d_hsg d_asst d_cm d_nutr d_unemp Ident  )
replace NBmis3 = 1 if NBmis !=0
recode NBmis3 (0=1) (1=0)
rename NBmis3 touse3
egen nbdeprN = rowtotal(d_satt d_educ d_lit d_elct d_wtr d_ckfl d_sani d_hsg d_asst d_cm d_nutr d_unemp Ident)
lab var nbdeprN "Number of deprivation Nat"

svy:mean nbdepr0  if touse0
svy:mean nbdeprP if touse1 
svy:mean nbdeprR if touse2 
svy:mean nbdeprN if touse3

*********************************************************  MPI BY REGION  ********************************************************************************

// PNUD SEUIL NATIONAL (comporte les indicateurs du PNUD sans nutrition mortalité Eau potable)
mpi d1(d_satt d_educ1) w1(0.25 0.25) d2(d_elct d_sani  d_hsg d_ckfl d_asst) w2(0.1 0.1 0.1 0.1 0.1) [pw=weight]  ,cutoff(0.3333) by (region) 

// PNUD SEUIL PNUD (comporte les indicateurs du PNUD sans nutrition mortalité Eau potable)
mpi d1(d_satt d_educ) w1(0.25 0.25) d2(d_elct d_sani  d_hsg d_ckfl d_asst) w2(0.1 0.1 0.1 0.1 0.1) [pw=weight]  ,cutoff(0.3333) by (region) 


// PNUD_SEUIL NATIONAL (comporte les indicateurs standards du PNUD)
mpi d1(d_satt d_educ1) w1(0.1666 0.1666) d2(d_cm1 d_nutr) w2(0.1666 0.1666) d3(d_elct d_wtrN d_sani  d_hsg d_ckfl d_asst) w3(0.056 0.0556  0.0556 0.0556  0.0556  0.0556)  [pweight= weight] ,cutoff(0.3333) by (region) 

// PNUD_SEUIL PNUD (comporte les indicateurs standards du PNUD )

mpi d1(d_satt d_educ) w1(0.1666 0.1666) d2(d_cm d_nutr) w2(0.1666 0.1666) d3(d_elct d_wtr d_sani  d_hsg d_ckfl d_asst) w3(0.056 0.0556  0.0556 0.0556  0.0556  0.0556)  [pweight= weight] ,cutoff(0.3333) by (region) 

// PNUD_SEUIL NATIONAL (comporte les indicateurs standards auxquels on rajoute l'alphabétisation et le chomage)

mpi d1(d_educ1 d_satt d_lit ) w1(0.083 0.083 0.083) d2(d_unemp) w2(0.25) d3(d_elct d_wtr1 d_sani  d_hsg d_ckfl  d_asst) w3(0.041 0.041 0.041 0.041 0.041 0.041) d4(d_cm1) w4(0.25) [pweight=weight]   , cutoff (0.3333) by (region) 

// PNUD_SEUIL PNUD (comporte les indicateurs standards auxquels on rajoute l'alphabétisation et le chomage)
cap drop si vulnerable sev_pauvre poor R

mpi d1(d_educ d_satt  d_lit ) w1(0.083 0.083 0.083) d2(d_unemp) w2(0.25) d3(d_elct d_wtr d_sani d_hsg d_ckfl d_asst) w3(0.041 0.041 0.041 0.041 0.041 0.041) d4(d_cm) w4(0.25) [pweight=weight]   , cutoff (0.3333) by (region) 

// Proposition Nationale_SEUIL NATIONAL (comporte la version précédente et l'identification)
global nb_zone = 11
 mpi d1(d_educ10 d_satt  d_lit ) w1(0.066 0.066 0.066) d2(d_cm1) w2(0.20) d3(d_elct d_wtrN d_sani  d_hsg d_ckfl  d_asst) w3(0.033 0.033 0.033 0.033 0.033 0.033) d4( d_unemp) w4(0.20) d5(Ident) w5(0.20) [pweight=weight] , cutoff(0.3333) by (region) 

* M0 et H
mat A = e(by_mpi)
mat list A
mat define A=e(by_mpi)'
submatrix A, rownum(1/11) 
matlist r(mat)
mat define F=r(mat) 
submatrix A, rownum(12/22) 
matlist r(mat)
mat define G=r(mat)

* Indicateur
mat list e(by_ind)
mat define B=e(by_ind)'
mat list B
submatrix B, rownum(1/11) 
mat define BB=r(mat)
submatrix B, rownum(12/22) 
mat define CC=r(mat)
submatrix B, rownum(23/33) 
mat define DD=r(mat)
submatrix B, rownum(34/44) 
mat define EE=r(mat)
submatrix B, rownum(45/55) 
mat define FF=r(mat)

submatrix B, rownum(56/66) 
mat define GG=r(mat)
submatrix B, rownum(67/77) 
mat define HH=r(mat)
submatrix B, rownum(78/88) 
mat define II=r(mat)
submatrix B, rownum(89/99) 
mat define JJ=r(mat)
submatrix B, rownum(100/110) 
mat define KK=r(mat)
submatrix B, rownum(111/121) 
mat define LL=r(mat)
submatrix B, rownum(122/132) 
mat define MM=r(mat)

// Vulnérabilté
gen si = (d_educ10 + d_satt + d_lit)*0.066 + d_cm1*0.20 + (d_elct + d_wtrN + d_sani +  d_hsg + d_ckfl + d_asst)*0.033 + d_unemp*0.20 + Ident*0.20

ge vulnerable = (si>1/5) & (si<=1/3) if si!=.

gen sev_pauvre = si >= 1/2 if si!=.

gen poor = si>1/3

proportion region if si!=., over(vulnerable)
mat list r(table)

mat define temp = e(b)'

mat vulnerable = J($nb_zone ,1,0)

forvalues k = 1 / $nb_zone  {
	scalar define index = 2 * `k'
	mat vulnerable[`k',1] = temp[index,1]
}

proportion region if si!=., over(sev_pauvre)
mat list r(table)
mat define temp = e(b)'
mat sev_pauvre = J($nb_zone ,1,0)

forvalues k = 1 / $nb_zone  {
	scalar define index = 2 * `k'
	mat sev_pauvre[`k',1] = temp[index,1]
}


// Population
qui tab region if si!=.,matcell(pop)

tab region poor if si!=. & poor==1,matcell(poor)

mat A = F,G,BB,CC,DD,EE,FF,GG,HH,II,JJ, KK,LL, MM, vulnerable,sev_pauvre, pop, poor[1..$nb_zone,1]


mat colnames A = "H" "MO" "Année de scolarité" "Frequentation scolaire" "Alphabétisation" "Mortalité juvénile"  "Electricité" "Eau potable" "Toilette" "Logement"  "Energie de cuisson"  "Equipement" "Chomage" "Identification"  "Vulnerabilité" "sev_pauvre" "population" "population pauvre mpi"

/*Retenir le nom des région*/
decode region,gen(R)
levelsof R if si!=.,local(R)
mat rownames A = `R' 

/* Exportation sur Excel */
putexcel clear
putexcel set  "$sortie\INPM_MICS_2016", sheet("REGION_NATIONAL") modify

/* Mise en forme */
putexcel B6 = matrix(A), colnames  nformat(number_d2)
putexcel A7 = matrix(A), rownames

/*Sauvegarde définitive du Tableau */
putexcel save


// Proposition Nationale_SEUIL PNUD (comporte la version précédente et l'identification)
global nb_zone = 11
drop si vulnerable sev_pauvre poor R 
mpi d1(d_educ d_satt  d_lit ) w1(0.066 0.066 0.066) d2(d_cm) w2(0.20) d3(d_elct d_wtr d_sani  d_hsg d_ckfl  d_asst) w3(0.033 0.033 0.033 0.033 0.033 0.033) d4( d_unemp) w4(0.20) d5(Ident) w5(0.20) [pweight=weight]  , cutoff(0.3333) by (region) 

* M0 et H
mat A = e(by_mpi)
mat list A
mat define A=e(by_mpi)'
submatrix A, rownum(1/11) 
matlist r(mat)
mat define F=r(mat) 
submatrix A, rownum(12/22) 
matlist r(mat)
mat define G=r(mat)

* Indicateur
mat list e(by_ind)
mat define B=e(by_ind)'
mat list B
submatrix B, rownum(1/11) 
mat define BB=r(mat)
submatrix B, rownum(12/22) 
mat define CC=r(mat)
submatrix B, rownum(23/33) 
mat define DD=r(mat)
submatrix B, rownum(34/44) 
mat define EE=r(mat)
submatrix B, rownum(45/55) 
mat define FF=r(mat)

submatrix B, rownum(56/66) 
mat define GG=r(mat)
submatrix B, rownum(67/77) 
mat define HH=r(mat)
submatrix B, rownum(78/88) 
mat define II=r(mat)
submatrix B, rownum(89/99) 
mat define JJ=r(mat)
submatrix B, rownum(100/110) 
mat define KK=r(mat)
submatrix B, rownum(111/121) 
mat define LL=r(mat)
submatrix B, rownum(122/132) 
mat define MM=r(mat)

// Vulnerabilté
gen si = (d_educ + d_satt + d_lit)*0.066 + d_cm*0.20 + (d_elct + d_wtr + d_sani +  d_hsg + d_ckfl + d_asst)*0.033 + d_unemp*0.20 + Ident*0.20

gen vulnerable = (si>1/5) & (si<=1/3) if si!=.

gen sev_pauvre = si >= 1/2 if si!=.

gen poor = si>1/3

proportion region if si!=., over(vulnerable)
mat list r(table)

mat define temp = e(b)'

mat vulnerable = J($nb_zone ,1,0)

forvalues k = 1 / $nb_zone  {
	scalar define index = 2 * `k'
	mat vulnerable[`k',1] = temp[index,1]
}

proportion region if si!=., over(sev_pauvre)
mat list r(table)
mat define temp = e(b)'
mat sev_pauvre = J($nb_zone ,1,0)

forvalues k = 1 / $nb_zone  {
	scalar define index = 2 * `k'
	mat sev_pauvre[`k',1] = temp[index,1]
}


// Population
qui tab region if si!=.,matcell(pop)

tab region poor if si!=. & poor==1,matcell(poor)

mat A = F,G,BB,CC,DD,EE,FF,GG,HH,II,JJ, KK,LL, MM, vulnerable,sev_pauvre, pop, poor[1..$nb_zone,1]


mat colnames A = "H" "MO" "Année de scolarité" "Frequentation scolaire" "Alphabétisation" "Mortalité juvénile" "Electricité" "Eau potable" "Toilette" "Logement"  "Energie de cuisson"  "Equipement" "Chomage" "Identification"  "Vulnerabilité" "sev_pauvre" "population" "population pauvre mpi"


decode region,gen(R)
levelsof R if si!=.,local(R)
mat rownames A = `R' 
/* Exportation sur Excel*/
putexcel clear
putexcel set  "$sortie\INPM_MICS_2016", sheet("REGION_PNUD") modify

/* Mise en forme */
putexcel C6 = matrix(A), colnames  nformat(number_d2)
putexcel A7 = matrix(A), rownames

*********************************************************************** MPI AREA *************************************************************************
// Proposition Nationale_SEUIL PNUD (comporte la version précédente et l'identification)
global nb_zone = 2

drop si vulnerable sev_pauvre poor 

mpi d1(d_educ d_satt  d_lit) w1(0.066 0.066 0.066) d2(d_cm) w2(0.20) d3(d_elct d_wtr d_sani  d_hsg d_ckfl  d_asst) w3(0.033 0.033 0.033 0.033 0.033 0.033) d4( d_unemp) w4(0.20) d5(Ident) w5(0.20) [pweight=weight], cutoff(0.3333) by (area) 

global nb_zone = 2
* M0 et H
mat A = e(by_mpi)
mat list A
mat define A=e(by_mpi)'
submatrix A, rownum(1/2) 
matlist r(mat)
mat define F=r(mat) 
submatrix A, rownum(3/4) 
matlist r(mat)
mat define G=r(mat)

* Indicateur
mat list e(by_ind)
mat define B=e(by_ind)'
mat list B
submatrix B, rownum(1/2) 
mat define BB=r(mat)
submatrix B, rownum(3/4) 
mat define CC=r(mat)
submatrix B, rownum(5/6) 
mat define DD=r(mat)
submatrix B, rownum(7/8) 
mat define EE=r(mat)
submatrix B, rownum(9/10) 
mat define FF=r(mat)

submatrix B, rownum(11/12) 
mat define GG=r(mat)
submatrix B, rownum(13/14) 
mat define HH=r(mat)
submatrix B, rownum(15/16) 
mat define II=r(mat)
submatrix B, rownum(17/18) 
mat define JJ=r(mat)
submatrix B, rownum(19/20) 
mat define KK=r(mat)
submatrix B, rownum(21/22) 
mat define LL=r(mat)
submatrix B, rownum(23/24) 
mat define MM=r(mat)

// Vulnerabilté
gen si = (d_educ + d_satt + d_lit)*0.066 + d_cm*0.20 + (d_elct + d_wtr + d_sani +  d_hsg + d_ckfl + d_asst)*0.033 + d_unemp*0.20 + Ident*0.20

ge vulnerable = (si>1/5) & (si<=1/3) if si!=.

gen sev_pauvre = si >= 1/2 if si!=.

gen poor = si>1/3

proportion area if si!=., over(vulnerable)
mat list r(table)

mat define temp = e(b)'

mat vulnerable = J($nb_zone ,1,0)

forvalues k = 1 / $nb_zone  {
	scalar define index = 2 * `k'
	mat vulnerable[`k',1] = temp[index,1]
}

proportion area if si!=., over(sev_pauvre)
mat list r(table)
mat define temp = e(b)'
mat sev_pauvre = J($nb_zone ,1,0)

forvalues k = 1 / $nb_zone  {
	scalar define index = 2 * `k'
	mat sev_pauvre[`k',1] = temp[index,1]
}


// Population
qui tab area if si!=.,matcell(pop)

tab area poor if si!=. & poor==1,matcell(poor)

mat A = F,G,BB,CC,DD,EE,FF,GG,HH,II,JJ,KK,LL, MM, vulnerable,sev_pauvre, pop, poor[1..$nb_zone,1]


mat colnames A = "H" "MO" "Année de scolarité" "Frequentation scolaire" "Alphabétisation" "Mortalité juvénile" "Electricité" "Eau potable" "Toilette" "Logement"  "Energie de cuisson"  "Equipement" "Chomage" "Identification"  "Vulnerabilité" "sev_pauvre" "population" "population pauvre mpi"


/* Exportation sur Excel dans le dossier Resultats_Tab*/
putexcel clear
putexcel set  "$sortie\INPM_MICS_2016.xlsx", sheet("MILLIEU_PNUD") modify

/*Retenir le nom des milieux */
decode area,gen(AR)
levelsof AR if si!=.,local(AR)
mat rownames A = `AR' 

/* Mise en forme */
putexcel B6 = matrix(A), colnames  nformat(number_d2)
putexcel A7 = matrix(A), rownames

// Proposition Nationale_SEUIL NATIONAL (comporte la version précédente et l'identification)
 drop si vulnerable sev_pauvre poor AR

mpi d1(d_educ10 d_satt  d_lit) w1(0.066 0.066 0.066) d2(d_cm1) w2(0.20) d3(d_elct d_wtrN d_sani  d_hsg d_ckfl  d_asst) w3(0.033 0.033 0.033 0.033 0.033 0.033) d4( d_unemp) w4(0.20) d5(Ident) w5(0.20) [pweight=weight], cutoff(0.3333) by (area) 
* M0 et H
mat A = e(by_mpi)
mat list A
mat define A=e(by_mpi)'
submatrix A, rownum(1/2) 
matlist r(mat)
mat define F=r(mat) 
submatrix A, rownum(3/4) 
matlist r(mat)
mat define G=r(mat)

* Indicateur
mat list e(by_ind)
mat define B=e(by_ind)'
mat list B
submatrix B, rownum(1/2) 
mat define BB=r(mat)
submatrix B, rownum(3/4) 
mat define CC=r(mat)
submatrix B, rownum(5/6) 
mat define DD=r(mat)
submatrix B, rownum(7/8) 
mat define EE=r(mat)
submatrix B, rownum(9/10) 
mat define FF=r(mat)

submatrix B, rownum(11/12) 
mat define GG=r(mat)
submatrix B, rownum(13/14) 
mat define HH=r(mat)
submatrix B, rownum(15/16) 
mat define II=r(mat)
submatrix B, rownum(17/18) 
mat define JJ=r(mat)
submatrix B, rownum(19/20) 
mat define KK=r(mat)
submatrix B, rownum(21/22) 
mat define LL=r(mat)
submatrix B, rownum(23/24) 
mat define MM=r(mat)


// Vulnerabilté
gen si = (d_educ10 + d_satt + d_lit)*0.066  + d_cm1*0.20 + (d_elct + d_wtrN + d_sani +  d_hsg + d_ckfl + d_asst)*0.033  + d_unemp*0.20 + Ident*0.20

ge vulnerable = (si>1/5) & (si<=1/3) if si!=.

gen sev_pauvre = si >= 1/2 if si!=.

gen poor = si>1/3

proportion area if si!=., over(vulnerable)
mat list r(table)

mat define temp = e(b)'

mat vulnerable = J($nb_zone ,1,0)

forvalues k = 1 / $nb_zone  {
	scalar define index = 2 * `k'
	mat vulnerable[`k',1] = temp[index,1]
}

proportion area if si!=., over(sev_pauvre)
mat list r(table)
mat define temp = e(b)'
mat sev_pauvre = J($nb_zone ,1,0)

forvalues k = 1 / $nb_zone  {
	scalar define index = 2 * `k'
	mat sev_pauvre[`k',1] = temp[index,1]
}


// Population
qui tab area if si!=.,matcell(pop)

tab area poor if si!=. & poor==1,matcell(poor)

mat A = F,G,BB,CC,DD,EE,FF,GG,HH,II,JJ, KK,LL,MM, vulnerable,sev_pauvre, pop, poor[1..$nb_zone,1]

mat colnames A = "H" "MO" "Frequentation scolaire"  "Année de scolarité" "Mortalité juvénile" "Nutrition" "Electricité" "Eau potable" "Toilette" "Logement"  "Energie de cuisson"  "Equipement" "Chomage"  "Vulnerabilité" "sev_pauvre" "population" "population pauvre mpi"


/* Exportation sur Excel */
putexcel clear
putexcel set  "$sortie\INPM_MICS_2016", sheet("MILIEU_NATIONAL") modify


/*Retenir le nom des milieux */
decode area,gen(AR)
levelsof AR if si!=.,local(AR)
mat rownames A = `AR' 

* Mise en forme */
putexcel B6 = matrix(A), colnames  nformat(number_d2)
putexcel A7 = matrix (A), rownames
