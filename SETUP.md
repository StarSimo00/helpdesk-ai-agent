# Helpdesk AI Agent V3 — OpenLDAP Setup Guide

## What Changed from V2
- **Samba AD → OpenLDAP** (no TLS, plain auth on port 389, zero config headaches)
- **toolCode Python** for all LDAP and Postgres operations
- **Native Jira node** as tool for ticket creation
- **No knowledge_base table needed** — KB search uses Postgres directly

## File Structure
```
helpdesk-v3/
├── docker-compose.yml
├── Dockerfile.n8n
├── openldap/
│   └── bootstrap.ldif       ← users + OUs loaded at startup
├── postgres/
│   └── init.sql             ← schema + KB articles
└── n8n-workflows/
    └── helpdesk-agent.json  ← importable workflow
```

## Step 1 — Deploy
```bash
cd ~/helpdesk-v3
sudo docker compose up -d --build
```

Wait ~60 seconds for OpenLDAP to bootstrap users.

## Step 2 — Verify OpenLDAP
```bash
# Test plain auth - should return John Doe
sudo docker exec helpdesk-n8n ldapsearch \
  -x -H ldap://helpdesk-openldap:389 \
  -D "cn=admin,dc=support,dc=local" \
  -w "Admin1234!" \
  -b "ou=Users,dc=support,dc=local" \
  -LLL "(uid=jdoe)" uid displayName mail departmentNumber
```

Expected: `dn: uid=jdoe,ou=Users,dc=support,dc=local` + attributes

## Step 3 — Verify Postgres
```bash
sudo docker exec -e PGPASSWORD=helpdeskpass helpdesk-n8n psql \
  -h postgres -U helpdesk -d helpdesk \
  -c "SELECT title FROM knowledge_base LIMIT 3;"
```

## Step 4 — Verify ldapmodify (unlock)
```bash
# This should succeed (remove LOCKED flag from bjones)
sudo docker exec helpdesk-n8n bash -c \
  'printf "dn: uid=bjones,ou=Users,dc=support,dc=local\nchangetype: modify\ndelete: description\ndescription: LOCKED\n" | ldapmodify -x -H ldap://helpdesk-openldap:389 -D "cn=admin,dc=support,dc=local" -w "Admin1234!"'
```

## Step 5 — Verify ldapmodify (password reset)
```bash
sudo docker exec helpdesk-n8n bash -c \
  'printf "dn: uid=jdoe,ou=Users,dc=support,dc=local\nchangetype: modify\nreplace: userPassword\nuserPassword: TestPass123!\n" | ldapmodify -x -H ldap://helpdesk-openldap:389 -D "cn=admin,dc=support,dc=local" -w "Admin1234!"'
```

## Step 6 — Import Workflow in n8n
1. Open http://localhost:5678
2. Login: admin / admin1234
3. Go to **Settings → Credentials** and add:
   - **Postgres**: host=postgres, port=5432, db=helpdesk, user=helpdesk, pass=helpdeskpass, SSL=disabled
   - **Ollama**: http://host-gateway:11434
   - **Jira**: your Jira Cloud API token
4. Go to **Workflows → Import from file** → select `helpdesk-agent.json`
5. Assign credentials to Ollama and Postgres Memory nodes
6. Publish

## Step 7 — Test Scenarios
```
# Scenario 1 - Unlock
my account is locked → username: bjones

# Scenario 2 - Password reset
I forgot my password → username: jdoe

# Scenario 3 - KB search
Teams is showing a blank black screen

# Scenario 4 - French
je narrive pas a me connecter au VPN

# Scenario 5 - Jira access request
I need access to Salesforce for my new role in Sales

# Scenario 6 - Jira escalation
The entire ERP is down, nobody can work
```

## Demo Users
| Username  | Name          | Dept       | Status  |
|-----------|---------------|------------|---------|
| jdoe      | John Doe      | IT         | ACTIVE  |
| mwilson   | Mark Wilson   | IT         | ACTIVE  |
| dwhite    | David White   | IT         | ACTIVE  |
| bjones    | Bob Jones     | HR         | LOCKED  |
| sjohnson  | Sarah Johnson | HR         | ACTIVE  |
| asmith    | Alice Smith   | Finance    | ACTIVE  |
| ebrown    | Emma Brown    | Finance    | ACTIVE  |
| jmartin   | James Martin  | Sales      | ACTIVE  |
| cdurand   | Claire Durand | Management | ACTIVE  |
| svc-n8n   | Service Acct  | IT         | ACTIVE  |

## LDAP Credentials
- Admin DN: `cn=admin,dc=support,dc=local`
- Password: `Admin1234!`
- Base DN: `ou=Users,dc=support,dc=local`
- Port: 389 (plain, no TLS)

## Postgres Credentials
- Host: postgres | DB: helpdesk | User: helpdesk | Pass: helpdeskpass

## Ollama
- URL: `http://host-gateway:11434`
- Model: `qwen3:latest` (or any model you have pulled)
