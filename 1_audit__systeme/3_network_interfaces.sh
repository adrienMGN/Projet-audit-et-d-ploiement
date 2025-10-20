#!/usr/bin/env sh
# script pour afficher les adresses IP et MAC des interfaces réseau
# aucun paramètre nécessaire

# Utilisation de la commande ip pour lister les interfaces réseau avec leurs adresses
# -o pour format one-line
ip -o addr show
