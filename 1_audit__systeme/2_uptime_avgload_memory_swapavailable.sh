# uptime, charge moyenne, mémoire et swap disponibles et utilisés

echo -e '\nUptime:'
uptime -p

echo -e '\nCharge moyenne en coeurs:'
uptime | cut -d':' -f5
# les valeurs qu'on trouve dans uptime sont les 3 charges moyennes aux cours des 1, 5 et 15 dernières minutes.
# on l'interprete en fonction du nombre de coeur CPU
# Si il y a 4 coeurs, alors la charge peut aller de 0.00 à 4.00
# -d':' permet d'utiliser le caractère ':' comme séparateur au lieu des tabulations

echo -e '\nMémoire utilisée | disponible:'
LANG=C free -h | grep Mem: | tr -s ' ' | cut -d' ' -f3,4
# à gauche la mémoire libre et à droite la mémoire utilise
# données en gibioctet grâce à l'option -h (--human)

echo -e '\nSwap utilisé | disponible'
LANG=C free -h | grep Swap: | tr -s ' ' | cut -d' ' -f3,4
