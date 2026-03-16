# 🤖 HelpBot — AI-Powered IT Helpdesk Agent

> **Level 1 IT Support Automation** — Powered by Qwen3-Coder, n8n, OpenLDAP, Jira, and Qdrant RAG

![Stack](https://img.shields.io/badge/AI-Qwen3--Coder-8b5cf6?style=flat-square)
![n8n](https://img.shields.io/badge/Workflow-n8n-ef4444?style=flat-square)
![React](https://img.shields.io/badge/Frontend-React%20%2B%20Vite-22d3ee?style=flat-square)
![Docker](https://img.shields.io/badge/Deploy-Docker%20Compose-2496ed?style=flat-square)
![Jira](https://img.shields.io/badge/Ticketing-Jira%20Cloud-0052cc?style=flat-square)

---

## 📋 Overview

HelpBot is a fully automated **N1 IT support agent** that handles employee IT requests through a conversational interface. It authenticates against **Active Directory (OpenLDAP)**, performs real IT actions (unlock accounts, reset passwords, diagnose VPN, provision access), creates tickets in **Jira**, and escalates complex issues to **N2 engineers** — all autonomously.

### ✨ Key Features

- 🔐 **AD Authentication** — Real OpenLDAP login with department-based access control
- 🤖 **AI Agent** — Qwen3-Coder via Ollama with strict tool-calling discipline
- 🎫 **Dual Ticketing** — DB ticket created on first message + Jira ticket at resolution
- 🔍 **RAG Knowledge Base** — 34 IT articles indexed in Qdrant with semantic search
- 🚨 **N1→N2 Escalation** — Full context passed to N2 dashboard when N1 can't resolve
- 👤 **Guest OTP Flow** — Anonymous users can reset passwords via email OTP
- 📊 **IT Dashboard** — Real-time overview, N1 tickets, N2 escalations, action logs
- 💬 **Session Memory** — PostgreSQL-backed conversation memory per session

---

## 🏗️ Architecture

```
Browser (React :3000)
    │
    ├── /api/* → Flask API (:5001)
    │              ├── OpenLDAP (:389)     — Auth, lookup, unlock, reset
    │              ├── PostgreSQL (:5432)  — Tickets, logs, KB, escalations
    │              └── Mailhog (:1025)     — OTP email delivery
    │
    └── /webhook/* → n8n (:5678)
                      └── AI Agent (Qwen3-Coder via Ollama :11434)
                              ├── Tools: unlock, reset, VPN, access, KB
                              ├── Memory: PostgreSQL session store
                              ├── RAG: Qdrant (:6333) + nomic-embed-text
                              └── Jira Cloud API
```

---

## 🐳 Services

| Service | Port | Description |
|---|---|---|
| `helpdesk-frontend` | 3000 | React + Vite UI (nginx) |
| `helpdesk-ldap-api` | 5001 | Flask REST API (22 endpoints) |
| `helpdesk-n8n` | 5678 | n8n workflow engine |
| `helpdesk-postgres` | 5432 | PostgreSQL 15 (shared DB) |
| `helpdesk-openldap` | 389 | OpenLDAP with 50 users |
| `helpdesk-ollama` | 11434 | Ollama LLM server |
| `helpdesk-qdrant` | 6333 | Qdrant vector database |
| `helpdesk-mailhog` | 8025 | Email testing UI |

---

## 🚀 Quick Start

### Prerequisites
- Docker + Docker Compose
- 16GB RAM recommended (Ollama + Qwen3-Coder)
- Jira Cloud account + API token

### 1. Clone & Configure

```bash
git clone https://github.com/StarSimo00/helpdesk-ai-agent.git
cd helpdesk-ai-agent
cp helpdesk-frontend/.env.example helpdesk-frontend/.env
```

### 2. Set Environment Variables

Edit `helpdesk-frontend/.env`:
```env
VITE_N8N_WEBHOOK=http://localhost:5678/webhook/YOUR-WEBHOOK-ID
```

### 3. Start All Services

```bash
sudo docker compose up -d
```

### 4. Pull AI Models

```bash
sudo docker exec helpdesk-ollama ollama pull qwen3-coder-next:cloud
sudo docker exec helpdesk-ollama ollama pull nomic-embed-text
```

### 5. Import n8n Workflow

1. Open n8n at `http://localhost:5678`
2. Import `HelpBot-agent-final.json`
3. Configure credentials:
   - **Postgres account** → `helpdesk-postgres:5432`
   - **Ollama account** → `http://helpdesk-ollama:11434`
   - **Qdrant account** → `http://helpdesk-qdrant:6333`
   - **Jira SW Cloud** → your Jira domain + API token
4. Paste system prompt from `system_prompt.txt` into AI Agent node
5. Save → Publish

### 6. Index Knowledge Base

In n8n, run the **KB Indexer** workflow once to embed all 34 articles into Qdrant.

### 7. Access

| URL | Description |
|---|---|
| `http://localhost:3000` | HelpBot Chat Interface |
| `http://localhost:3000/dashboard` | IT Admin Dashboard (IT dept only) |
| `http://localhost:5678` | n8n Workflow Editor |
| `http://localhost:8025` | Mailhog (OTP emails) |
| `http://localhost:5001/apidocs` | Flask API Swagger Docs |

---

## 👥 Test Users

| Username | Password | Department | Role |
|---|---|---|---|
| `jdoe` | `Password123!` | IT | IT Technician |
| `ebrown` | `Password123!` | Finance | Accountant |
| `mwilson` | `Password123!` | IT | IT Manager |
| `asmith` | `Password123!` | HR | HR Manager |

---

## 🤖 N1 Automation Flows

### Authenticated Users
| Issue | Actions |
|---|---|
| Account Locked | Lookup → Unlock → Jira ticket → Log |
| Password Reset | Reset → Temp password → Jira ticket → Log |
| VPN Issue | Diagnose → RAG KB search → Steps → Jira → Log |
| Access Request | Provision LDAP group → Jira → Log |
| App Error | resolve_app_error → RAG KB → Steps → Jira → Log |

### Guest Users (OTP Flow)
1. Enter company email
2. Identity verification (name, department, title)
3. OTP sent to email via Mailhog
4. OTP verified → password reset automatically
5. Jira ticket created

---

## 🎫 Ticket Lifecycle

```
User sends message
    │
    ├── Frontend auto-creates DB ticket (status: open)
    │
    ├── AI classifies issue → update_ticket (status: in_progress)
    │
    ├── AI performs actions → update_ticket (action logged)
    │
    ├── Issue resolved → create_issue in Jira → update_ticket (jira_key, resolved)
    │
    └── If unresolved → escalate → update_ticket (escalated: true)
```

---

## 📊 Dashboard Features

| Tab | Content |
|---|---|
| Overview | KPI cards, action charts, daily activity, recent logs |
| N1 Tickets | All DB tickets with Jira links, actions timeline, detail modal |
| N2 Escalations | Open escalations with Take/Resolve actions |
| Action Logs | Filterable full audit log with pagination |
| Access Requests | Approve/Reject/Provision access requests |

---

## 🗄️ Database Schema

Key tables in PostgreSQL:

```sql
n1_tickets      -- Support tickets (DB source of truth)
escalations     -- N2 escalation records
automation_logs -- All AI actions audit trail
knowledge_base  -- 34 IT KB articles
n8n_chat_memory -- AI conversation memory
chat_history    -- Resolved conversation summaries
access_requests -- LDAP access request tracking
otp_store       -- Temporary OTP codes
```

---

## 🔧 API Endpoints

The Flask API exposes 22+ endpoints documented at `/apidocs`:

| Endpoint | Method | Description |
|---|---|---|
| `/ldap-login` | POST | AD authentication |
| `/lookup` | POST | User lookup |
| `/unlock` | POST | Unlock AD account |
| `/reset-password` | POST | Reset with temp password |
| `/diagnose-vpn` | POST | VPN health check |
| `/provision-access` | POST | Add user to LDAP group |
| `/resolve-app-error` | POST | App troubleshooting steps |
| `/send-otp` | POST | Send OTP email |
| `/verify-otp` | POST | Verify OTP + reset password |
| `/tickets` | GET/POST | N1 ticket management |
| `/tickets/<id>` | PATCH | Update ticket |
| `/escalate` | POST | Create N2 escalation |
| `/escalations` | GET | List escalations |
| `/dashboard/stats` | GET | Dashboard metrics |
| `/logs` | GET | Action logs with filters |

---

## 📁 Project Structure

```
helpdesk-ai-agent/
├── docker-compose.yml
├── helpdesk-frontend/          # React + Vite frontend
│   ├── src/components/
│   │   ├── LoginPage.jsx       # AD login + guest mode
│   │   ├── ChatPage.jsx        # Main chat interface
│   │   └── DashboardPage.jsx   # IT admin dashboard
│   └── nginx.conf
├── ldap-api/
│   └── app.py                  # Flask API (1700+ lines)
├── postgres/
│   └── init.sql                # DB schema + seed data
├── openldap/
│   └── init.ldif               # 50 test users
├── HelpBot-agent-final.json    # n8n workflow
└── system_prompt.txt           # AI agent instructions
```

---

## 🛠️ Tech Stack

| Layer | Technology |
|---|---|
| **AI Model** | Qwen3-Coder-Next via Ollama |
| **Orchestration** | n8n (self-hosted) |
| **RAG** | Qdrant + nomic-embed-text embeddings |
| **Frontend** | React 18 + Vite 5 + React Router |
| **API** | Flask + Flask-CORS + Flasgger (Swagger) |
| **Auth** | OpenLDAP + ldap3 |
| **Database** | PostgreSQL 15 |
| **Ticketing** | Jira Cloud REST API |
| **Email** | Mailhog (SMTP testing) |
| **Deploy** | Docker Compose |

---

## 📝 License

MIT — built for educational and demonstration purposes.
