from flask import Flask, request, jsonify
from flask_cors import CORS
from flasgger import Swagger
import ldap3, random, string, psycopg2, psycopg2.extras
import datetime, subprocess, socket, os, smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from qdrant_client import QdrantClient
from qdrant_client.models import Distance, VectorParams, PointStruct

app = Flask(__name__)

swagger_config = {
    "headers": [],
    "specs": [{"endpoint": "apispec", "route": "/apispec.json", "rule_filter": lambda rule: True, "model_filter": lambda tag: True}],
    "static_url_path": "/flasgger_static",
    "swagger_ui": True,
    "specs_route": "/docs"
}
swagger_template = {
    "info": {
        "title": "HelpBot Helpdesk API",
        "description": "Agent IA pour automatiser le support N1 applicatif",
        "version": "2.0.0"
    },
    "tags": [
        {"name": "Auth", "description": "LDAP authentication"},
        {"name": "Account", "description": "Unlock accounts and reset passwords"},
        {"name": "VPN", "description": "VPN diagnostics"},
        {"name": "Access", "description": "Application access provisioning"},
        {"name": "Knowledge Base", "description": "KB search"},
        {"name": "OTP", "description": "One-time password flow"},
        {"name": "Dashboard", "description": "Stats and metrics"}
    ]
}
Swagger(app, config=swagger_config, template=swagger_template)
CORS(app)

LDAP_HOST = os.getenv("LDAP_HOST", "helpdesk-openldap")
LDAP_PORT = int(os.getenv("LDAP_PORT", 389))
LDAP_BIND = os.getenv("LDAP_BIND", "cn=admin,dc=support,dc=local")
LDAP_PASS = os.getenv("LDAP_PASS", "Admin1234!")
LDAP_BASE = os.getenv("LDAP_BASE", "ou=Users,dc=support,dc=local")

PG = {
    "host":     os.getenv("PG_HOST", "postgres"),
    "dbname":   os.getenv("PG_DB",   "helpdesk"),
    "user":     os.getenv("PG_USER", "helpdesk"),
    "password": os.getenv("PG_PASS", "helpdeskpass"),
}

SMTP_HOST = os.getenv("SMTP_HOST", "helpdesk-mailhog")
SMTP_PORT = int(os.getenv("SMTP_PORT", 1025))
SMTP_FROM = os.getenv("SMTP_FROM", "helpdesk@support.local")

VPN_GATEWAYS = [
    {"name": "Primary Gateway",   "host": "8.8.8.8",  "port": 443},
    {"name": "Secondary Gateway", "host": "8.8.4.4",  "port": 443},
    {"name": "DNS Server",        "host": "1.1.1.1",  "port": 53},
]

# ── Helpers ───────────────────────────────────────────────────────────────────
def get_ldap():
    server = ldap3.Server(LDAP_HOST, port=LDAP_PORT, use_ssl=False)
    return ldap3.Connection(server, user=LDAP_BIND, password=LDAP_PASS, auto_bind=True)

def get_pg():
    return psycopg2.connect(**PG)

def pg_log(action_type, target_user, status, details, ticket_id="", session_id=""):
    try:
        conn = get_pg()
        cur = conn.cursor()
        cur.execute(
            "INSERT INTO automation_logs (action_type, target_user, status, details, ticket_id, session_id) "
            "VALUES (%s,%s,%s,%s,%s,%s) RETURNING id",
            (action_type, target_user, status, details, ticket_id, session_id)
        )
        row = cur.fetchone()
        conn.commit(); conn.close()
        return row[0]
    except Exception:
        return None

# ── Health ────────────────────────────────────────────────────────────────────
@app.route("/health", methods=["GET"])
def health():
    """
    Health check
    ---
    tags: [Dashboard]
    responses:
      200:
        description: API is running
    """
    return jsonify({"success": True, "data": {"status": "ok", "version": "2.0"}})

@app.route("/whoami", methods=["GET"])
def whoami():
    return jsonify({"success": True, "data": {"service": "Helpdesk Automation API", "version": "2.0"}})

# ── LDAP Login (search → bind pattern) ───────────────────────────────────────
@app.route("/ldap-login", methods=["POST"])
def ldap_login():
    """
    Authenticate user against LDAP/AD
    ---
    tags: [Auth]
    parameters:
      - in: body
        name: body
        schema:
          properties:
            username: {type: string, example: jdoe}
            password: {type: string, example: Password123!}
    responses:
      200:
        description: Login success or failure
    """
    data = request.json or {}
    username = data.get("username", "").strip().lower()
    password = data.get("password", "")
    if not username or not password:
        return jsonify({"success": False, "error": "username and password required"}), 400
    try:
        server = ldap3.Server(LDAP_HOST, port=LDAP_PORT, use_ssl=False)
        # Step 1: admin bind to find user DN
        admin_conn = ldap3.Connection(server, user=LDAP_BIND, password=LDAP_PASS, auto_bind=True)
        admin_conn.search(LDAP_BASE, f"(uid={username})", attributes=["uid"])
        if not admin_conn.entries:
            pg_log("LOGIN", username, "failure", "User not found in LDAP")
            return jsonify({"success": False, "error": "USER_NOT_FOUND"}), 404
        user_dn = admin_conn.entries[0].entry_dn
        # Step 2: bind as user to verify password
        user_conn = ldap3.Connection(server, user=user_dn, password=password)
        if not user_conn.bind():
            pg_log("LOGIN", username, "failure", "Invalid credentials")
            return jsonify({"success": False, "error": "INVALID_CREDENTIALS"}), 401
        pg_log("LOGIN", username, "success", "LDAP authentication successful")
        return jsonify({"success": True, "data": {"username": username, "authenticated": True}})
    except Exception as ex:
        pg_log("LOGIN", username, "failure", str(ex))
        return jsonify({"success": False, "error": str(ex)}), 500

# ── Lookup User ───────────────────────────────────────────────────────────────
@app.route("/lookup", methods=["POST"])
def lookup():
    """
    Lookup LDAP user details
    ---
    tags: [Account]
    parameters:
      - in: body
        name: body
        schema:
          properties:
            username: {type: string, example: jdoe}
    responses:
      200:
        description: User details
    """
    data = request.json or {}
    username = data.get("username", "").strip().lower()
    if not username:
        return jsonify({"success": False, "error": "username required"}), 400
    try:
        conn = get_ldap()
        conn.search(LDAP_BASE, f"(uid={username})",
                    attributes=["uid","displayName","mail","departmentNumber","title","description"])
        if not conn.entries:
            return jsonify({"success": False, "error": "USER_NOT_FOUND"}), 404
        e = conn.entries[0]
        desc = str(e.description) if e.description else ""
        return jsonify({"success": True, "data": {
            "dn":          str(e.entry_dn),
            "username":    username,
            "displayName": str(e.displayName)     if e.displayName     else username,
            "email":       str(e.mail)             if e.mail             else "",
            "department":  str(e.departmentNumber) if e.departmentNumber else "",
            "title":       str(e.title)            if e.title            else "",
            "status":      "LOCKED" if "LOCKED" in desc.upper() else "ACTIVE",
        }})
    except Exception as ex:
        return jsonify({"success": False, "error": str(ex)}), 500

