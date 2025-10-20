#!/bin/bash

##############################################
# Script : Affichage de l’espace disque
# Description :
#   Ce script affiche l’espace disque utilisé
#   et disponible sur chaque partition du système.
##############################################

# --- Espace disque par partition (disponible, utilisé) ---
# La commande `df` indique les quantités d’espace disque utilisées et disponibles
# sur les systèmes de fichiers montés.
# L’option `-h` permet d’afficher les valeurs dans un format lisible pour l’humain (Ko, Mo, Go).
echo "=== Espace disque par systèmes de fichiers montés==="
df -h

echo ""
echo "=== Partitions physiques/virtuelles uniquement ==="
# Pour afficher uniquement les partitions physiques ou virtuelles,
# on filtre les résultats avec `grep`.
# - L’option `-E` permet d’utiliser des expressions régulières étendues.
# - On sélectionne :
#     - la ligne d’en-tête (commençant par “Filesystem”)
#     - les lignes commençant par “/dev/” (qui correspondent aux partitions)
df -h | grep -E "^Filesystem|^/dev/" --color=never


##############################################
# Explications complémentaires
##############################################

# Pourquoi les partitions apparaissent dans “Système de fichiers” :
# Dans Linux, *tout est un fichier*.
# Les disques, partitions et systèmes de fichiers sont représentés comme
# des fichiers spéciaux situés dans le répertoire /dev.

# Définition d’un système de fichiers :
# Ce n’est pas un disque en lui-même, mais une structure logique utilisée
# pour stocker et organiser les fichiers sur un support (ex : ext4, xfs, vfat, ntfs...).

# Pourquoi `df` affiche les partitions dans la colonne “Système de fichiers” :
# Cette colonne ne désigne pas le *type* de système de fichiers (comme ext4),
# mais *quel système de fichiers est monté* à cet emplacement.
# En d’autres termes, elle indique le périphérique ou le volume logique
# qui contient le système de fichiers monté.
