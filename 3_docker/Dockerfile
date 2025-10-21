FROM debian:bookworm

RUN apt-get update && apt-get install -y \
    curl \
    ruby \
    nethogs \
    openssh-client \
 && rm -rf /var/lib/apt/lists/*

# Création d'un utilisateur non privilégié    
RUN useradd -m audit && mkdir -p /usr/src/app && chown -R audit:audit /usr/src/app
USER audit

# Copier le script d'audit dans le conteneur
COPY ../2_audit.rb /usr/src/app

# Définir le répertoire de travail
WORKDIR /usr/src/app

# Donner les permissions d'exécution au script
RUN chmod 755 /usr/src/app
# ENTRYPOINT ["ruby", "/usr/src/app/2_audit.rb"]
ENTRYPOINT ["sleep", "10000000000"]
