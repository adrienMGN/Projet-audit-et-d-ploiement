#!/usr/bin/env sh
# script pour afficher les adresses IP et MAC des interfaces réseau
# aucun paramètre nécessaire

# utilisation de ip car ifconfig est obsolète sur de nombreuses distributions

# Utilisation de la commande ip pour lister les interfaces réseau avec leurs adresses
# -o pour format one-line
ip -o addr show 
ip -o link show

# Explications complémentaires
# La commande `ip addr show` affiche les informations des interfaces réseau.
# L'option `-o` (ou `--oneline`) permet d'afficher
# chaque interface sur une seule ligne pour une lecture plus facile.
# Les informations affichées incluent :
# - l'index de l'interface
# - le nom de l'interface (ex : eth0, wlan0)
# - l'état de l'interface (UP/DOWN)
# - l'adresse MAC (link/ether)
# - les adresses IP associées (inet pour IPv4, inet6 pour IPv6)
# Cela permet d'obtenir rapidement un aperçu des interfaces réseau
# et de leurs adresses associées sur le système.
# en ruby on assurerait le formatage et le nettoyage de la sortie.
