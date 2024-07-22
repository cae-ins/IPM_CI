
cls
args region_data

use  "`region_data'", replace

sort $list_var_menage

egen w = count(P14), by($list_var_menage)
*br TOTMEN w 

keep if P17_LIENPARENTE==1

keep $list_var_menage DE59_DECES TOTMEN w

save "$sortie\Treated_1\\`region_data'_treated.dta", replace