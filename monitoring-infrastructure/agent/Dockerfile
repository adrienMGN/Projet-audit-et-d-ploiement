FROM debian:bookworm

LABEL description="Container d'audit système via SSH"

ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

# Installation des dépendances système
RUN apt-get update && apt-get install -y \
    openssh-client \
    procps \
    ruby \
    cron \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copie du script d'audit
COPY audit.rb /app/audit.rb

# Copie du fichier cron
COPY cron/audit_cron /etc/cron.d/audit_cron

# droit exec sur le script et pour le fichier cron
RUN chmod +x /app/audit.rb
RUN chmod 0640 /etc/cron.d/audit_cron
RUN crontab /etc/cron.d/audit_cron

# Configuration SSH (dir, droits, StrictHostKeyChecking pour éviter les prompts, droit de config)
RUN mkdir -p /root/.ssh && \
    chmod 700 /root/.ssh && \
    echo "StrictHostKeyChecking no" > /root/.ssh/config && \
    chmod 600 /root/.ssh/config

#commande au lancement du conteneur
CMD ["cron", "-f"]
