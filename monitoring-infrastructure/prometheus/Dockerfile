FROM prom/prometheus:latest

USER root

# Installation de SSH server
RUN apk add --no-cache openssh-server

# Configuration SSH
RUN mkdir -p /var/run/sshd /prometheus/node-metrics /root/.ssh \
    && chmod 700 /root/.ssh

# Configuration sshd
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config \
    && sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config \
    && sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config

# Génération des clés SSH du serveur
RUN ssh-keygen -A

# Copie des clés publiques autorisées
COPY ssh/authorized_keys /root/.ssh/authorized_keys
RUN chmod 600 /root/.ssh/authorized_keys

# Script de démarrage
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 9090 22

ENTRYPOINT ["/entrypoint.sh"]