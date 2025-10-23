# Projet Audit et Déploiement
#### Auteurs Comte Grabriel, Denis Oscar, Mangin Adrien 
----------------
Outil d'audit système Linux containerisé avec Docker, permettant d'analyser à distance un système via SSH. Un paquet debian est également fourni pour lancer le script localement sans docker. 

---

## Prérequis

- **Privilèges administrateur** (sudo) sur la machine hôte
- **Docker** et **Docker Compose** installés
- Système d'exploitation : **Linux** (Debian/Ubuntu recommandé)

---

## Installation et Configuration

Le script `deploy.sh` automatise l'installation et la configuration :

1. **Installation de SSH** : vérifie et installe `openssh-server` et `nethogs` si nécessaires
2. **Génération des clés SSH** : crée une paire de clés RSA 4096 bits dans `./ssh-keys/`
3. **Configuration SSH** : ajoute la clé publique aux autorisations root
4. **Création du répertoire de sortie** : prépare le dossier `./output/` pour les rapports
5. **Build et lancement** : construit l'image Docker et lance l'audit

### Utilisation

```bash
# Lancer l'audit avec configuration par défaut
sudo ./deploy.sh

# Personnaliser les seuils et le format de sortie
sudo ./deploy.sh -o json -c 10 -m 15 -p /output/rapport.json
```

---

## Architecture du Projet

```
Projet-audit-et-d-ploiement/
│
├── deploy.sh                    # Script principal d'installation et lancement
├── docker-compose.yml           # Configuration Docker pour l'audit
├── Dockerfile                   # Image Docker de l'audit
├── 2_audit.rb                   # Script Ruby d'audit système
├── .gitignore                   # Fichiers et dossiers ignorés par Git
│
├── 1_audit__systeme/            # Scripts bash individuels (références)
│   ├── 1_nom_distro.sh
│   ├── 2_uptime_avgload_memory_swapavailable.sh
│   ├── 3_network_interfaces.sh
│   ├── 4_users_humains.sh
│   ├── 5_espace_disque.sh
│   ├── 6_proc.sh
│   ├── 7_proc+conso.sh
│   └── 8_services_status.sh
│
├── 3audit/                      # Package Debian (structure)
│   ├── DEBIAN/
│   │   └── control
│   ├── usr/
│   │   ├── local/
│   │   │   ├── bin/3audit
│   │   │   └── share/man/man1/3audit.1
│   │   └── lib/3_audit/
│   │       ├── docker-compose.yml
│   │       ├── Dockerfile
│   │       └── 2_audit.rb
│
├── ssh-keys/                    # Clés SSH (généré, ignoré par Git)
└── output/                      # Rapports d'audit (généré, ignoré par Git)
```

---

## Informations Collectées

L'audit collecte les données suivantes :

- **Système** : hostname, distribution, kernel
- **Ressources** : uptime, charge, RAM, swap
- **Réseau** : interfaces (IP, MAC), flux réseau
- **Utilisateurs** : comptes humains, sessions actives
- **Stockage** : espace disque des partitions
- **Processus** : consommation CPU et mémoire
- **Services** : statut et activation des services systemd

---

## Export des Résultats

Les rapports peuvent être générés en :

- **Format texte** (stdout par défaut)
- **Format JSON** (avec l'option `-o json -p fichier.json`)

Les fichiers JSON sont automatiquement sauvegardés dans `./output/` par défaut.
On peut aussi utiliser l'argument -p pour spécifier le fichier de sortie.

---

## Documentation

Consultez la page de manuel : `3audit/usr/local/share/man/man1/3audit.1`
On peut consulter la page du manuel avec `man 3audit` lorsque le packet debian est installé.

# Détails partie 1

Afin de versionner nos réponses à la première partie du sujet qui consistent en des commandes Unix, nous avons décidé d’enregistrer nos réponses dans des scripts shell.
Les commandes sont ainsi séparéees en plusieurs fichiers, un par ligne dans le sujet (pour un total donc de 8 scripts .sh).

Ca a aussi facilité la réalisation du script ruby de la deuxième partie, puisqu’on possédait déjà les commandes avec les arguments appropriés pour ne récupérer que les données nécessaires.

# Docker explication

## Architecture Docker

### Dockerfile

**Image de base** : `debian:bookworm`
- Distribution stable et légère
- Compatibilité maximale avec les systèmes Debian/Ubuntu

**Dépendances installées** :
- `openssh-client` : connexion SSH à l'hôte
- `procps` : outils système (ps, top)
- `ruby` : exécution du script d'audit

**Configuration SSH** :
- Désactivation de `StrictHostKeyChecking` pour éviter les prompts interactifs
- Permissions correctes (700 pour `.ssh`, 600 pour la config)

**Point d'entrée** :
- Le script Ruby `/app/audit.rb` est défini comme ENTRYPOINT
- Arguments par défaut : format JSON, seuils CPU/RAM à 0.1%, sortie dans `/output/`

### docker-compose.yml

**Variables d'environnement** :
- `TARGET_HOST=172.17.0.1` : IP du bridge Docker (permet d'atteindre l'hôte)
- `TARGET_USER=root` : utilisateur SSH pour l'audit
- `SSH_KEY_PATH=/root/.ssh/id_rsa` : chemin de la clé privée dans le conteneur

**Volumes montés** :
- `./ssh-keys/id_rsa` → `/root/.ssh/id_rsa` (lecture seule) : clé SSH privée
- `./output` → `/output` : répertoire de sortie partagé hôte/conteneur

**Réseau** :
- Mode `bridge` (réseau par défaut Docker)
- Permet la communication conteneur → hôte via `172.17.0.1`

### Script de Déploiement (`deploy.sh`)

Le script `deploy.sh` automatise l'installation et la configuration complète :

**1. Installation de SSH**
- Vérifie si le service SSH est actif sur l'hôte
- Installe `openssh-server` et `nethogs` si nécessaires
- Active et démarre le service SSH

**2. Génération des clés SSH**
- Crée une paire de clés RSA 4096 bits dans `./ssh-keys/`
- Permet au conteneur de se connecter à l'hôte sans mot de passe

**3. Configuration SSH**
- Ajoute la clé publique dans `/root/.ssh/authorized_keys`
- Configure les permissions (700 pour `.ssh`, 600 pour `authorized_keys`)

**4. Création du répertoire de sortie**
- Prépare le dossier `./output/` pour recevoir les rapports d'audit

**5. Build et lancement**
- Construit l'image Docker avec les dépendances
- Lance le conteneur d'audit avec les paramètres fournis
