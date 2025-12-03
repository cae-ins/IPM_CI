library(haven)
library(data.table)
library(writexl)

# 1. Lire les données et convertir en data.table
df <- setDT(read_dta("Sortie/bf_13112025.dta"))

# 2. Créer la variable de poids
df[, poids := TOTMEN * EW]

# 3. Créer labels pour REGION
region_labels <- attr(df$REGION, "labels")
if (!is.null(region_labels)) {
  region_map <- setNames(names(region_labels), as.character(unname(region_labels)))
  df[, region_label := region_map[as.character(REGION)]]
} else {
  df[, region_label := as.character(REGION)]
}

# 4. Créer labels pour DEPART
depart_labels <- attr(df$DEPART, "labels")
if (!is.null(depart_labels)) {
  depart_map <- setNames(names(depart_labels), as.character(unname(depart_labels)))
  df[, depart_label := depart_map[as.character(DEPART)]]
} else {
  df[, depart_label := as.character(DEPART)]
}

# 5. Créer labels pour SOUSPREFID
sp_labels <- attr(df$SOUSPREFID, "labels")
if (!is.null(sp_labels)) {
  sp_map <- setNames(names(sp_labels), as.character(unname(sp_labels)))
  df[, sp_label := sp_map[as.character(SOUSPREFID)]]
} else {
  df[, sp_label := as.character(SOUSPREFID)]
}

# 6. Récupérer les labels de milieu
milieu_labels <- attr(df$milieu, "labels")
if (!is.null(milieu_labels)) {
  milieu_map <- setNames(names(milieu_labels), as.character(unname(milieu_labels)))
  df[, milieu_label := milieu_map[as.character(milieu)]]
} else {
  df[, milieu_label := fcase(
    milieu == 1, "Abidjan",
    milieu == 2, "Autres Urbain",
    milieu == 3, "Rural",
    default = as.character(milieu)
  )]
}

# 7. Variables binaires
binary_vars <- c(
  "paselec", "paseaup", "combsale", "pasta", "solterre", "toiture",
  "matmur", "logement", "pasequi", "desco", "educ", "educ1", "mfsa",
  "chom", "chom2", "Ident", "decs18", "mjuv"
)

# Vérifier que toutes les variables existent
missing_vars <- setdiff(binary_vars, names(df))
if (length(missing_vars) > 0) {
  stop("Variables manquantes : ", paste(missing_vars, collapse = ", "))
}

# Convertir en numérique
df[, (binary_vars) := lapply(.SD, as.numeric), .SDcols = binary_vars]

# 8a. Calcul par SOUSPREFECTURE seule (tous milieux confondus)
results_sp <- df[, c(
  list(n_observations = .N),
  lapply(.SD, function(x) weighted.mean(x, w = poids, na.rm = TRUE))
), 
by = .(code_region = REGION, 
       nom_region = region_label,
       code_departement = DEPART, 
       nom_departement = depart_label,
       code_sousprefecture = SOUSPREFID, 
       nom_sousprefecture = sp_label),
.SDcols = binary_vars]

# Ajouter la colonne milieu après le calcul
results_sp[, milieu := "Ensemble"]

# 8b. Calcul par SOUSPREFECTURE x MILIEU
results_sp_milieu <- df[, c(
  list(n_observations = .N),
  lapply(.SD, function(x) weighted.mean(x, w = poids, na.rm = TRUE))
), 
by = .(code_region = REGION, 
       nom_region = region_label,
       code_departement = DEPART, 
       nom_departement = depart_label,
       code_sousprefecture = SOUSPREFID, 
       nom_sousprefecture = sp_label,
       milieu = milieu_label),
.SDcols = binary_vars]

# 9. Combiner les deux résultats
results <- rbindlist(list(results_sp, results_sp_milieu), use.names = TRUE)

# 10. Arrondir les proportions
results[, (binary_vars) := lapply(.SD, round, digits = 4), .SDcols = binary_vars]

# 11. Trier les résultats
results[, milieu_order := fcase(
  milieu == "Ensemble", 0,
  milieu == "Abidjan", 1,
  milieu == "Autres Urbain", 2,
  milieu == "Rural", 3,
  default = 4
)]
setorder(results, code_region, code_departement, code_sousprefecture, milieu_order)
results[, milieu_order := NULL]

# 12. Export Excel
write_xlsx(results, "Sortie/binary_proportions_weighted.xlsx")

# 13. Afficher un aperçu
print(head(results, 20))
cat("\n=== Résumé ===\n")
cat("Nombre total de lignes :", nrow(results), "\n")
cat("Nombre de régions :", uniqueN(results$code_region), "\n")
cat("Nombre de départements :", uniqueN(results$code_departement), "\n")
cat("Nombre de sous-préfectures :", uniqueN(results$code_sousprefecture), "\n")
cat("\nRépartition par niveau :\n")
print(results[, .N, by = milieu])
cat("\nFichier exporté avec succès : binary_proportions_weighted.xlsx\n")
