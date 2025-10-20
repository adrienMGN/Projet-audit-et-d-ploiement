# liste des utilisateurs humain (uid ⩾ 1000) existants, en distinguant ceux actuellement connectés.

echo -e '\nUtilisateurs humains:'
grep -E '^[^:]+:[^:]*:[0-9]{4,}:' /etc/passwd | cut -d: -f1
# /etc/passwd liste les utilisateurs avec notamment leur noms (1er champ) et leur id (3eme champ)
# Un id egal ou superieur a 1000 désigne un humain
# donc tous les ids en 4 chiffres ou plus désignents des humains
# en utilisant [0-9]{4,} on match uniquement les uids de 4 chiffres ou plus, donc seulements les humains et tous les humains.
# le cut permet de seulement récupérer le premier champ, le nom de l'users

echo -e '\nHumains connectés:'
who | cut -d' ' -f1 | uniq
# who affiche les utilisateurs connectés : ça ne peut etre que des humains
# le cut permet de ne récupérer que le nom, pas l'ihm
# uniq enlève les doublons (meme utilisateurs connecté plusieurs fois
# on pourrait utiliser 'users' et ne pas avoir besoin de cut, mais il n'est pas possible d'utiliser 'uniq' directement dessus, les deux options sont donc aussi complexes

#Usage type:
#$ ./4_users_humains.sh 
#
#Utilisateurs humains:
#nobody
#denis154u
#libvirt-qemu
#
#Humains connectés:
#denis154u

