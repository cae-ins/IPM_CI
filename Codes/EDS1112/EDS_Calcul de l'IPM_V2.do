********************************************************************************
/*
Citation:
Oxford Poverty and Human Development Initiative (OPHI), University of Oxford. 
Global Multidimensional Poverty Index - Cote d'Ivoire DHS 2011-2012 
[STATA do-file]. Available from OPHI website: http://ophi.org.uk/  

For further queries, contact: ophi@qeh.ox.ac.uk
*/
********************************************************************************

clear all 
set more off
set maxvar 10000

*** Working Folder Path ***
global data "C:\Users\Dell\OneDrive\Bureau\PHAS\INPM\EDS\Bases brutes" 
global sortie "C:\Users\Dell\OneDrive\Bureau\PHAS\INPM\EDS\Sortie"
global dofile "C:\Users\Dell\OneDrive\Bureau\PHAS\INPM\EDS\Do file"
global adoigrowthup "C:\Users\Dell\OneDrive\Bureau\PHAS\INPM\EDS\Bases brutes\igrowup_update-master"
global adowho "C:\Users\Dell\OneDrive\Bureau\PHAS\INPM\EDS\Bases brutes\who2007_update"	
********************************************************************************
*** COTE D'IVOIRE DHS-MICS 2011-2012 ***
********************************************************************************

********************************************************************************
*** Step 1: Data preparation 
*** Selecting variables from BR, IR, & MR recode & merging with PR recode 
********************************************************************************

	/*Cote D'Ivoire DHS 2011-12: Anthropometric information were recorded 
	for a subsample of 1/2 of all eligible children age 0-59 months and 
	eligible women aged 15-49 (p.7). Anthropometric information was not 
	collected from men 15-59.*/


********************************************************************************
*** Step 1.1 PR - INDIVIDUAL RECODE
*** (Children under 5 years) 
********************************************************************************


use "$data/CIPR62FL.DTA", clear 


*** Generate individual unique key variable required for data merging using:
	*** hv001=cluster number; 
	*** hv002=household number; 
	*** hvidx=respondent's line number.
gen double ind_id = hv001*1000000 + hv002*100 + hvidx 
format ind_id %20.0g
label var ind_id "Individual ID"
codebook ind_id

duplicates report ind_id


	/*Following the checks carried out above, we keep only eligible children in
	this section since the interest is to generate measures for children under 
	5*/
keep if hv120==1
count	
	//4,337 children under 5		
	
	
*** Check the variables to calculate the z-scores:

*** Variable: SEX ***
clonevar gender = hc27


*** Variable: AGE ***
clonevar age_months = hc1  

gen mdate = mdy(hc18, hc17, hc19)
gen bdate = mdy(hc30, hc16, hc31) if hc16 <= 31
	//Calculate birth date in days from date of interview
replace bdate = mdy(hc30, 15, hc31) if hc16 > 31 
	//If date of birth of child has been expressed as more than 31, we use 15
gen age = (mdate-bdate)/30.4375 
	//Calculate age in months with days expressed as decimals
sum age
count if age<0
replace age = age_months if age<0  
	

gen  str6 ageunit = "months" 
lab var ageunit "Months"

	
*** Variable: BODY WEIGHT (KILOGRAMS) ***
codebook hc2, tab (9999)
gen	weight = hc2/10 
	//We divide it by 10 in order to express it in kilograms 
tab hc2 if hc2>9990, miss nol   
	//Missing values are 9994 to 9996
replace weight = . if hc2>=9990 
	//All missing values or out of range are replaced as "."
tab	hc13 hc2 if hc2>=9990 | hc2==., miss 
	//hw13: result of the measurement
sum weight


*** Variable: HEIGHT (CENTIMETERS)
codebook hc3, tab (9999)
gen	height = hc3/10 
	//We divide it by 10 in order to express it in centimeters
tab hc3 if hc3>9990, miss nol   
	//Missing values are 9994 to 9996
replace height = . if hc3>=9990 
	//All missing values or out of range are replaced as "."
tab	hc13 hc3   if hc3>=9990 | hc3==., miss
sum height


*** Variable: MEASURED STANDING/LYING DOWN ***	
codebook hc15
gen measure = "l" if hc15==1 
	//Child measured lying down
replace measure = "h" if hc15==2 
	//Child measured standing up
replace measure = " " if hc15==.
	//Replace with " " if unknown


*** Variable: OEDEMA ***
gen  oedema = "n"  


*** Variable: SAMPLING WEIGHT ***
gen sw = 1	


*** Indicate to STATA where the igrowup_restricted.ado file is stored:
	***Source of ado file: http://www.who.int/childgrowth/software/en/
adopath + "$adoigrowthup"

*** We will now proceed to create three nutritional variables: 
	*** weight-for-age (underweight),  
	*** weight-for-height (wasting) 
	*** height-for-age (stunting)

/* We use 'reflib' to specify the package directory where the .dta files 
containing the WHO Child Growth Standards are stored.*/	
gen str100 reflib = "$adoigrowthup"
lab var reflib "Directory of reference tables"

/* We use datalib to specify the working directory where the input STATA 
dataset containing the anthropometric measurement is stored. */
gen str100 datalib = "$data" 
lab var datalib "Directory for datafiles"

/* We use datalab to specify the name that will prefix the output files that 
will be produced from using this ado file (datalab_z_r_rc and datalab_prev_rc)*/
gen str30 datalab = "children_nutri_civ" 
lab var datalab "Working file"

	
/*We now run the command to calculate the z-scores with the adofile */
igrowup_restricted reflib datalib datalab gender age ageunit weight height ///
measure oedema sw


/*We now turn to using the dta file that was created and that contains 
the calculated z-scores to create the child nutrition variables following WHO 
standards */
use "$data/children_nutri_civ_z_rc.dta", clear 


	
*** Standard MPI indicator ***	
gen	underweight = (_zwei < -2.0) 
replace underweight = . if _zwei == . | _fwei==1
lab var underweight  "Child is undernourished (weight-for-age) 2sd - WHO"
tab underweight, miss


gen stunting = (_zlen < -2.0)
replace stunting = . if _zlen == . | _flen==1
lab var stunting "Child is stunted (length/height-for-age) 2sd - WHO"
tab stunting, miss


gen wasting = (_zwfl < - 2.0)
replace wasting = . if _zwfl == . | _fwfl == 1
lab var wasting  "Child is wasted (weight-for-length/height) 2sd - WHO"
tab wasting, miss


*** Destitution MPI indicator  ***	
gen	underweight_u = (_zwei < -3.0) 
replace underweight_u = . if _zwei == . | _fwei==1
lab var underweight_u  "Child is undernourished (weight-for-age) 3sd - WHO"


gen stunting_u = (_zlen < -3.0)
replace stunting_u = . if _zlen == . | _flen==1
lab var stunting_u "Child is stunted (length/height-for-age) 3sd - WHO"


gen wasting_u = (_zwfl < - 3.0)
replace wasting_u = . if _zwfl == . | _fwfl == 1
lab var wasting_u  "Child is wasted (weight-for-length/height) 3sd - WHO"
 

gen weight_ch = hv005/1000000
label var weight_ch "sample weight child under 5" 
 
 
	//Retain relevant variables:
keep ind_id weight_ch underweight* stunting* wasting* 
order ind_id weight_ch underweight* stunting* wasting* 
sort ind_id
save "$sortie/CIV11-12_PR_child.dta", replace

	
	
	//Erase files from folder:
erase "$data/children_nutri_civ_z_rc.xls"
erase "$data/children_nutri_civ_prev_rc.xls"
erase "$data/children_nutri_civ_z_rc.dta"

	
********************************************************************************
*** Step 1.2  BR - BIRTH RECODE 
*** (All females 15-49 years who ever gave birth)  
********************************************************************************


use "$data/CIBR62FL.dta", clear

	
*** Generate individual unique key variable required for data merging
*** v001=cluster number;  
*** v002=household number; 
*** v003=respondent's line number
gen double ind_id = v001*1000000 + v002*100 + v003 
format ind_id %20.0g
label var ind_id "Individual ID"


desc b3 b7	
gen date_death = b3 + b7
	//Date of death = date of birth (b3) + age at death (b7)
gen mdead_survey = v008 - date_death
	//Months dead from survey = Date of interview (v008) - date of death
gen ydead_survey = mdead_survey/12
	//Years dead from survey
	
gen age_death = b7	
label var age_death "Age at death in months"
tab age_death, miss
		
	
codebook b5, tab (10)	
gen child_died = 1 if b5==0
replace child_died = 0 if b5==1
replace child_died = . if b5==.
label define lab_died 1 "child has died" 0 "child is alive"
label values child_died lab_died
tab b5 child_died, miss
	

	/*NOTE: For each woman, sum the number of children who died and compare to 
	the number of sons/daughters whom they reported have died */
bysort ind_id: egen tot_child_died = sum(child_died) 
egen tot_child_died_2 = rsum(v206 v207)
	//v206: sons who have died; v207: daughters who have died
compare tot_child_died tot_child_died_2
	//Cote D'Ivoire DHS-MICS 2011-12: these figures are identical.
	
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
	/*All children who are alive or who died longer than 5 years from the 
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

gen women_BR = 1 
	//Identification variable for observations in BR recode

	
	//Retain relevant variables
keep ind_id women_BR childu18_died_per_wom_5y  childu18_died_per_wom_1y 
order ind_id women_BR childu18_died_per_wom_5y childu18_died_per_wom_1y 
sort ind_id
save "$sortie/CIV11-12_BR.dta", replace	

	

********************************************************************************
*** Step 1.3  IR - WOMEN's RECODE  
*** (Eligible female 15-49 years in the household)
********************************************************************************


use "$data/CIIR62FL.dta", clear

	
*** Generate individual unique key variable required for data merging
*** Hv001=cluster number;  
*** Hv002=household number; 
*** v003=respondent's line number
gen double ind_id = v001*1000000 + v002*100 + v003 
format ind_id %20.0g
label var ind_id "Individual ID"

duplicates report ind_id


gen women_IR=1 
	//Identification variable for observations in IR recode

	
	//Retain relevant variables:
	
clonevar religion_wom = v130
lab var religion_wom "Women's religion"	


clonevar ethnic_wom = v131
lab var ethnic_wom "Women's ethnicity"	


clonevar insurance_wom = v481
label var insurance_wom "Women have health insurance"	


	//Retain relevant variables:
keep ind_id women_IR v003 v005 v012 v201 v206 v207 *_wom 
order ind_id women_IR v003 v005 v012 v201 v206 v207 *_wom 
sort ind_id
save "$sortie/CIV11-12_IR.dta", replace



********************************************************************************
*** Step 1.4  PR - INDIVIDUAL RECODE  
*** (Girls 15-19 years in the household)
********************************************************************************

use "$data/CIPR62FL.dta", clear

		
*** Generate individual unique key variable required for data merging using:
gen double ind_id = hv001*1000000 + hv002*100 + hvidx 
format ind_id %20.0g
label var ind_id "Individual ID"
codebook ind_id


*** Keep relevant sample	
keep if hv105>=15 & hv105<=19 & hv104==2 & hv027==1 
count
	//Total girls 15-19 years: 1,222

	
***Variables required to calculate the z-scores to produce BMI-for-age:

*** Variable: SEX ***
codebook hv104, tab (9)
clonevar gender = hv104
	//2:female 


*** Variable: AGE ***
lookfor hv807c hv008 ha32
gen age_month = hv008 - ha32
lab var age_month "Age in months, individuals 15-19 years (girls)"
sum age_month
	/*Note: For a couple of observations, we find that the age in months is 
	beyond 228 months. In this secton, while calculating the z-scores, these 
	cases will be excluded. However, in section 2.3, we will take the BMI 
	information of these girls. */

	
