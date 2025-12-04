library(haven)
library(data.table)

# ===== CONFIGURATION =====
# Chemins des fichiers
fichier_menage <- "data/data_out/final_data.dta"  # Base ménage finale
fichier_individu <- "data/data_in/IPM_Data_191125.dta"  # Base individuelle temporaire
fichier_sortie <- "data/data_out/individus_final.dta"  # Base individuelle filtrée

# Variables composant l'identifiant ménage
id_vars <- c("SOUSPREFID", "P04", "P08", "P05", "P07", "P09", "P09A", "P09B", "P10", "DEPART", "REGION")

# ===== LECTURE DES DONNÉES =====
cat("=== Chargement des données ===\n")

# Lire la base ménage finale
menage <- setDT(read_dta(fichier_menage))
cat("Base ménage chargée :", nrow(menage), "ménages\n")

# Lire la base individuelle temporaire
individu <- setDT(read_dta(fichier_individu))
cat("Base individuelle chargée :", nrow(individu), "individus\n")

# ===== VÉRIFICATIONS =====
cat("\n=== Vérifications ===\n")

# Vérifier que toutes les variables de jonction existent dans les deux bases
missing_menage <- setdiff(id_vars, names(menage))
missing_individu <- setdiff(id_vars, names(individu))

if (length(missing_menage) > 0) {
  stop("Variables manquantes dans la base ménage : ", paste(missing_menage, collapse = ", "))
}
if (length(missing_individu) > 0) {
  stop("Variables manquantes dans la base individuelle : ", paste(missing_individu, collapse = ", "))
}

cat("Toutes les variables de jonction sont présentes dans les deux bases.\n")

# ===== CRÉATION D'UN IDENTIFIANT UNIQUE TEMPORAIRE =====
cat("\n=== Création de l'identifiant ménage composite ===\n")

# Créer un identifiant unique pour chaque ménage (concaténation des variables)
menage[, id_menage_temp := do.call(paste, c(.SD, sep = "_")), .SDcols = id_vars]
individu[, id_menage_temp := do.call(paste, c(.SD, sep = "_")), .SDcols = id_vars]

cat("Nombre de ménages uniques (base ménage) :", uniqueN(menage$id_menage_temp), "\n")
cat("Nombre de ménages uniques (base individuelle) :", uniqueN(individu$id_menage_temp), "\n")

# ===== IDENTIFICATION DES INDIVIDUS À SUPPRIMER =====
cat("\n=== Identification des individus à supprimer ===\n")

# Individus dont le ménage n'existe pas dans la base ménage finale
individus_sans_menage <- individu[!id_menage_temp %in% menage$id_menage_temp]
n_individus_supprimes <- nrow(individus_sans_menage)

cat("Individus à supprimer (sans ménage dans base finale) :", n_individus_supprimes, "\n")

if (n_individus_supprimes > 0) {
  cat("\nAperçu des ménages concernés :\n")
  menages_absents <- individus_sans_menage[, .(n_individus = .N), by = id_vars]
  print(head(menages_absents, 10))
  
  # Sauvegarder la liste des individus supprimés
  write_dta(individus_sans_menage, "Sortie/individus_supprimes.dta")
  cat("\nListe des individus supprimés sauvegardée : individus_supprimes.dta\n")
}

# ===== FILTRAGE DES INDIVIDUS =====
cat("\n=== Filtrage des individus ===\n")

# Garder uniquement les individus dont le ménage existe dans la base finale
individu_filtre <- individu[id_menage_temp %in% menage$id_menage_temp]

# Supprimer l'identifiant temporaire
individu_filtre[, id_menage_temp := NULL]

cat("Individus conservés :", nrow(individu_filtre), "\n")
cat("Individus supprimés :", n_individus_supprimes, "\n")
cat("Taux de conservation :", round(100 * nrow(individu_filtre) / nrow(individu), 2), "%\n")

# ===== EXPORT =====
cat("\n=== Export de la base finale ===\n")

write_dta(individu_filtre, fichier_sortie)
cat("Base individuelle filtrée exportée :", fichier_sortie, "\n")

# ===== RÉSUMÉ FINAL =====
cat("\n=== RÉSUMÉ FINAL ===\n")
cat("Base ménage (référence) :", nrow(menage), "ménages\n")
cat("Base individuelle initiale :", nrow(individu), "individus\n")
cat("Individus supprimés :", n_individus_supprimes, 
    "(", round(100 * n_individus_supprimes / nrow(individu), 2), "%)\n")
cat("Base individuelle finale :", nrow(individu_filtre), "individus\n")
cat("Nombre de variables :", ncol(individu_filtre), "(inchangé)\n")

# Statistiques par ménage dans la base filtrée
individu_filtre[, id_menage_check := do.call(paste, c(.SD, sep = "_")), .SDcols = id_vars]
cat("\nMénages uniques dans base individuelle filtrée :", uniqueN(individu_filtre$id_menage_check), "\n")

stats_menage <- individu_filtre[, .(n_individus = .N), by = id_vars]
cat("\nStatistiques taille des ménages :\n")
cat("  Nombre de ménages :", nrow(stats_menage), "\n")
cat("  Taille min :", min(stats_menage$n_individus), "\n")
cat("  Taille max :", max(stats_menage$n_individus), "\n")
cat("  Taille moyenne :", round(mean(stats_menage$n_individus), 2), "\n")
cat("  Taille médiane :", median(stats_menage$n_individus), "\n")

# Distribution de la taille des ménages
cat("\nDistribution de la taille des ménages :\n")
print(stats_menage[, .N, by = n_individus][order(n_individus)])

# Nettoyer l'identifiant temporaire
individu_filtre[, id_menage_check := NULL]

cat("\n=== Opération terminée avec succès! ===\n")
cat("Le fichier individuel filtré conserve toutes ses variables originales.\n")