# ── Unlock Account ────────────────────────────────────────────────────────────
@app.route("/unlock", methods=["POST"])
def unlock():
    """
    Unlock a locked LDAP account
    ---
    tags: [Account]
    parameters:
      - in: body
        name: body
        schema:
          properties:
            username: {type: string, example: jdoe}
    responses:
      200:
        description: Account unlocked
    """
    data = request.json or {}
    username   = data.get("username",   "").strip().lower()
    ticket_id  = data.get("ticket_id",  "")
    session_id = data.get("session_id", "")
    if not username:
        return jsonify({"success": False, "error": "username required"}), 400
    try:
        conn = get_ldap()
        conn.search(LDAP_BASE, f"(uid={username})", attributes=["description"])
        if not conn.entries:
            return jsonify({"success": False, "error": "USER_NOT_FOUND"}), 404
        dn = str(conn.entries[0].entry_dn)
        conn.modify(dn, {"description": [(ldap3.MODIFY_DELETE, ["LOCKED"])]})
        if conn.result["result"] in (0, 16):
            pg_log("UNLOCK_ACCOUNT", username, "success",
                   f"Account unlocked for {username}", ticket_id, session_id)
            return jsonify({"success": True, "data": {"username": username, "message": "Account unlocked"}})
        return jsonify({"success": False, "error": conn.result["description"]}), 500
    except Exception as ex:
        pg_log("UNLOCK_ACCOUNT", username, "failure", str(ex), ticket_id, session_id)
        return jsonify({"success": False, "error": str(ex)}), 500

# ── Reset Password (also unlocks if locked) ───────────────────────────────────
@app.route("/reset-password", methods=["POST"])
def reset_password():
    """
    Reset user password and generate temp password
    ---
    tags: [Account]
    parameters:
      - in: body
        name: body
        schema:
          properties:
            username: {type: string, example: jdoe}
    responses:
      200:
        description: Password reset with temp password
    """
    data = request.json or {}
    username   = data.get("username",   "").strip().lower()
    ticket_id  = data.get("ticket_id",  "")
    session_id = data.get("session_id", "")
    if not username:
        return jsonify({"success": False, "error": "username required"}), 400
    try:
        conn = get_ldap()
        conn.search(LDAP_BASE, f"(uid={username})", attributes=["displayName","description"])
        if not conn.entries:
            return jsonify({"success": False, "error": "USER_NOT_FOUND"}), 404
        dn   = str(conn.entries[0].entry_dn)
        desc = str(conn.entries[0].description) if conn.entries[0].description else ""

        # Auto-unlock if account was locked
        was_locked = "LOCKED" in desc.upper()
        if was_locked:
            conn.modify(dn, {"description": [(ldap3.MODIFY_DELETE, ["LOCKED"])]})

        # Generate temp password
        chars = string.ascii_letters + string.digits + "!@#$%"
        tmp   = "Hd" + "".join(random.choices(chars, k=10)) + "!"
        conn.modify(dn, {"userPassword": [(ldap3.MODIFY_REPLACE, [tmp])]})

        if conn.result["result"] == 0:
            detail = f"Password reset for {username}, temp password issued"
            if was_locked:
                detail += " (account was also unlocked)"
            pg_log("RESET_PASSWORD", username, "success", detail, ticket_id, session_id)
            return jsonify({"success": True, "data": {
                "username":    username,
                "tempPassword": tmp,
                "wasLocked":   was_locked,
            }})
        return jsonify({"success": False, "error": conn.result["description"]}), 500
    except Exception as ex:
        pg_log("RESET_PASSWORD", username, "failure", str(ex), ticket_id, session_id)
        return jsonify({"success": False, "error": str(ex)}), 500

# ── Search KB (RAG — Qdrant vector search) ────────────────────────────────────
@app.route("/search-kb", methods=["GET"])
def search_kb():
    """
    Search KB using semantic vector search (RAG)
    ---
    tags: [Knowledge Base]
    parameters:
      - in: query
        name: q
        type: string
        example: vpn not connecting
    responses:
      200:
        description: Matching KB articles
    """
    q = request.args.get("q", "").strip()
    if not q:
        return jsonify({"success": True, "data": {"results": []}})
    try:
        vector  = list(get_embedder().embed([q]))[0].tolist()
        hits    = get_qdrant().query_points(
            collection_name=KB_COLLECTION,
            query=vector,
            limit=3,
            score_threshold=0.3
        ).points
        results = [{"title": h.payload["title"], "category": h.payload["category"],
                    "solution_text": h.payload["solution_text"], "score": round(h.score, 3)}
                   for h in hits]
        pg_log("SEARCH_KB", "agent", "success", f"RAG search: '{q}' → {len(results)} results")
        return jsonify({"success": True, "data": {"results": results}})
    except Exception as ex:
        # Fallback to SQL if Qdrant not ready
        try:
            conn = get_pg(); cur = conn.cursor()
            cur.execute(
                "SELECT title, category, solution_text FROM knowledge_base "
                "WHERE is_active=true AND (title ILIKE %s OR solution_text ILIKE %s) "
                "ORDER BY confidence_boost DESC LIMIT 3",
                (f"%{q}%", f"%{q}%")
            )
            rows = cur.fetchall(); conn.close()
            return jsonify({"success": True, "data": {"results": [
                {"title": r[0], "category": r[1], "solution_text": r[2]} for r in rows
            ]}})
        except Exception as ex2:
            return jsonify({"success": False, "error": str(ex2)})

# ── Log Action ────────────────────────────────────────────────────────────────
@app.route("/log-action", methods=["POST"])
def log_action():
    data       = request.json or {}
    action     = data.get("action_type", "AGENT_ACTION")
    user       = data.get("target_user", "unknown")
    details    = str(data.get("details", data.get("action", "")))
    ticket_id  = data.get("ticket_id",  "")
    session_id = data.get("session_id", "")
    status     = data.get("status",     "success")
    try:
        conn = get_pg(); cur = conn.cursor()
        cur.execute(
            "INSERT INTO automation_logs (action_type, target_user, status, details, ticket_id, session_id) "
            "VALUES (%s,%s,%s,%s,%s,%s) RETURNING id",
            (action, user, status, details, ticket_id, session_id)
        )
        row = cur.fetchone(); conn.commit(); conn.close()
        return jsonify({"success": True, "data": {"log_id": row[0], "message": "Action logged"}})
    except Exception as ex:
        return jsonify({"success": False, "error": str(ex)}), 500

