********************************************************************************
/*
 Cote d'Ivoire EHCVM 2018 
[STATA do-file]. 
*/
********************************************************************************

clear all 
set more off
set maxvar 10000

*** Chemins d'accès des dossiers de travail ***

global data_raw "C:\Users\omen\OneDrive - GOUVCI (1)\INS_JOB\DATABASES" //A adapter
global data_rawehcvm18 "$data_raw\Complement\EHCVM_CIV_200421\New (tx 39.40)" 
global datain_rawehcvm18 "$data_rawehcvm18\Datain"
global datain_men "$datain_rawehcvm18\Menage"
global datain_com "$datain_rawehcvm18\Commune"
global datain_aux "$datain_rawehcvm18\Auxiliaire"

global dataout_rawehcvm18 "$data_rawehcvm18 \Dataout"

global chemin_perso "C:\Users\omen\OneDrive - GOUVCI (1)\CAE_INS\IPM\INPM" //A adapter

global projet "$chemin_perso\Data_results"
global data_inpm "$projet\Data"
global data_temp18 "$data\Data2018"
*global bases_reg_ind98 "$data_temp98\bases_reg_ind98"
*global bases_reg_ind98_treated "$bases_reg_ind98 \treated"
global result "$projet\Resultats"
global result18 "$Resultats\res18"

global log_inpm "$projet\Log"

********************************************************************************
*** COTE D'IVOIRE EHCVM 2018  ***
********************************************************************************
use "C:\Users\omen\OneDrive - GOUVCI (1)\INS_JOB\DATABASES\Complement\EHCVM_CIV_200421\New (tx 39.40)\datain\Menage\s12_me_CIV2018.dta"
*****Potential household indicators 
/*

Alkire, S., & Kanagaratnam, U. (2021). Revisions of the global multidimensional poverty index: indicator options and their empirical assessment. Oxford Development Studies, 49(2), 169-183.

Ce article propose une liste de trente-trois indicateurs potentiels à inclure dans ceux 
de l'analyse de la pauvreté multidimensionnnelle.

A-Household has access to information technology

or Internet access

collapse 

Smartphone 
35:Téléphone portable, //Alkire et Kabagaratnam (2021) parle de "smartphone", s12q02,03

B-Small physical assets: 
Сatégories: 
1:Salon (Fauteuils et table basse), 
2:Table à manger (table + chaises), //Alkire et Kabagaratnam (2021), 
3:Lit, //Alkire et Kabagaratnam (2021), 
4:Matelas simple, 
5:Armoires et autres meubles, //Alkire et Kabagaratnam (2021), 
6:Tapis, 

C-Household has electrical assets
7:Fer à repasser électrique, 
 
9:Cuisinière à gaz ou électrique, 
10:Bonbonne de gaz, 
11:Réchaud (plaque) à gaz ou électrique, 
12:Four à micro-onde ou électrique, 
13:Foyers améliorés, 
14:Robot de cuisine électrique (Moulinex), 
15:Mixeur/Presse-fruits non électrique, 
16:Réfrigérateur, 
17:Congélateur, 
18:Ventilateur sur pied, 
19:Radio simple/Radiocassette, 
20:Appareil TV, 
21:Magnétoscope/CD/DVD, 
22:Antenne parabolique / décodeur, 
23:Lave-linge, sèche linge, 
24:Aspirateur, 
25:Climatiseurs/splits, 
26:Tondeuse à gazon et autre article de jardinage, 
27:Groupe électrogène, 
28:Voiture personnelle, 
29:Cyclomoteur/Vélomoteur, motocyclette, 
30:Bicyclette, 
31:Appareil photo, 
32:Camescope, 
33:Chaîne Hi Fi, 
34:Téléphone fixe, 

36:Tablette, 
37:Ordinateur, //Alkire et Kabagaratnam (2021), 
38:Imprimante/Fax, 
39:Caméra Vidéo,
40:Pirogue et hors-bord (bateaux de plaisance), 
41:Fusils de chasse, 
42:Guitare, 
43:Piano et autre appareil de musique, 
44:Immeuble/Maison, 
45:Terrain non bâti
*/



********************************************************************************
*** Step 1: Data preparation 
*** Selecting main variables from CH, WM, HH & MN recode & merging with HL recode 
********************************************************************************


********************************************************************************
*** Step 1.6 HH - HOUSEHOLD RECODE 
***(All households interviewed) 
********************************************************************************

use "$path_in/hh.dta", clear 
	
rename _all, lower	


*** Generate individual unique key variable required for data merging
*** hh1=cluster number;  
*** hh2=household number; 
gen	double hh_id = hh1*100 + hh2 
format	hh_id %20.0g
lab var hh_id "Household ID"

save "$path_out/CIV16_HH.dta", replace



