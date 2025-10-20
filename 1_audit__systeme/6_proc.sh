#!/usr/bin/env sh

# script qui donne les processus les plus consommateurs de CPU et de mémoire (paramétrer par un seuil)

# paramètres (1 mini)
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <CPU threshold> <RAM threshold>"
    exit 1
fi

# seuils donnés en paramètre
CPU_THRESHOLD=$1
RAM_THRESHOLD=$2

# fonction checkProc Vérifie la charge CPU et RAM pour chaque processus
checkProc() {
    echo "Processus dépassant le seuil CPU de $CPU_THRESHOLD% ou RAM de $RAM_THRESHOLD% :"
    echo "------------------------------------------------------------"
    # ps pour obtenir la liste des processus avec leur utilisation CPU et RAM
    # --no-headers pour ne pas afficher l'en-tête -e pour tous les processus -o pour format personnalisé
    ps -eo pid,comm,%cpu,%mem --no-headers | while read -r pid comm cpu mem; do
        # comparaison des valeurs actuelles avec les seuils donnés en paramètre
        # Convertir en entiers en multipliant par 10 pour gérer les décimales
        # bc pour les calculs flottants
        cpu_int=$(echo "$cpu * 10" | bc | cut -d. -f1)
        mem_int=$(echo "$mem * 10" | bc | cut -d. -f1)
        cpu_threshold_int=$(echo "$CPU_THRESHOLD * 10" | bc | cut -d. -f1)
        mem_threshold_int=$(echo "$RAM_THRESHOLD * 10" | bc | cut -d. -f1)

        # compare et affiche si dépassement
        if [ "$cpu_int" -ge "$cpu_threshold_int" ] || [ "$mem_int" -ge "$mem_threshold_int" ]; then
            echo "PID: $pid, Commande: $comm, CPU: $cpu%, RAM: $mem%"
        fi
    done
}

# appel de la fonction pour vérifier les processus
checkProc

# utilisation d'une fonction pour le traitement de la charge système car plus facile à lire et à maintenir
# permet aussi de réutiliser le code si besoin
# comparaison des valeurs actuelles avec les seuils donnés en paramètre
# affiche les processus dépassant les seuils
# utilise bc pour les calculs flottants 
# https://unix.stackexchange.com/questions/153157/format-ps-command-output-without-whitespace