# ── VPN Diagnostics ───────────────────────────────────────────────────────────
@app.route("/diagnose-vpn", methods=["POST"])
def diagnose_vpn():
    """
    Run N1 VPN diagnostic (internet, DNS, gateways, MTU, split DNS)
    ---
    tags: [VPN]
    parameters:
      - in: body
        name: body
        schema:
          properties:
            username: {type: string, example: jdoe}
    responses:
      200:
        description: VPN diagnostic results
    """
    data       = request.json or {}
    username   = data.get("username",   "unknown")
    ticket_id  = data.get("ticket_id",  "")
    session_id = data.get("session_id", "")

    results         = []
    overall_status  = "healthy"
    recommendations = []

    # Check 1: Internet connectivity
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(3)
        r = sock.connect_ex(("8.8.8.8", 80))
        sock.close()
        if r == 0:
            results.append({"check": "Internet Connectivity", "status": "pass", "detail": "Internet connection available"})
        else:
            results.append({"check": "Internet Connectivity", "status": "fail", "detail": "No internet connectivity detected"})
            recommendations.append("Check your network cable or WiFi connection before attempting VPN")
            overall_status = "critical"
    except Exception as ex:
        results.append({"check": "Internet Connectivity", "status": "fail", "detail": str(ex)})
        overall_status = "critical"

    # Check 2: DNS resolution
    try:
        socket.setdefaulttimeout(3)
        socket.gethostbyname("google.com")
        results.append({"check": "DNS Resolution", "status": "pass", "detail": "DNS resolving correctly"})
    except Exception:
        results.append({"check": "DNS Resolution", "status": "fail", "detail": "DNS resolution failed"})
        recommendations.append("Flush DNS: run 'ipconfig /flushdns' as administrator")
        recommendations.append("Check DNS server settings in Network Adapter properties")
        if overall_status == "healthy":
            overall_status = "degraded"

    # Check 3: VPN gateway ports
    gateway_failures = 0
    for gw in VPN_GATEWAYS:
        try:
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.settimeout(3)
            r = sock.connect_ex((gw["host"], gw["port"]))
            sock.close()
            if r == 0:
                results.append({"check": f"Gateway: {gw['name']}", "status": "pass", "detail": f"Reachable on port {gw['port']}"})
            else:
                results.append({"check": f"Gateway: {gw['name']}", "status": "fail", "detail": f"Port {gw['port']} unreachable — firewall may be blocking VPN"})
                gateway_failures += 1
                if overall_status == "healthy":
                    overall_status = "degraded"
        except Exception as ex:
            results.append({"check": f"Gateway: {gw['name']}", "status": "fail", "detail": str(ex)})
            gateway_failures += 1
            if overall_status == "healthy":
                overall_status = "degraded"

    if gateway_failures == len(VPN_GATEWAYS):
        overall_status = "critical"
        recommendations.append("All VPN gateways unreachable — firewall or antivirus may be blocking ports 443/53")
        recommendations.append("Try from a different network (mobile hotspot) to rule out ISP blocking")
        recommendations.append("Contact IT — a VPN gateway outage may be in progress")
    elif gateway_failures > 0:
        recommendations.append("Some gateways unreachable — try switching to an alternate VPN profile/gateway")

    # Check 4: MTU (safe cross-platform version)
    try:
        result = subprocess.run(
            ["ping", "-c", "1", "-s", "1400", "8.8.8.8"],
            capture_output=True, text=True, timeout=5
        )
        if result.returncode == 0:
            results.append({"check": "MTU Check (1400 bytes)", "status": "pass", "detail": "No packet fragmentation issues detected"})
        else:
            results.append({"check": "MTU Check (1400 bytes)", "status": "warn", "detail": "Large packets may be fragmented — can cause VPN instability"})
            recommendations.append("MTU issue detected — set MTU to 1350 on your VPN or network adapter")
            if overall_status == "healthy":
                overall_status = "warning"
    except Exception:
        results.append({"check": "MTU Check", "status": "skip", "detail": "MTU test skipped"})

    # Check 5: Internal DNS (split-tunnel check)
    try:
        socket.gethostbyname("helpdesk-openldap")
        results.append({"check": "Internal DNS (Split Tunnel)", "status": "pass", "detail": "Internal hostnames resolving — split DNS working"})
    except Exception:
        results.append({"check": "Internal DNS (Split Tunnel)", "status": "warn", "detail": "Cannot resolve internal hostnames — VPN split DNS may not be configured"})
        if overall_status == "healthy":
            overall_status = "warning"

    # Always-recommended VPN client steps
    recommendations += [
        "Ensure VPN client is up to date (GlobalProtect / Cisco AnyConnect / FortiClient)",
        "Disconnect and reconnect the VPN client",
        "Restart your computer if VPN shows connected but traffic is not routing",
    ]

    summary = {
        "healthy":  "VPN infrastructure looks healthy. Issue likely client-side — try reconnecting.",
        "warning":  "Minor issues detected. VPN may work with degraded performance.",
        "degraded": "Connectivity issues found. VPN will likely fail. Follow recommendations.",
        "critical": "Critical connectivity failure. VPN cannot connect. Escalation required.",
    }.get(overall_status, "Unknown")

    failed = len([r for r in results if r["status"] == "fail"])
    pg_log("VPN_DIAGNOSTIC", username, overall_status,
           f"VPN diagnostic: {overall_status} — {failed} checks failed", ticket_id, session_id)

    return jsonify({"success": True, "data": {
        "overall_status":  overall_status,
        "summary":         summary,
        "checks":          results,
        "recommendations": recommendations,
        "failed_count":    failed,
        "checked_at":      datetime.datetime.utcnow().isoformat() + "Z",
        "username":        username,
    }})

# ── Access Request ────────────────────────────────────────────────────────────
@app.route("/access-request", methods=["POST"])
def access_request():
    data           = request.json or {}
    username       = data.get("username",       "").strip().lower()
    application    = data.get("application",    "").strip()
    business_reason= data.get("business_reason","").strip()
    access_level   = data.get("access_level",   "Read").strip()
    ticket_id      = data.get("ticket_id",      "")
    session_id     = data.get("session_id",     "")

    if not username or not application:
        return jsonify({"success": False, "error": "username and application required"}), 400
    try:
        conn = get_pg(); cur = conn.cursor()
        cur.execute(
            "SELECT id FROM access_requests WHERE username=%s AND application=%s AND status='pending'",
            (username, application)
        )
        existing = cur.fetchone()
        if existing:
            conn.close()
            return jsonify({"success": False, "error": "DUPLICATE_REQUEST",
                            "data": {"message": f"Pending request already exists (ID: {existing[0]})"}}), 409
        cur.execute(
            "INSERT INTO access_requests (username, application, business_reason, access_level, status, ticket_id, session_id) "
            "VALUES (%s,%s,%s,%s,'pending',%s,%s) RETURNING id, created_at",
            (username, application, business_reason, access_level, ticket_id, session_id)
        )
        row = cur.fetchone(); conn.commit(); conn.close()
        pg_log("ACCESS_REQUEST", username, "pending",
               f"Access request for {application} ({access_level}) — {business_reason}", ticket_id, session_id)
        return jsonify({"success": True, "data": {
            "request_id":      row[0],
            "username":        username,
            "application":     application,
            "access_level":    access_level,
            "business_reason": business_reason,
            "status":          "pending",
            "ticket_id":       ticket_id,
            "message":         f"Access request #{row[0]} submitted for {application}. Pending manager approval. IT will provision within 24-48h after approval.",
            "created_at":      str(row[1]),
        }})
    except Exception as ex:
        return jsonify({"success": False, "error": str(ex)}), 500

@app.route("/access-requests", methods=["GET"])
def list_access_requests():
    username = request.args.get("username", "")
    status   = request.args.get("status",   "")
    try:
        conn = get_pg()
        cur  = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
        q    = "SELECT * FROM access_requests WHERE 1=1"
        params = []
        if username: q += " AND username=%s"; params.append(username)
        if status:   q += " AND status=%s";   params.append(status)
        q += " ORDER BY created_at DESC LIMIT 100"
        cur.execute(q, params)
        rows = cur.fetchall(); conn.close()
        return jsonify({"success": True, "data": {"requests": [dict(r) for r in rows], "count": len(rows)}})
    except Exception as ex:
        return jsonify({"success": False, "error": str(ex)}), 500

@app.route("/access-request/<int:req_id>", methods=["PATCH"])
def update_access_request(req_id):
    data   = request.json or {}
    status = data.get("status", "")
    notes  = data.get("notes",  "")
    if status not in ("pending", "approved", "rejected", "provisioned"):
        return jsonify({"success": False, "error": "invalid status"}), 400
    try:
        conn = get_pg(); cur = conn.cursor()
        cur.execute(
            "UPDATE access_requests SET status=%s, notes=%s, updated_at=NOW() WHERE id=%s RETURNING username, application",
            (status, notes, req_id)
        )
        row = cur.fetchone(); conn.commit(); conn.close()
        if row:
            pg_log("ACCESS_REQUEST_UPDATE", row[0], status,
                   f"Request #{req_id} for {row[1]} → {status}. Notes: {notes}")
            return jsonify({"success": True, "data": {"request_id": req_id, "status": status}})
        return jsonify({"success": False, "error": "request not found"}), 404
    except Exception as ex:
        return jsonify({"success": False, "error": str(ex)}), 500

