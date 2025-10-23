FROM debian:bookworm

LABEL description="Container d'audit système via SSH"

ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

# Installation des dépendances système
RUN apt-get update && apt-get install -y \
    openssh-client \
    procps \
    ruby \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copie du script d'audit
COPY 2_audit.rb /app/audit.rb
# droit exec sur le script
RUN chmod +x /app/audit.rb

# Configuration SSH (dir, droits, StrictHostKeyChecking pour éviter les prompts, droit de config)
RUN mkdir -p /root/.ssh && \
    chmod 700 /root/.ssh && \
    echo "StrictHostKeyChecking no" > /root/.ssh/config && \
    chmod 600 /root/.ssh/config

# Point d'entrée (endroit où le conteneur commence l'exécution)
# le conteneur exécute le script d'audit Ruby et se termine
ENTRYPOINT ["/app/audit.rb"]
CMD ["-o", "json", "-c", "0.1", "-m", "0.1", "-p", "/output/1audit_report.json"]
