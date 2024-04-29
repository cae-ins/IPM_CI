use "C:\Users\elodi\OneDrive\DATABASES\MKR\rgph_individu.dta"
tab I01_REGI, nolab
forval k= 1 / 19 {
	preserve
	keep if I01_REGI==`k'
	save "C:\Users\elodi\OneDrive\DATABASES\MKR\rgph98_ind_R`k'.dta"
	restore
}