# ── Automation Logs ───────────────────────────────────────────────────────────
@app.route("/logs", methods=["GET"])
def get_logs():
    """
    Get automation logs with filters
    ---
    tags: [Dashboard]
    parameters:
      - in: query
        name: username
        type: string
      - in: query
        name: action_type
        type: string
      - in: query
        name: limit
        type: integer
    responses:
      200:
        description: List of logs
    """
    limit      = int(request.args.get("limit",  100))
    offset     = int(request.args.get("offset", 0))
    username   = request.args.get("username",   "")
    action_type= request.args.get("action_type","")
    ticket_id  = request.args.get("ticket_id",  "")
    try:
        conn = get_pg()
        cur  = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
        q    = "SELECT * FROM automation_logs WHERE 1=1"
        params = []
        if username:    q += " AND target_user=%s";  params.append(username)
        if action_type: q += " AND action_type=%s";  params.append(action_type)
        if ticket_id:   q += " AND ticket_id=%s";    params.append(ticket_id)
        q += " ORDER BY created_at DESC LIMIT %s OFFSET %s"
        params += [limit, offset]
        cur.execute(q, params)
        rows = cur.fetchall()
        # Fix: alias the count column
        cur.execute("SELECT COUNT(*) AS total FROM automation_logs")
        total = cur.fetchone()["total"]
        conn.close()
        return jsonify({"success": True, "data": {
            "logs": [dict(r) for r in rows], "total": total, "limit": limit, "offset": offset
        }})
    except Exception as ex:
        return jsonify({"success": False, "error": str(ex)}), 500

# ── Dashboard Stats ───────────────────────────────────────────────────────────
@app.route("/dashboard/stats", methods=["GET"])
def dashboard_stats():
    """
    Get all dashboard KPI metrics
    ---
    tags: [Dashboard]
    responses:
      200:
        description: Dashboard statistics
    """
    try:
        conn = get_pg()
        cur  = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

        cur.execute("SELECT COUNT(*) AS total FROM automation_logs")
        total_actions = cur.fetchone()["total"]

        cur.execute("SELECT action_type, COUNT(*) AS count FROM automation_logs GROUP BY action_type ORDER BY count DESC")
        by_action = cur.fetchall()

        cur.execute("SELECT status, COUNT(*) AS count FROM automation_logs GROUP BY status")
        by_status = cur.fetchall()

        cur.execute("SELECT COUNT(*) AS count FROM automation_logs WHERE status='success'")
        success_count = cur.fetchone()["count"]
        success_rate  = round((success_count / total_actions * 100), 1) if total_actions > 0 else 0

        cur.execute("""
            SELECT DATE(created_at) AS day, COUNT(*) AS count
            FROM automation_logs
            WHERE created_at >= NOW() - INTERVAL '7 days'
            GROUP BY day ORDER BY day
        """)
        daily_activity = cur.fetchall()

        cur.execute("SELECT * FROM automation_logs ORDER BY created_at DESC LIMIT 10")
        recent = cur.fetchall()

        cur.execute("SELECT status, COUNT(*) AS count FROM access_requests GROUP BY status")
        access_stats = cur.fetchall()

        cur.execute("SELECT COUNT(*) AS count FROM automation_logs WHERE action_type ILIKE '%kb%' OR action_type='SEARCH_KB'")
        kb_searches = cur.fetchone()["count"]

        # Metric: Average resolution time (seconds between first and last log per ticket)
        cur.execute("""
            SELECT ROUND(AVG(EXTRACT(EPOCH FROM (max_t - min_t)))) AS avg_seconds
            FROM (
                SELECT ticket_id, MIN(created_at) AS min_t, MAX(created_at) AS max_t
                FROM automation_logs
                WHERE ticket_id != '' AND ticket_id IS NOT NULL
                GROUP BY ticket_id
                HAVING COUNT(*) > 1
            ) sub
        """)
        avg_row = cur.fetchone()
        avg_seconds = int(avg_row["avg_seconds"]) if avg_row and avg_row["avg_seconds"] else 0
        if avg_seconds < 60:
            avg_resolution_display = f"{avg_seconds}s"
        elif avg_seconds < 3600:
            avg_resolution_display = f"{avg_seconds // 60}m {avg_seconds % 60}s"
        else:
            avg_resolution_display = f"{avg_seconds // 3600}h {(avg_seconds % 3600) // 60}m"

        # Metric: Simulated satisfaction score
        # Based on: success rate, resolution speed, auto-resolution rate
        # Formula: weighted score out of 5
        auto_resolved = success_count
        total_t = max(total_actions, 1)
        speed_score = max(0, 5 - (avg_seconds / 60))  # loses points if > 5min avg
        speed_score = min(5, speed_score)
        success_score = (success_count / total_t) * 5
        satisfaction = round((speed_score * 0.4 + success_score * 0.6), 1)
        satisfaction = min(5.0, max(1.0, satisfaction))

        conn.close()
        return jsonify({"success": True, "data": {
            "total_actions":        total_actions,
            "success_rate":         success_rate,
            "by_action":            [dict(r) for r in by_action],
            "by_status":            [dict(r) for r in by_status],
            "daily_activity":       [{"day": str(r["day"]), "count": r["count"]} for r in daily_activity],
            "recent_logs":          [dict(r) for r in recent],
            "access_requests":      [dict(r) for r in access_stats],
            "kb_searches":          kb_searches,
            "avg_resolution":       avg_seconds,
            "avg_resolution_display": avg_resolution_display,
            "satisfaction_score":   satisfaction,
            "satisfaction_label":   "Excellent" if satisfaction >= 4.5 else "Bon" if satisfaction >= 3.5 else "Moyen" if satisfaction >= 2.5 else "Faible",
        }})
    except Exception as ex:
        return jsonify({"success": False, "error": str(ex)}), 500

# ── List Users ────────────────────────────────────────────────────────────────
@app.route("/list-users", methods=["GET"])
def list_users():
    try:
        conn = get_ldap()
        conn.search(LDAP_BASE, "(objectClass=inetOrgPerson)",
                    attributes=["uid","displayName","departmentNumber","title","description"])
        users = []
        for e in conn.entries:
            desc = str(e.description) if e.description else ""
            users.append({
                "uid":         str(e.uid)             if e.uid             else "",
                "displayName": str(e.displayName)     if e.displayName     else "",
                "department":  str(e.departmentNumber) if e.departmentNumber else "",
                "title":       str(e.title)            if e.title            else "",
                "status":      "LOCKED" if "LOCKED" in desc.upper() else "ACTIVE",
            })
        return jsonify({"success": True, "data": {"count": len(users), "users": users}})
    except Exception as ex:
        return jsonify({"success": False, "error": str(ex)}), 500


# ── App → LDAP Group mapping ──────────────────────────────────────────────────
APP_GROUPS = {
    'vpn':        'grp-vpn',
    'outlook':    'grp-outlook',
    'exchange':   'grp-outlook',
    'teams':      'grp-teams',
    'sharepoint': 'grp-sharepoint',
    'erp':        'grp-erp',
    'sap':        'grp-erp',
    'oracle':     'grp-erp',
    'crm':        'grp-crm',
    'salesforce': 'grp-crm',
    'hr':         'grp-hr',
    'portal':     'grp-hr',
    'github':     'grp-devtools',
    'jira':       'grp-devtools',
    'devtools':   'grp-devtools',
}

def get_group_for_app(application):
    app_lower = application.lower()
    for key, group in APP_GROUPS.items():
        if key in app_lower:
            return group
    return None