*** Variable: AGE UNIT ***
gen str6 ageunit = "months" 
lab var ageunit "Months"

			
*** Variable: BODY WEIGHT (KILOGRAMS) ***
codebook ha2, tab (9999)
count if ha2>9990 
tab ha13 if ha2>9990, miss
gen weight = ha2/10 if ha2<9990
	/*Weight information from girls. We divide it by 10 in order to express 
	it in kilograms. Missing values or out of range are identified as "." */	
sum weight


*** Variable: HEIGHT (CENTIMETERS)	
codebook ha3, tab (9999)
count if ha3>9990 
tab ha13 if ha3>9990, miss
gen height = ha3/10 if ha3<9990
sum height


*** Variable: OEDEMA
	// We assume all individuals in the sample have no oedema
gen oedema = "n"  
tab oedema	


*** Variable: SAMPLING WEIGHT ***
	/* We don't require individual weight to compute the z-scores. We 
	assume all individuals in the sample have the same sample weight */
gen sw = 1
sum sw

					
/* 
For this part of the do-file we use the WHO AnthroPlus software. This is to 
calculate the z-scores for young individuals aged 15-19 years. 
Source of ado file: https://www.who.int/growthref/tools/en/
*/

*** Indicate to STATA where the igrowup_restricted.ado file is stored:	
adopath + "$adowho"

	
/* We use 'reflib' to specify the package directory where the .dta files 
containing the WHO Growth reference are stored. Note that we use strX to specify 
the length of the path in string. */		
gen str100 reflib = "$adowho"
lab var reflib "Directory of reference tables"


/* We use datalib to specify the working directory where the input STATA data
set containing the anthropometric measurement is stored. */
gen str100 datalib = "$data" 
lab var datalib "Directory for datafiles"


/* We use datalab to specify the name that will prefix the output files that 
will be produced from using this ado file*/
gen str30 datalab = "girl_nutri_civ" 
lab var datalab "Working file"
	

/*We now run the command to calculate the z-scores with the adofile */
who2007 reflib datalib datalab gender age_month ageunit weight height oedema sw


/*We now turn to using the dta file that was created and that contains 
the calculated z-scores to compute BMI-for-age*/
use "$data/girl_nutri_civ_z.dta", clear 

	
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


gen girl_PR=1 
	//Identification variable for girls 15-19 years in PR recode 


	//Retain relevant variables:	
keep ind_id girl_PR age_month low_bmiage*
order ind_id girl_PR age_month low_bmiage*
sort ind_id
save "$sortie/CIV11-12_PR_girls.dta", replace

	

	//Erase files from folder:
erase "$data/girl_nutri_civ_z.xls"
erase "$data/girl_nutri_civ_prev.xls"
erase "$data/girl_nutri_civ_z.dta"



********************************************************************************
*** Step 1.5  MR - MEN'S RECODE  
***(Eligible man 15-54 years in the household) 
********************************************************************************


use "$data/CIMR62FL.dta", clear 

	
*** Generate individual unique key variable required for data merging
	*** mv001=cluster number; 
	*** mv002=household number;
	*** mv003=respondent's line number
gen double ind_id = mv001*1000000 + mv002*100 + mv003 	
format ind_id %20.0g
label var ind_id "Individual ID"

duplicates report ind_id

tab mv012, miss
codebook mv201 mv206 mv207,tab (999)
	/* Cote D'Ivoire DHS-MICS 2011-12: Fertility and mortality questions were 
	collected from men 15-59 years.*/

gen men_MR=1 	
	//Identification variable for observations in MR recode


	//Retain relevant variables:
clonevar religion_men = mv130
lab var religion_men "Men's religion"	


clonevar ethnic_men = mv131
lab var ethnic_men "Men's ethnicity"


clonevar insurance_men = mv481
label var insurance_men "Men have health insurance"	

	
keep ind_id men_MR mv003 mv005 mv012 mv201 mv206 mv207 *_men 
order ind_id men_MR mv003 mv005 mv012 mv201 mv206 mv207 *_men 
sort ind_id
save "$sortie/CIV11-12_MR.dta", replace


	
********************************************************************************
*** Step 1.6  PR - INDIVIDUAL RECODE  
*** (Boys 15-19 years in the household)
********************************************************************************

	//Anthropometric data was not collected from men.
	
********************************************************************************
*** Step 1.7  PR - HOUSEHOLD MEMBER'S RECODE 
********************************************************************************

use "$data/CIPR62FL.dta", clear

	
*** Generate a household unique key variable at the household level using: 
	***hv001=cluster number 
	***hv002=household number
gen double hh_id = hv001*10000 + hv002 
format hh_id %20.0g
label var hh_id "Household ID"
codebook hh_id  


*** Generate individual unique key variable required for data merging using:
	*** hv001=cluster number; 
	*** hv002=household number; 
	*** hvidx=respondent's line number.
gen double ind_id = hv001*1000000 + hv002*100 + hvidx 
format ind_id %20.0g
label var ind_id "Individual ID"
codebook ind_id


sort hh_id ind_id

	
********************************************************************************
*** Step 1.8 DATA MERGING 
******************************************************************************** 
 
 
*** Merging BR Recode 
*****************************************
merge 1:1 ind_id  using "$sortie/CIV11-12_BR.dta"
drop _merge

*** Merging IR Recode 
*****************************************
merge 1:1 ind_id using "$sortie/CIV11-12_IR.dta"
drop _merge

*** Merging 15-19 years: girls 
*****************************************
merge 1:1 ind_id using "$sortie/CIV11-12_PR_girls.dta"
drop _merge
		
*** Merging MR Recode 
*****************************************
merge 1:1 ind_id using "$sortie/CIV11-12_MR.dta"
drop _merge

*** Merging 15-19 years: boys 
*****************************************
gen age_month_b = .
lab var age_month_b "Age in months, individuals 15-19 years (boys)"	

gen	low_bmiage_b = .
lab var low_bmiage_b "Teenage low bmi 2sd - WHO (boys)"

gen	low_bmiage_b_u = .
lab var low_bmiage_b_u "Teenage very low bmi 3sd - WHO (boys)"


*** Merging child under 5 
*****************************************
merge 1:1 ind_id using "$sortie/CIV11-12_PR_child.dta"
drop _merge

sort ind_id


********************************************************************************
*** Step 1.9 KEEP ONLY DE JURE HOUSEHOLD MEMBERS ***
********************************************************************************

clonevar resident = hv102 
tab resident, miss
label var resident "Permanent (de jure) household member"
drop if resident!=1 
tab resident, miss
	/*Cote D'Ivoire DHS 2011-12: 834 (1.63%) 
	individuals who were non-usual residents were 
	dropped from the sample. */

	
********************************************************************************
*** Step 1.10 KEEP HOUSEHOLDS SELECTED FOR ANTHROPOMETRIC SUBSAMPLE ***
*** if relevant
********************************************************************************


	/*Cote D'Ivoire DHS 2011-12: height and weight measurements 
	were collected from children (0-5) and women (15-49) living in 
	1/2 of the households sampled for the male interview.*/
	
codebook hv027, tab (9)
clonevar subsample=hv027
label var subsample "Households selected as part of nutrition subsample" 
*drop if subsample!=1 
tab subsample, miss	
	
	
********************************************************************************
*** Step 1.11 CONTROL VARIABLES
********************************************************************************


*** No eligible women 15-49 years 
*** for adult nutrition indicator
***********************************************
tab ha13, miss
tab ha13 if hv105>=15 & hv105<=49 & hv104==2, miss

gen fem_nutri_eligible = (ha13!=.)
tab fem_nutri_eligible, miss
bysort hh_id: egen hh_n_fem_nutri_eligible = sum(fem_nutri_eligible) 	
gen	no_fem_nutri_eligible = (hh_n_fem_nutri_eligible==0)
lab var no_fem_nutri_eligible "Household has no eligible women for anthropometric"	
drop hh_n_fem_nutri_eligible
tab no_fem_nutri_eligible, miss


*** No eligible women 15-49 years 
*** for child mortality indicator
*****************************************
gen	fem_eligible = (hv117==1)
bysort	hh_id: egen hh_n_fem_eligible = sum(fem_eligible) 	
gen	no_fem_eligible = (hh_n_fem_eligible==0) 									
lab var no_fem_eligible "Household has no eligible women for interview"
drop hh_n_fem_eligible 
tab no_fem_eligible, miss


*** No eligible men 15-54 years 
*** for adult nutrition indicator (if relevant)
***********************************************
gen	male_nutri_eligible = .
gen	no_male_nutri_eligible = .
lab var no_male_nutri_eligible "Household has no eligible men for anthropometric"	



*** No eligible men 15-54 years
*** for child mortality indicator (if relevant)
*****************************************
gen	male_eligible = (hv118==1)
bysort	hh_id: egen hh_n_male_eligible = sum(male_eligible)  
	//Number of eligible men for interview in the hh
gen	no_male_eligible = (hh_n_male_eligible==0) 	
	//Takes value 1 if the household had no eligible men for an interview
lab var no_male_eligible "Household has no eligible man for interview"
drop hh_n_male_eligible
tab no_male_eligible, miss


*** No eligible children under 5
*** for child nutrition indicator
*****************************************
gen	child_eligible = (hv120==1) 
bysort	hh_id: egen hh_n_children_eligible = sum(child_eligible)  
	//Number of eligible children for anthropometrics
gen	no_child_eligible = (hh_n_children_eligible==0) 
	//Takes value 1 if there were no eligible children for anthropometrics
lab var no_child_eligible "Household has no children eligible for anthropometric"
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


sort hh_id ind_id



********************************************************************************
*** Step 1.12 RENAMING DEMOGRAPHIC VARIABLES ***
********************************************************************************

//Sample weight
desc hv005
clonevar weight = hv005
replace weight = weight/1000000 
label var weight "Sample weight"


//Area: urban or rural	
desc hv025
codebook hv025, tab (5)		
clonevar area = hv025  
replace area=0 if area==2  
label define lab_area 1 "urban" 0 "rural"
label values area lab_area
label var area "Area: urban-rural"



//Relationship to the head of household 
clonevar relationship = hv101 
codebook relationship, tab (20)
recode relationship (1=1)(2=2)(3 11=3)(4/10=4)(12=5)(98=.)
label define lab_rel 1"head" 2"spouse" 3"child" 4"extended family" 5"not related" 6"maid"
label values relationship lab_rel
label var relationship "Relationship to the head of household"
tab hv101 relationship, miss


