# nom de la machine, distribution, version du noyau

echo -e '\nNom de la machine:'
uname --nodename
# '-e' permet à echo d'intepreter les caracteres comme '\n'

echo -e '\nDistribution:'
lsb_release -a | grep Description | cut -f2
# lsb_release donne toutes les informations de la distribution en plusieurs lignes.
# La ligne "Description" contient un condensé de ces informations (distribution, release de la distirbution, identifiant de la distribution.

echo -e '\nVersion du kernel:'
uname -r
# donne la version et l'architecture (amd par exemple) du kernel
