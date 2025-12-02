# Indice National de Pauvreté Multidimensionnelle Côte d'Ivoire

Analyse reproductible de l'Indice de Pauvreté Multidimensionnelle (IPM) — Côte d'Ivoire

Ce dépôt regroupe les scripts d’extraction, nettoyage, calculs et production des résultats (principalement en Stata) pour calculer et documenter l’IPM et les indicateurs associés à partir de différentes enquêtes et recensements.

---

## 📌 But du dépôt

- Centraliser les scripts et les jeux de données nécessaires pour reproduire les calculs de l’IPM.
- Fournir des workflows automatisés (fichiers .do) pour :
  - Calcul des privations et indicateurs associés
  - Calcul de l’IPM au niveau ménage / milieu / région
  - Génération d’outputs, logs et exports pour rapports et visualisations

---

## 📁 Structure principale (extrait)

- `Codes/` — Scripts Stata organisés par enquête / source (ex. `MICS`, `EDS1112`, `rgph2014`, `rp2021`, `EHCVM`).
- `Do file/` — Do-files maîtres, automatisation et scripts utilitaires.
  - Exemple : `Do file\IPM_Code\v2\VF\master.do` — fichier maître qui orchestre le calcul des privations et de l’IPM.
- `Data/` — Données d’entrée (.dta, .sav). Ex. `IPM_Data_191125.dta`, `MORTALITE_RP2021_TRAITEMENT.dta`.
- `Sortie/` — Fichiers de sortie générés (.dta) par les workflows.
- `Log/` — Logs d’exécution des scripts.
- `Resultats/` — Résultats finaux et exports organisés par enquête/version.

---

## 🔧 Prérequis

- Stata (recommandé : Stata 15+ ; IC/SE/MP selon taille des jeux de données).
- Espace disque suffisant pour les jeux de données et résultats.
- (Optionnel) Git pour versionner les modifications.

---

## ▶️ Exécution — guide rapide

1. Placez les fichiers de données brutes dans `Data/`.
2. Ouvrez Stata (ou exécutez en batch). Exemple (Windows PowerShell) :

```powershell
"C:\Program Files\Stata17\StataSE-64.exe" /e do "C:\Users\f.migone\Desktop\projects\IPM_CI\Do file\IPM_Code\v2\VF\master.do"
```

3. Vous pouvez aussi lancer `Do file\IPM_Code\v2\VF\master.do` directement depuis l’interface Do-file Editor de Stata.
4. Vérifiez les logs dans `Log/` et les résultats dans `Sortie/` et `Resultats/`.

Remarque : `master.do` utilise des variables globales (ex. `projet`) et inclut plusieurs fichiers `.do` — adaptez les chemins si vous changez la structure.

---

## 🛡️ Données & confidentialité

- Les jeux de données présents sont (souvent) sensibles. Vérifiez les droits de diffusion et procédez à l’anonymisation si nécessaire avant toute publication.
- Évitez de committer des fichiers de données non anonymisés dans un dépôt public.

---

## 🧭 Bonnes pratiques & reproductibilité

- Conserver les données brutes dans `Data/` et enregistrer les outputs dans `Sortie/` et `Resultats/`.
- Préférer des chemins relatifs ou des variables de configuration plutôt que des chemins absolus dans les dofiles.
- Documenter toute modification majeure via des commits et des fichiers README locaux (p. ex. `Do file/IPM_Code/v2/VF/README.md`).

---

## 📎 Fichiers importants

- `Do file\IPM_Code\v2\VF\master.do` — Orchestration principale (privations + IPM).
- `Extraction_Variables_IPM*.sps` — Scripts SPSS d’extraction / préparation.
- `Rename_Variables.do` / `Rename_Variables_21112025.do` — Harmonisation / renommage des variables.
- `Data/*.dta` — Données par région, jeux IPM, traitements.

---

## 🤝 Contribuer

1. Fork → créer une branche → modifier → ouvrir une Pull Request.
2. Expliquer les tests et les résultats attendus dans la description du PR.
3. Pour un nouveau workflow, ajoutez un petit README dans le sous-dossier concerné.

---

## 📞 Contact

Pour toute question technique, contacter : 
- a.djaha@stat.plan.gouv.ci ;
- j.migone@stat.plan.gouv.ci ;
- cae@stat.plan.gouv.ci.

---