//Sex of household member	
codebook hv104
clonevar sex = hv104 
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
codebook hv105, tab (999)
clonevar age = hv105  
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



//Marital status of household member
clonevar marital = hv115 
codebook marital, tab (10)
recode marital (0=1)(1=2)
label define lab_mar 1"never married" 2"currently married" 3"widowed" ///
4"divorced" 5"not living together"
label values marital lab_mar	
label var marital "Marital status of household member"
tab hv115 marital, miss


//Total number of de jure hh members in the household
gen member = 1
bysort hh_id: egen hhsize = sum(member)
label var hhsize "Household size"
tab hhsize, miss
drop member


//Religion of the household head
gen religion_hh = .
label var religion_hh "Religion of household head"


//Ethnicity of the household head
gen ethnic_hh = .
label var ethnic_hh "Ethnicity of household head"


//Subnational region
	/*The sample was stratified to provide adequate representation of 
	urban and rural areas as well as eleven areas of study, corresponding 
	to the ten former administrative regions and the city of Abidjan,
	for which there is estimate for all key indicators (p.7).*/
	
	
codebook hv024, tab (99)
decode hv024, gen(temp)
replace temp =  proper(temp)
encode temp, gen(region)
lab var region "Region for subnational decomposition"
codebook region, tab (99)
drop temp

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


********************************************************************************
***  Step 2 Data preparation  ***
***  Standardization of the 10 Global MPI indicators 
***  Identification of non-deprived & deprived individuals  
********************************************************************************

********************************************************************************
*** Step 2.1 Years of Schooling ***
********************************************************************************

codebook hv108, tab(30)
clonevar  eduyears = hv108   
	//Total number of years of education
replace eduyears = . if eduyears>30
	//Recode any unreasonable years of highest education as missing value
replace eduyears = . if eduyears>=age & age>0
	/*The variable "eduyears" was replaced with a '.' if total years of 
	education was more than individual's age */
replace eduyears = . if age < 10 
	/*The variable "eduyears" was replaced with a '.' given that the criteria 
	for this indicator is household member aged 10 years or older */

	/*A control variable is created on whether there is information on 
	years of education for at least 2/3 of the household members aged 
	10 years and older */	
gen temp = 1 if eduyears!=. & age>=10 & age!=.
bysort	hh_id: egen no_missing_edu = sum(temp)
	/*Total household members who are 10 years and older with no missing 
	years of education */
gen temp2 = 1 if age>=10 & age!=.
bysort hh_id: egen hhs = sum(temp2)
	//Total number of household members who are 10 years and older 
replace no_missing_edu = no_missing_edu/hhs
replace no_missing_edu = (no_missing_edu>=2/3)
	/*Identify whether there is information on years of education for at 
	least 2/3 of the household members aged 10 years and older */
tab no_missing_edu, miss
	//Check that values for 0 are less than 1%: 0.29%.
label var no_missing_edu "No missing edu for at least 2/3 of the HH members aged 10 years & older"		
drop temp temp2 hhs


*** Standard MPI ***
/*The entire household is considered deprived if no eligible 
household member has completed SIX years of schooling. */
******************************************************************* 
gen	 years_edu6 = (eduyears>=6) & age>=10
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
replace eduyears = . if age < 17 
	/*The variable "eduyears" was replaced with a '0' given that the criteria 
	for this indicator is household member aged 17 years or older */

	/*A control variable is created on whether there is information on 
	years of education for at least 2/3 of the household members aged 
	17 years and older */	
gen temp = 1 if eduyears!=. & age>=17 & age!=.
bysort	hh_id: egen no_missing_edu10 = sum(temp)
	/*Total household members who are 17 years and older with no missing 
	years of education */
gen temp2 = 1 if age>=17 & age!=.
bysort hh_id: egen hhs = sum(temp2)
	//Total number of household members who are 17 years and older 
replace no_missing_edu10 = no_missing_edu10/hhs
replace no_missing_edu10 = (no_missing_edu10>=2/3)
	/*Identify whether there is information on years of education for at 
	least 2/3 of the household members aged 17 years and older */
tab no_missing_edu10, miss
	//Check that values for 0 are less than 1%: 0.34%.
label var no_missing_edu10 "No missing edu for at least 2/3 of the HH members aged 17 years & older"		
drop temp temp2 hhs


*** National MPI ***

gen	years_edu10 = (eduyears>=10) & age>=17
replace years_edu10 = . if eduyears==.
bysort	hh_id: egen hh_years_edu_10 = max(years_edu10)
replace hh_years_edu_10 = . if hh_years_edu_10==0 & no_missing_edu==0
lab var hh_years_edu_10 "Household has at least one member with 10 year of edu"


********************************************************************************
*** Step 2.2 Child School Attendance ***
********************************************************************************

codebook hv121, tab (99)
clonevar attendance = hv121 
recode attendance (2=1) 
label define lab_attend 1 "currently attending" 0 "not currently attending"
label values attendance lab_attend
label var attendance "Attended school during current school year"
codebook attendance, tab (99)
replace attendance = 0 if (attendance==9 | attendance==.) & hv109==0 
replace attendance = . if  attendance==9 & hv109!=0

	

*** Standard MPI ***
/*The entire household is considered deprived if any school-aged 
child is not attending school up to class 8. */ 
******************************************************************* 
gen	child_schoolage = (age>=6 & age<=14)
	/*In Cote D'Ivoire, the official school entrance age to primary school is 
	6 years. So, age range is 6-14 (=6+8) 
	Source: p.26 of the survey report.*/

	
	/*A control variable is created on whether there is no information on 
	school attendance for at least 2/3 of the school age children */
count if child_schoolage==1 & attendance==.
	//Understand how many eligible school aged children are not attending school 
gen temp = 1 if child_schoolage==1 & attendance!=.
	/*Generate a variable that captures the number of eligible school aged 
	children who are attending school */
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
	
	
bysort hh_id: egen hh_children_schoolage = sum(child_schoolage)
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
	/*In Cote D'Ivoire, the official school entrance age is 6 years.  
	  So, age range for destitution measure is 6-12 (=6+6) */

	
	/*A control variable is created on whether there is no information on 
	school attendance for at least 2/3 of the children attending school up to 
	class 6 */	
count if child_schoolage_6==1 & attendance==.	
gen temp = 1 if child_schoolage_6==1 & attendance!=.
bysort hh_id: egen no_missing_atten_u = sum(temp)	
gen temp2 = 1 if child_schoolage_6==1	
bysort hh_id: egen hhs = sum(temp2)
replace no_missing_atten_u = no_missing_atten_u/hhs 
replace no_missing_atten_u = (no_missing_atten_u>=2/3)			
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


********************************************************************************
*** Step 2.3 Nutrition ***
********************************************************************************

********************************************************************************
*** Step 2.3a Adult Nutrition ***
********************************************************************************


foreach var in ha40 {
			 gen inf_`var' = 1 if `var'!=.
			 bysort sex: tab age inf_`var' 
			 /*Cote D'Ivoire DHS-MICS 2011-12 has anthropometric 
			 data only for women 15-49 years */
			 drop inf_`var'
			 }
***

*** BMI Indicator for Women 15-49 years ***
******************************************************************* 
gen	f_bmi = ha40/100
lab var f_bmi "Women's BMI"
gen	f_low_bmi = (f_bmi<18.5)
replace f_low_bmi = . if f_bmi==. | f_bmi>=99.97
lab var f_low_bmi "BMI of women < 18.5"

gen	f_low_bmi_u = (f_bmi<17)
replace f_low_bmi_u = . if f_bmi==. | f_bmi>=99.97
lab var f_low_bmi_u "BMI of women <17"



*** BMI Indicator for Men 15-59 years ***
******************************************************************* 	
gen m_bmi = .
lab var m_bmi "Male's BMI"
gen m_low_bmi = .
lab var m_low_bmi "BMI of male < 18.5"

gen m_low_bmi_u = .
lab var m_low_bmi_u "BMI of male <17"


*** Standard MPI: BMI-for-age for individuals 15-19 years 
*** 				  and BMI for individuals 20-54 years ***
*******************************************************************  
gen low_bmi_byage = 0
lab var low_bmi_byage "Individuals with low BMI or BMI-for-age"
replace low_bmi_byage = 1 if f_low_bmi==1
	//Replace variable "low_bmi_byage = 1" if eligible women have low BMI	
replace low_bmi_byage = 1 if low_bmi_byage==0 & m_low_bmi==1 
	/*Replace variable "low_bmi_byage = 1" if eligible men have low BMI. If 
	there is no male anthropometric data, then 0 changes are made.*/

	
/*Note: The following command replaces BMI with BMI-for-age for those between 
the age group of 15-19 by their age in months where information is available */
	//Replacement for girls: 
replace low_bmi_byage = 1 if low_bmiage==1 & age_month!=.
replace low_bmi_byage = 0 if low_bmiage==0 & age_month!=.
	/*Replacements for boys - if there is no male anthropometric data for boys, 
	then 0 changes are made: */
replace low_bmi_byage = 1 if low_bmiage_b==1 & age_month_b!=.
replace low_bmi_byage = 0 if low_bmiage_b==0 & age_month_b!=.
	
	
/*Note: The following control variable is applied when there is BMI information 
for adults and BMI-for-age for teenagers.*/	
replace low_bmi_byage = . if f_low_bmi==. & m_low_bmi==. & low_bmiage==. & low_bmiage_b==. 
		
bysort hh_id: egen low_bmi = max(low_bmi_byage)
gen	hh_no_low_bmiage = (low_bmi==0)
	/*Households take a value of '1' if all eligible adults and teenagers in the 
	household has normal bmi or bmi-for-age */	
replace hh_no_low_bmiage = . if low_bmi==.
	/*Households take a value of '.' if there is no information from eligible 
	individuals in the household */
replace hh_no_low_bmiage = 1 if no_adults_eligible==1	
	//Households take a value of '1' if there is no eligible adult population.
drop low_bmi
lab var hh_no_low_bmiage "Household has no adult with low BMI or BMI-for-age"
tab hh_no_low_bmiage, miss	


	
*** Destitution MPI: BMI-for-age for individuals 15-19 years 
*** 			     and BMI for individuals 20-54 years ***
********************************************************************************
gen low_bmi_byage_u = 0
replace low_bmi_byage_u = 1 if f_low_bmi_u==1
	/*Replace variable "low_bmi_byage_u = 1" if eligible women have low 
	BMI (destitute cutoff)*/	
replace low_bmi_byage_u = 1 if low_bmi_byage_u==0 & m_low_bmi_u==1 
	/*Replace variable "low_bmi_byage_u = 1" if eligible men have low 
	BMI (destitute cutoff). If there is no male anthropometric data, then 0 
	changes are made.*/

	
/*Note: The following command replaces BMI with BMI-for-age for those between 
the age group of 15-19 by their age in months where information is available */
	//Replacement for girls: 