@app.route("/provision-access", methods=["POST"])
def provision_access():
    """
    Auto-add user to LDAP application group
    ---
    tags: [Access]
    parameters:
      - in: body
        name: body
        schema:
          properties:
            username: {type: string, example: jdoe}
            application: {type: string, example: sharepoint}
    responses:
      200:
        description: User added to app group
    """
    data        = request.json or {}
    username    = data.get("username",    "").strip().lower()
    application = data.get("application", "").strip()
    ticket_id   = data.get("ticket_id",   "")
    session_id  = data.get("session_id",  "")

    if not username or not application:
        return jsonify({"success": False, "error": "username and application required"}), 400

    group_cn = get_group_for_app(application)
    if not group_cn:
        pg_log("ACCESS_PROVISION", username, "warning",
               f"No LDAP group found for {application} — manual provisioning required", ticket_id, session_id)
        return jsonify({"success": True, "data": {
            "username": username, "application": application,
            "provisioned": False, "group": None,
            "message": f"No LDAP group configured for {application}. Ticket created and IT notified for manual provisioning within 24-48h."
        }})

    group_dn = f"cn={group_cn},ou=Groups,dc=support,dc=local"
    user_dn  = f"uid={username},ou=Users,dc=support,dc=local"

    try:
        conn = get_ldap()
        conn.search("ou=Users,dc=support,dc=local", f"(uid={username})", attributes=["uid"])
        if not conn.entries:
            return jsonify({"success": False, "error": "USER_NOT_FOUND"}), 404

        conn.search("ou=Groups,dc=support,dc=local", f"(cn={group_cn})", attributes=["member"])
        if not conn.entries:
            return jsonify({"success": False, "error": f"GROUP_NOT_FOUND: {group_cn}"}), 404

        members = conn.entries[0].member.values if conn.entries[0].member else []
        if user_dn in members:
            pg_log("ACCESS_PROVISION", username, "info",
                   f"{username} already member of {group_cn}", ticket_id, session_id)
            return jsonify({"success": True, "data": {
                "username": username, "application": application,
                "provisioned": True, "group": group_cn, "already_member": True,
                "message": f"{username} already has access to {application} via group {group_cn}."
            }})

        conn.modify(group_dn, {"member": [(ldap3.MODIFY_ADD, [user_dn])]})
        if conn.result["result"] == 0:
            try:
                pg_conn = get_pg(); cur = pg_conn.cursor()
                cur.execute(
                    "UPDATE access_requests SET status=%s, notes=%s, updated_at=NOW() WHERE ticket_id=%s AND username=%s",
                    ("provisioned", f"Auto-provisioned to LDAP group {group_cn}", ticket_id, username)
                )
                pg_conn.commit(); pg_conn.close()
            except Exception:
                pass
            pg_log("ACCESS_PROVISION", username, "success",
                   f"Access provisioned: {username} added to {group_cn} for {application}", ticket_id, session_id)
            return jsonify({"success": True, "data": {
                "username": username, "application": application,
                "provisioned": True, "group": group_cn, "already_member": False,
                "message": f"Access granted! {username} has been added to {group_cn} and now has access to {application}."
            }})
        else:
            return jsonify({"success": False, "error": conn.result["description"]}), 500
    except Exception as ex:
        pg_log("ACCESS_PROVISION", username, "failure", str(ex), ticket_id, session_id)
        return jsonify({"success": False, "error": str(ex)}), 500


@app.route("/check-access", methods=["POST"])
def check_access():
    data        = request.json or {}
    username    = data.get("username",    "").strip().lower()
    application = data.get("application", "").strip()
    if not username or not application:
        return jsonify({"success": False, "error": "username and application required"}), 400
    group_cn = get_group_for_app(application)
    if not group_cn:
        return jsonify({"success": True, "data": {"has_access": None, "message": f"No group configured for {application}"}})
    try:
        conn    = get_ldap()
        user_dn = f"uid={username},ou=Users,dc=support,dc=local"
        conn.search("ou=Groups,dc=support,dc=local", f"(cn={group_cn})", attributes=["member"])
        if not conn.entries:
            return jsonify({"success": False, "error": "GROUP_NOT_FOUND"}), 404
        members    = conn.entries[0].member.values if conn.entries[0].member else []
        has_access = user_dn in members
        return jsonify({"success": True, "data": {
            "username": username, "application": application, "group": group_cn,
            "has_access": has_access,
            "message": f"{username} {'has' if has_access else 'does not have'} access to {application} (group: {group_cn})"
        }})
    except Exception as ex:
        return jsonify({"success": False, "error": str(ex)}), 500


@app.route("/resolve-app-error", methods=["POST"])
def resolve_app_error():
    data        = request.json or {}
    username    = data.get("username",    "unknown")
    application = data.get("application", "").strip()
    error_desc  = data.get("error",       "").strip()
    ticket_id   = data.get("ticket_id",   "")
    session_id  = data.get("session_id",  "")

    if not application or not error_desc:
        return jsonify({"success": False, "error": "application and error required"}), 400

    results = []
    steps   = []
    kb_found = False

    try:
        pg_conn = get_pg(); cur = pg_conn.cursor()
        cur.execute(
            "SELECT title, category, solution_text, confidence_boost FROM knowledge_base "
            "WHERE is_active=true AND (title ILIKE %s OR solution_text ILIKE %s OR %s = ANY(keywords)) "
            "ORDER BY confidence_boost DESC LIMIT 3",
            (f"%{application}%", f"%{error_desc}%", application.lower())
        )
        kb_rows = cur.fetchall(); pg_conn.close()
        if kb_rows:
            kb_found = True
            for row in kb_rows:
                steps.append({"source": "KB", "title": row[0], "steps": row[2]})
            results.append({"check": "Knowledge Base", "status": "found", "detail": f"{len(kb_rows)} article(s) found"})
        else:
            results.append({"check": "Knowledge Base", "status": "not_found", "detail": "No KB article found"})
    except Exception as ex:
        results.append({"check": "Knowledge Base", "status": "error", "detail": str(ex)})

    group_cn   = get_group_for_app(application)
    has_access = None
    if group_cn and username != "unknown":
        try:
            conn    = get_ldap()
            user_dn = f"uid={username},ou=Users,dc=support,dc=local"
            conn.search("ou=Groups,dc=support,dc=local", f"(cn={group_cn})", attributes=["member"])
            if conn.entries:
                members    = conn.entries[0].member.values if conn.entries[0].member else []
                has_access = user_dn in members
                status     = "pass" if has_access else "fail"
                detail     = f"{username} {'has' if has_access else 'MISSING'} access to {group_cn}"
                results.append({"check": "Access Verification", "status": status, "detail": detail})
                if not has_access:
                    steps.insert(0, {"source": "ACCESS_CHECK", "title": "Access Issue",
                                     "steps": f"{username} does not have access to {application}. Request access via helpdesk."})
        except Exception as ex:
            results.append({"check": "Access Verification", "status": "skip", "detail": str(ex)})

    if has_access is False:
        resolution_status = "access_issue_detected"
    elif kb_found:
        resolution_status = "kb_steps_provided"
    else:
        resolution_status = "escalation_required"

    summary = {
        "kb_steps_provided":    f"KB article found. Troubleshooting steps provided for {application}.",
        "access_issue_detected": f"{username} lacks permissions for {application}. Access provisioning recommended.",
        "escalation_required":   f"No solution found for {application} error. Escalating to L2 support.",
    }.get(resolution_status, "Unknown")

    pg_log("RESOLVE_APP_ERROR", username, resolution_status,
           f"App error: {application} — {error_desc[:80]}", ticket_id, session_id)

    return jsonify({"success": True, "data": {
        "application": application, "error_description": error_desc,
        "resolution_status": resolution_status, "summary": summary,
        "has_access": has_access, "kb_found": kb_found,
        "diagnostic_checks": results, "resolution_steps": steps,
        "escalate": resolution_status == "escalation_required",
        "checked_at": datetime.datetime.utcnow().isoformat() + "Z",
    }})

# ── OTP Store (Postgres) ──────────────────────────────────────────────────────
def send_email(to_addr, subject, body_html, body_text):
    try:
        msg = MIMEMultipart("alternative")
        msg["Subject"] = subject
        msg["From"]    = SMTP_FROM
        msg["To"]      = to_addr
        msg.attach(MIMEText(body_text, "plain"))
        msg.attach(MIMEText(body_html, "html"))
        with smtplib.SMTP(SMTP_HOST, SMTP_PORT, timeout=5) as server:
            server.sendmail(SMTP_FROM, to_addr, msg.as_string())
        return True
    except Exception as ex:
        print(f"Email error: {ex}")
        return False

