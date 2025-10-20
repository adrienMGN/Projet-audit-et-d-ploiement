#!/bin/bash

##############################################################
# Script : Processus consommateurs de trafic réseau (compact)
# Description :
#   Affiche les processus dont le trafic réseau total
#   (entrant + sortant) dépasse un seuil donné.
#   Utilise `nethogs` en mode texte, filtré par `awk`.
#   L’exécution s’arrête automatiquement après un délai défini.
#
# Exemple de ligne : /usr/sbin/tailscaled/844/0   4.33535 5.05586
#
# $1 : /usr/sbin/tailscaled/844/0
#      - Chemin du programme ou nom du processus : /usr/sbin/tailscaled
#      - PID (numéro de processus) : 844
#      - UID (ID utilisateur qui exécute le processus) : 0 (root)
#
# $2 : 4.33535
#      - Trafic entrant en KB/s (données reçues par ce processus)
#
# $3 : 5.05586
#      - Trafic sortant en KB/s (données envoyées par ce processus)
#
##############################################################

# --- Paramètres ---
DUREE=15          # Durée en secondes pour la mesure
SEUIL=2          # Seuil minimal de trafic total en KB/s

echo "=== Processus réseau consommant plus de $SEUIL KB/s (durée : $DUREE s) ==="

# --- Commande principale ---
# timeout 5 sudo nethogs -t -a | awk '{seuil=$2+$3} seuil>2 {print $0}'
# Version avec variables et explications

timeout "$DUREE" sudo nethogs -t -a 2>/dev/null | \
awk -v seuil="$SEUIL" '
{
    # $0 : ligne entière lue par awk
    # $1 : premier champ = programme/processus
    # $2 : deuxième champ = trafic entrant (KB/s)
    # $3 : troisième champ = trafic sortant (KB/s)
    total = $2 + $3           # calcul du trafic total
}
total > seuil {
    # ce bloc s’exécute uniquement si la condition est vraie
    # print $0 affiche la ligne complète (programm, entrant, sortant)
    print $0
}'

#en une ligne :
```
	#timeout 5 sudo nethogs -t -a 2>/dev/null | awk '{seuil=$2+$3} seuil>2 {print $0}'
	#ici -v avec awk nest pas nécessaire car -v sert à définir une variable externe avant l'excution du script awk.
```
##############################################################
# Explications complémentaires
##############################################################

# 1. nethogs -t -a :
#    -t : mode texte (utile pour traitement automatique)
#    -a : toutes interfaces, y compris loopback
#
# 2. awk :
#    - awk divise chaque ligne en champs : $1 = premier champ, $2 = deuxième, $3 = troisième, $0 = ligne entière.
#      Par défaut, les champs sont séparés par espaces ou tabulations, mais on peut changer le séparateur avec -F (ex : awk -F: …).
#
#    - Les blocs { ... } s’exécutent pour chaque ligne
#    - Une condition avant un bloc { ... } signifie :
#        "exécute ce bloc seulement si la condition est vraie"
#      Ici : total > seuil { print $0 }
#
# 3. timeout :
#    - interrompt `nethogs` après DUREE secondes
#    - empêche le script de tourner indéfiniment
#
# 4. Redirection d’erreur (2>/dev/null) :
#    - Certaines lignes, comme "Unknown connection", sont envoyées sur STDERR (flux d’erreurs)
#    - La syntaxe `2>/dev/null` redirige ce flux vers /dev/null, ce qui signifie :
#         - "ne rien afficher pour les erreurs"
#    - Cela permet de ne voir que les lignes valides sur STDOUT, traitées par awk
##############################################################
