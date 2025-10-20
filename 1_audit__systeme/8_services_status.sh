#!/bin/bash

# Vérifier si les services sont actifs et activés au démarrage
# Vérification de la présence et du statut des services clés

# SSHD

# vérifier d'abord si le service existe pour éviter les erreurs
# -q quiet : ne pas afficher de sortie
if systemctl list-unit-files | grep -q "^sshd\.service"; then
    echo "sshd : $(systemctl is-active sshd) / $(systemctl is-enabled sshd 2>/dev/null)"
else
    echo "sshd : non présent sur le système"
fi

# CRON
if systemctl list-unit-files | grep -q "^cron\.service"; then
    echo "cron : $(systemctl is-active cron) / $(systemctl is-enabled cron 2>/dev/null)"
else
    echo "cron : non présent sur le système"
fi

# DOCKER
if systemctl list-unit-files | grep -q "^docker\.service"; then
    echo "docker : $(systemctl is-active docker) / $(systemctl is-enabled docker 2>/dev/null)"
else
    echo "docker : non présent sur le système"
fi


# Explications complémentaires
# La commande `systemctl list-unit-files` liste tous les services disponibles sur le système.
# Le `grep -q` permet de vérifier silencieusement la présence d'un service spécifique
# La commande `systemctl is-active <service>` vérifie si un service est actuellement actif (en cours d'exécution).
# La commande `systemctl is-enabled <service>` vérifie si un service est configuré pour démarrer automatiquement au démarrage du système.
# Les services vérifiés ici sont :
# - sshd : serveur SSH pour les connexions distantes sécurisées
# - cron : service de planification des tâches
# - docker : plateforme de conteneurisation
# La sortie affiche l'état actif et l'état d'activation au démarrage pour chaque service.

# Dans un script ruby on utiliserait une liste et une boucle.