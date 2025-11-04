#!/bin/bash

set -e

TIMESTAMP=$(date +%s)
OUTPUT_DIR="/app/output"
JSON_FILE="${OUTPUT_DIR}/audit_${TIMESTAMP}.json"
PROM_FILE="${OUTPUT_DIR}/metrics.prom"
HOSTNAME="${AGENT_HOSTNAME:-$(hostname)}"
PROMETHEUS_HOST="${PROMETHEUS_HOST:-prometheus}"
PROMETHEUS_PORT="${PROMETHEUS_PORT:-22}"

echo "[$(date)] Starting metrics collection for ${HOSTNAME}"

# 1. Lancer deploy.sh pour générer le JSON
cd /app
./deploy.sh --output json > "${JSON_FILE}"

if [ ! -f "${JSON_FILE}" ]; then
    echo "[$(date)] ERROR: Failed to generate JSON file"
    exit 1
fi

echo "[$(date)] JSON file generated: ${JSON_FILE}"

# 2. Convertir JSON en format Prometheus
ruby /app/scripts/json_to_prometheus.rb "${JSON_FILE}" "${PROM_FILE}" "${HOSTNAME}"

if [ ! -f "${PROM_FILE}" ]; then
    echo "[$(date)] ERROR: Failed to generate Prometheus metrics file"
    exit 1
fi

echo "[$(date)] Prometheus metrics file generated: ${PROM_FILE}"

# 3. Envoyer le fichier au serveur Prometheus via SCP
scp -P ${PROMETHEUS_PORT} \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/root/.ssh/known_hosts \
    -i /root/.ssh/id_rsa \
    "${PROM_FILE}" \
    "root@${PROMETHEUS_HOST}:/prometheus/node-metrics/${HOSTNAME}.prom"

if [ $? -eq 0 ]; then
    echo "[$(date)] Metrics successfully sent to Prometheus server"
    # Nettoyage des anciens fichiers (garder seulement les 10 derniers)
    ls -t ${OUTPUT_DIR}/audit_*.json | tail -n +11 | xargs -r rm
else
    echo "[$(date)] ERROR: Failed to send metrics to Prometheus server"
    exit 1
fi

echo "[$(date)] Metrics collection completed"