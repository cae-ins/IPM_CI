** Indice de Pauvreté Multi-dimensionnel (IPM)
import spss in 1/27984405 using "C:\CAE_IPM\IPM_Data_110924.sav", clear

save "C:/CAE_IPM/Data/IPM_Data_110924.dta", replace

rename REGION_NEW REGION
rename DEPART_NEW DEPART
rename SOUSPREFID_NEW SOUSPREFID
rename P18BCONTROL_New P18A_AGE
rename P30A_NEW P30A
rename P32_NEW P32
rename P34ANEWTBB P34A
rename P34BNEWtb P34B
rename P34BAUTNEW P34BAUT
rename P34CNEWtbb p34C
rename P34DNEWtbB P34D
rename P34ENEWtbB P34E
rename P55AA P55A
rename P55BB P55B
rename P55CC P55C
rename P55DD P55D
rename P55EE P55E
rename P55FF P55F
rename P55GG P55G
rename P55HH P55H
rename P56AA P56A
rename P56BB P56B
rename P56CC P56C
rename P56DD P56D
rename P56EE P56E
rename P56FF P56F
rename P56GG P56G
rename P56HH P56H
rename P56II P56I
rename P56JJ P56J
rename P57AA P57A
rename P57BB P57B
rename P57CC P57C
rename P57DD P57D
rename P57EE P57E
rename P57FF P57F
rename P57GG P57G
rename P57HH P57H
rename P57II P57I
rename P57JJ P57J
rename P57KK P57K
rename P57LL P57L

save "C:/CAE_IPM/Data/IPM_Data_131124.dta", replace