********************************************************************************
*** Step 1.7 HL - HOUSEHOLD MEMBER  
********************************************************************************

use "$path_in/hl.dta", clear 

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
merge 1:1 ind_id using "$path_out/CIV16_BH.dta"
drop _merge
erase "$path_out/CIV16_BH.dta" 
 
 
*** Merging WM Recode 
*****************************************
merge 1:1 ind_id using "$path_out/CIV16_WM.dta"
drop _merge
erase "$path_out/CIV16_WM.dta"



*** Merging WM Recode: 15-19 years girls 
*****************************************
merge 1:1 ind_id using "$path_out/CIV16_WM_girls.dta"
drop _merge
erase "$path_out/CIV16_WM_girls.dta"



*** Merging HH Recode 
*****************************************
merge m:1 hh_id using "$path_out/CIV16_HH.dta"
tab hh9 if _m==2
drop  if _merge==2
	//Drop households that were not interviewed 
drop _merge
erase "$path_out/CIV16_HH.dta"



*** Merging MN Recode 
*****************************************
merge 1:1 ind_id using "$path_out/CIV16_MN.dta"
drop _merge
erase "$path_out/CIV16_MN.dta"



*** Merging CH Recode 
*****************************************
merge 1:1 ind_id using "$path_out/CIV16_CH.dta"
drop _merge
erase "$path_out/CIV16_CH.dta"

sort ind_id



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


	/*In this survey, the harmonised 'region_01' variable is the 
	same as the standardised 'region' variable.*/	
clonevar region_01 = region 

						 
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


*** Standard MPI ***
/*The entire household is considered deprived if no eligible 
household member has completed SIX years of schooling. */
******************************************************************* 
gen	 years_edu6 = (eduyears>=6)
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
clonevar animal_cart = hc9e