replace low_bmi_byage_u = 1 if low_bmiage_u==1 & age_month!=.
replace low_bmi_byage_u = 0 if low_bmiage_u==0 & age_month!=.
	/*Replacements for boys - if there is no male anthropometric data for boys, 
	then 0 changes are made: */
replace low_bmi_byage_u = 1 if low_bmiage_b_u==1 & age_month_b!=.
replace low_bmi_byage_u = 0 if low_bmiage_b_u==0 & age_month_b!=.
	
	
/*Note: The following control variable is applied when there is BMI information 
for adults and BMI-for-age for teenagers. */
replace low_bmi_byage_u = . if f_low_bmi_u==. & low_bmiage_u==. & m_low_bmi_u==. & low_bmiage_b_u==. 

		
bysort hh_id: egen low_bmi = max(low_bmi_byage_u)
gen	hh_no_low_bmiage_u = (low_bmi==0)
	/*Households take a value of '1' if all eligible adults and teenagers in the 
	household has normal bmi or bmi-for-age (destitution cutoff) */
replace hh_no_low_bmiage_u = . if low_bmi==.
	/*Households take a value of '.' if there is no information from eligible 
	individuals in the household */
replace hh_no_low_bmiage_u = 1 if no_adults_eligible==1	
	//Households take a value of '1' if there is no eligible adult population.
drop low_bmi
lab var hh_no_low_bmiage_u "Household has no adult with low BMI or BMI-for-age(<17/-3sd)"
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
gen hh_no_uw_st = 1 if hh_no_stunting==1 & hh_no_underweight==1
replace hh_no_uw_st = 0 if hh_no_stunting==0 | hh_no_underweight==0
	//Takes value 0 if child in the hh is stunted or underweight 
replace hh_no_uw_st = . if hh_no_stunting==. & hh_no_underweight==.
replace hh_no_uw_st = 1 if no_child_eligible==1
	//Households with no eligible children will receive a value of 1 
lab var hh_no_uw_st "Household has no child underweight or stunted"


*** Destitution MPI  ***
gen hh_no_uw_st_u = 1 if hh_no_stunting_u==1 & hh_no_underweight_u==1
replace hh_no_uw_st_u = 0 if hh_no_stunting_u==0 | hh_no_underweight_u==0
replace hh_no_uw_st_u = . if hh_no_stunting_u==. & hh_no_underweight_u==.
replace hh_no_uw_st_u = 1 if no_child_eligible==1 
lab var hh_no_uw_st_u "Destitute: Household has no child underweight or stunted"


********************************************************************************
*** Step 2.3c Household Nutrition Indicator ***
********************************************************************************

*** Standard MPI ***
/* Members of the household are considered deprived if the household has a 
child under 5 whose height-for-age or weight-for-age is under two standard 
deviation below the median, or has teenager with BMI-for-age that is under two 
standard deviation below the median, or has adults with BMI threshold that is 
below 18.5 kg/m2. */
************************************************************************

gen	hh_nutrition_uw_st = 1
replace hh_nutrition_uw_st = 0 if hh_no_low_bmiage==0 | hh_no_uw_st==0
replace hh_nutrition_uw_st = . if hh_no_low_bmiage==. & hh_no_uw_st==.
	/*Replace indicator as missing if household has eligible adult and child 
	with missing nutrition information */
replace hh_nutrition_uw_st = . if hh_no_low_bmiage==. & hh_no_uw_st==1 & no_child_eligible==1
	/*Replace indicator as missing if household has eligible adult with missing 
	nutrition information and no eligible child for anthropometric measures */ 
replace hh_nutrition_uw_st = . if hh_no_uw_st==. & hh_no_low_bmiage==1 & no_adults_eligible==1
	/*Replace indicator as missing if household has eligible child with missing 
	nutrition information and no eligible adult for anthropometric measures */ 
replace hh_nutrition_uw_st = 1 if no_eligibles==1  
 	/*We replace households that do not have the applicable population, that is, 
	women 15-49 & children 0-5, as non-deprived in nutrition*/		
lab var hh_nutrition_uw_st "Household has no individuals malnourished"
tab hh_nutrition_uw_st, miss


*** Destitution MPI ***
/* Members of the household are considered deprived if the household has a 
child under 5 whose height-for-age or weight-for-age is under three standard 
deviation below the median, or has teenager with BMI-for-age that is under three 
standard deviation below the median, or has adults with BMI threshold that is 
below 17.0 kg/m2. Households that have no eligible adult AND no eligible 
children are considered non-deprived. The indicator takes a value of missing 
only if all eligible adults and eligible children have missing information 
in their respective nutrition variable. */
************************************************************************

gen	hh_nutrition_uw_st_u = 1
replace hh_nutrition_uw_st_u = 0 if hh_no_low_bmiage_u==0 | hh_no_uw_st_u==0
replace hh_nutrition_uw_st_u = . if hh_no_low_bmiage_u==. & hh_no_uw_st_u==.
	/*Replace indicator as missing if household has eligible adult and child 
	with missing nutrition information */
replace hh_nutrition_uw_st_u = . if hh_no_low_bmiage_u==. & hh_no_uw_st_u==1 & no_child_eligible==1
	/*Replace indicator as missing if household has eligible adult with missing 
	nutrition information and no eligible child for anthropometric measures */ 
replace hh_nutrition_uw_st_u = . if hh_no_uw_st_u==. & hh_no_low_bmiage_u==1 & no_adults_eligible==1
	/*Replace indicator as missing if household has eligible child with missing 
	nutrition information and no eligible adult for anthropometric measures */ 
replace hh_nutrition_uw_st_u = 1 if no_eligibles==1   
 	/*We replace households that do not have the applicable population, that is, 
	women 15-49 & children 0-5, as non-deprived in nutrition*/		 	 	
lab var hh_nutrition_uw_st_u "Household has no individuals malnourished (destitution)"
tab hh_nutrition_uw_st_u, miss



********************************************************************************
*** Step 2.4 Child Mortality ***
********************************************************************************
	
codebook v206 v207 mv206 mv207
	/*v206 or mv206: number of sons who have died 
	  v207 or mv207: number of daughters who have died*/
	
egen temp_f = rowtotal(v206 v207), missing
	//Total child mortality reported by eligible women
replace temp_f = 0 if v201==0
	//This line replaces women who have never given birth	
bysort	hh_id: egen child_mortality_f = sum(temp_f), missing
lab var child_mortality_f "Occurrence of child mortality reported by women"
tab child_mortality_f, miss
drop temp_f
		
		
egen temp_m = rowtotal(mv206 mv207), missing
	//Total child mortality reported by eligible men
replace temp_m = 0 if mv201==0	
bysort	hh_id: egen child_mortality_m = sum(temp_m), missing
lab var child_mortality_m "Occurrence of child mortality reported by men"
tab child_mortality_m, miss
drop temp_m


egen child_mortality = rowmax(child_mortality_f child_mortality_m)
lab var child_mortality "Total child mortality within household"
tab child_mortality, miss

		
 *** Standard MPI *** 
/* Members of the household are considered deprived if 
women in the household reported mortality among children 
under 18 in the last 5 years from the survey year. */
************************************************************************

tab childu18_died_per_wom_5y, miss

replace childu18_died_per_wom_5y = 0 if v201==0 
	/*Assign a value of "0" for:
	- all eligible women who never ever gave birth */	
replace childu18_died_per_wom_5y = 0 if no_fem_eligible==1 
	/*Assign a value of "0" for:
	- individuals living in households that have non-eligible women */	
	
bysort hh_id: egen childu18_mortality_5y = sum(childu18_died_per_wom_5y), missing
replace childu18_mortality_5y = 0 if childu18_mortality_5y==. & child_mortality==0
label var childu18_mortality_5y "Under 18 child mortality within household past 5 years reported by women"
tab childu18_mortality_5y, miss		
	
gen hh_mortality_u18_5y = (childu18_mortality_5y==0)
replace hh_mortality_u18_5y = . if childu18_mortality_5y==.
lab var hh_mortality_u18_5y "Household had no under 18 child mortality in the last 5 years"
tab hh_mortality_u18_5y, miss 


*** Destitution MPI *** 
*** (same as standard MPI) ***
************************************************************************
gen hh_mortality_u = hh_mortality_u18_5y	
lab var hh_mortality_u "Household had no under 18 child mortality in the last 5 years"		
*/

*** National MPI *** 
/* Members of the household are considered deprived if 
women in the household reported mortality among children 
under 18 in the last 1 year from the survey year. */
**********************************************************************

tab childu18_died_per_wom_1y, miss

replace childu18_died_per_wom_1y = 0 if v201==0 
	/*Assign a value of "0" for:
	- all eligible women who never ever gave birth */	
replace childu18_died_per_wom_1y = 0 if no_fem_eligible==1 
	/*Assign a value of "0" for:
	- individuals living in households that have non-eligible women */	
	
bysort hh_id: egen childu18_mortality_1y = sum(childu18_died_per_wom_1y), missing
replace childu18_mortality_1y = 0 if childu18_mortality_1y==. & child_mortality==0
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
clonevar electricity = hv206 
codebook electricity, tab (9)
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


clonevar toilet = hv205  
clonevar shared_toilet = hv225
codebook shared_toilet, tab(99)  

	
*** Standard MPI ***
/*Members of the household are considered deprived if the household's 
sanitation facility is not improved (according to the SDG guideline) 
or it is improved but shared with other households*/
********************************************************************
codebook toilet, tab(99)

gen	toilet_mdg     =      (toilet<23 | toilet==41) & shared_toilet!=1	
replace toilet_mdg = 0 if (toilet<23 | toilet==41) & shared_toilet==1   
replace toilet_mdg = 0 if toilet==14	
replace toilet_mdg = . if toilet==.	
lab var toilet_mdg "Household has improved sanitation"
tab toilet toilet_mdg, miss


*** Destitution MPI ***
/*Members of the household are considered deprived if household practises 
open defecation or uses other unidentifiable sanitation practises */
********************************************************************
gen	toilet_u = .
replace toilet_u = 0 if toilet==31 | toilet==96 
replace toilet_u = 1 if toilet!=31 & toilet!=96 & toilet!=. 	
lab var toilet_u "Household does not practise open defecation or others"
tab toilet toilet_u, miss


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

desc hv201 hv204 hv202
clonevar water = hv201  
clonevar timetowater = hv204  
clonevar ndwater = hv202  
	//no data


*** Standard MPI ***
/* Members of the household are considered deprived if the household 
does not have access to improved drinking water (according to the SDG 
guideline) or safe drinking water is at least a 30-minute walk from 
home, roundtrip */
********************************************************************
codebook water, tab(99)

gen	water_mdg     = 1 if water<=31 | water==41 | water==71  	
replace water_mdg = 0 if water==32 | water==42 | water==43 | ///
						 water==61 | water==62 | water==96 

codebook timetowater, tab(9999)	

replace water_mdg = 0 if water_mdg==1 & timetowater >= 30 & timetowater!=. & ///
						 timetowater!=996 & timetowater!=998 

