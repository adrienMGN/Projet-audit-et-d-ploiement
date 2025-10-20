#!/usr/bin/env sh
# script pour afficher les adresses IP et MAC des interfaces réseau
# aucun paramètre nécessaire

# fonction printNetworkInfo Afficher les adresses IP et MAC des interfaces réseau
printNetworkInfo() {
    # Utilisation de ip link et ip addr pour obtenir les informations réseau    
    
    # read pour lire la sortie ligne par ligne
    # -o pour format compact (1 ligne)
    ip -o link show | while read -r line; do
        iface=$(echo "$line" | sed -n 's/^[0-9]*: \([^:]*\):.*/\1/p')
        mac=$(echo "$line" | grep -o '[0-9a-f]\{2\}:[0-9a-f]\{2\}:[0-9a-f]\{2\}:[0-9a-f]\{2\}:[0-9a-f]\{2\}:[0-9a-f]\{2\}')
        
        # obtenir toutes les adresses IP (IPv4 et IPv6) associées à l'interface 
        # sed nettoie (inet)
        ip_addrs=$(ip -o addr show "$iface" | grep -o 'inet[6]\? [0-9a-f:.]\+/[0-9]\+' | sed 's/inet[6]\? //')
        
        echo "Interface: $iface"
        echo "  MAC Address: $mac"
        # si (-n ) non vide 
        if [ -n "$ip_addrs" ]; then
            echo "  IP Addresses:"
            echo "$ip_addrs" | while read -r ip; do
                echo "    $ip"
            done
        else
            echo "  IP Address: None"
        fi
        echo "-----------------------------------"
    done
}

# appel de la fonction pour afficher les informations réseau
printNetworkInfo

# utilisation d'une fonction pour le traitement des interfaces réseau car plus facile à lire et à maintenir
# permet aussi de réutiliser le code si besoin
# boucle sur les interfaces réseau pour traiter chaque interface
# une adresse MAC par interface, plusieurs adresses IP possibles (v4 et v6)