foreach var in television radio telephone mobiletelephone refrigerator ///
			   car bicycle motorbike computer animal_cart  {
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
 
 
	//Generate presence of subsample
gen subsample = .
 

*** Keep main variables require for MPI calculation ***
keep hh_id ind_id subsample strata psu weight weight_ch sex age hhsize ///
area agec7 agec4 agec2 headship marital_wom marital_men relationship ///
region region_01 year_interview month_interview date_interview /// 
no_fem_eligible no_male_eligible child_eligible no_child_eligible ///
eduyears no_missing_edu hh_years_edu6 hh_years_edu_u ///
attendance child_schoolage no_missing_atten hh_child_atten hh_child_atten_u ///
fem_nutri_eligible no_fem_nutri_eligible no_child_fem_eligible ///
underweight stunting wasting underweight_u stunting_u wasting_u ///
low_bmiage low_bmiage_u low_bmi_byage f_bmi ///
hh_no_low_bmiage hh_no_low_bmiage_u ///
hh_no_underweight hh_no_stunting hh_no_wasting hh_no_uw_st ///
hh_no_underweight_u hh_no_stunting_u hh_no_wasting_u hh_no_uw_st_u ///
hh_nutrition_uw_st hh_nutrition_uw_st_u ///
child_mortality hh_mortality_u18_5y hh_mortality_u ///
electricity electricity_u toilet toilet_mdg shared_toilet toilet_u ///
water timetowater ndwater water_mdg water_u floor wall roof ///
floor_imp wall_imp roof_imp housing_1 housing_u ///
cookingfuel cooking_mdg cooking_u television radio telephone ///
refrigerator car bicycle motorbike animal_cart computer ///
n_small_assets2 hh_assets2 hh_assets2_u ///
water_mdg_c water_u_c

	 
*** Order file	***
order hh_id ind_id subsample strata psu weight weight_ch sex age hhsize ///
area agec7 agec4 agec2 headship marital_wom marital_men relationship ///
region region_01 year_interview month_interview date_interview /// 
no_fem_eligible no_male_eligible child_eligible no_child_eligible ///
eduyears no_missing_edu hh_years_edu6 hh_years_edu_u ///
attendance child_schoolage no_missing_atten hh_child_atten hh_child_atten_u ///
fem_nutri_eligible no_fem_nutri_eligible no_child_fem_eligible ///
underweight stunting wasting underweight_u stunting_u wasting_u ///
low_bmiage low_bmiage_u low_bmi_byage f_bmi ///
hh_no_low_bmiage hh_no_low_bmiage_u ///
hh_no_underweight hh_no_stunting hh_no_wasting hh_no_uw_st ///
hh_no_underweight_u hh_no_stunting_u hh_no_wasting_u hh_no_uw_st_u ///
hh_nutrition_uw_st hh_nutrition_uw_st_u ///
child_mortality hh_mortality_u18_5y hh_mortality_u ///
electricity electricity_u toilet toilet_mdg shared_toilet toilet_u ///
water timetowater ndwater water_mdg water_u floor wall roof ///
floor_imp wall_imp roof_imp housing_1 housing_u ///
cookingfuel cooking_mdg cooking_u television radio telephone ///
refrigerator car bicycle motorbike animal_cart computer ///
n_small_assets2 hh_assets2 hh_assets2_u ///
water_mdg_c water_u_c



*** Rename key global MPI indicators for estimation ***
recode hh_mortality_u18_5y  (0=1)(1=0) , gen(d_cm)
recode hh_nutrition_uw_st 	(0=1)(1=0) , gen(d_nutr)
recode hh_child_atten 		(0=1)(1=0) , gen(d_satt)
recode hh_years_edu6 		(0=1)(1=0) , gen(d_educ)
recode electricity 			(0=1)(1=0) , gen(d_elct)
recode water_mdg 			(0=1)(1=0) , gen(d_wtr)
recode toilet_mdg 			(0=1)(1=0) , gen(d_sani)
recode housing_1 			(0=1)(1=0) , gen(d_hsg)
recode cooking_mdg 			(0=1)(1=0) , gen(d_ckfl)
recode hh_assets2 			(0=1)(1=0) , gen(d_asst)
 


*** Rename key global MPI indicators for destitution estimation ***
recode hh_mortality_u       (0=1)(1=0) , gen(dst_cm)
recode hh_nutrition_uw_st_u (0=1)(1=0) , gen(dst_nutr)
recode hh_child_atten_u 	(0=1)(1=0) , gen(dst_satt)
recode hh_years_edu_u 		(0=1)(1=0) , gen(dst_educ)
recode electricity_u		(0=1)(1=0) , gen(dst_elct)
recode water_u 			    (0=1)(1=0) , gen(dst_wtr)
recode toilet_u 			(0=1)(1=0) , gen(dst_sani)
recode housing_u 			(0=1)(1=0) , gen(dst_hsg)
recode cooking_u			(0=1)(1=0) , gen(dst_ckfl)
recode hh_assets2_u 		(0=1)(1=0) , gen(dst_asst) 


*** Rename indicators for changes over time estimation ***	
recode hh_mortality_u18_5y  (0=1)(1=0) , gen(d_cm_01)
recode hh_nutrition_uw_st 	(0=1)(1=0) , gen(d_nutr_01)
recode hh_child_atten 		(0=1)(1=0) , gen(d_satt_01)
recode hh_years_edu6 		(0=1)(1=0) , gen(d_educ_01)
recode electricity 			(0=1)(1=0) , gen(d_elct_01)
recode water_mdg_c 			(0=1)(1=0) , gen(d_wtr_01)
recode toilet_mdg 			(0=1)(1=0) , gen(d_sani_01)
recode housing_1 			(0=1)(1=0) , gen(d_hsg_01)
recode cooking_mdg 			(0=1)(1=0) , gen(d_ckfl_01)
recode hh_assets2 			(0=1)(1=0) , gen(d_asst_01)	
	

recode hh_mortality_u       (0=1)(1=0) , gen(dst_cm_01)
recode hh_nutrition_uw_st_u (0=1)(1=0) , gen(dst_nutr_01)
recode hh_child_atten_u 	(0=1)(1=0) , gen(dst_satt_01)
recode hh_years_edu_u 		(0=1)(1=0) , gen(dst_educ_01)
recode electricity_u		(0=1)(1=0) , gen(dst_elct_01)
recode water_u_c	 		(0=1)(1=0) , gen(dst_wtr_01)
recode toilet_u 			(0=1)(1=0) , gen(dst_sani_01)
recode housing_u 			(0=1)(1=0) , gen(dst_hsg_01)
recode cooking_u			(0=1)(1=0) , gen(dst_ckfl_01)
recode hh_assets2_u 		(0=1)(1=0) , gen(dst_asst_01)


*** Eligibility for years of schooling indicator ***
gen educ_elig = 1 
replace educ_elig = 0 if age < 10 
label define lab_educ_elig 0"ineligible" 1"eligible"  
label values educ_elig lab_educ_elig
lab var educ_elig "Individual is eligible for educ indicator"
ta eduyears educ_elig,m


*** Generate coutry and survey details for estimation ***
char _dta[cty] "Côte d'Ivoire"
char _dta[ccty] "CIV"
char _dta[year] "2016" 	
char _dta[survey] "MICS"
char _dta[ccnum] "384"
char _dta[type] "micro"



*** Sort, compress and save data for estimation ***
sort ind_id
compress
la da "Micro data for `_dta[ccty]' (`_dta[ccnum]') from `c(current_date)' (`c(current_time)')."
save "$path_out/civ_mics16.dta", replace 
