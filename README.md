# Description

Ce dépôt contient l'implémentation d'un convertisseur Mardown vers HTML.

# Pré requis

* [Pandoc](https://pandoc.org/). 
  La version pour Windows peut être téléchargée [ici](https://github.com/jgm/pandoc/releases/tag/2.9.1.1).
* Perl. La version pour Windows peut être téléchargée [ici](http://strawberryperl.com/).

# Utilisation

Pour convertir l'ensemble des documents Markdown d'un dossier, il suffit de suivre la procédure suivante:

* Copier les fichiers `md2html.pl` et `pandoc.css` dans le dossier qui contient les fichiers Markdown à convertir.
* Editer le fichier `md2html.pl` et renseigner la valeur de la variable `PANDOC`.
  Vous devez indiquer le chemin vers l'exécutable `pandoc`.
  Sous MSDOS, pour afficher le chemin vers l'exécutable `pandoc`: `where pandoc`.
* Lancer le script `md2html.pl`: `perl md2html.pl --verbose`. 


