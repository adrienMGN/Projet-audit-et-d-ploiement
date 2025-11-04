FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

# Installer les dépendances
RUN apt-get update && \
    apt-get install -y \
    wget \
    tar \
    openssh-server \
    ca-certificates \
    curl \
    && apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Télécharger et installer Prometheus
ARG PROMETHEUS_VERSION=2.48.0
RUN cd /tmp && \
    wget https://github.com/prometheus/prometheus/releases/download/v${PROMETHEUS_VERSION}/prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz && \
    tar -xzf prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz && \
    mv prometheus-${PROMETHEUS_VERSION}.linux-amd64 /opt/prometheus && \
    rm prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz && \
    ln -s /opt/prometheus/prometheus /usr/local/bin/prometheus && \
    ln -s /opt/prometheus/promtool /usr/local/bin/promtool

# Créer les répertoires nécessaires
RUN mkdir -p \
    /var/run/sshd \
    /etc/prometheus \
    /prometheus/data \
    /prometheus/node-metrics \
    /root/.ssh && \
    chmod 700 /root/.ssh && \
    chmod 755 /prometheus && \
    chmod 755 /prometheus/data && \
    chmod 755 /prometheus/node-metrics

# Créer un fichier JSON vide pour file_sd_configs
RUN echo '[]' > /prometheus/node-metrics/placeholder.json

# Configuration SSH
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config && \
    sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config

# Génération des clés SSH du serveur
RUN ssh-keygen -A

# Copie de la configuration Prometheus
COPY prometheus.yml /etc/prometheus/prometheus.yml

# Copie des clés publiques autorisées
COPY ssh/authorized_keys /root/.ssh/authorized_keys
RUN chmod 600 /root/.ssh/authorized_keys

# Script de démarrage
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 9090 22

WORKDIR /prometheus

ENTRYPOINT ["/entrypoint.sh"]