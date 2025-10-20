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

# fonction pour convertir un nombre décimal en entier pour comparaison
# exemples: 1.5 -> 15, 1 -> 10, 0.3 -> 3
to_int() {
    number=$1
    
    # si le nombre contient un point (nombre décimal)
    if echo "$number" | grep -q '\.'; then
        # supprimer le point: 1.5 devient 15
        echo "$number" | sed 's/\.//'
    else
        # si c'est un entier, ajouter un 0: 1 devient 10
        echo "${number}0"
    fi
}

# fonction checkProc Vérifie la charge CPU et RAM pour chaque processus
checkProc() {
    echo "Processus dépassant le seuil CPU de $CPU_THRESHOLD% ET RAM de $RAM_THRESHOLD% :"
    echo "------------------------------------------------------------"
    
    # Convertir les seuils en entiers
    cpu_threshold_int=$(to_int "$CPU_THRESHOLD")
    mem_threshold_int=$(to_int "$RAM_THRESHOLD")
    
    # -e pour sélectionner les colonnes, --no-headers pour ne pas afficher l'en-tête
    # -o pour format customisé 
    ps -eo pid,comm,%cpu,%mem --no-headers | while read -r pid comm cpu mem; do
        # Convertir les valeurs actuelles
        cpu_int=$(to_int "$cpu")
        mem_int=$(to_int "$mem")

        # compare et affiche si dépassement des DEUX seuils
        if [ "$cpu_int" -ge "$cpu_threshold_int" ] && [ "$mem_int" -ge "$mem_threshold_int" ]; then
            # affichage des infos du processus avec les variables lues
            echo "PID: $pid, Commande: $comm, CPU: $cpu%, RAM: $mem%"
        fi
    done
}

# appel de la fonction pour vérifier les processus
checkProc

# utilisation de deux fonctions pour le traitement de la charge système car plus facile à lire et à maintenir
# fonction de conversion pour comparaison essentielle
# permet aussi de réutiliser le code si besoin
# comparaison des valeurs actuelles avec les seuils donnés en paramètre
# affiche les processus dépassant les seuils
# https://unix.stackexchange.com/questions/153157/format-ps-command-output-without-whitespace