@app.route("/send-otp", methods=["POST"])
def send_otp():
    """
    Generate and send OTP to user email
    ---
    tags: [OTP]
    parameters:
      - in: body
        name: body
        schema:
          properties:
            username: {type: string, example: jdoe}
            purpose: {type: string, example: password_reset}
    responses:
      200:
        description: OTP sent
    """
    data      = request.json or {}
    username  = data.get("username", "").strip().lower().split("@")[0]
    purpose   = data.get("purpose", "password_reset")   # password_reset | account_unlock
    if not username:
        return jsonify({"success": False, "error": "username required"})
    try:
        # Lookup user in LDAP to get real email
        conn = get_ldap()
        conn.search(LDAP_BASE, f"(uid={username})",
                    attributes=["uid", "displayName", "mail"])
        if not conn.entries:
            return jsonify({"success": False, "error": "USER_NOT_FOUND",
                            "message": "Username not found. Please verify and try again."})
        e            = conn.entries[0]
        display_name = str(e.displayName) if e.displayName else username
        email        = str(e.mail) if e.mail else None
        if not email:
            return jsonify({"success": False, "error": "NO_EMAIL_ON_FILE",
                            "message": f"No email address found for {username}. Contact IT directly."})

        # Generate 6-digit OTP
        otp      = str(random.randint(100000, 999999))
        expires  = datetime.datetime.utcnow() + datetime.timedelta(minutes=5)

        # Store in Postgres
        pg_conn = get_pg(); cur = pg_conn.cursor()
        # Invalidate previous OTPs for this user+purpose
        cur.execute("UPDATE otp_store SET used=true WHERE username=%s AND purpose=%s AND used=false",
                    (username, purpose))
        cur.execute(
            "INSERT INTO otp_store (username, otp_code, purpose, expires_at, email_sent_to) "
            "VALUES (%s, %s, %s, %s, %s)",
            (username, otp, purpose, expires, email)
        )
        pg_conn.commit(); pg_conn.close()

        # Send email via Mailhog
        purpose_label = "réinitialisation de mot de passe" if purpose == "password_reset" else "déverrouillage de compte"
        subject = f"[HelpBot] Code de vérification — {purpose_label.title()}"
        body_html = f"""
        <div style="font-family:Arial,sans-serif;max-width:500px;margin:0 auto;padding:20px;border:1px solid #e0e0e0;border-radius:8px;">
            <div style="background:#6d28d9;padding:16px;border-radius:6px 6px 0 0;text-align:center;">
                <h2 style="color:white;margin:0;">🔐 HelpBot — Code de vérification</h2>
            </div>
            <div style="padding:24px;">
                <p>Bonjour <strong>{display_name}</strong>,</p>
                <p>Votre code de vérification pour <strong>{purpose_label}</strong> :</p>
                <div style="background:#f3f0ff;border:2px solid #6d28d9;border-radius:8px;padding:20px;text-align:center;margin:20px 0;">
                    <span style="font-size:36px;font-weight:bold;letter-spacing:8px;color:#6d28d9;">{otp}</span>
                </div>
                <p style="color:#dc2626;font-weight:bold;">⏱ Ce code expire dans <strong>5 minutes</strong>.</p>
                <p style="color:#6b7280;font-size:12px;">Si vous n'avez pas demandé ce code, ignorez cet email et contactez l'IT immédiatement.</p>
            </div>
            <div style="background:#f9fafb;padding:12px;border-radius:0 0 6px 6px;text-align:center;">
                <p style="color:#9ca3af;font-size:11px;margin:0;">HelpBot IT Support Intelligence — support.local</p>
            </div>
        </div>"""
        body_text = f"Code de vérification HelpBot: {otp}\nExpire dans 5 minutes.\nPurpose: {purpose_label}"

        sent = send_email(email, subject, body_html, body_text)
        pg_log("SEND_OTP", username, "success" if sent else "email_failed",
               f"OTP sent for {purpose} to {email[:3]}***@{email.split('@')[-1] if '@' in email else '?'}")

        # Mask email for response
        parts      = email.split("@")
        masked     = parts[0][:2] + "***@" + parts[1] if len(parts) == 2 else "***"
        return jsonify({"success": True, "data": {
            "username":   username,
            "email_sent": masked,
            "purpose":    purpose,
            "message":    f"Un code de vérification a été envoyé à {masked}. Valable 5 minutes.",
            "email_ok":   sent,
        }})
    except Exception as ex:
        return jsonify({"success": False, "error": str(ex)}), 500


@app.route("/verify-otp", methods=["POST"])
def verify_otp():
    """
    Verify OTP and execute the requested action
    ---
    tags: [OTP]
    parameters:
      - in: body
        name: body
        schema:
          properties:
            username: {type: string, example: jdoe}
            otp: {type: string, example: "123456"}
            purpose: {type: string, example: password_reset}
    responses:
      200:
        description: OTP verified, action executed
    """
    data      = request.json or {}
    username  = data.get("username",  "").strip().lower().lstrip("=").split("@")[0]
    otp_input = data.get("otp",       "").strip().lstrip("=")
    purpose   = data.get("purpose",   "password_reset").strip().lstrip("=")
    ticket_id = data.get("ticket_id", "")
    session_id= data.get("session_id","")

    if not username or not otp_input:
        return jsonify({"success": False, "error": "username and otp required"})
    try:
        pg_conn = get_pg(); cur = pg_conn.cursor()
        cur.execute(
            "SELECT id, otp_code, expires_at, used FROM otp_store "
            "WHERE username=%s AND purpose=%s AND used=false "
            "ORDER BY created_at DESC LIMIT 1",
            (username, purpose)
        )
        row = cur.fetchone()
        if not row:
            return jsonify({"success": False, "error": "OTP_NOT_FOUND",
                            "message": "Aucun code actif trouvé. Demandez un nouveau code."})

        otp_id, otp_code, expires_at, used = row

        # Check expiry
        if datetime.datetime.utcnow() > expires_at.replace(tzinfo=None):
            cur.execute("UPDATE otp_store SET used=true WHERE id=%s", (otp_id,))
            pg_conn.commit(); pg_conn.close()
            pg_log("VERIFY_OTP", username, "expired", f"OTP expired for {purpose}")
            return jsonify({"success": False, "error": "OTP_EXPIRED",
                            "message": "Code expiré. Demandez un nouveau code."})

        # Check code
        if otp_input != otp_code:
            pg_log("VERIFY_OTP", username, "invalid", f"Wrong OTP attempt for {purpose}")
            pg_conn.close()
            return jsonify({"success": False, "error": "OTP_INVALID",
                            "message": "Code incorrect. Vérifiez votre email et réessayez."})

        # Mark used
        cur.execute("UPDATE otp_store SET used=true WHERE id=%s", (otp_id,))
        pg_conn.commit()

        # Now perform the action
        ldap_conn = get_ldap()
        ldap_conn.search(LDAP_BASE, f"(uid={username})", attributes=["displayName", "mail", "description"])
        if not ldap_conn.entries:
            pg_conn.close()
            return jsonify({"success": False, "error": "USER_NOT_FOUND",
                            "message": "User not found in LDAP."})

        e           = ldap_conn.entries[0]
        user_dn     = str(e.entry_dn)
        email       = str(e.mail) if e.mail else None
        display_name= str(e.displayName) if e.displayName else username
        desc        = str(e.description) if e.description else ""

        result_data = {"username": username, "purpose": purpose, "otp_verified": True}

        if purpose == "password_reset":
            import string as _string
            chars = _string.ascii_letters + _string.digits + "!@#$%"
            tmp   = "Hd" + "".join(random.choices(chars, k=10)) + "!"
            ldap_conn.modify(user_dn, {"userPassword": [(ldap3.MODIFY_REPLACE, [tmp])]})
            # Also unlock if locked
            if "LOCKED" in desc.upper():
                ldap_conn.modify(user_dn, {"description": [(ldap3.MODIFY_DELETE, ["LOCKED"])]})

            # Send temp password via email
            if email:
                subj = "[HelpBot] Votre nouveau mot de passe temporaire"
                html = f"""
                <div style="font-family:Arial,sans-serif;max-width:500px;margin:0 auto;padding:20px;border:1px solid #e0e0e0;border-radius:8px;">
                    <div style="background:#059669;padding:16px;border-radius:6px 6px 0 0;text-align:center;">
                        <h2 style="color:white;margin:0;">✅ Mot de passe réinitialisé</h2>
                    </div>
                    <div style="padding:24px;">
                        <p>Bonjour <strong>{display_name}</strong>,</p>
                        <p>Votre mot de passe a été réinitialisé avec succès. Votre mot de passe temporaire :</p>
                        <div style="background:#f0fdf4;border:2px solid #059669;border-radius:8px;padding:20px;text-align:center;margin:20px 0;">
                            <code style="font-size:20px;font-weight:bold;color:#065f46;">{tmp}</code>
                        </div>
                        <p style="color:#dc2626;font-weight:bold;">⚠️ Changez ce mot de passe dès votre première connexion.</p>
                        <p style="color:#6b7280;font-size:12px;">Ce mot de passe est valable pour une connexion uniquement.</p>
                    </div>
                </div>"""
                txt = f"Votre mot de passe temporaire: {tmp}\nChangez-le à la première connexion."
                send_email(email, subj, html, txt)

            pg_log("RESET_PASSWORD", username, "success",
                   f"OTP-verified password reset for {username}", ticket_id, session_id)
            result_data.update({"action": "password_reset", "email_sent": bool(email),
                                 "message": f"Mot de passe réinitialisé. Votre nouveau mot de passe temporaire a été envoyé à votre email enregistré."})

        elif purpose == "account_unlock":
            ldap_conn.modify(user_dn, {"description": [(ldap3.MODIFY_DELETE, ["LOCKED"])]})
            pg_log("UNLOCK_ACCOUNT", username, "success",
                   f"OTP-verified account unlock for {username}", ticket_id, session_id)
            result_data.update({"action": "account_unlock",
                                 "message": f"Compte {username} déverrouillé avec succès."})

        pg_conn.close()
        return jsonify({"success": True, "data": result_data})

    except Exception as ex:
        return jsonify({"success": False, "error": str(ex)}), 500


