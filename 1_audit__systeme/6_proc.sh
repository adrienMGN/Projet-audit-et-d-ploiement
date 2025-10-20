#!/bin/sh
# top_procs.sh
# Usage: ./top_procs.sh CPU_THRESHOLD MEM_THRESHOLD
CPU_TH=${1:-5}   # défaut 5%
MEM_TH=${2:-5}   # défaut 5%

# Processus au-dessus du seuil CPU
echo "Processes with CPU > $CPU_TH%:"
ps -eo pid,user,comm,pcpu,pmem --sort=-pcpu | awk -v th="$CPU_TH" 'NR==1{print;next} $4+0>th{printf "%s\t%s\t%s\t%s%%\t%s%%\n",$1,$2,$3,$4,$5}'

# Processus au-dessus du seuil MEM
echo
echo "Processes with MEM > $MEM_TH%:"
ps -eo pid,user,comm,pcpu,pmem --sort=-pmem | awk -v th="$MEM_TH" 'NR==1{print;next} $5+0>th{printf "%s\t%s\t%s\t%s%%\t%s%%\n",$1,$2,$3,$4,$5}'

# Explications complémentaires
# La commande `ps` avec les options `-eo` permet de spécifier les colonnes à afficher :
# - pid : ID du processus
# - user : utilisateur propriétaire du processus
# - comm : nom de la commande
# - pcpu : pourcentage d'utilisation CPU
# - pmem : pourcentage d'utilisation mémoire
# L'option `--sort` permet de trier les processus par utilisation CPU ou mémoire
# Le filtrage est effectué avec `awk` pour n'afficher que les processus
# dépassant les seuils spécifiés en arguments.
# Si aucun argument n'est fourni, les seuils par défaut sont de 5% pour CPU et mémoire.
# détails awk : 
# - NR==1{print;next} : affiche la première ligne (en-tête) sans filtrage
# - $4+0>th : filtre les lignes où la 4ème colonne (pcpu) est supérieure au seuil CPU
# - $5+0>th : filtre les lignes où la 5ème colonne (pmem) est supérieure au seuil mémoire
# - printf : formatte la sortie pour une meilleure lisibilité