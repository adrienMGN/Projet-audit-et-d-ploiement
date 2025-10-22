#!/usr/bin/env bash

echo "=== Configuration de l'audit système Docker ==="

# 1. Vérifier que SSH est installé sur l'hôte
if ! systemctl is-active --quiet ssh; then
    echo "Installation du serveur SSH..."
    sudo apt-get update
    sudo apt-get install -y openssh-server nethogs
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



# 4. Créer le répertoire de sortie
mkdir output

# 5. Build et lancement du conteneur
echo "Construction de l'image Docker..."
docker compose build

echo "Lancement de l'audit..."
docker compose run --rm audit "$@"

echo "=== Audit terminé ==="