# ── Lookup by Email ───────────────────────────────────────────────────────────
@app.route("/lookup-by-email", methods=["POST"])
def lookup_by_email():
    """
    Find username by email — first step of guest identity verification
    ---
    tags: [OTP]
    parameters:
      - in: body
        name: body
        schema:
          properties:
            email: {type: string, example: jdoe@support.local}
    responses:
      200:
        description: User found or not found (always 200)
    """
    data  = request.get_json() or {}
    email = data.get("email", "").strip().lower()
    if not email:
        return jsonify({"success": False, "error": "MISSING_FIELDS",
                        "message": "email is required"})
    try:
        conn = get_ldap()
        conn.search(LDAP_BASE, f"(mail={email})",
                    attributes=["uid", "displayName", "mail"])
        if not conn.entries:
            return jsonify({"success": False, "error": "USER_NOT_FOUND",
                            "message": "No account found with this email address. Please check and try again."})
        entry  = conn.entries[0]
        uid    = str(entry.uid).strip() if entry.uid else ""
        parts  = email.split("@")
        masked = parts[0][:2] + "***@" + parts[1] if len(parts) == 2 else "***"
        return jsonify({"success": True, "data": {
            "username":     uid,
            "masked_email": masked,
            "message":      "Account found. Please answer the security questions to verify your identity."
        }})
    except Exception as ex:
        return jsonify({"success": False, "error": str(ex)})


# ── Verify Identity (pre-OTP check) ──────────────────────────────────────────
@app.route("/verify-identity", methods=["POST"])
def verify_identity():
    """
    Verify guest identity — checks full name, department AND job title against LDAP
    ---
    tags: [OTP]
    parameters:
      - in: body
        name: body
        schema:
          properties:
            username: {type: string, example: jdoe}
            full_name: {type: string, example: "John Doe"}
            department: {type: string, example: IT}
            title: {type: string, example: "IT Technician"}
    responses:
      200:
        description: Identity verified or denied (always 200)
    """
    data       = request.get_json() or {}
    username   = data.get("username", "").strip().lower().split("@")[0]
    full_name  = data.get("full_name", "").strip().lower()
    department = data.get("department", "").strip().lower()
    title      = data.get("title", "").strip().lower()

    if not username or not full_name or not department:
        return jsonify({"success": False, "error": "MISSING_FIELDS",
                        "message": "username, full_name and department are required"})
    try:
        conn = get_ldap()
        conn.search(LDAP_BASE, f"(uid={username})",
                    attributes=["displayName", "departmentNumber", "title", "mail"])
        if not conn.entries:
            return jsonify({"success": False, "error": "USER_NOT_FOUND",
                            "message": "Username not found in the system."})

        entry      = conn.entries[0]
        ldap_name  = str(entry.displayName).strip().lower() if entry.displayName else ""
        ldap_dept  = str(entry.departmentNumber).strip().lower() if entry.departmentNumber else ""
        ldap_title = str(entry.title).strip().lower() if entry.title else ""
        ldap_mail  = str(entry.mail).strip() if entry.mail else ""

        name_ok  = full_name == ldap_name
        dept_ok  = department == ldap_dept
        title_ok = (not title) or (title == ldap_title)

        if name_ok and dept_ok and title_ok:
            parts  = ldap_mail.split("@")
            masked = parts[0][:2] + "***@" + parts[1] if len(parts) == 2 else ""
            return jsonify({"success": True, "verified": True,
                            "username": username,
                            "masked_email": masked,
                            "message": "Identity verified successfully. Sending OTP now."})
        else:
            failed = []
            if not name_ok:  failed.append("full name")
            if not dept_ok:  failed.append("department")
            if not title_ok: failed.append("job title")
            return jsonify({"success": False, "verified": False,
                            "error": "IDENTITY_MISMATCH",
                            "message": f"The information provided does not match our records ({', '.join(failed)} incorrect). Access denied. Please contact IT directly."})

    except Exception as ex:
        return jsonify({"success": False, "error": str(ex)})


