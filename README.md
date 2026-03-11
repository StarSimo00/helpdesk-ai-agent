# 🤖 HelpBot — Agent IA pour le Support N1 Applicatif

> Projet 2026 — Automatisation du support helpdesk avec un agent conversationnel IA

## 📋 Description

HelpBot est un agent IA autonome capable de qualifier et résoudre automatiquement les incidents N1 de support informatique. Il s'intègre avec Active Directory (LDAP), Jira, et un système de ticketing complet.

## ✨ Fonctionnalités

| Fonctionnalité | Statut |
|---|---|
| 🔐 Authentification AD (LDAP) + mode invité | ✅ |
| 🔓 Déblocage de compte automatique | ✅ |
| 🔑 Réinitialisation de mot de passe | ✅ |
| 🌐 Diagnostic VPN (5 vérifications) | ✅ |
| 🚀 Provisionnement d'accès applicatif | ✅ |
| 🐛 Résolution d'erreurs applicatives | ✅ |
| 📧 Vérification OTP par email (invités) | ✅ |
| 🎫 Intégration Jira (create/update/close) | ✅ |
| 📚 Base de connaissances (18+ articles) | ✅ |
| 📊 Dashboard avec 5 métriques ITIL | ✅ |
| 🌍 Bilingue FR / EN | ✅ |

## 🏗️ Architecture

```
Browser (React :3000)
    ↓
n8n Webhook Agent (AI: qwen3-coder)
    ↓
Flask REST API (:5001) → Swagger UI at /docs
    ↓              ↓              ↓
OpenLDAP:389   Postgres:5432   Mailhog:1025
```

## 🚀 Démarrage rapide

### Prérequis
- Docker + Docker Compose
- ngrok (pour exposer n8n publiquement)

### 1. Cloner le projet
```bash
git clone https://github.com/StarSimo00/helpdesk-ai-agent.git
cd helpdesk-ai-agent
```

### 2. Configurer l'environnement
```bash
# Frontend
cp helpdesk-frontend/env.example helpdesk-frontend/.env
# Éditer .env avec votre URL ngrok et webhook n8n
```

### 3. Lancer tous les services
```bash
sudo docker compose up -d --build
```

### 4. Accéder aux interfaces

| Service | URL |
|---|---|
| 💬 Chat Interface | http://localhost:3000 |
| 📊 Dashboard | http://localhost:3000/dashboard |
| 🔧 n8n Workflow | http://localhost:5678 |
| 📖 API Swagger | http://localhost:5001/docs |
| 📧 Mailhog (emails) | http://localhost:8025 |

## 👥 Utilisateurs de test

Tous les utilisateurs ont le mot de passe : `Password123!`

| Username | Nom | Département |
|---|---|---|
| jdoe | John Doe | IT |
| mwilson | Mark Wilson | IT |
| dwhite | David White | IT |
| bjones | Bob Jones | HR |
| sjohnson | Sarah Johnson | HR |
| asmith | Alice Smith | Finance |
| ebrown | Emma Brown | Finance |
| jmartin | James Martin | Sales |
| cdurand | Claire Durand | Management |

> 50 utilisateurs fictifs sont disponibles dans le LDAP (voir `openldap/bootstrap.ldif`)

## 📡 API Endpoints

La documentation complète est disponible sur **http://localhost:5001/docs** (Swagger UI).

| Endpoint | Méthode | Description |
|---|---|---|
| /ldap-login | POST | Authentification LDAP |
| /lookup | POST | Informations utilisateur |
| /unlock | POST | Déblocage de compte |
| /reset-password | POST | Réinitialisation mot de passe |
| /diagnose-vpn | POST | Diagnostic VPN N1 |
| /provision-access | POST | Provisionnement accès applicatif |
| /check-access | POST | Vérification accès |
| /resolve-app-error | POST | Résolution erreur applicative |
| /search-kb | GET | Recherche base de connaissances |
| /send-otp | POST | Envoi code OTP |
| /verify-otp | POST | Vérification OTP + exécution |
| /log-action | POST | Journalisation action |
| /logs | GET | Historique des logs |
| /dashboard/stats | GET | Métriques dashboard |

## 🗂️ Structure du projet

```
helpdesk-ai-agent/
├── docker-compose.yml
├── Dockerfile.n8n
├── ldap-api/
│   ├── app.py              # Flask API (993 lignes)
│   ├── Dockerfile
│   └── requirements.txt
├── postgres/
│   └── init.sql            # Tables + 500 tickets synthétiques + KB
├── openldap/
│   └── bootstrap.ldif      # 50 utilisateurs + groupes applicatifs
├── helpdesk-frontend/
│   ├── src/
│   │   ├── components/
│   │   │   ├── ChatPage.jsx
│   │   │   ├── LoginPage.jsx
│   │   │   └── DashboardPage.jsx
│   │   ├── App.jsx
│   │   └── index.jsx
│   ├── Dockerfile
│   └── nginx.conf
└── n8n-workflows/
    └── helpdesk-agent-v7.json
```

## 🔧 Technologies

- **Agent IA**: n8n + Ollama (qwen3-coder)
- **Backend**: Python Flask + Flasgger (Swagger)
- **Frontend**: React + Vite
- **LDAP/AD**: OpenLDAP (osixia)
- **Base de données**: PostgreSQL 15
- **Ticketing**: Jira (Atlassian)
- **Email**: Mailhog (dev SMTP)
- **Orchestration**: Docker Compose

## 📊 Métriques Dashboard

1. **Nombre total de tickets** — tickets traités par le bot
2. **Taux de résolution automatique** — % résolu sans escalade
3. **Temps moyen de traitement** — durée moyenne de résolution
4. **Répartition par catégorie** — account/vpn/access/app_error
5. **Satisfaction utilisateur simulée** — score /5 basé sur performance

## 🔒 Sécurité

- Authentification AD obligatoire pour les actions sensibles
- Mode invité limité : seuls search_kb, send_otp, verify_otp autorisés
- Vérification OTP pour reset/unlock sans compte AD
- Audit trail complet dans PostgreSQL

---
*Projet réalisé dans le cadre du cours Support Applicatif 2026*
