#!/bin/bash

echo "=== Configuration de l'audit système Docker ==="

# 1. Vérifier que SSH est installé sur l'hôte
if ! systemctl is-active --quiet ssh; then
    echo "Installation du serveur SSH..."
    sudo apt-get update
    sudo apt-get install -y openssh-server
    sudo systemctl enable ssh
    sudo systemctl start ssh
fi

# 2. Générer les clés SSH si elles n'existent pas
if [ ! -f ./ssh-keys/id_rsa ]; then
    echo "Génération des clés SSH..."
    mkdir -p ./ssh-keys
    ssh-keygen -t rsa -b 4096 -f ./ssh-keys/id_rsa -N "" -C "audit-container"
fi

# 3. Ajouter la clé publique aux autorisations root (script exécuté avec sudo)
echo "Ajout de la clé publique aux autorisations..."
sudo mkdir -p /root/.ssh
sudo cat ./ssh-keys/id_rsa.pub | sudo tee -a /root/.ssh/authorized_keys > /dev/null
sudo chmod 600 /root/.ssh/authorized_keys
sudo chmod 700 /root/.ssh



# 5. Créer le répertoire de sortie
mkdir -p ./output

# 6. Build et lancement du conteneur
echo "Construction de l'image Docker..."
docker compose build

echo "Lancement de l'audit..."
docker compose up

echo "=== Audit terminé ==="