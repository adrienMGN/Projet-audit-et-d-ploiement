#!/bin/bash
# filepath: /home/sinje/Projet-audit-et-d-ploiement/monitoring-infrastructure/prometheus/entrypoint.sh

set -e

echo "========================================="
echo "Démarrage Prometheus + SSH"
echo "========================================="

# Fonction de nettoyage
cleanup() {
    echo "Arrêt des services..."
    pkill -TERM sshd || true
    pkill -TERM prometheus || true
    exit 0
}

trap cleanup SIGTERM SIGINT

# Vérifier les clés SSH
if [ ! -f /root/.ssh/authorized_keys ]; then
    echo "ERREUR: /root/.ssh/authorized_keys introuvable"
    exit 1
fi

echo "✓ Clés SSH trouvées"
ls -la /root/.ssh/

# Démarrer SSH en arrière-plan
echo "Démarrage SSH..."
/usr/sbin/sshd -D &
SSH_PID=$!

# Attendre que SSH démarre
sleep 2

if pgrep sshd > /dev/null; then
    echo "✓ SSH démarré (PID: $SSH_PID)"
else
    echo "✗ Erreur: SSH n'a pas démarré"
    exit 1
fi

# Vérifier la config Prometheus
if [ ! -f /etc/prometheus/prometheus.yml ]; then
    echo "ERREUR: Configuration Prometheus introuvable"
    exit 1
fi

echo "✓ Configuration Prometheus trouvée"

# Vérifier que prometheus existe
if [ ! -f /usr/local/bin/prometheus ]; then
    echo "ERREUR: Binaire Prometheus introuvable"
    ls -la /usr/local/bin/
    ls -la /opt/prometheus/
    exit 1
fi

# Démarrer Prometheus en foreground (utiliser le bon chemin)
echo "Démarrage Prometheus..."
exec /usr/local/bin/prometheus \
    --config.file=/etc/prometheus/prometheus.yml \
    --storage.tsdb.path=/prometheus/data \
    --web.console.libraries=/opt/prometheus/console_libraries \
    --web.console.templates=/opt/prometheus/consoles \
    --web.enable-lifecycle \
    --web.listen-address=:9090 \
    --log.level=info