replace water_mdg = . if water==. 
lab var water_mdg "Household has drinking water with MDG standards (considering distance)"
tab water water_mdg, miss




*** Destitution MPI ***
/* Members of the household is identified as destitute if household 
does not have access to safe drinking water, or safe water is more 
than 45 minute walk from home, round trip.*/
********************************************************************
gen	water_u = .
replace water_u = 1 if water<=31 | water==41 | water==71 						   
replace water_u = 0 if water==32 | water==42 | water==43 | water==61 | ///
					   water==62 | water==96
						   
replace water_u = 0 if water_u==1 & timetowater>45 & timetowater!=. & ///
					   timetowater!=998 & timetowater!=996 
						   
replace water_u = . if water==. 						  
lab var water_u "Household has drinking water with MDG standards (45 minutes distance)"
tab water water_u, miss

*** National MPI ***
gen	water_mdgN     = 1 if water<=31 | water==41 | water==71  	
replace water_mdgN = 0 if water==32 | water==42 | water==43 | ///
						 water==61 | water==62 | water==96 
lab var water_mdgN "Household has drinking water"




********************************************************************************
*** Step 2.8 Housing ***
********************************************************************************

/* Members of the household are considered deprived if the household 
has a dirt, sand or dung floor */
clonevar floor = hv213 
codebook floor, tab(99)
gen	floor_imp = 1
replace floor_imp = 0 if floor<=12 | floor==96  
replace floor_imp = . if floor==.	
lab var floor_imp "Household has floor that it is not earth/sand/dung"
tab floor floor_imp, miss		


/* Members of the household are considered deprived if the household has walls 
made of natural or rudimentary materials. We followed the report's definitions
of natural or rudimentary materials. */
clonevar wall = hv214 
codebook wall, tab(99)	
gen	wall_imp = 1 
replace wall_imp = 0 if wall<=26 | wall==96  
replace wall_imp = . if wall==. 	
lab var wall_imp "Household has wall that it is not of low quality materials"
tab wall wall_imp, miss	
	

/* Members of the household are considered deprived if the household has roof 
made of natural or rudimentary materials. We followed the report's definitions
of natural and rudimentary materials. */
clonevar roof = hv215
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


********************************************************************************
*** Step 2.9 Cooking Fuel ***
********************************************************************************
/*
Solid fuel are solid materials burned as fuels, which includes coal as well as 
solid biomass fuels (wood, animal dung, crop wastes and charcoal). 

Source: 
https://apps.who.int/iris/bitstream/handle/10665/141496/9789241548885_eng.pdf
*/


clonevar cookingfuel = hv226


*** Standard MPI ***
/* Members of the household are considered deprived if the 
household uses solid fuels and solid biomass fuels for cooking. */
*****************************************************************
codebook cookingfuel, tab(99)

gen	cooking_mdg = 1
replace cooking_mdg = 0 if cookingfuel>5 & cookingfuel<95 
replace cooking_mdg = . if cookingfuel==.
lab var cooking_mdg "Household uses clean fuels for cooking"			 
tab cookingfuel cooking_mdg, miss	

	
*** Destitution MPI ***
*** (same as standard MPI) ***
****************************************
gen	cooking_u = cooking_mdg
lab var cooking_u "Household uses clean fuels for cooking"



********************************************************************************
*** Step 2.10 Assets ownership ***
********************************************************************************


*** Television/LCD TV/plasma TV/color TV/black & white tv
lookfor tv television plasma lcd	
codebook hv208 sh110g 
	//Check: 1=yes; 0=no
clonevar television = hv208
replace television=1 if television!=1 & sh110g==1
tab sh110g hv208 if television==1,miss
lab var television "Household has television"	

*** Air conditionner
lookfor air
//Check: 1=yes; 0=no
clonevar aircond = sh110m
lab var aircond "Household has air conditioner"	


***	Radio/walkman/stereo/kindle
lookfor radio walkman stereo
codebook hv207
	//Check: 1=yes; 0=no
clonevar radio = hv207 
lab var radio "Household has radio"	
	

***	Handphone/telephone/iphone/mobilephone/ipod
lookfor telephone téléphone mobilephone ipod
codebook hv221 hv243a
	//Check: 1=yes; 0=no
clonevar telephone = hv221
replace telephone=1 if telephone!=1 & hv243a==1	
	//hv243a=mobilephone. Combine information on telephone and mobilephone.	
tab hv243a hv221 if telephone==1,miss
lab var telephone "Household has telephone (landline/mobilephone)"	

	
***	Refrigerator/icebox/fridge
lookfor refrigerator réfrigérateur
codebook hv209
	//Check: 1=yes; 0=no
clonevar refrigerator = hv209 
lab var refrigerator "Household has refrigerator"


***	Car/van/lorry/truck
lookfor car voiture truck van
codebook hv212
	//Check: 1=yes; 0=no
clonevar car = hv212  
lab var car "Household has car"		

	
***	Bicycle/cycle rickshaw
lookfor bicycle bicyclette
codebook hv210
	//Check: 1=yes; 0=no	
clonevar bicycle = hv210 
lab var bicycle "Household has bicycle"	


***	Motorbike/motorized bike/autorickshaw
lookfor motorbike moto
codebook hv211
	//Check: 1=yes; 0=no	
clonevar motorbike = hv211 
lab var motorbike "Household has motorbike"	

**** motorized boat(insignificant)
lookfor motor
codebook hv243d
//Check: 1=yes; 0=no	
clonevar boat = hv243d 
lab var boat "Household has motorized boat"	

*** ventilator
lookfor ven fan 
// no data 

***	Computer/laptop/tablet
lookfor computer ordinateur laptop ipad tablet
codebook sh110n
	//Check: 1=yes; 0=no
clonevar computer = sh110n
lab var computer "Household has computer"

	
***	Animal cart
lookfor cart 
codebook hv243c
	//Check: 1=yes; 0=no
clonevar animal_cart = hv243c
lab var animal_cart "Household has animal cart"	

lookfor internet
	//Check: 1=yes; 0=no
clonevar internet = sh110o
lab var internet "Household has internet"

gen mveh= car | boat | motorbike
lab var mveh "motorized vehicle"

foreach var in television radio telephone refrigerator car ///
			   bicycle motorbike computer animal_cart internet  aircond boat  {
replace `var' = 0 if `var'==2 
label define lab_`var' 0"No" 1"Yes"
label values `var' lab_`var'
replace `var' = . if `var'==9 | `var'==99 | `var'==8 | `var'==98 
}
	//Missing values replaced


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

*** National MPI ***
/*The household has at most 1 equipment from the following list: ventilator, air 
conditioner, television, radio, telephone, computer, refrigerator/freezer, 
bicycle, motorcycle, internet, AND is deprived of a vehicle*/

egen n_small_assetsN = rowtotal( television radio telephone refrigerator bicycle motorbike computer animal_cart ), missing
lab var n_small_assetsN "Household Number of Small Assets Owned- National" 
   
gen hh_assetsN = (mveh==1| n_small_assetsN > 1) 
replace hh_assetsN = . if mveh==. & n_small_assetsN==.
lab var hh_assetsN "Household Asset Ownership: HH has car or more than 1 small assets"


********************************************************************************
*** Step 2.11 Identification***
********************************************************************************
lookfor certificate birth
codebook hv140 
	//replace dont know by no certificate
replace hv140=0 if hv140==. & !(age>17)
gen Identification = !inlist(hv140,1,2) & (age>=5 & age<=15)
by hhid, sort : egen Ident = max(Identification)
drop Identification
lab var Iden "Household has a child (5-15) who has no birth certificate or is not declared"

save "$sortie\base_travail_EDS12", replace
*******************************************************************************
*** Step 2.12 Rename and keep variables for MPI calculation 
********************************************************************************

	//Retain DHS wealth index:	
clonevar windex=hv270
clonevar windexf=hv271


	//Retain data on sampling design: 	
clonevar strata = hv022
clonevar psu = hv021
label var psu "Primary sampling unit"
label var strata "Sample strata"

	
*** Rename key global MPI indicators for estimation ***
recode hh_mortality_u18_5y  (0=1)(1=0) , gen(d_cm)
recode hh_mortality_u18_1y  (0=1)(1=0) , gen(d_cm1)
recode hh_nutrition_uw_st 	(0=1)(1=0) , gen(d_nutr)
recode hh_child_atten 		(0=1)(1=0) , gen(d_satt)
recode hh_years_edu6 		(0=1)(1=0) , gen(d_educ)
recode hh_years_edu_10		(0=1)(1=0) , gen(d_educ1)
recode electricity 			(0=1)(1=0) , gen(d_elct)
recode water_mdg 			(0=1)(1=0) , gen(d_wtr)
recode water_mdgN			(0=1)(1=0) , gen(d_wtr1)
recode toilet_mdg 			(0=1)(1=0) , gen(d_sani)
recode housing_1 			(0=1)(1=0) , gen(d_hsg)
recode cooking_mdg 			(0=1)(1=0) , gen(d_ckfl)
recode hh_assets2 			(0=1)(1=0) , gen(d_asst)
recode hh_assetsN 			(0=1)(1=0) , gen(d_asst1)
/*
*** Rename key global MPI indicators for destitution estimation ***
recode hh_mortality_u       (0=1)(1=0) , gen(dst_cm)
recode hh_nutrition_uw_st_u (0=1)(1=0) , gen(dst_nutr)
recode hh_child_atten_u 	(0=1)(1=0) , gen(dst_satt)
recode hh_years_edu_u 		(0=1)(1=0) , gen(dst_educ)
recode electricity_u		(0=1)(1=0) , gen(dst_elct)
recode water_u 				(0=1)(1=0) , gen(dst_wtr)
recode toilet_u 			(0=1)(1=0) , gen(dst_sani)
recode housing_u 			(0=1)(1=0) , gen(dst_hsg)
recode cooking_u			(0=1)(1=0) , gen(dst_ckfl)
recode hh_assets2_u 		(0=1)(1=0) , gen(dst_asst) 
 

*** Rename indicators for changes over time estimation ***	
recode hh_mortality_u18_5y  (0=1)(1=0) , gen(d_cm_01)
recode hh_nutrition_uw_st   (0=1)(1=0) , gen(d_nutr_01)
recode hh_child_atten 		(0=1)(1=0) , gen(d_satt_01)
recode hh_years_edu6 		(0=1)(1=0) , gen(d_educ_01)
recode electricity 			(0=1)(1=0) , gen(d_elct_01)
recode water_mdg 			(0=1)(1=0) , gen(d_wtr_01)
recode toilet_mdg 			(0=1)(1=0) , gen(d_sani_01)
recode housing_1 			(0=1)(1=0) , gen(d_hsg_01)
recode cooking_mdg 			(0=1)(1=0) , gen(d_ckfl_01)
recode hh_assets2 			(0=1)(1=0) , gen(d_asst_01)	
	

recode hh_mortality_u         (0=1)(1=0) , gen(dst_cm_01)
recode hh_nutrition_uw_st_u   (0=1)(1=0) , gen(dst_nutr_01)
recode hh_child_atten_u 	  (0=1)(1=0) , gen(dst_satt_01)
recode hh_years_edu_u 		  (0=1)(1=0) , gen(dst_educ_01)
recode electricity_u		  (0=1)(1=0) , gen(dst_elct_01)
recode water_u	 			  (0=1)(1=0) , gen(dst_wtr_01)
recode toilet_u 			  (0=1)(1=0) , gen(dst_sani_01)
recode housing_u 			  (0=1)(1=0) , gen(dst_hsg_01)
recode cooking_u			  (0=1)(1=0) , gen(dst_ckfl_01)
recode hh_assets2_u 		  (0=1)(1=0) , gen(dst_asst_01)
*/


	/*In this survey, the harmonised 'region_01' variable is the 
	same as the standardised 'region' variable.*/	
