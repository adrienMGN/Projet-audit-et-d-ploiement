FROM ruby:3.2-slim

# Installation des dépendances système
RUN apt-get update && apt-get install -y \
    openssh-client \
    cron \
    curl \
    sysstat \
    procps \
    docker.io \
    && rm -rf /var/lib/apt/lists/*

# Création du répertoire de travail
WORKDIR /app

# Copie des scripts
COPY deploy.sh /app/deploy.sh
COPY 2_audit.rb /app/2_audit.rb
COPY scripts/collect_metrics.sh /app/scripts/collect_metrics.sh
COPY scripts/json_to_prometheus.rb /app/scripts/json_to_prometheus.rb

# Rendre les scripts exécutables
RUN chmod +x /app/deploy.sh \
    && chmod +x /app/scripts/collect_metrics.sh \
    && chmod +x /app/scripts/json_to_prometheus.rb

# Création des répertoires nécessaires
RUN mkdir -p /app/output /root/.ssh

# Configuration SSH
RUN chmod 700 /root/.ssh

# Installation du cron job
COPY cron/metrics-collector /etc/cron.d/metrics-collector
RUN chmod 0644 /etc/cron.d/metrics-collector \
    && crontab /etc/cron.d/metrics-collector

# Création du fichier de log
RUN touch /var/log/metrics-collector.log

# Démarrage du cron et maintien du conteneur actif
CMD cron && tail -f /var/log/metrics-collector.log