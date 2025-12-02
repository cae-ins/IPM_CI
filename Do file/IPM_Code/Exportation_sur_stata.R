# Charger la biblioth??que haven pour lire les fichiers SPSS
library(haven)

# Chemin du dossier contenant les fichiers SPSS
dossier_spss <- "C:/Users/Dell/OneDrive/Bureau/PHAS/IPM-CI/RGPH/RGPH 2021/Bases brutes/Decoupage_REGIONRP21spss"

# Chemin du dossier o?? vous souhaitez sauvegarder les fichiers Stata
dossier_stata <- "C:/Users/Dell/OneDrive/Bureau/PHAS/IPM-CI/RGPH/RGPH 2021/Bases brutes/Decoupage_REGIONRP21stata"

# Liste des fichiers SPSS dans le dossier
fichiers_spss <- list.files(path = dossier_spss, pattern = "\\.sav$", full.names = TRUE)

# Boucle ?? travers chaque fichier SPSS
for (fichier_spss in fichiers_spss) {
  # Charger le fichier SPSS
  data <- read_sav(fichier_spss)
  
  # Extraire le nom du fichier sans extension
  nom_fichier <- tools::file_path_sans_ext(basename(fichier_spss))
  
  # Sauvegarder le fichier au format Stata
  write_dta(data, file.path(dossier_stata, paste0(nom_fichier, ".dta")))
}
