# 🧠 Projet d’Audit et de Déploiement

Ce projet a pour objectif de **déployer une infrastructure d’audit et de monitoring** automatisée à l’aide de **Prometheus**, **Grafana** et d’un **agent d’audit** développé sur mesure.  
Il permet d’assurer une supervision continue des systèmes et d’automatiser la collecte d’informations de performance et de sécurité.

---

## 📁 Structure du projet

```

Projet-audit-et-d-ploiement/
├── monitoring-infrastructure/
│   ├── prometheus/
│   │   ├── docker-compose.yml          # Stack Prometheus + Grafana
│   │   ├── prometheus.yml              # Configuration des jobs Prometheus
│   │   └── grafana/
│   │       └── provisioning/
│   │           └── datasources/
│   │               └── prometheus.yml  # Datasource Grafana pour Prometheus
│   └── agent/
│       ├── Dockerfile                  # Image de l’agent d’audit
│       ├── docker-compose.yml          # Déploiement de l’agent
│       ├── deploy.sh                   # Script de déploiement automatisé
│       ├── audit.rb                    # Script principal d’audit (Ruby)
│       └── cron/
│           └── audit_cron              # Tâche planifiée pour exécuter l’audit
└── .gitignore

````

---

## 🚀 Lancer le projet

### 1. Prérequis
Assure-toi d’avoir installé :
- **Docker** et **Docker Compose**
- **Git** (pour le clonage)
- (Optionnel) **Ruby** si tu veux exécuter le script `audit.rb` hors container

### 2. Cloner le dépôt
```bash
git clone https://github.com/votre-utilisateur/Projet-audit-et-deploiement.git
cd Projet-audit-et-deploiement
````

### 3. Démarrer Prometheus & Grafana

```bash
cd monitoring-infrastructure/prometheus
docker-compose up -d
```

* Prometheus sera accessible sur : **[http://localhost:9090](http://localhost:9090)**
* Grafana sera accessible sur : **[http://localhost:3000](http://localhost:3000)**

### 4. Déployer l’agent d’audit

```bash
cd ../agent
bash deploy.sh
```

L’agent collectera automatiquement les métriques selon la configuration du cron (`audit_cron`).

---

## 🧩 Fonctionnalités

* 📊 **Surveillance système en temps réel** (CPU, mémoire, disques, etc.)
* 🔍 **Audit automatisé** via scripts Ruby planifiés
* 🧱 **Infrastructure modulaire** avec Docker Compose
* ⚙️ **Déploiement simplifié** grâce à `deploy.sh`
* 🧠 **Visualisation** des données via Grafana

---

## ⚙️ Technologies utilisées

| Composant            | Description                           |
| -------------------- | ------------------------------------- |
| **Docker / Compose** | Conteneurisation et orchestration     |
| **Prometheus**       | Collecte et stockage des métriques    |
| **Grafana**          | Visualisation des métriques           |
| **Ruby**             | Langage de script pour l’audit        |
| **Cron**             | Automatisation des tâches périodiques |

---

## 📦 Maintenance et évolution

* Ajouter de nouvelles métriques à surveiller via `prometheus.yml`
* Étendre l’agent Ruby pour collecter des indicateurs spécifiques
* Intégrer des alertes Prometheus / Grafana selon les seuils définis

---

## 🧑‍💻 Auteurs

* **Gabriel Comte**
* **Oscar Tom Denis**
* **Adrien Mangin**

