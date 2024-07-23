# IPM_CI

**IPM_CI** est un dépôt GitHub privé dédié à la gestion, l'analyse et la visualisation des données issues de différentes enquêtes et recensements pour la réalisation de l'Indice de Pauvreté Multidimensionnelle (IPM) de Côte d'Ivoire. Ce projet utilise principalement le logiciel Stata pour les analyses statistiques et les automatisations de calcul.

## Structure du dépôt

Le dépôt est structuré comme suit :

### Dossiers principaux

- **Codes** : Contient les scripts Stata pour différents ensembles de données ou projets.
  - `EDS1112` : Scripts pour l'enquête EDS 2011-2012.
  - `EHCVM` : Scripts pour l'enquête EHCVM.
  - `MICS` : Scripts pour l'enquête MICS.
  - `rgph1998` : Scripts pour le recensement général de la population et de l'habitat de 1998.
  - `rgph2014` : Scripts pour le recensement général de la population et de l'habitat de 2014.
    - `Old` : Versions antérieures des scripts ou fichiers archivés.
  - `rp2021` : Scripts pour le recensement ou projet de 2021.
- **Log** : Contient les fichiers journaux des différentes analyses.
- **Resultats** : Contient les résultats des analyses.

### Fichiers

- **.gitignore** : Liste des fichiers et répertoires à ignorer par Git.
- **README.md** : Ce fichier, fournissant une vue d'ensemble du projet.

## Utilisation

### Pré-requis

- [Stata](https://www.stata.com/) installé sur votre machine.
- Cloner le dépôt sur votre machine locale.

### Clonage du dépôt

Utilisez la commande suivante pour cloner le dépôt :

```bash
git clone https://github.com/votre-utilisateur/IPM_CI.git
```

Exécution des scripts
1. Naviguez vers le répertoire Codes :
```bash
cd IPM_CI/Codes
```

2. Sélectionnez le sous-répertoire correspondant à l'ensemble de données ou projet que vous souhaitez analyser, par exemple 
```bash
cd rgph2014
```
3. Ouvrez le fichier .do correspondant dans Stata et exécutez-le.

## Contributing
Les contributions sont les bienvenues. Veuillez suivre les étapes suivantes pour contribuer :

### Fork ce dépôt.
Créez une branche pour votre fonctionnalité ou correctif (git checkout -b feature/amazing-feature).
Commitez vos modifications (git commit -m 'Add some amazing feature').
Poussez vers la branche (git push origin feature/amazing-feature).
Ouvrez une Pull Request.

## Contact
Pour toute question, veuillez contacter Armand Djaha, a.djaha@stat.plan.gouv.ci .
