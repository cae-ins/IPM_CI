// Cette base provient du bureau des demographes (voir Aminata ou Doyen Touré)

use "C:\CAE_IPM\Sortie\bf.dta", clear

mpi d1(desco educ mfsa) w1(0.066 0.066 0.066) d2(chom) w2(0.2) d3(paselec paseaup combsale pasta logement pasequi) w3(0.033 0.033 0.033 0.033 0.033 0.033) d4(mjuv) w4(0.2) d5(Ident) w5(0.2) [fw=TOTMEN], cutoff(0.3333) 

clear 

input str90 Contribution valeur
"Frequentation scolaire"		10.8
"Années de scolarité"			14.1
"Alphabétisation"				9.2
"Chomage"						3.8
"Electricité"					2.4
"Eau potable"					2.8
"Energie de cuisson"			7.1
"Toilette"					    4.7
"Logement"						4.1
"Equipement"					2.0
"Mortalité Juvénile"			3.2
"Identification"			   35.8
end
sort valeur
graph hbar valeur , over(Contribution) blabel (bar, color(black))