clonevar region_01 = region

 	
*** Generate country and survey details for estimation ***
char _dta[cty] "Côte d'Ivoire"
char _dta[ccty] "CIV"
char _dta[year] "2011-2012" 	
char _dta[survey] "DHS"
char _dta[ccnum] "384"
char _dta[type] "micro"


*** Sort, compress and save data for estimation ***
sort ind_id
compress
la da "Micro data for `_dta[ccty]' (`_dta[ccnum]') from `c(current_date)' (`c(current_time)')."
save "$sortie\base_travail_EDS12", replace 


********************************************************************************
*** Step 2.12 Employment & Literacy***
********************************************************************************
 
/*The entire household is considered deprived if 
 */ 
 
use "$data/CIMR62FL.dta", clear 

keep mcaseid mv714a mv714 mv716 mv717 mv719 mv721 mv002 mv001 mv003 mv012 mv155
ren mcaseid hhid
ren mv714 v714
ren mv714a v714a
ren mv716 V716
ren mv717 v717
ren mv719 v719
ren mv721 v721
ren mv012 v012
ren mv155 v155
ren mv001 hv001 
ren mv002 hv002
ren mv003 hv003

gen literacy= !inlist(v155,2) & (v012>=17 & v012 <= 49)
bysort hv001 hv002 : egen lit= max(literacy)
lab var lit "A household member aged 17 or over does not know how to read (French); 1=yes, 0=no"

gen double ind_id = hv001*1000000 + hv002*100 + hv003
format ind_id %20.0g
label var ind_id "Individual ID"
codebook ind_id
duplicates report ind_id
save "$sortie/emplhom.dta" , replace
 
use "$data/CIIR62FL.dta", clear

keep  caseid v714a v714 v716 v717 v719 v721 v003 v002  v001 v155 v012 
ren  caseid hhid
ren v001 hv001
ren v002 hv002
ren v003 hv003
gen literacy= !inlist(v155,2) & (v012>=17 & v012 <= 49)
*Notez que j'ai une réserve concernant la formulation de la question mwb7 : 
bysort hv001 hv002: egen lit= max(literacy)
*replace lit=. if mwb7==.
lab var lit "A household member aged 17 or over does not know how to read (French); 1=yes, 0=no"
gen double ind_id = hv001*1000000 + hv002*100 + hv003
format ind_id %20.0g
label var ind_id "Individual ID"
codebook ind_id

append using "$sortie/emplhom.dta"

rename lit d_lit

clonevar employed = v714

by hhid, sort : gen first = _n==1

save "$sortie/employment.dta", replace



****Merging
use "$sortie\base_travail_EDS12", clear
merge 1:1   ind_id  using "$sortie/employment.dta"
drop _merge

bysort hh_id : egen hh_employed = sum( employed )
gen empage = ( hv105 >=15 & hv105 <=24)
gen temp = 1 if empage==1 & employed!=.
bysort hh_id : egen no_missing_emp_u = sum(temp)
codebook hv121
gen temp2 = 1 if empage==1 & hv121 != 2
bysort hh_id : egen hhemp = sum(temp2)
compare no_missing_emp_u hhemp

gen all_unemp = hh_employed== 0 & hhemp !=0
gen some_unemp = hh_employed < hhemp
lab var all_unemp "All adults unemployed"
lab var some_unemp "At least one adult unemployed"
clonevar d_unemp = all_unemp



	//Retain year, month & date of interview:
desc hv007 hv006 hv008
clonevar year_interview = hv007 	
clonevar month_interview = hv006 
clonevar date_interview = hv008
 
 		
*** Keep main variables require for MPI calculation ***
/*
keep hh_id ind_id subsample strata psu weight weight_ch sex age hhsize ///
area agec7 agec4 agec2 region headship region marital relationship ///
fem_nutri_eligible no_fem_nutri_eligible no_fem_eligible ///
male_nutri_eligible no_male_nutri_eligible no_male_eligible ///
child_eligible no_child_eligible no_adults_eligible ///
no_child_fem_eligible no_eligibles ///
religion_wom religion_men religion_hh ethnic_wom ethnic_men ethnic_hh ///
insurance_wom insurance_men year_interview month_interview date_interview /// 
eduyears no_missing_edu hh_years_edu6 hh_years_edu_u hh_years_edu_10 ///
attendance child_schoolage no_missing_atten hh_child_atten hh_child_atten_u ///
underweight stunting wasting underweight_u stunting_u wasting_u ///
low_bmiage low_bmiage_u low_bmi_byage f_bmi m_bmi ///
hh_no_low_bmiage hh_no_low_bmiage_u ///
hh_no_underweight hh_no_stunting hh_no_wasting hh_no_uw_st ///
hh_no_underweight_u hh_no_stunting_u hh_no_wasting_u hh_no_uw_st_u ///
hh_nutrition_uw_st hh_nutrition_uw_st_u ///
child_mortality hh_mortality_u18_5y hh_mortality_u ///
electricity electricity_u toilet shared_toilet toilet_mdg toilet_u ///
water timetowater ndwater water_mdg water_mdg_1 water_u floor wall roof ///
floor_imp wall_imp roof_imp housing_1 housing_u ///
cookingfuel cooking_mdg cooking_u television radio telephone ///
refrigerator car bicycle motorbike animal_cart computer ///
n_small_assets2 hh_assets2 hh_assets2_u windex windexf   ///
literacy mveh internet boat aircond hh_mortality_u18_1y hh_years_edu_10 ///
water_mdg_1 hh_assetsN  hv001 hv002 hv105  hv121 hv140 Ident age
	 
*** Order file	***
order hh_id ind_id subsample strata psu weight weight_ch sex age hhsize ///
area agec7 agec4 agec2 region headship region marital relationship ///
fem_nutri_eligible no_fem_nutri_eligible no_fem_eligible ///
male_nutri_eligible no_male_nutri_eligible no_male_eligible ///
child_eligible no_child_eligible no_adults_eligible ///
no_child_fem_eligible no_eligibles ///
religion_wom religion_men religion_hh ethnic_wom ethnic_men ethnic_hh ///
insurance_wom insurance_men year_interview month_interview date_interview /// 
eduyears no_missing_edu hh_years_edu6 hh_years_edu_u ///
attendance child_schoolage no_missing_atten hh_child_atten hh_child_atten_u ///
underweight stunting wasting underweight_u stunting_u wasting_u ///
low_bmiage low_bmiage_u low_bmi_byage f_bmi m_bmi ///
hh_no_low_bmiage hh_no_low_bmiage_u ///
hh_no_underweight hh_no_stunting hh_no_wasting hh_no_uw_st ///
hh_no_underweight_u hh_no_stunting_u hh_no_wasting_u hh_no_uw_st_u ///
hh_nutrition_uw_st hh_nutrition_uw_st_u ///
child_mortality hh_mortality_u18_5y hh_mortality_u ///
electricity electricity_u toilet shared_toilet toilet_mdg toilet_u ///
water timetowater ndwater water_mdg water_u floor wall roof ///
floor_imp wall_imp roof_imp housing_1 housing_u ///
cookingfuel cooking_mdg cooking_u television radio telephone ///
refrigerator car bicycle motorbike animal_cart computer mveh ///
n_small_assets2 hh_assets2 hh_assets2_u windex windexf ///
internet boat aircond hh_mortality_u18_1y hh_years_edu_10 ///
water_mdg_1*/
save "$sortie\base_travail_EDS12", replace

// some statistics before MPI

// Number of deprivation accord. to Cote d'Ivoire threshold
svyset psu[pweight=weight], strata(strata)
svy:mean d_satt             
svy:mean d_educ1
svy:mean d_elct
svy:mean d_ckfl
svy:mean d_sani
svy:mean d_hsg
svy:mean d_asst
svy:mean d_cm1
svy:mean d_nutr
svy:mean d_wtr1
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

egen NBmis3 = rowmiss(d_satt d_educ1 d_lit d_elct d_wtr1 d_ckfl d_sani d_hsg d_asst d_cm1 d_nutr d_unemp Ident)
replace NBmis3 = 1 if NBmis !=0
recode NBmis3 (0=1) (1=0)
rename NBmis3 touse3
egen nbdeprN = rowtotal(d_satt d_educ1 d_lit d_elct d_wtr1 d_ckfl d_sani d_hsg d_asst d_cm1 d_nutr d_unemp Ident)
lab var nbdeprN "Number of deprivation Nat"

svy:mean nbdepr0  if touse0
svy:mean nbdeprP if touse1 
svy:mean nbdeprR if touse2 
svy:mean nbdeprN if touse3

drop nbdepr0 touse0 nbdeprP touse1  nbdeprR touse2  nbdeprN touse3

// Number of deprivation accord. to PNUD threshold
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
lab var touse2 "Household without missing value for MPI indicators - REFERENCE "
egen nbdeprR = rowtotal(d_satt d_educ d_lit d_elct d_wtr d_ckfl d_sani d_hsg d_asst d_cm d_nutr d_unemp)
lab var nbdeprR "Number of deprivation Reference"

egen NBmis3 = rowmiss(d_satt d_educ d_lit d_elct d_wtr d_ckfl d_sani d_hsg d_asst d_cm d_nutr d_unemp Ident)
replace NBmis3 = 1 if NBmis !=0
recode NBmis3 (0=1) (1=0)
rename NBmis3 touse3
egen nbdeprN = rowtotal(d_satt d_educ d_lit d_elct d_wtr d_ckfl d_sani d_hsg d_asst d_cm d_nutr d_unemp Ident)
lab var nbdeprN "Number of deprivation Nat"

svy:mean nbdepr0  if touse0
svy:mean nbdeprP if touse1 
svy:mean nbdeprR if touse2 
svy:mean nbdeprN if touse3



**************************** MPI *******************************


// PNUD SEUIL NATIONAL (comporte les indicateurs du PNUD sans nutrition mortalité Eau potable)
mpi d1(d_satt d_educ1) w1(0.25 0.25) d2(d_elct d_sani  d_hsg d_ckfl d_asst) w2(0.1 0.1 0.1 0.1 0.1) [pw=weight]  ,cutoff(0.3333) by (region) 

global nb_zone = 11
// zone=region = 11

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