# ── Escalation N1→N2 ──────────────────────────────────────────────────────────
@app.route("/escalate", methods=["POST"])
def escalate():
    """
    Escalate a ticket from N1 to N2 with full context
    ---
    tags: [Escalation]
    parameters:
      - in: body
        name: body
        schema:
          properties:
            ticket_id: {type: string, example: PROJ-42}
            username: {type: string}
            display_name: {type: string}
            department: {type: string}
            issue_type: {type: string}
            priority: {type: string, example: high}
            summary: {type: string}
            steps_tried: {type: string}
            error_details: {type: string}
            session_id: {type: string}
    responses:
      200:
        description: Escalation created
    """
    d            = request.json or {}
    ticket_id    = d.get("ticket_id", "")
    username     = d.get("username", "unknown")
    display_name = d.get("display_name", username)
    department   = d.get("department", "")
    issue_type   = d.get("issue_type", "General")
    priority     = d.get("priority", "medium")
    summary      = d.get("summary", "")
    steps_tried  = d.get("steps_tried", "")
    error_details= d.get("error_details", "")
    session_id   = d.get("session_id", "")
    try:
        conn = get_pg(); cur = conn.cursor()
        cur.execute("""
            INSERT INTO escalations
              (ticket_id, username, display_name, department, issue_type,
               priority, summary, steps_tried, error_details, session_id, status)
            VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,'open') RETURNING id
        """, (ticket_id, username, display_name, department, issue_type,
              priority, summary, steps_tried, error_details, session_id))
        esc_id = cur.fetchone()[0]
        conn.commit(); conn.close()
        pg_log("ESCALATION", username, "escalated",
               f"Ticket {ticket_id} escalated to N2 — {issue_type}", ticket_id, session_id)
        # Send email to N2
        send_email(
            "it-support-n2@support.local",
            f"[N2 ESCALATION] {ticket_id} — {issue_type} — {priority.upper()}",
            f"""<div style="font-family:Arial,sans-serif;max-width:600px;padding:20px;">
                <h2 style="color:#dc2626;">🚨 N2 Escalation Required</h2>
                <table style="width:100%;border-collapse:collapse;">
                  <tr><td style="padding:8px;font-weight:bold;">Ticket</td><td>{ticket_id}</td></tr>
                  <tr><td style="padding:8px;font-weight:bold;">User</td><td>{display_name} ({username})</td></tr>
                  <tr><td style="padding:8px;font-weight:bold;">Department</td><td>{department}</td></tr>
                  <tr><td style="padding:8px;font-weight:bold;">Issue Type</td><td>{issue_type}</td></tr>
                  <tr><td style="padding:8px;font-weight:bold;">Priority</td><td style="color:#dc2626;">{priority.upper()}</td></tr>
                  <tr><td style="padding:8px;font-weight:bold;">Summary</td><td>{summary}</td></tr>
                  <tr><td style="padding:8px;font-weight:bold;">Steps Tried</td><td>{steps_tried}</td></tr>
                  <tr><td style="padding:8px;font-weight:bold;">Error Details</td><td>{error_details}</td></tr>
                </table>
                <p style="margin-top:20px;color:#6b7280;">View in dashboard: http://localhost:3000/dashboard</p>
            </div>""",
            f"N2 Escalation: {ticket_id} — {issue_type}\nUser: {username}\nPriority: {priority}\nSummary: {summary}\nSteps tried: {steps_tried}"
        )
        return jsonify({"success": True, "escalation_id": esc_id,
                        "message": f"Ticket {ticket_id} escalated to N2. The team has been notified."})
    except Exception as ex:
        return jsonify({"success": False, "error": str(ex)})


@app.route("/escalations", methods=["GET"])
def list_escalations():
    """Get all escalations for N2 dashboard ---
    tags: [Escalation]
    responses:
      200:
        description: List of escalations
    """
    try:
        conn = get_pg(); cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
        cur.execute("SELECT * FROM escalations ORDER BY created_at DESC")
        rows = cur.fetchall(); conn.close()
        return jsonify({"success": True, "data": {"escalations": [dict(r) for r in rows]}})
    except Exception as ex:
        return jsonify({"success": False, "error": str(ex)})


@app.route("/escalation/<int:esc_id>", methods=["PATCH"])
def update_escalation(esc_id):
    """Update escalation status ---
    tags: [Escalation]
    responses:
      200:
        description: Updated
    """
    d      = request.json or {}
    status = d.get("status", "in_progress")
    notes  = d.get("notes", "")
    try:
        conn = get_pg(); cur = conn.cursor()
        cur.execute("UPDATE escalations SET status=%s, n2_notes=%s, updated_at=NOW() WHERE id=%s",
                    (status, notes, esc_id))
        conn.commit(); conn.close()
        return jsonify({"success": True})
    except Exception as ex:
        return jsonify({"success": False, "error": str(ex)})


# ── Chat History ───────────────────────────────────────────────────────────────
@app.route("/chat-history", methods=["POST"])
def save_chat_history():
    """Save conversation summary ---
    tags: [Chat]
    responses:
      200:
        description: Saved
    """
    d          = request.json or {}
    username   = d.get("username", "")
    session_id = d.get("session_id", "")
    summary    = d.get("summary", "")
    ticket_id  = d.get("ticket_id", "")
    issue_type = d.get("issue_type", "")
    if not username or not session_id:
        return jsonify({"success": False, "error": "username and session_id required"})
    try:
        conn = get_pg(); cur = conn.cursor()
        cur.execute("""
            INSERT INTO chat_history (username, session_id, summary, ticket_id, issue_type)
            VALUES (%s,%s,%s,%s,%s)
            ON CONFLICT (session_id) DO UPDATE
            SET summary=%s, ticket_id=%s, issue_type=%s, updated_at=NOW()
        """, (username, session_id, summary, ticket_id, issue_type,
              summary, ticket_id, issue_type))
        conn.commit(); conn.close()
        return jsonify({"success": True})
    except Exception as ex:
        return jsonify({"success": False, "error": str(ex)})


@app.route("/chat-history/<username>", methods=["GET"])
def get_chat_history(username):
    """Get chat history for a user ---
    tags: [Chat]
    responses:
      200:
        description: Chat history
    """
    try:
        conn = get_pg(); cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
        cur.execute("""
            SELECT session_id, summary, ticket_id, issue_type, created_at, updated_at
            FROM chat_history WHERE username=%s
            ORDER BY updated_at DESC LIMIT 20
        """, (username,))
        rows = cur.fetchall(); conn.close()
        return jsonify({"success": True, "data": {"history": [dict(r) for r in rows]}})
    except Exception as ex:
        return jsonify({"success": False, "error": str(ex)})



# ── Conversations ─────────────────────────────────────────────────────────────
@app.route("/conversations/<username>", methods=["GET"])
def get_conversations(username):
    import re, json as _json
    if not username or username.startswith("guest"):
        return jsonify({"success": True, "data": {"conversations": []}})
    try:
        conn = get_pg()
        cur  = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
        cur.execute("""
            SELECT session_id, MIN(created_at) as started_at,
                   MAX(created_at) as last_message_at, COUNT(*) as message_count,
                   (SELECT message->>'content' FROM n8n_chat_memory m2
                    WHERE m2.session_id = m.session_id AND message->>'type' = 'ai'
                    ORDER BY created_at ASC LIMIT 1) as first_ai_message
            FROM n8n_chat_memory m
            WHERE session_id ILIKE %s AND session_id NOT ILIKE 'guest%%'
            GROUP BY session_id ORDER BY last_message_at DESC LIMIT 10
        """, (f"%{username}%",))
        rows = cur.fetchall(); conn.close()
        convos = []
        for r in rows:
            preview = re.sub(r"[*#`]", "", r["first_ai_message"] or "")[:80]
            convos.append({"session_id": r["session_id"], "started_at": str(r["started_at"]),
                           "last_message_at": str(r["last_message_at"]),
                           "message_count": r["message_count"], "preview": preview})
        return jsonify({"success": True, "data": {"conversations": convos}})
    except Exception as ex:
        return jsonify({"success": False, "error": str(ex)})


@app.route("/conversation/<path:session_id>", methods=["GET"])
def get_conversation(session_id):
    import re, json as _json
    try:
        conn = get_pg()
        cur  = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
        cur.execute("SELECT message, created_at FROM n8n_chat_memory WHERE session_id=%s ORDER BY created_at ASC",
                    (session_id,))
        rows = cur.fetchall(); conn.close()
        messages = []
        for r in rows:
            msg = r["message"]
            if isinstance(msg, str):
                try: msg = _json.loads(msg)
                except: continue
            mtype   = msg.get("type", "")
            content = msg.get("content", "")
            if mtype == "ai":
                messages.append({"role": "ai", "content": content, "ts": str(r["created_at"])})
            elif mtype == "human":
                content = content.split("=== USER MESSAGE ===")[-1].strip() if "=== USER MESSAGE ===" in content else content
                if content:
                    messages.append({"role": "human", "content": content, "ts": str(r["created_at"])})
        return jsonify({"success": True, "data": {"messages": messages}})
    except Exception as ex:
        return jsonify({"success": False, "error": str(ex)})

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=False)
