#!/usr/bin/env sh

# script pour afficher le status des services donnés en paramètre

# paramètres (1 mini)
if [ "$#" -lt 1 ]; then
    echo "Usage: $0 <service-name>"
    echo " Donner la liste des services "
    exit 1
fi

# fonction printServiceStatus Afficher services status (up, down)
printServiceStatus() {
    local service="$1"
    # Vérifie si le service existe (pas dans la liste)
    if ! systemctl list-units --type=service --all | grep -q "^\s*$service"; then
        echo "Le service $service n'existe pas ou n'est pas présent."
        return
    fi
 
    # is-active retourne 0 si le service est en cours d'exécution
    if systemctl is-active --quiet "$service"; then
        echo "Le service $service est en cours d'exécution."
    else
        echo "Le service $service est arrêté."
    fi
}

# listes des services donnés en paramètre
for service in "$@"; do
    printServiceStatus "$service"
    echo "-----------------------------------"
done


# utilisation d'une fonction pour le traitement d'un service car plus facile à lire et à maintenir
# permet aussi de réutiliser le code si besoin
# boucle sur les paramètres pour traiter chaque service