// Vulnerabilté
gen si = (d_satt + d_educ1)*0.25  + (d_elct + d_wtr + d_sani +  d_hsg + d_ckfl + d_asst)*0.1 

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

tab region poor if si!=.,matcell(poor)

mat A = F,G,BB,CC,DD,EE,FF,GG,HH,II,JJ,KK, vulnerable,sev_pauvre, pop, poor[1..$nb_zone,1]


mat colnames A = "H" "MO" "Frequentation scolaire"  "Année de scolarité" "Electricité" "Eau potable" "Toilette" "Logement"  "Energie de cuisson"  "Equipement"  "Vulnerabilité" "sev_pauvre" "population" "population pauvre mpi"

decode REGION,gen(R)
levelsof R if si!=.,local(R)
mat rownames A = `R' 


/* Exportation sur Excel dans le dossier Resultats_Tab*/
putexcel clear
putexcel set  "$sortie\INPM_EDS_1112", sheet("PNUD") replace

/* Mise en forme */
putexcel C6 = matrix(A), colnames  nformat(number_d2)
putexcel A7 = matrix(A), rownames
*Sauvegarde définitive du Tableau
putexcel save
*Fermeture du fichier
putexcel close



// PNUD SEUIL PNUD (comporte les indicateurs du PNUD sans nutrition mortalité Eau potable)
mpi d1(d_satt d_educ) w1(0.25 0.25) d2(d_elct d_sani  d_hsg d_ckfl d_asst) w2(0.1 0.1 0.1 0.1 0.1) [pw=weight]  ,cutoff(0.3333) by (region) 

global nb_zone = 11
// zone=region = 11

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

// Vulnerabilté
gen si = (d_satt + d_educ)*0.17 + (d_cm + d_nutr)*0.17 + (d_elct + d_wtr + d_sani +  d_hsg + d_ckfl + d_asst)*0.0556 

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

tab region poor if si!=.,matcell(poor)

mat A = F,G,BB,CC,DD,EE,FF,GG,HH,II,JJ,KK, vulnerable,sev_pauvre, pop, poor[1..$nb_zone,1]


mat colnames A = "H" "MO" "Frequentation scolaire"  "Année de scolarité" "Mortalité juvénile" "Nutrition" "Electricité" "Eau potable" "Toilette" "Logement"  "Energie de cuisson"  "Equipement"  "Vulnerabilité" "sev_pauvre" "population" "population pauvre mpi"


decode REGION,gen(R)
levelsof R if si!=.,local(R)
mat rownames A = `R' 


/* Exportation sur Excel dans le dossier Resultats_Tab*/
putexcel clear
putexcel set  "$sortie\INPM_EDS_1112", sheet("PNUD") replace

/* Mise en forme */
putexcel C6 = matrix(A), colnames  nformat(number_d2)
putexcel A7 = matrix(A), rownames

*Sauvegarde définitive du Tableau
putexcel save

*Fermeture du fichier
putexcel close


cap drop si vulnerable sev_pauvre poor
// PNUD_SEUIL NATIONAL (comporte les indicateurs standards du PNUD )
mpi d1(d_satt d_educ1) w1(0.1666 0.1666) d2(d_cm1 d_nutr) w2(0.1666 0.1666) d3(d_elct d_wtr1 d_sani  d_hsg d_ckfl d_asst) w3(0.056 0.0556  0.0556 0.0556  0.0556  0.0556)  [pweight= weight] ,cutoff(0.3333) by (region) 


global nb_zone = 11
// zone=region = 11

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

// Vulnerabilté
gen si = (d_satt + d_educ)*0.17 + (d_cm + d_nutr)*0.17 + (d_elct + d_wtr + d_sani +  d_hsg + d_ckfl + d_asst)*0.0556 

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

tab region poor if si!=.,matcell(poor)

mat A = F,G,BB,CC,DD,EE,FF,GG,HH,II,JJ,KK, vulnerable,sev_pauvre, pop, poor[1..$nb_zone,1]


mat colnames A = "H" "MO" "Frequentation scolaire"  "Année de scolarité" "Mortalité juvénile" "Nutrition" "Electricité" "Eau potable" "Toilette" "Logement"  "Energie de cuisson"  "Equipement"  "Vulnerabilité" "sev_pauvre" "population" "population pauvre mpi"


decode REGION,gen(R)
levelsof R if si!=.,local(R)
mat rownames A = `R' 

putexcel clear
putexcel set  "$sortie\INPM_EDS_1112", sheet("PNUD_SEUIL_NATIONAL") replace

/* Mise en forme */
putexcel C6 = matrix(A), colnames  nformat(number_d2)
putexcel A7 = matrix(A), rownames



*Sauvegarde définitive du Tableau
putexcel save

*Fermeture du fichier
putexcel close



// PNUD_SEUIL PNUD (comporte les indicateurs standards du PNUD )
mpi d1(d_satt d_educ) w1(0.1666 0.1666) d2(d_cm d_nutr) w2(0.1666 0.1666) d3(d_elct d_wtr d_sani  d_hsg d_ckfl d_asst) w3(0.056 0.0556  0.0556 0.0556  0.0556  0.0556)  [pweight= weight] ,cutoff(0.3333) by (region) 

global nb_zone = 11
// zone=region = 11

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

// Vulnerabilté
gen si = (d_satt + d_educ)*0.17 + (d_cm + d_nutr)*0.17 + (d_elct + d_wtr + d_sani +  d_hsg + d_ckfl + d_asst)*0.0556 

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

tab region poor if si!=.,matcell(poor)

mat A = F,G,BB,CC,DD,EE,FF,GG,HH,II,JJ,KK, vulnerable,sev_pauvre, pop, poor[1..$nb_zone,1]


mat colnames A = "H" "MO" "Frequentation scolaire"  "Année de scolarité" "Mortalité juvénile" "Nutrition" "Electricité" "Eau potable" "Toilette" "Logement"  "Energie de cuisson"  "Equipement"  "Vulnerabilité" "sev_pauvre" "population" "population pauvre mpi"


decode REGION,gen(R)
levelsof R if si!=.,local(R)
mat rownames A = `R' 

putexcel clear
putexcel set  "$sortie\INPM_EDS_1112", sheet("PNUD_SEUIL_PNUD") replace

/* Mise en forme */
putexcel C6 = matrix(A), colnames  nformat(number_d2)
putexcel A7 = matrix(A), rownames



*Sauvegarde définitive du Tableau
putexcel save

*Fermeture du fichier
putexcel close


// PNUD_SEUIL NATIONAL (comporte les indicateurs standards auxquels on rajoute l'alphabétisation et le chomage)
cap drop si vulnerable sev_pauvre poor

mpi d1(d_educ1 d_satt d_lit ) w1(0.083 0.083 0.083)  d2(d_cm1 d_nutr) w2(0.125 0.125) d3(d_elct d_wtr1 d_sani  d_hsg d_ckfl  d_asst) w3(0.041 0.041 0.041 0.041 0.041 0.041) d4(d_unemp) w4(0.25) [pweight=weight] , cutoff (0.3333) by (region) 


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

// Vulnerabilté
gen si = (d_educ1 + d_satt + d_lit)*0.083 + d_unemp*0.25 + (d_elct + water_mdg_1 + d_sani +  d_hsg + d_ckfl + d_asst1)*0.041 + d_cm1*0.25

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

tab region poor if si!=.,matcell(poor)

mat A = F,G,BB,CC,DD,EE,FF,GG,HH,II,JJ, KK,LL, vulnerable,sev_pauvre, pop, poor[1..$nb_zone,1]


mat colnames A = "H" "MO" "Année de scolarité" "Frequentation scolaire" "Alphabétisation" "Chomage"  "Electricité" "Eau potable" "Toilette" "Logement"  "Energie de cuisson"  "Equipement" "Mortalité juvénile"  "Vulnerabilité" "sev_pauvre" "population" "population pauvre mpi"


decode REGION,gen(R)
levelsof R if si!=.,local(R)
mat rownames A = `R' 


/* Exportation sur Excel dans le dossier Resultats_Tab*/
putexcel clear
putexcel set  "$sortie\INPM_EDS_1112", sheet("Année de référence 1998") modify

/* Mise en forme */
putexcel C6 = matrix(A), colnames  nformat(number_d2)
putexcel A7 = matrix(A), rownames



// PNUD_SEUIL PNUD (comporte les indicateurs standards auxquels on rajoute l'alphabétisation et le chomage)
cap drop si vulnerable sev_pauvre poor

mpi d1(d_educ d_satt d_lit ) w1(0.083 0.083 0.083)  d2(d_cm d_nutr) w2(0.125 0.125) d3(d_elct d_wtr d_sani  d_hsg d_ckfl  d_asst) w3(0.041 0.041 0.041 0.041 0.041 0.041) d4(d_unemp) w4(0.25) [pweight=weight] , cutoff (0.3333) by (region) nosummary nodecomposition

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

// Vulnerabilté
gen si = (d_educ1 + d_satt + d_lit)*0.083 + d_unemp*0.25 + (d_elct + water_mdg_1 + d_sani +  d_hsg + d_ckfl + d_asst1)*0.041 + d_cm1*0.25

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

tab region poor if si!=.,matcell(poor)

mat A = F,G,BB,CC,DD,EE,FF,GG,HH,II,JJ, KK,LL, vulnerable,sev_pauvre, pop, poor[1..$nb_zone,1]


mat colnames A = "H" "MO" "Année de scolarité" "Frequentation scolaire" "Alphabétisation" "Chomage"  "Electricité" "Eau potable" "Toilette" "Logement"  "Energie de cuisson"  "Equipement" "Mortalité juvénile"  "Vulnerabilité" "sev_pauvre" "population" "population pauvre mpi"


decode REGION,gen(R)
levelsof R if si!=.,local(R)
mat rownames A = `R' 


/* Exportation sur Excel dans le dossier Resultats_Tab*/
putexcel clear
putexcel set  "$sortie\INPM_EDS_1112", sheet("Année de référence 1998") modify

/* Mise en forme */
putexcel C6 = matrix(A), colnames  nformat(number_d2)
putexcel A7 = matrix(A), rownames





// Proposition Nationale_SEUIL NATIONAL (comporte la version précédente et l'identification)
cap drop si vulnerable sev_pauvre poor
mpi d1(d_educ1 d_satt  d_lit ) w1(0.066 0.066 0.066) d2(d_cm1 d_nutr) w2(0.1 0.1) d3(d_elct d_wtr1 d_sani  d_hsg d_ckfl  d_asst) w3(0.033 0.033 0.033 0.033 0.033 0.033) d4( d_unemp) w4(0.20) d5(Ident) w5(0.20) [pweight=weight]  , cutoff(0.3333) by (region) 




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
mat define FF=r(mat)
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
gen si = (d_educ1 + d_satt + d_li)*0.066 + d_unemp*0.20 + (d_elct + d_wtr1 + d_sani +  d_hsg + d_ckfl + d_asst1)*0.033 + d_cm1*0.20 + id*0.20

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

tab region poor if si!=.,matcell(poor)

