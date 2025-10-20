# uptime, charge moyenne, mémoire et swap disponibles et utilisés

echo -e '\nUptime:'
uptime -p

echo -e '\nCharge moyenne en coeurs:'
LANG=C uptime | grep -o 'load average:.*' | cut -d':' -f2
# les valeurs qu'on trouve dans uptime sont les 3 charges moyennes aux cours des 1, 5 et 15 dernières minutes.
# on l'interprete en fonction du nombre de coeur CPU
# Si il y a 4 coeurs, alors la charge peut aller de 0.00 à 4.00
# -d':' permet d'utiliser le caractère ':' comme séparateur au lieu des tabulations
# LANG=C permet d'avoir le resultat en anglais, afin que le grep 'load average' fonctionne sur toutes les machines

echo -e '\nMémoire utilisée | disponible:'
LANG=C free -h | grep Mem: | tr -s ' ' | cut -d' ' -f3,4
# à gauche la mémoire utilisee et à droite la mémoire disponible
# données en gibioctet grâce à l'option -h (--human)
# tr -s ' '  permet de supprimer les nombreux espaces inutiles.

echo -e '\nSwap utilisé | disponible'
LANG=C free -h | grep Swap: | tr -s ' ' | cut -d' ' -f3,4
# à gauche le swap utilisé et à droite le swap disponible (souvent 0), encore en gibi

#Usage type:
#$ ./2_uptime_avgload_memory_swapavailable.sh
#
#Uptime:
#up 10 minutes
#
#Charge moyenne en coeurs:
# 0,34, 0,50, 0,36
#
#Mémoire utilisée | disponible:
#5.5Gi 6.2Gi
#
#Swap utilisé | disponible
#0B 4.7Gi

