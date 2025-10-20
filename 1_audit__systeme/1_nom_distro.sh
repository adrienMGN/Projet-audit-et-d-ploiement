# nom de la machine, distribution, version du noyau

# nom de la machine
uname --nodename

# distribution
lsb_release -a | grep Description | cut -f2
# lsb_release donne toutes les informations de la distribution en plusieurs lignes.
# La ligne "Description" contient un condensé de ces informations (distribution, release de la distirbution, identifiant de la distribution.

# version du kernel
uname -r
# donne la version et l'architecture (amd par exemple) du kernel


# Usage type :
# ./1_nom_distro.sh
# iutnc-503-05
# Debian GNU/Linux 12 (bookworm)
# 6.1.0-40-amd64
#