mat A = F,G,BB,CC,DD,EE,FF,GG,HH,II,JJ, KK,LL, MM, vulnerable,sev_pauvre, pop, poor[1..$nb_zone,1]


mat colnames A = "H" "MO" "Année de scolarité" "Frequentation scolaire" "Alphabétisation" "Chomage"  "Electricité" "Eau potable" "Toilette" "Logement"  "Energie de cuisson"  "Equipement" "Mortalité juvénile" "Identification"  "Vulnerabilité" "sev_pauvre" "population" "population pauvre mpi"

decode REGION,gen(R)
levelsof R if si!=.,local(R)
mat rownames A = `R' 



/* Exportation sur Excel dans le dossier Resultats_Tab*/
putexcel clear
putexcel set  "$sortie\INPM_EDS_1112", sheet("Proposition nationale") modify


/* Mise en forme */
putexcel C6 = matrix(A), colnames  nformat(number_d2)
putexcel A7 = matrix(A), rownames

*Sauvegarde définitive du Tableau
putexcel save


// Proposition Nationale_SEUIL PNUD (comporte la version précédente et l'identification)
cap drop si vulnerable sev_pauvre poor
mpi d1(d_educ d_satt  d_lit ) w1(0.066 0.066 0.066) d2(d_cm d_nutr) w2(0.1 0.1) d3(d_elct d_wtr d_sani  d_hsg d_ckfl  d_asst) w3(0.033 0.033 0.033 0.033 0.033 0.033) d4( d_unemp) w4(0.20) d5(Ident) w5(0.20) [pweight=weight]  , cutoff(0.3333) by (region) 

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
mat define FF=r(mat)
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
gen si = (d_educ1 + d_satt + d_li)*0.066 + d_unemp*0.20 + (d_elct + d_wtr1 + d_sani +  d_hsg + d_ckfl + d_asst1)*0.033 + d_cm1*0.20 + id*0.20

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

tab region poor if si!=.,matcell(poor)

mat A = F,G,BB,CC,DD,EE,FF,GG,HH,II,JJ, KK,LL, MM, vulnerable,sev_pauvre, pop, poor[1..$nb_zone,1]


mat colnames A = "H" "MO" "Année de scolarité" "Frequentation scolaire" "Alphabétisation" "Chomage"  "Electricité" "Eau potable" "Toilette" "Logement"  "Energie de cuisson"  "Equipement" "Mortalité juvénile" "Identification"  "Vulnerabilité" "sev_pauvre" "population" "population pauvre mpi"


decode REGION,gen(R)
levelsof R if si!=.,local(R)
mat rownames A = `R' 
/* Exportation sur Excel dans le dossier Resultats_Tab*/
putexcel clear
putexcel set  "$sortie\INPM_EDS_1112", sheet("Proposition nationale") modify

/* Mise en forme */
putexcel C6 = matrix(A), colnames  nformat(number_d2)
putexcel A7 = matrix(A), rownames

* Titre du tableau */
putexcel A1 = "Tableau 1  : INPM Global par REGION"
putexcel A1, bold border(bottom)
putexcel (A1:B1), merge 

*En tête colonne du Tableau
putexcel A5 = "REGION"
*putexcel (A2:A4), merge
putexcel B5 = "% de la population"
putexcel C5 = "Borné entre O et 1"
putexcel D5 = "Contribution %"
putexcel E5:O5 = "Contribution %"
putexcel P5:Q5 = "% de la population"
putexcel R5:S5 = "Milliers"

putexcel C4 = "INDICE DE PAUVRETE MULTIDIMENSIONEL, (IPM=H*A)"
putexcel B4 = "Taux d'effectif : Population en situation de pauvreté multidimensionnelle (H)"

putexcel (D4:F4)="EDUCATION", merge
putexcel G4 ="EMPLOI"
putexcel (H4:M4)="CONDITIONS DE VIE", merge 
putexcel N4="SANTE"
putexcel O4="IDENTIFICATION"
putexcel P4="Vulnérables à la pauvreté (qui connaissent une intensité de privations de 20 à 33,33 %)"
putexcel Q4="En situation de pauvreté extrême (avec une intensité supérieure à 50 %)"
putexcel R4="POPULATION TOTALE"
putexcel S4="POPULATION MULTIDIMENSIONELLEMENT PAUVRE"

putexcel (B3:O3)="PAUVRETE MULTIDIMENSIONELLE", merge

putexcel (P3:S3)="POPULATION & VULNERABILITE", merge
putexcel (O4:R4), bold border(bottom)

putexcel (A2:S2), bold border(bottom)
putexcel (A19:S19), bold border(bottom)

putexcel (B4:S4), bold border(bottom)

******************************************************************* MPI AREA ******************************************************************************
// PNUD
cap drop si vulnerable sev_pauvre poor AR

mpi d1(d_satt d_educ) w1(0.1666 0.1666) d2(d_cm d_nutr) w2(0.1666 0.1666) d3(d_elct d_wtr d_sani  d_hsg d_ckfl d_asst) w3(0.056 0.0556  0.0556 0.0556  0.0556  0.0556)  [weight= weight] ,cutoff(0.3333) by (area) 


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

// Vulnerabilté
gen si = (d_satt + d_educ)*0.17 + (d_cm + d_nutr)*0.17 + (d_elct + d_wtr + d_sani +  d_hsg + d_ckfl + d_asst)*0.0556 

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

tab area poor if si!=.,matcell(poor)

mat A = F,G,BB,CC,DD,EE,FF,GG,HH,II,JJ,KK, vulnerable,sev_pauvre, pop, poor[1..$nb_zone,1]


mat colnames A = "H" "MO" "Frequentation scolaire"  "Année de scolarité" "Mortalité juvénile" "Nutrition" "Electricité" "Eau potable" "Toilette" "Logement"  "Energie de cuisson"  "Equipement"  "Vulnerabilité" "sev_pauvre" "population" "population pauvre mpi"


/* Exportation sur Excel dans le dossier Resultats_Tab*/
putexcel clear
putexcel set  "$sortie\INPM_EDS_1112", sheet("ZONE") modify

/* Mise en forme */
putexcel B6 = matrix(A), colnames  nformat(number_d2)
decode area,gen(AR)
levelsof AR if si!=.,local(AR)
mat rownames A = `AR' 


//year of reference 1998

cap drop si vulnerable sev_pauvre poor AR

mpi d1(d_educ1 d_satt  d_lit ) w1(0.083 0.083 0.083) d2(d_cm1) w2(0.25) d3(d_elct water_mdg_1 d_sani  d_hsg d_ckfl  d_asst1) w3(0.041 0.041 0.041 0.041 0.041 0.041) d4( d_unemp) w4(0.25) [weight=weight]   , cutoff (0.3333) by (area)  

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


*Vulnerabilté
gen si = (d_educ1 + d_satt + d_lit)*0.083 + d_cm1*0.25 + (d_elct + d_wtr + d_sani +  d_hsg + d_ckfl + d_asst)*0.041 + d_unemp*0.25

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


*Population
qui tab area if si!=.,matcell(pop)

tab area poor if si!=.,matcell(poor)

mat A = F,G,BB,CC,DD,EE,FF,GG,HH,II,JJ, KK,LL, vulnerable,sev_pauvre, pop, poor[1..$nb_zone,1]

/* Exportation sur Excel dans le dossier Resultats_Tab*/
putexcel clear
putexcel set  "$sortie\INPM_EDS_1112", sheet("ZONE") modify
putexcel B11=matrix(A), nformat(number_d2)
decode area,gen(AR)
levelsof AR if si!=.,local(AR)
mat rownames A = `AR' 

// Proposition nationale
cap drop si vulnerable sev_pauvre poor AR

mpi d1(d_educ1 d_satt  d_lit ) w1(0.066 0.066 0.066) d2(d_cm1) w2(0.20) d3(d_elct d_wtr d_sani  d_hsg d_ckfl  d_asst1) w3(0.033 0.033 0.033 0.033 0.033 0.033) d4( d_unemp) w4(0.20) d5(id) w5(0.20) [weight=weight], cutoff(0.3333) by (area) 
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
gen si = (d_educ1 + d_satt + d_lit)*0.066  + d_cm1*0.20 + (d_elct + d_wtr + d_sani +  d_hsg + d_ckfl + d_asst1)*0.033  + d_unemp*0.20 + id*0.20 

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

tab area poor if si!=.,matcell(poor)

mat A = F,G,BB,CC,DD,EE,FF,GG,HH,II,JJ, KK,LL,MM, vulnerable,sev_pauvre, pop, poor[1..$nb_zone,1]

/* Exportation sur Excel dans le dossier Resultats_Tab*/
putexcel clear
putexcel set  "$sortie\INPM_EDS_1112", sheet("ZONE") modify
putexcel B14=matrix(A), nformat(number_d2)
decode area,gen(AR)
levelsof AR if si!=.,local(AR)
mat rownames A = `AR' 


/* Titre du tableau */
putexcel U1= "REFERENCE"
putexcel (U7:U9)="PNUD", merge
putexcel (U10:U12)="ANNEE DE REFERENCE 1998", merge
putexcel (U14:U16)="PROPOSITION NATIONALE", merge

putexcel A1 = "Tableau 1  : INPM Global par Zone"
putexcel A1, bold border(bottom)
putexcel (A1:B1), merge 

*En tête colonne du Tableau
putexcel A5 = "Référence/zone"
putexcel B5 = "% de la population"
putexcel C5 = "Borné entre O et 1"
putexcel D5 = "Contribution %"
putexcel E5:P5 = "Contribution %"
putexcel Q5:R5 = "% de la population"
putexcel S5:T5 = "Milliers"

putexcel C4 = "INDICE DE PAUVRETE MULTIDIMENSIONELLE, (IPM=H*A)"
putexcel B4 = "Taux d'effectif : Population en situation de pauvreté multidimensionnelle (H)"

putexcel (D4:F4)="EDUCATION", merge
putexcel (G4:H4) ="SANTE", merge
putexcel (I4:N4)="CONDITIONS DE VIE", merge 
putexcel N4="MORTALITE"
putexcel O4="EMPLOI"
putexcel P4="IDENTIFICATION"
putexcel Q4="Vulnérables à la pauvreté (qui connaissent une intensité de privations de 20 à 33,33 %)"
putexcel R4="En situation de pauvreté extrême (avec une intensité supérieure à 50 %)"
putexcel S4="POPULATION TOTALE"
putexcel T4="POPULATION MULTIDIMENSIONELLEMENT PAUVRE"

putexcel (B3:Q3)="PAUVRETE MULTIDIMENSIONELLE", merge
putexcel (A3:U3), bold border(bottom)
putexcel (A4:U4), bold border(bottom)

putexcel Q3="POPULATION & VULNERABILITE"
putexcel (Q3:T3), merge
putexcel (Q3:T3), bold border(bottom)
putexcel (Q4:T4), bold border(bottom)

putexcel (A2:U2), bold border(bottom)
putexcel (A17:U17), bold border(bottom)

*Sauvegarde définitive du Tableau
putexcel save


putexcel close









