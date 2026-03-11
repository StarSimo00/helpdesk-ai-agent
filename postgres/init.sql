-- =============================================================================
-- HelpBot Helpdesk — Complete Database Initialization
-- =============================================================================

-- ─── n8n chat memory ─────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS n8n_chat_memory (
  id          SERIAL PRIMARY KEY,
  session_id  TEXT NOT NULL,
  message     JSONB NOT NULL,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_chat_memory_session ON n8n_chat_memory(session_id);

-- ─── tickets ─────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS tickets (
  id              SERIAL PRIMARY KEY,
  jira_issue_key  TEXT,
  ticket_type     TEXT NOT NULL DEFAULT 'N1',
  category        TEXT NOT NULL DEFAULT 'general',
  priority        TEXT NOT NULL DEFAULT 'Medium',
  summary         TEXT NOT NULL,
  description     TEXT,
  status          TEXT NOT NULL DEFAULT 'open',
  username        TEXT DEFAULT '',
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  updated_at      TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_tickets_category ON tickets(category);
CREATE INDEX IF NOT EXISTS idx_tickets_status ON tickets(status);

-- ─── automation logs ─────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS automation_logs (
  id           SERIAL PRIMARY KEY,
  action_type  TEXT NOT NULL,
  target_user  TEXT,
  status       TEXT NOT NULL DEFAULT 'success',
  details      TEXT,
  ticket_id    TEXT DEFAULT '',
  session_id   TEXT DEFAULT '',
  created_at   TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_logs_action_type ON automation_logs(action_type);
CREATE INDEX IF NOT EXISTS idx_logs_created_at ON automation_logs(created_at);
CREATE INDEX IF NOT EXISTS idx_logs_ticket_id ON automation_logs(ticket_id);

-- ─── knowledge base ──────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS knowledge_base (
  id               SERIAL PRIMARY KEY,
  title            TEXT NOT NULL,
  category         TEXT NOT NULL,
  keywords         TEXT[] NOT NULL DEFAULT '{}',
  solution_text    TEXT NOT NULL,
  steps            JSONB,
  confidence_boost INT DEFAULT 0,
  views            INT DEFAULT 0,
  is_active        BOOLEAN DEFAULT TRUE,
  created_at       TIMESTAMPTZ DEFAULT NOW()
);

-- ─── access requests ─────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS access_requests (
  id              SERIAL PRIMARY KEY,
  username        TEXT NOT NULL,
  application     TEXT NOT NULL,
  business_reason TEXT DEFAULT '',
  access_level    TEXT DEFAULT 'Read',
  status          TEXT NOT NULL DEFAULT 'pending',
  ticket_id       TEXT DEFAULT '',
  session_id      TEXT DEFAULT '',
  notes           TEXT DEFAULT '',
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  updated_at      TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_access_requests_username ON access_requests(username);
CREATE INDEX IF NOT EXISTS idx_access_requests_status ON access_requests(status);

-- ─── OTP store ───────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS otp_store (
  id            SERIAL PRIMARY KEY,
  username      TEXT NOT NULL,
  otp_code      TEXT NOT NULL,
  purpose       TEXT NOT NULL DEFAULT 'password_reset',
  expires_at    TIMESTAMPTZ NOT NULL,
  email_sent_to TEXT DEFAULT '',
  used          BOOLEAN DEFAULT FALSE,
  created_at    TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_otp_username ON otp_store(username, purpose, used);

-- =============================================================================
-- KNOWLEDGE BASE SEEDS
-- =============================================================================
INSERT INTO knowledge_base (title, category, keywords, solution_text, confidence_boost, is_active) VALUES

('Outlook Not Syncing Emails', 'email',
 ARRAY['outlook','sync','email','mail','not receiving','exchange'],
 '1. Close Outlook completely.
2. Open Control Panel > Mail > Email Accounts.
3. Remove and re-add the email account.
4. If still failing: delete the OST file at %localappdata%\Microsoft\Outlook\.
5. Restart Outlook and let it rebuild the mailbox.
6. If issue persists: check Exchange server status with IT.', 10, true),

('Teams Black or Blank Screen', 'software',
 ARRAY['teams','black','blank','screen','microsoft','crash','freeze'],
 '1. Fully quit Microsoft Teams (check system tray).
2. Navigate to %appdata%\Microsoft\Teams.
3. Delete everything EXCEPT the logs folder.
4. Relaunch Teams.
5. If still blank: uninstall and reinstall Teams from Microsoft Store.', 10, true),

('VPN Connection Failed', 'network',
 ARRAY['vpn','connection','failed','network','remote','cisco','globalprotect','fortinet'],
 '1. Check your internet connection first.
2. Disconnect and fully close the VPN client.
3. Flush DNS: run ipconfig /flushdns in CMD as admin.
4. Reopen VPN client and reconnect.
5. Try from a different network (hotspot) to rule out firewall.
6. If still failing: escalate to N2 - may be a server-side issue.', 10, true),

('MFA Not Working', 'security',
 ARRAY['mfa','authenticator','code','two factor','2fa','otp','authentication'],
 '1. Ensure your phone clock is set to automatic time.
2. Open the authenticator app and wait for a fresh code.
3. Use backup codes if available.
4. If phone lost: contact IT to reset MFA for your account.', 9, true),

('Printer Offline or Not Printing', 'hardware',
 ARRAY['printer','offline','print','printing','stuck','queue','spooler'],
 '1. Check printer is powered on and connected to network.
2. Go to Settings > Printers, right-click > See what is printing.
3. Cancel all pending jobs.
4. Uncheck Use Printer Offline if checked.
5. Restart Print Spooler: services.msc > Print Spooler > Restart.
6. If still offline: re-add the printer.', 8, true),

('Windows Update Stuck or Failed', 'os',
 ARRAY['windows','update','stuck','failed','error','patch','wuauserv'],
 '1. Run Windows Update Troubleshooter from Settings > Troubleshoot.
2. Open CMD as admin and run: net stop wuauserv.
3. Delete contents of C:\Windows\SoftwareDistribution\Download.
4. Run: net start wuauserv.
5. Retry Windows Update.', 7, true),

('Computer Running Slow', 'hardware',
 ARRAY['slow','performance','freeze','lag','cpu','memory','ram','disk'],
 '1. Open Task Manager (Ctrl+Shift+Esc) and check CPU/Memory/Disk usage.
2. End any process using >50% CPU that is not essential.
3. Run Disk Cleanup: search "Disk Cleanup" in Start menu.
4. Disable startup programs: Task Manager > Startup tab.
5. Restart the computer.
6. If still slow: check for malware with Windows Defender.', 8, true),

('WiFi Not Connecting', 'network',
 ARRAY['wifi','wireless','internet','network','not connecting','no internet'],
 '1. Turn WiFi off and on again from the taskbar.
2. Forget the network and reconnect: Settings > Network > WiFi > Manage known networks.
3. Run network troubleshooter: Settings > Troubleshoot > Internet Connections.
4. Flush DNS: ipconfig /flushdns in CMD as admin.
5. Reset network stack: netsh winsock reset (requires restart).', 9, true),

('Account Locked Out', 'account',
 ARRAY['locked','account','cannot login','lockout','blocked','access denied'],
 '1. Contact IT helpdesk to unlock your account.
2. Do not attempt to login again — repeated failures extend the lockout.
3. Once unlocked, reset your password immediately.
4. Enable MFA to prevent future lockouts.', 10, true),

('Password Reset Request', 'account',
 ARRAY['password','reset','forgot','change','expired','cannot login'],
 '1. Use the self-service password reset portal if available.
2. Contact IT helpdesk with your username and employee ID.
3. IT will generate a temporary password sent to your registered email.
4. Change your password immediately on first login.
5. Password must be 12+ characters with uppercase, number, and symbol.', 10, true),

('SAP ERP Login Error', 'erp',
 ARRAY['sap','erp','login','cannot connect','client','logon','transaction'],
 '1. Check your network connection and VPN — SAP requires VPN when working remotely.
2. Verify your SAP username and client number are correct.
3. Clear SAP GUI cache: SAP Logon > Options > Clear cache.
4. Check if SAP system is down: contact IT for system status.
5. Reinstall SAP GUI if the client is corrupted.', 10, true),

('Salesforce CRM Not Loading', 'crm',
 ARRAY['salesforce','crm','loading','slow','not working','login','access'],
 '1. Clear your browser cache and cookies completely.
2. Try a different browser (Chrome, Firefox, Edge).
3. Disable browser extensions.
4. Check Salesforce status at status.salesforce.com.
5. Contact IT if your Salesforce profile or permissions were recently changed.', 9, true),

('SharePoint Cannot Access Files', 'sharepoint',
 ARRAY['sharepoint','files','access','site','permissions','cannot open'],
 '1. Check you are connected to VPN or company network.
2. Clear browser cache: Ctrl+Shift+Delete > clear all.
3. Try opening SharePoint in an InPrivate/Incognito window.
4. Sign out of all Microsoft accounts and sign back in.
5. Contact your site owner if permissions were recently changed.', 9, true),

('GitHub Access Denied', 'devtools',
 ARRAY['github','access denied','repository','not found','permission','ssh','token'],
 '1. Verify you are logged into the correct GitHub account.
2. Check if you have been added to the organization.
3. Generate a new Personal Access Token if authentication is failing.
4. Check SSH key: run ssh -T git@github.com to test.
5. Contact IT to verify your GitHub organization membership.', 9, true),

('HR Portal Login Failed', 'hr',
 ARRAY['hr','portal','login','payroll','data','not loading','human resources'],
 '1. Clear your browser cache and try again.
2. Check you are using your company email address to log in.
3. Try password reset from the HR portal login page.
4. Check if the HR portal requires VPN — connect to VPN and retry.
5. Contact HR department or IT if your account is locked.', 8, true),

('Blue Screen of Death (BSOD)', 'os',
 ARRAY['bsod','blue screen','crash','stop error','kernel','restart'],
 '1. Note the error code shown on the blue screen.
2. Restart the computer and check if it recurs.
3. Run Windows Memory Diagnostic: search mdsched.exe.
4. Check Event Viewer for critical errors: search eventvwr.
5. Run SFC scan: sfc /scannow in CMD as admin.
6. If recurring: escalate to N2 for hardware diagnosis.', 9, true),

('Shared Drive Not Accessible', 'network',
 ARRAY['shared','drive','network','mapped','not accessible','disconnected','nas'],
 '1. Check you are connected to the company network or VPN.
2. Try accessing via UNC path: \\server\share in File Explorer.
3. Re-map the drive: right-click This PC > Map network drive.
4. Check credentials: Control Panel > Credential Manager.
5. Contact IT if the share permissions were recently changed.', 8, true),

('Email Signature Not Displaying', 'email',
 ARRAY['signature','email','outlook','display','missing','template'],
 '1. Open Outlook > File > Options > Mail > Signatures.
2. Check that a signature is selected for New messages and Replies.
3. If missing: create a new signature and save.
4. For HTML signatures: ensure Rich Text or HTML is selected as email format.', 5, true);

-- =============================================================================
-- 500 SYNTHETIC TICKETS (100 per category)
-- =============================================================================

-- Helper: generate timestamps spread over last 30 days
-- Categories: account_locked, password_reset, vpn, access_request, app_error

INSERT INTO tickets (jira_issue_key, category, priority, summary, description, status, username, created_at) VALUES
-- ── ACCOUNT LOCKED (100) ─────────────────────────────────────────────────────
('PROJ-S001','account_locked','Medium','[ACCOUNT LOCKED] jdoe - Account locked after failed attempts','User jdoe locked out after 3 failed login attempts. Requires immediate unlock.','resolved','jdoe', NOW() - INTERVAL '30 days'),
('PROJ-S002','account_locked','High','[ACCOUNT LOCKED] mwilson - Cannot access workstation','mwilson account locked, blocking critical project work.','resolved','mwilson', NOW() - INTERVAL '29 days' + INTERVAL '2 hours'),
('PROJ-S003','account_locked','Medium','[ACCOUNT LOCKED] bjones - Locked after password change attempt','bjones attempted password change, account locked.','resolved','bjones', NOW() - INTERVAL '29 days'),
('PROJ-S004','account_locked','Medium','[ACCOUNT LOCKED] asmith - Account locked','asmith locked out of workstation.','resolved','asmith', NOW() - INTERVAL '28 days'),
('PROJ-S005','account_locked','High','[ACCOUNT LOCKED] ebrown - Urgent unlock needed','ebrown locked out before critical meeting.','resolved','ebrown', NOW() - INTERVAL '28 days' + INTERVAL '3 hours'),
('PROJ-S006','account_locked','Medium','[ACCOUNT LOCKED] sjohnson - Account locked','sjohnson account locked.','resolved','sjohnson', NOW() - INTERVAL '27 days'),
('PROJ-S007','account_locked','Medium','[ACCOUNT LOCKED] jmartin - Locked out','jmartin cannot access system.','resolved','jmartin', NOW() - INTERVAL '27 days' + INTERVAL '1 hour'),
('PROJ-S008','account_locked','Medium','[ACCOUNT LOCKED] cdurand - Account locked','cdurand account locked after VPN session.','resolved','cdurand', NOW() - INTERVAL '26 days'),
('PROJ-S009','account_locked','High','[ACCOUNT LOCKED] dwhite - Admin account locked','dwhite admin account locked — critical.','resolved','dwhite', NOW() - INTERVAL '26 days' + INTERVAL '2 hours'),
('PROJ-S010','account_locked','Medium','[ACCOUNT LOCKED] jdoe - Locked again','jdoe locked out second time this week.','resolved','jdoe', NOW() - INTERVAL '25 days'),
('PROJ-S011','account_locked','Medium','[ACCOUNT LOCKED] mwilson - Account locked','mwilson account locked.','resolved','mwilson', NOW() - INTERVAL '25 days' + INTERVAL '4 hours'),
('PROJ-S012','account_locked','Medium','[ACCOUNT LOCKED] bjones - Locked out','bjones locked out.','resolved','bjones', NOW() - INTERVAL '24 days'),
('PROJ-S013','account_locked','Medium','[ACCOUNT LOCKED] asmith - Cannot login','asmith cannot login.','resolved','asmith', NOW() - INTERVAL '24 days' + INTERVAL '1 hour'),
('PROJ-S014','account_locked','High','[ACCOUNT LOCKED] ebrown - Locked before deadline','ebrown locked out before project deadline.','resolved','ebrown', NOW() - INTERVAL '23 days'),
('PROJ-S015','account_locked','Medium','[ACCOUNT LOCKED] sjohnson - Account locked','sjohnson locked out.','resolved','sjohnson', NOW() - INTERVAL '23 days' + INTERVAL '2 hours'),
('PROJ-S016','account_locked','Medium','[ACCOUNT LOCKED] jmartin - Locked account','jmartin account locked.','resolved','jmartin', NOW() - INTERVAL '22 days'),
('PROJ-S017','account_locked','Medium','[ACCOUNT LOCKED] cdurand - Account locked','cdurand locked out.','resolved','cdurand', NOW() - INTERVAL '22 days' + INTERVAL '3 hours'),
('PROJ-S018','account_locked','Medium','[ACCOUNT LOCKED] dwhite - Account locked','dwhite account locked.','resolved','dwhite', NOW() - INTERVAL '21 days'),
('PROJ-S019','account_locked','High','[ACCOUNT LOCKED] jdoe - Critical lock','jdoe locked during system maintenance.','resolved','jdoe', NOW() - INTERVAL '21 days' + INTERVAL '1 hour'),
('PROJ-S020','account_locked','Medium','[ACCOUNT LOCKED] mwilson - Account locked','mwilson locked out.','resolved','mwilson', NOW() - INTERVAL '20 days'),
('PROJ-S021','account_locked','Medium','[ACCOUNT LOCKED] bjones - Locked','bjones account locked.','open','bjones', NOW() - INTERVAL '20 days' + INTERVAL '2 hours'),
('PROJ-S022','account_locked','Medium','[ACCOUNT LOCKED] asmith - Account locked','asmith locked out.','resolved','asmith', NOW() - INTERVAL '19 days'),
('PROJ-S023','account_locked','Medium','[ACCOUNT LOCKED] ebrown - Locked out','ebrown locked.','resolved','ebrown', NOW() - INTERVAL '19 days' + INTERVAL '4 hours'),
('PROJ-S024','account_locked','High','[ACCOUNT LOCKED] sjohnson - Urgent unlock','sjohnson locked before payroll run.','resolved','sjohnson', NOW() - INTERVAL '18 days'),
('PROJ-S025','account_locked','Medium','[ACCOUNT LOCKED] jmartin - Account locked','jmartin locked out.','resolved','jmartin', NOW() - INTERVAL '18 days' + INTERVAL '1 hour'),
('PROJ-S026','account_locked','Medium','[ACCOUNT LOCKED] cdurand - Locked','cdurand account locked.','resolved','cdurand', NOW() - INTERVAL '17 days'),
('PROJ-S027','account_locked','Medium','[ACCOUNT LOCKED] dwhite - Account locked','dwhite locked.','resolved','dwhite', NOW() - INTERVAL '17 days' + INTERVAL '2 hours'),
('PROJ-S028','account_locked','Medium','[ACCOUNT LOCKED] jdoe - Locked out','jdoe locked.','resolved','jdoe', NOW() - INTERVAL '16 days'),
('PROJ-S029','account_locked','High','[ACCOUNT LOCKED] mwilson - Account locked','mwilson locked.','resolved','mwilson', NOW() - INTERVAL '16 days' + INTERVAL '3 hours'),
('PROJ-S030','account_locked','Medium','[ACCOUNT LOCKED] bjones - Locked','bjones locked.','resolved','bjones', NOW() - INTERVAL '15 days'),
('PROJ-S031','account_locked','Medium','[ACCOUNT LOCKED] asmith - Account locked','asmith locked.','resolved','asmith', NOW() - INTERVAL '15 days' + INTERVAL '1 hour'),
('PROJ-S032','account_locked','Medium','[ACCOUNT LOCKED] ebrown - Locked out','ebrown locked.','resolved','ebrown', NOW() - INTERVAL '14 days'),
('PROJ-S033','account_locked','Medium','[ACCOUNT LOCKED] sjohnson - Account locked','sjohnson locked.','resolved','sjohnson', NOW() - INTERVAL '14 days' + INTERVAL '2 hours'),
('PROJ-S034','account_locked','High','[ACCOUNT LOCKED] jmartin - Locked','jmartin locked out urgently.','resolved','jmartin', NOW() - INTERVAL '13 days'),
('PROJ-S035','account_locked','Medium','[ACCOUNT LOCKED] cdurand - Account locked','cdurand locked.','resolved','cdurand', NOW() - INTERVAL '13 days' + INTERVAL '4 hours'),
('PROJ-S036','account_locked','Medium','[ACCOUNT LOCKED] dwhite - Locked','dwhite locked out.','resolved','dwhite', NOW() - INTERVAL '12 days'),
('PROJ-S037','account_locked','Medium','[ACCOUNT LOCKED] jdoe - Account locked','jdoe locked.','resolved','jdoe', NOW() - INTERVAL '12 days' + INTERVAL '1 hour'),
('PROJ-S038','account_locked','Medium','[ACCOUNT LOCKED] mwilson - Locked','mwilson locked.','resolved','mwilson', NOW() - INTERVAL '11 days'),
('PROJ-S039','account_locked','High','[ACCOUNT LOCKED] bjones - Urgent unlock','bjones locked before meeting.','resolved','bjones', NOW() - INTERVAL '11 days' + INTERVAL '2 hours'),
('PROJ-S040','account_locked','Medium','[ACCOUNT LOCKED] asmith - Account locked','asmith locked.','resolved','asmith', NOW() - INTERVAL '10 days'),
('PROJ-S041','account_locked','Medium','[ACCOUNT LOCKED] ebrown - Locked','ebrown locked.','resolved','ebrown', NOW() - INTERVAL '10 days' + INTERVAL '3 hours'),
('PROJ-S042','account_locked','Medium','[ACCOUNT LOCKED] sjohnson - Account locked','sjohnson locked.','resolved','sjohnson', NOW() - INTERVAL '9 days'),
('PROJ-S043','account_locked','Medium','[ACCOUNT LOCKED] jmartin - Locked','jmartin locked.','resolved','jmartin', NOW() - INTERVAL '9 days' + INTERVAL '1 hour'),
('PROJ-S044','account_locked','High','[ACCOUNT LOCKED] cdurand - Account locked','cdurand locked.','resolved','cdurand', NOW() - INTERVAL '8 days'),
('PROJ-S045','account_locked','Medium','[ACCOUNT LOCKED] dwhite - Locked','dwhite locked.','resolved','dwhite', NOW() - INTERVAL '8 days' + INTERVAL '2 hours'),
('PROJ-S046','account_locked','Medium','[ACCOUNT LOCKED] jdoe - Account locked','jdoe locked again.','resolved','jdoe', NOW() - INTERVAL '7 days'),
('PROJ-S047','account_locked','Medium','[ACCOUNT LOCKED] mwilson - Locked','mwilson locked.','resolved','mwilson', NOW() - INTERVAL '7 days' + INTERVAL '4 hours'),
('PROJ-S048','account_locked','Medium','[ACCOUNT LOCKED] bjones - Account locked','bjones locked.','resolved','bjones', NOW() - INTERVAL '6 days'),
('PROJ-S049','account_locked','High','[ACCOUNT LOCKED] asmith - Urgent unlock','asmith locked before audit.','resolved','asmith', NOW() - INTERVAL '6 days' + INTERVAL '1 hour'),
('PROJ-S050','account_locked','Medium','[ACCOUNT LOCKED] ebrown - Locked','ebrown locked.','resolved','ebrown', NOW() - INTERVAL '5 days'),
('PROJ-S051','account_locked','Medium','[ACCOUNT LOCKED] sjohnson - Account locked','sjohnson locked.','open','sjohnson', NOW() - INTERVAL '5 days' + INTERVAL '2 hours'),
('PROJ-S052','account_locked','Medium','[ACCOUNT LOCKED] jmartin - Locked','jmartin locked.','resolved','jmartin', NOW() - INTERVAL '4 days'),
('PROJ-S053','account_locked','Medium','[ACCOUNT LOCKED] cdurand - Account locked','cdurand locked.','resolved','cdurand', NOW() - INTERVAL '4 days' + INTERVAL '3 hours'),
('PROJ-S054','account_locked','High','[ACCOUNT LOCKED] dwhite - Locked','dwhite locked.','resolved','dwhite', NOW() - INTERVAL '3 days'),
('PROJ-S055','account_locked','Medium','[ACCOUNT LOCKED] jdoe - Account locked','jdoe locked.','resolved','jdoe', NOW() - INTERVAL '3 days' + INTERVAL '1 hour'),
('PROJ-S056','account_locked','Medium','[ACCOUNT LOCKED] mwilson - Locked','mwilson locked.','resolved','mwilson', NOW() - INTERVAL '2 days'),
('PROJ-S057','account_locked','Medium','[ACCOUNT LOCKED] bjones - Account locked','bjones locked.','resolved','bjones', NOW() - INTERVAL '2 days' + INTERVAL '2 hours'),
('PROJ-S058','account_locked','Medium','[ACCOUNT LOCKED] asmith - Locked','asmith locked.','resolved','asmith', NOW() - INTERVAL '1 day'),
('PROJ-S059','account_locked','High','[ACCOUNT LOCKED] ebrown - Urgent unlock','ebrown locked.','resolved','ebrown', NOW() - INTERVAL '1 day' + INTERVAL '4 hours'),
('PROJ-S060','account_locked','Medium','[ACCOUNT LOCKED] sjohnson - Account locked','sjohnson locked.','resolved','sjohnson', NOW() - INTERVAL '12 hours'),
('PROJ-S061','account_locked','Medium','[ACCOUNT LOCKED] jmartin - Locked','jmartin locked.','open','jmartin', NOW() - INTERVAL '10 hours'),
('PROJ-S062','account_locked','Medium','[ACCOUNT LOCKED] cdurand - Account locked','cdurand locked.','open','cdurand', NOW() - INTERVAL '8 hours'),
('PROJ-S063','account_locked','High','[ACCOUNT LOCKED] dwhite - Locked','dwhite locked.','open','dwhite', NOW() - INTERVAL '6 hours'),
('PROJ-S064','account_locked','Medium','[ACCOUNT LOCKED] jdoe - Account locked','jdoe locked.','open','jdoe', NOW() - INTERVAL '4 hours'),
('PROJ-S065','account_locked','Medium','[ACCOUNT LOCKED] mwilson - Locked','mwilson locked.','open','mwilson', NOW() - INTERVAL '3 hours'),
('PROJ-S066','account_locked','Medium','[ACCOUNT LOCKED] bjones - Account locked','bjones locked.','resolved','bjones', NOW() - INTERVAL '29 days' + INTERVAL '5 hours'),
('PROJ-S067','account_locked','Medium','[ACCOUNT LOCKED] asmith - Locked','asmith locked.','resolved','asmith', NOW() - INTERVAL '28 days' + INTERVAL '6 hours'),
('PROJ-S068','account_locked','High','[ACCOUNT LOCKED] ebrown - Urgent','ebrown locked urgently.','resolved','ebrown', NOW() - INTERVAL '27 days' + INTERVAL '7 hours'),
('PROJ-S069','account_locked','Medium','[ACCOUNT LOCKED] sjohnson - Locked','sjohnson locked.','resolved','sjohnson', NOW() - INTERVAL '26 days' + INTERVAL '8 hours'),
('PROJ-S070','account_locked','Medium','[ACCOUNT LOCKED] jmartin - Account locked','jmartin locked.','resolved','jmartin', NOW() - INTERVAL '25 days' + INTERVAL '9 hours'),
('PROJ-S071','account_locked','Medium','[ACCOUNT LOCKED] cdurand - Locked','cdurand locked.','resolved','cdurand', NOW() - INTERVAL '24 days' + INTERVAL '10 hours'),
('PROJ-S072','account_locked','Medium','[ACCOUNT LOCKED] dwhite - Account locked','dwhite locked.','resolved','dwhite', NOW() - INTERVAL '23 days' + INTERVAL '11 hours'),
('PROJ-S073','account_locked','High','[ACCOUNT LOCKED] jdoe - Locked','jdoe locked.','resolved','jdoe', NOW() - INTERVAL '22 days' + INTERVAL '12 hours'),
('PROJ-S074','account_locked','Medium','[ACCOUNT LOCKED] mwilson - Account locked','mwilson locked.','resolved','mwilson', NOW() - INTERVAL '21 days' + INTERVAL '13 hours'),
('PROJ-S075','account_locked','Medium','[ACCOUNT LOCKED] bjones - Locked','bjones locked.','resolved','bjones', NOW() - INTERVAL '20 days' + INTERVAL '14 hours'),
('PROJ-S076','account_locked','Medium','[ACCOUNT LOCKED] asmith - Account locked','asmith locked.','resolved','asmith', NOW() - INTERVAL '19 days' + INTERVAL '2 hours'),
('PROJ-S077','account_locked','Medium','[ACCOUNT LOCKED] ebrown - Locked','ebrown locked.','resolved','ebrown', NOW() - INTERVAL '18 days' + INTERVAL '3 hours'),
('PROJ-S078','account_locked','High','[ACCOUNT LOCKED] sjohnson - Urgent','sjohnson locked.','resolved','sjohnson', NOW() - INTERVAL '17 days' + INTERVAL '4 hours'),
('PROJ-S079','account_locked','Medium','[ACCOUNT LOCKED] jmartin - Locked','jmartin locked.','resolved','jmartin', NOW() - INTERVAL '16 days' + INTERVAL '5 hours'),
('PROJ-S080','account_locked','Medium','[ACCOUNT LOCKED] cdurand - Account locked','cdurand locked.','resolved','cdurand', NOW() - INTERVAL '15 days' + INTERVAL '6 hours'),
('PROJ-S081','account_locked','Medium','[ACCOUNT LOCKED] dwhite - Locked','dwhite locked.','resolved','dwhite', NOW() - INTERVAL '14 days' + INTERVAL '7 hours'),
('PROJ-S082','account_locked','Medium','[ACCOUNT LOCKED] jdoe - Account locked','jdoe locked.','resolved','jdoe', NOW() - INTERVAL '13 days' + INTERVAL '8 hours'),
('PROJ-S083','account_locked','High','[ACCOUNT LOCKED] mwilson - Locked','mwilson locked.','resolved','mwilson', NOW() - INTERVAL '12 days' + INTERVAL '9 hours'),
('PROJ-S084','account_locked','Medium','[ACCOUNT LOCKED] bjones - Account locked','bjones locked.','resolved','bjones', NOW() - INTERVAL '11 days' + INTERVAL '10 hours'),
('PROJ-S085','account_locked','Medium','[ACCOUNT LOCKED] asmith - Locked','asmith locked.','resolved','asmith', NOW() - INTERVAL '10 days' + INTERVAL '11 hours'),
('PROJ-S086','account_locked','Medium','[ACCOUNT LOCKED] ebrown - Account locked','ebrown locked.','resolved','ebrown', NOW() - INTERVAL '9 days' + INTERVAL '12 hours'),
('PROJ-S087','account_locked','Medium','[ACCOUNT LOCKED] sjohnson - Locked','sjohnson locked.','resolved','sjohnson', NOW() - INTERVAL '8 days' + INTERVAL '13 hours'),
('PROJ-S088','account_locked','High','[ACCOUNT LOCKED] jmartin - Urgent','jmartin locked.','resolved','jmartin', NOW() - INTERVAL '7 days' + INTERVAL '14 hours'),
('PROJ-S089','account_locked','Medium','[ACCOUNT LOCKED] cdurand - Locked','cdurand locked.','resolved','cdurand', NOW() - INTERVAL '6 days' + INTERVAL '2 hours'),
('PROJ-S090','account_locked','Medium','[ACCOUNT LOCKED] dwhite - Account locked','dwhite locked.','resolved','dwhite', NOW() - INTERVAL '5 days' + INTERVAL '3 hours'),
('PROJ-S091','account_locked','Medium','[ACCOUNT LOCKED] jdoe - Locked','jdoe locked.','resolved','jdoe', NOW() - INTERVAL '4 days' + INTERVAL '4 hours'),
('PROJ-S092','account_locked','High','[ACCOUNT LOCKED] mwilson - Account locked','mwilson locked.','resolved','mwilson', NOW() - INTERVAL '3 days' + INTERVAL '5 hours'),
('PROJ-S093','account_locked','Medium','[ACCOUNT LOCKED] bjones - Locked','bjones locked.','resolved','bjones', NOW() - INTERVAL '2 days' + INTERVAL '6 hours'),
('PROJ-S094','account_locked','Medium','[ACCOUNT LOCKED] asmith - Account locked','asmith locked.','resolved','asmith', NOW() - INTERVAL '1 day' + INTERVAL '7 hours'),
('PROJ-S095','account_locked','Medium','[ACCOUNT LOCKED] ebrown - Locked','ebrown locked.','resolved','ebrown', NOW() - INTERVAL '23 hours'),
('PROJ-S096','account_locked','High','[ACCOUNT LOCKED] sjohnson - Urgent unlock','sjohnson locked.','resolved','sjohnson', NOW() - INTERVAL '20 hours'),
('PROJ-S097','account_locked','Medium','[ACCOUNT LOCKED] jmartin - Account locked','jmartin locked.','resolved','jmartin', NOW() - INTERVAL '16 hours'),
('PROJ-S098','account_locked','Medium','[ACCOUNT LOCKED] cdurand - Locked','cdurand locked.','resolved','cdurand', NOW() - INTERVAL '14 hours'),
('PROJ-S099','account_locked','Medium','[ACCOUNT LOCKED] dwhite - Account locked','dwhite locked.','resolved','dwhite', NOW() - INTERVAL '11 hours'),
('PROJ-S100','account_locked','High','[ACCOUNT LOCKED] jdoe - Locked','jdoe locked urgently.','open','jdoe', NOW() - INTERVAL '2 hours'),

-- ── PASSWORD RESET (100) ──────────────────────────────────────────────────────
('PROJ-S101','password_reset','Medium','[PASSWORD RESET] jdoe - Password reset requested','jdoe forgot password.','resolved','jdoe', NOW() - INTERVAL '30 days' + INTERVAL '1 hour'),
('PROJ-S102','password_reset','Medium','[PASSWORD RESET] mwilson - Password expired','mwilson password expired.','resolved','mwilson', NOW() - INTERVAL '29 days' + INTERVAL '1 hour'),
('PROJ-S103','password_reset','Medium','[PASSWORD RESET] bjones - Forgot password','bjones forgot password.','resolved','bjones', NOW() - INTERVAL '28 days' + INTERVAL '1 hour'),
('PROJ-S104','password_reset','High','[PASSWORD RESET] asmith - Urgent reset','asmith needs urgent reset.','resolved','asmith', NOW() - INTERVAL '27 days' + INTERVAL '1 hour'),
('PROJ-S105','password_reset','Medium','[PASSWORD RESET] ebrown - Password reset','ebrown password reset.','resolved','ebrown', NOW() - INTERVAL '26 days' + INTERVAL '1 hour'),
('PROJ-S106','password_reset','Medium','[PASSWORD RESET] sjohnson - Forgot password','sjohnson forgot password.','resolved','sjohnson', NOW() - INTERVAL '25 days' + INTERVAL '1 hour'),
('PROJ-S107','password_reset','Medium','[PASSWORD RESET] jmartin - Password reset','jmartin password reset.','resolved','jmartin', NOW() - INTERVAL '24 days' + INTERVAL '1 hour'),
('PROJ-S108','password_reset','Medium','[PASSWORD RESET] cdurand - Forgot password','cdurand forgot password.','resolved','cdurand', NOW() - INTERVAL '23 days' + INTERVAL '1 hour'),
('PROJ-S109','password_reset','High','[PASSWORD RESET] dwhite - Urgent reset','dwhite password reset urgently.','resolved','dwhite', NOW() - INTERVAL '22 days' + INTERVAL '1 hour'),
('PROJ-S110','password_reset','Medium','[PASSWORD RESET] jdoe - Password expired','jdoe password expired.','resolved','jdoe', NOW() - INTERVAL '21 days' + INTERVAL '1 hour'),
('PROJ-S111','password_reset','Medium','[PASSWORD RESET] mwilson - Forgot password','mwilson forgot password.','resolved','mwilson', NOW() - INTERVAL '20 days' + INTERVAL '1 hour'),
('PROJ-S112','password_reset','Medium','[PASSWORD RESET] bjones - Password reset','bjones password reset.','resolved','bjones', NOW() - INTERVAL '19 days' + INTERVAL '1 hour'),
('PROJ-S113','password_reset','Medium','[PASSWORD RESET] asmith - Forgot password','asmith forgot password.','resolved','asmith', NOW() - INTERVAL '18 days' + INTERVAL '1 hour'),
('PROJ-S114','password_reset','High','[PASSWORD RESET] ebrown - Urgent reset','ebrown urgent reset.','resolved','ebrown', NOW() - INTERVAL '17 days' + INTERVAL '1 hour'),
('PROJ-S115','password_reset','Medium','[PASSWORD RESET] sjohnson - Password expired','sjohnson password expired.','resolved','sjohnson', NOW() - INTERVAL '16 days' + INTERVAL '1 hour'),
('PROJ-S116','password_reset','Medium','[PASSWORD RESET] jmartin - Forgot password','jmartin forgot password.','resolved','jmartin', NOW() - INTERVAL '15 days' + INTERVAL '1 hour'),
('PROJ-S117','password_reset','Medium','[PASSWORD RESET] cdurand - Password reset','cdurand password reset.','resolved','cdurand', NOW() - INTERVAL '14 days' + INTERVAL '1 hour'),
('PROJ-S118','password_reset','Medium','[PASSWORD RESET] dwhite - Forgot password','dwhite forgot password.','resolved','dwhite', NOW() - INTERVAL '13 days' + INTERVAL '1 hour'),
('PROJ-S119','password_reset','High','[PASSWORD RESET] jdoe - Urgent reset','jdoe urgent reset.','resolved','jdoe', NOW() - INTERVAL '12 days' + INTERVAL '1 hour'),
('PROJ-S120','password_reset','Medium','[PASSWORD RESET] mwilson - Password expired','mwilson password expired.','resolved','mwilson', NOW() - INTERVAL '11 days' + INTERVAL '1 hour'),
('PROJ-S121','password_reset','Medium','[PASSWORD RESET] bjones - Forgot password','bjones forgot password.','resolved','bjones', NOW() - INTERVAL '10 days' + INTERVAL '1 hour'),
('PROJ-S122','password_reset','Medium','[PASSWORD RESET] asmith - Password reset','asmith password reset.','resolved','asmith', NOW() - INTERVAL '9 days' + INTERVAL '1 hour'),
('PROJ-S123','password_reset','Medium','[PASSWORD RESET] ebrown - Forgot password','ebrown forgot password.','resolved','ebrown', NOW() - INTERVAL '8 days' + INTERVAL '1 hour'),
('PROJ-S124','password_reset','High','[PASSWORD RESET] sjohnson - Urgent reset','sjohnson urgent reset.','resolved','sjohnson', NOW() - INTERVAL '7 days' + INTERVAL '1 hour'),
('PROJ-S125','password_reset','Medium','[PASSWORD RESET] jmartin - Password expired','jmartin password expired.','resolved','jmartin', NOW() - INTERVAL '6 days' + INTERVAL '1 hour'),
('PROJ-S126','password_reset','Medium','[PASSWORD RESET] cdurand - Forgot password','cdurand forgot password.','resolved','cdurand', NOW() - INTERVAL '5 days' + INTERVAL '1 hour'),
('PROJ-S127','password_reset','Medium','[PASSWORD RESET] dwhite - Password reset','dwhite password reset.','resolved','dwhite', NOW() - INTERVAL '4 days' + INTERVAL '1 hour'),
('PROJ-S128','password_reset','Medium','[PASSWORD RESET] jdoe - Forgot password','jdoe forgot password.','resolved','jdoe', NOW() - INTERVAL '3 days' + INTERVAL '1 hour'),
('PROJ-S129','password_reset','High','[PASSWORD RESET] mwilson - Urgent reset','mwilson urgent reset.','resolved','mwilson', NOW() - INTERVAL '2 days' + INTERVAL '1 hour'),
('PROJ-S130','password_reset','Medium','[PASSWORD RESET] bjones - Password expired','bjones password expired.','resolved','bjones', NOW() - INTERVAL '1 day' + INTERVAL '1 hour'),
('PROJ-S131','password_reset','Medium','[PASSWORD RESET] asmith - Forgot password','asmith forgot password.','open','asmith', NOW() - INTERVAL '20 hours'),
('PROJ-S132','password_reset','Medium','[PASSWORD RESET] ebrown - Password reset','ebrown password reset.','open','ebrown', NOW() - INTERVAL '15 hours'),
('PROJ-S133','password_reset','High','[PASSWORD RESET] sjohnson - Urgent reset','sjohnson urgent reset.','open','sjohnson', NOW() - INTERVAL '10 hours'),
('PROJ-S134','password_reset','Medium','[PASSWORD RESET] jmartin - Forgot password','jmartin forgot password.','open','jmartin', NOW() - INTERVAL '5 hours'),
('PROJ-S135','password_reset','Medium','[PASSWORD RESET] cdurand - Password expired','cdurand password expired.','open','cdurand', NOW() - INTERVAL '3 hours'),
('PROJ-S136','password_reset','Medium','[PASSWORD RESET] jdoe - Password reset','jdoe password reset.','resolved','jdoe', NOW() - INTERVAL '30 days' + INTERVAL '6 hours'),
('PROJ-S137','password_reset','Medium','[PASSWORD RESET] mwilson - Forgot password','mwilson forgot password.','resolved','mwilson', NOW() - INTERVAL '29 days' + INTERVAL '6 hours'),
('PROJ-S138','password_reset','High','[PASSWORD RESET] bjones - Urgent reset','bjones urgent reset.','resolved','bjones', NOW() - INTERVAL '28 days' + INTERVAL '6 hours'),
('PROJ-S139','password_reset','Medium','[PASSWORD RESET] asmith - Password expired','asmith password expired.','resolved','asmith', NOW() - INTERVAL '27 days' + INTERVAL '6 hours'),
('PROJ-S140','password_reset','Medium','[PASSWORD RESET] ebrown - Forgot password','ebrown forgot password.','resolved','ebrown', NOW() - INTERVAL '26 days' + INTERVAL '6 hours'),
('PROJ-S141','password_reset','Medium','[PASSWORD RESET] sjohnson - Password reset','sjohnson password reset.','resolved','sjohnson', NOW() - INTERVAL '25 days' + INTERVAL '6 hours'),
('PROJ-S142','password_reset','Medium','[PASSWORD RESET] jmartin - Forgot password','jmartin forgot password.','resolved','jmartin', NOW() - INTERVAL '24 days' + INTERVAL '6 hours'),
('PROJ-S143','password_reset','High','[PASSWORD RESET] cdurand - Urgent reset','cdurand urgent reset.','resolved','cdurand', NOW() - INTERVAL '23 days' + INTERVAL '6 hours'),
('PROJ-S144','password_reset','Medium','[PASSWORD RESET] dwhite - Password expired','dwhite password expired.','resolved','dwhite', NOW() - INTERVAL '22 days' + INTERVAL '6 hours'),
('PROJ-S145','password_reset','Medium','[PASSWORD RESET] jdoe - Forgot password','jdoe forgot password.','resolved','jdoe', NOW() - INTERVAL '21 days' + INTERVAL '6 hours'),
('PROJ-S146','password_reset','Medium','[PASSWORD RESET] mwilson - Password reset','mwilson password reset.','resolved','mwilson', NOW() - INTERVAL '20 days' + INTERVAL '6 hours'),
('PROJ-S147','password_reset','Medium','[PASSWORD RESET] bjones - Forgot password','bjones forgot password.','resolved','bjones', NOW() - INTERVAL '19 days' + INTERVAL '6 hours'),
('PROJ-S148','password_reset','High','[PASSWORD RESET] asmith - Urgent reset','asmith urgent reset.','resolved','asmith', NOW() - INTERVAL '18 days' + INTERVAL '6 hours'),
('PROJ-S149','password_reset','Medium','[PASSWORD RESET] ebrown - Password expired','ebrown password expired.','resolved','ebrown', NOW() - INTERVAL '17 days' + INTERVAL '6 hours'),
('PROJ-S150','password_reset','Medium','[PASSWORD RESET] sjohnson - Forgot password','sjohnson forgot password.','resolved','sjohnson', NOW() - INTERVAL '16 days' + INTERVAL '6 hours'),
('PROJ-S151','password_reset','Medium','[PASSWORD RESET] jmartin - Password reset','jmartin password reset.','resolved','jmartin', NOW() - INTERVAL '15 days' + INTERVAL '6 hours'),
('PROJ-S152','password_reset','Medium','[PASSWORD RESET] cdurand - Forgot password','cdurand forgot password.','resolved','cdurand', NOW() - INTERVAL '14 days' + INTERVAL '6 hours'),
('PROJ-S153','password_reset','High','[PASSWORD RESET] dwhite - Urgent reset','dwhite urgent reset.','resolved','dwhite', NOW() - INTERVAL '13 days' + INTERVAL '6 hours'),
('PROJ-S154','password_reset','Medium','[PASSWORD RESET] jdoe - Password expired','jdoe password expired.','resolved','jdoe', NOW() - INTERVAL '12 days' + INTERVAL '6 hours'),
('PROJ-S155','password_reset','Medium','[PASSWORD RESET] mwilson - Forgot password','mwilson forgot password.','resolved','mwilson', NOW() - INTERVAL '11 days' + INTERVAL '6 hours'),
('PROJ-S156','password_reset','Medium','[PASSWORD RESET] bjones - Password reset','bjones password reset.','resolved','bjones', NOW() - INTERVAL '10 days' + INTERVAL '6 hours'),
('PROJ-S157','password_reset','Medium','[PASSWORD RESET] asmith - Forgot password','asmith forgot password.','resolved','asmith', NOW() - INTERVAL '9 days' + INTERVAL '6 hours'),
('PROJ-S158','password_reset','High','[PASSWORD RESET] ebrown - Urgent reset','ebrown urgent reset.','resolved','ebrown', NOW() - INTERVAL '8 days' + INTERVAL '6 hours'),
('PROJ-S159','password_reset','Medium','[PASSWORD RESET] sjohnson - Password expired','sjohnson password expired.','resolved','sjohnson', NOW() - INTERVAL '7 days' + INTERVAL '6 hours'),
('PROJ-S160','password_reset','Medium','[PASSWORD RESET] jmartin - Forgot password','jmartin forgot password.','resolved','jmartin', NOW() - INTERVAL '6 days' + INTERVAL '6 hours'),
('PROJ-S161','password_reset','Medium','[PASSWORD RESET] cdurand - Password reset','cdurand password reset.','resolved','cdurand', NOW() - INTERVAL '5 days' + INTERVAL '6 hours'),
('PROJ-S162','password_reset','Medium','[PASSWORD RESET] dwhite - Forgot password','dwhite forgot password.','resolved','dwhite', NOW() - INTERVAL '4 days' + INTERVAL '6 hours'),
('PROJ-S163','password_reset','High','[PASSWORD RESET] jdoe - Urgent reset','jdoe urgent reset.','resolved','jdoe', NOW() - INTERVAL '3 days' + INTERVAL '6 hours'),
('PROJ-S164','password_reset','Medium','[PASSWORD RESET] mwilson - Password expired','mwilson password expired.','resolved','mwilson', NOW() - INTERVAL '2 days' + INTERVAL '6 hours'),
('PROJ-S165','password_reset','Medium','[PASSWORD RESET] bjones - Forgot password','bjones forgot password.','resolved','bjones', NOW() - INTERVAL '1 day' + INTERVAL '6 hours'),
('PROJ-S166','password_reset','Medium','[PASSWORD RESET] asmith - Password reset','asmith password reset.','resolved','asmith', NOW() - INTERVAL '30 days' + INTERVAL '10 hours'),
('PROJ-S167','password_reset','Medium','[PASSWORD RESET] ebrown - Forgot password','ebrown forgot password.','resolved','ebrown', NOW() - INTERVAL '29 days' + INTERVAL '10 hours'),
('PROJ-S168','password_reset','High','[PASSWORD RESET] sjohnson - Urgent reset','sjohnson urgent reset.','resolved','sjohnson', NOW() - INTERVAL '28 days' + INTERVAL '10 hours'),
('PROJ-S169','password_reset','Medium','[PASSWORD RESET] jmartin - Password expired','jmartin password expired.','resolved','jmartin', NOW() - INTERVAL '27 days' + INTERVAL '10 hours'),
('PROJ-S170','password_reset','Medium','[PASSWORD RESET] cdurand - Forgot password','cdurand forgot password.','resolved','cdurand', NOW() - INTERVAL '26 days' + INTERVAL '10 hours'),
('PROJ-S171','password_reset','Medium','[PASSWORD RESET] dwhite - Password reset','dwhite password reset.','resolved','dwhite', NOW() - INTERVAL '25 days' + INTERVAL '10 hours'),
('PROJ-S172','password_reset','Medium','[PASSWORD RESET] jdoe - Forgot password','jdoe forgot password.','resolved','jdoe', NOW() - INTERVAL '24 days' + INTERVAL '10 hours'),
('PROJ-S173','password_reset','High','[PASSWORD RESET] mwilson - Urgent reset','mwilson urgent reset.','resolved','mwilson', NOW() - INTERVAL '23 days' + INTERVAL '10 hours'),
('PROJ-S174','password_reset','Medium','[PASSWORD RESET] bjones - Password expired','bjones password expired.','resolved','bjones', NOW() - INTERVAL '22 days' + INTERVAL '10 hours'),
('PROJ-S175','password_reset','Medium','[PASSWORD RESET] asmith - Forgot password','asmith forgot password.','resolved','asmith', NOW() - INTERVAL '21 days' + INTERVAL '10 hours'),
('PROJ-S176','password_reset','Medium','[PASSWORD RESET] ebrown - Password reset','ebrown password reset.','resolved','ebrown', NOW() - INTERVAL '20 days' + INTERVAL '10 hours'),
('PROJ-S177','password_reset','Medium','[PASSWORD RESET] sjohnson - Forgot password','sjohnson forgot password.','resolved','sjohnson', NOW() - INTERVAL '19 days' + INTERVAL '10 hours'),
('PROJ-S178','password_reset','High','[PASSWORD RESET] jmartin - Urgent reset','jmartin urgent reset.','resolved','jmartin', NOW() - INTERVAL '18 days' + INTERVAL '10 hours'),
('PROJ-S179','password_reset','Medium','[PASSWORD RESET] cdurand - Password expired','cdurand password expired.','resolved','cdurand', NOW() - INTERVAL '17 days' + INTERVAL '10 hours'),
('PROJ-S180','password_reset','Medium','[PASSWORD RESET] dwhite - Forgot password','dwhite forgot password.','resolved','dwhite', NOW() - INTERVAL '16 days' + INTERVAL '10 hours'),
('PROJ-S181','password_reset','Medium','[PASSWORD RESET] jdoe - Password reset','jdoe password reset.','resolved','jdoe', NOW() - INTERVAL '15 days' + INTERVAL '10 hours'),
('PROJ-S182','password_reset','Medium','[PASSWORD RESET] mwilson - Forgot password','mwilson forgot password.','resolved','mwilson', NOW() - INTERVAL '14 days' + INTERVAL '10 hours'),
('PROJ-S183','password_reset','High','[PASSWORD RESET] bjones - Urgent reset','bjones urgent reset.','resolved','bjones', NOW() - INTERVAL '13 days' + INTERVAL '10 hours'),
('PROJ-S184','password_reset','Medium','[PASSWORD RESET] asmith - Password expired','asmith password expired.','resolved','asmith', NOW() - INTERVAL '12 days' + INTERVAL '10 hours'),
('PROJ-S185','password_reset','Medium','[PASSWORD RESET] ebrown - Forgot password','ebrown forgot password.','resolved','ebrown', NOW() - INTERVAL '11 days' + INTERVAL '10 hours'),
('PROJ-S186','password_reset','Medium','[PASSWORD RESET] sjohnson - Password reset','sjohnson password reset.','resolved','sjohnson', NOW() - INTERVAL '10 days' + INTERVAL '10 hours'),
('PROJ-S187','password_reset','Medium','[PASSWORD RESET] jmartin - Forgot password','jmartin forgot password.','resolved','jmartin', NOW() - INTERVAL '9 days' + INTERVAL '10 hours'),
('PROJ-S188','password_reset','High','[PASSWORD RESET] cdurand - Urgent reset','cdurand urgent reset.','resolved','cdurand', NOW() - INTERVAL '8 days' + INTERVAL '10 hours'),
('PROJ-S189','password_reset','Medium','[PASSWORD RESET] dwhite - Password expired','dwhite password expired.','resolved','dwhite', NOW() - INTERVAL '7 days' + INTERVAL '10 hours'),
('PROJ-S190','password_reset','Medium','[PASSWORD RESET] jdoe - Forgot password','jdoe forgot password.','resolved','jdoe', NOW() - INTERVAL '6 days' + INTERVAL '10 hours'),
('PROJ-S191','password_reset','Medium','[PASSWORD RESET] mwilson - Password reset','mwilson password reset.','resolved','mwilson', NOW() - INTERVAL '5 days' + INTERVAL '10 hours'),
('PROJ-S192','password_reset','Medium','[PASSWORD RESET] bjones - Forgot password','bjones forgot password.','resolved','bjones', NOW() - INTERVAL '4 days' + INTERVAL '10 hours'),
('PROJ-S193','password_reset','High','[PASSWORD RESET] asmith - Urgent reset','asmith urgent reset.','resolved','asmith', NOW() - INTERVAL '3 days' + INTERVAL '10 hours'),
('PROJ-S194','password_reset','Medium','[PASSWORD RESET] ebrown - Password expired','ebrown password expired.','resolved','ebrown', NOW() - INTERVAL '2 days' + INTERVAL '10 hours'),
('PROJ-S195','password_reset','Medium','[PASSWORD RESET] sjohnson - Forgot password','sjohnson forgot password.','resolved','sjohnson', NOW() - INTERVAL '1 day' + INTERVAL '10 hours'),
('PROJ-S196','password_reset','Medium','[PASSWORD RESET] jmartin - Password reset','jmartin password reset.','open','jmartin', NOW() - INTERVAL '18 hours'),
('PROJ-S197','password_reset','Medium','[PASSWORD RESET] cdurand - Forgot password','cdurand forgot password.','open','cdurand', NOW() - INTERVAL '12 hours'),
('PROJ-S198','password_reset','High','[PASSWORD RESET] dwhite - Urgent reset','dwhite urgent reset.','open','dwhite', NOW() - INTERVAL '8 hours'),
('PROJ-S199','password_reset','Medium','[PASSWORD RESET] jdoe - Password expired','jdoe password expired.','open','jdoe', NOW() - INTERVAL '4 hours'),
('PROJ-S200','password_reset','Medium','[PASSWORD RESET] mwilson - Forgot password','mwilson forgot password.','open','mwilson', NOW() - INTERVAL '1 hour'),

-- ── VPN DIAGNOSTICS (100) ─────────────────────────────────────────────────────
('PROJ-S201','vpn','High','[VPN] jdoe - VPN not connecting from home','jdoe cannot connect to VPN working remotely.','resolved','jdoe', NOW() - INTERVAL '30 days' + INTERVAL '2 hours'),
('PROJ-S202','vpn','High','[VPN] mwilson - VPN disconnects frequently','mwilson VPN drops every 10 minutes.','resolved','mwilson', NOW() - INTERVAL '29 days' + INTERVAL '2 hours'),
('PROJ-S203','vpn','Medium','[VPN] bjones - Cannot connect to VPN','bjones VPN not connecting.','resolved','bjones', NOW() - INTERVAL '28 days' + INTERVAL '2 hours'),
('PROJ-S204','vpn','High','[VPN] asmith - VPN error 619','asmith VPN error 619.','resolved','asmith', NOW() - INTERVAL '27 days' + INTERVAL '2 hours'),
('PROJ-S205','vpn','Medium','[VPN] ebrown - VPN slow connection','ebrown VPN very slow.','resolved','ebrown', NOW() - INTERVAL '26 days' + INTERVAL '2 hours'),
('PROJ-S206','vpn','High','[VPN] sjohnson - VPN not connecting','sjohnson VPN not connecting.','resolved','sjohnson', NOW() - INTERVAL '25 days' + INTERVAL '2 hours'),
('PROJ-S207','vpn','Critical','[VPN] jmartin - Cannot work remotely','jmartin completely blocked.','resolved','jmartin', NOW() - INTERVAL '24 days' + INTERVAL '2 hours'),
('PROJ-S208','vpn','High','[VPN] cdurand - VPN authentication failed','cdurand VPN auth failed.','resolved','cdurand', NOW() - INTERVAL '23 days' + INTERVAL '2 hours'),
('PROJ-S209','vpn','High','[VPN] dwhite - VPN client crash','dwhite VPN crashes on connect.','resolved','dwhite', NOW() - INTERVAL '22 days' + INTERVAL '2 hours'),
('PROJ-S210','vpn','Medium','[VPN] jdoe - VPN timeout','jdoe VPN keeps timing out.','resolved','jdoe', NOW() - INTERVAL '21 days' + INTERVAL '2 hours'),
('PROJ-S211','vpn','High','[VPN] mwilson - No internet after VPN','mwilson loses internet when VPN connected.','resolved','mwilson', NOW() - INTERVAL '20 days' + INTERVAL '2 hours'),
('PROJ-S212','vpn','Medium','[VPN] bjones - VPN not connecting','bjones VPN issue.','resolved','bjones', NOW() - INTERVAL '19 days' + INTERVAL '2 hours'),
('PROJ-S213','vpn','High','[VPN] asmith - VPN blocked by firewall','asmith VPN blocked.','resolved','asmith', NOW() - INTERVAL '18 days' + INTERVAL '2 hours'),
('PROJ-S214','vpn','Medium','[VPN] ebrown - VPN reconnecting loop','ebrown VPN loops.','resolved','ebrown', NOW() - INTERVAL '17 days' + INTERVAL '2 hours'),
('PROJ-S215','vpn','High','[VPN] sjohnson - Cannot connect to VPN','sjohnson VPN down.','resolved','sjohnson', NOW() - INTERVAL '16 days' + INTERVAL '2 hours'),
('PROJ-S216','vpn','Critical','[VPN] jmartin - VPN outage','jmartin VPN outage.','escalated','jmartin', NOW() - INTERVAL '15 days' + INTERVAL '2 hours'),
('PROJ-S217','vpn','High','[VPN] cdurand - VPN not working','cdurand VPN not working.','resolved','cdurand', NOW() - INTERVAL '14 days' + INTERVAL '2 hours'),
('PROJ-S218','vpn','Medium','[VPN] dwhite - VPN slow','dwhite VPN slow.','resolved','dwhite', NOW() - INTERVAL '13 days' + INTERVAL '2 hours'),
('PROJ-S219','vpn','High','[VPN] jdoe - VPN error','jdoe VPN error.','resolved','jdoe', NOW() - INTERVAL '12 days' + INTERVAL '2 hours'),
('PROJ-S220','vpn','High','[VPN] mwilson - VPN not connecting','mwilson VPN not connecting.','resolved','mwilson', NOW() - INTERVAL '11 days' + INTERVAL '2 hours'),
('PROJ-S221','vpn','Medium','[VPN] bjones - VPN disconnects','bjones VPN disconnects.','resolved','bjones', NOW() - INTERVAL '10 days' + INTERVAL '2 hours'),
('PROJ-S222','vpn','High','[VPN] asmith - VPN issue','asmith VPN issue.','resolved','asmith', NOW() - INTERVAL '9 days' + INTERVAL '2 hours'),
('PROJ-S223','vpn','High','[VPN] ebrown - Cannot connect','ebrown cannot connect.','resolved','ebrown', NOW() - INTERVAL '8 days' + INTERVAL '2 hours'),
('PROJ-S224','vpn','Critical','[VPN] sjohnson - VPN blocked','sjohnson VPN blocked.','escalated','sjohnson', NOW() - INTERVAL '7 days' + INTERVAL '2 hours'),
('PROJ-S225','vpn','High','[VPN] jmartin - VPN error 800','jmartin VPN error 800.','resolved','jmartin', NOW() - INTERVAL '6 days' + INTERVAL '2 hours'),
('PROJ-S226','vpn','Medium','[VPN] cdurand - VPN slow connection','cdurand VPN slow.','resolved','cdurand', NOW() - INTERVAL '5 days' + INTERVAL '2 hours'),
('PROJ-S227','vpn','High','[VPN] dwhite - VPN not working','dwhite VPN not working.','resolved','dwhite', NOW() - INTERVAL '4 days' + INTERVAL '2 hours'),
('PROJ-S228','vpn','High','[VPN] jdoe - VPN not connecting','jdoe VPN not connecting.','resolved','jdoe', NOW() - INTERVAL '3 days' + INTERVAL '2 hours'),
('PROJ-S229','vpn','Critical','[VPN] mwilson - VPN outage','mwilson VPN outage.','escalated','mwilson', NOW() - INTERVAL '2 days' + INTERVAL '2 hours'),
('PROJ-S230','vpn','High','[VPN] bjones - VPN authentication','bjones VPN auth.','resolved','bjones', NOW() - INTERVAL '1 day' + INTERVAL '2 hours'),
('PROJ-S231','vpn','High','[VPN] asmith - VPN not connecting','asmith VPN not connecting.','open','asmith', NOW() - INTERVAL '22 hours'),
('PROJ-S232','vpn','Medium','[VPN] ebrown - VPN slow','ebrown VPN slow.','open','ebrown', NOW() - INTERVAL '18 hours'),
('PROJ-S233','vpn','High','[VPN] sjohnson - VPN error','sjohnson VPN error.','open','sjohnson', NOW() - INTERVAL '14 hours'),
('PROJ-S234','vpn','Critical','[VPN] jmartin - Cannot work','jmartin cannot work.','open','jmartin', NOW() - INTERVAL '10 hours'),
('PROJ-S235','vpn','High','[VPN] cdurand - VPN not working','cdurand VPN not working.','open','cdurand', NOW() - INTERVAL '6 hours'),
('PROJ-S236','vpn','High','[VPN] jdoe - VPN issue','jdoe VPN issue.','resolved','jdoe', NOW() - INTERVAL '30 days' + INTERVAL '8 hours'),
('PROJ-S237','vpn','Medium','[VPN] mwilson - VPN slow','mwilson VPN slow.','resolved','mwilson', NOW() - INTERVAL '29 days' + INTERVAL '8 hours'),
('PROJ-S238','vpn','High','[VPN] bjones - VPN not connecting','bjones VPN not connecting.','resolved','bjones', NOW() - INTERVAL '28 days' + INTERVAL '8 hours'),
('PROJ-S239','vpn','High','[VPN] asmith - VPN authentication failed','asmith VPN auth failed.','resolved','asmith', NOW() - INTERVAL '27 days' + INTERVAL '8 hours'),
('PROJ-S240','vpn','Critical','[VPN] ebrown - VPN blocked','ebrown VPN blocked.','escalated','ebrown', NOW() - INTERVAL '26 days' + INTERVAL '8 hours'),
('PROJ-S241','vpn','High','[VPN] sjohnson - VPN not working','sjohnson VPN not working.','resolved','sjohnson', NOW() - INTERVAL '25 days' + INTERVAL '8 hours'),
('PROJ-S242','vpn','Medium','[VPN] jmartin - VPN slow','jmartin VPN slow.','resolved','jmartin', NOW() - INTERVAL '24 days' + INTERVAL '8 hours'),
('PROJ-S243','vpn','High','[VPN] cdurand - VPN error','cdurand VPN error.','resolved','cdurand', NOW() - INTERVAL '23 days' + INTERVAL '8 hours'),
('PROJ-S244','vpn','High','[VPN] dwhite - VPN not connecting','dwhite VPN not connecting.','resolved','dwhite', NOW() - INTERVAL '22 days' + INTERVAL '8 hours'),
('PROJ-S245','vpn','High','[VPN] jdoe - VPN disconnects','jdoe VPN disconnects.','resolved','jdoe', NOW() - INTERVAL '21 days' + INTERVAL '8 hours'),
('PROJ-S246','vpn','Medium','[VPN] mwilson - VPN error','mwilson VPN error.','resolved','mwilson', NOW() - INTERVAL '20 days' + INTERVAL '8 hours'),
('PROJ-S247','vpn','High','[VPN] bjones - VPN blocked','bjones VPN blocked.','resolved','bjones', NOW() - INTERVAL '19 days' + INTERVAL '8 hours'),
('PROJ-S248','vpn','Critical','[VPN] asmith - Cannot connect remotely','asmith cannot connect.','escalated','asmith', NOW() - INTERVAL '18 days' + INTERVAL '8 hours'),
('PROJ-S249','vpn','High','[VPN] ebrown - VPN not working','ebrown VPN not working.','resolved','ebrown', NOW() - INTERVAL '17 days' + INTERVAL '8 hours'),
('PROJ-S250','vpn','High','[VPN] sjohnson - VPN error 619','sjohnson VPN error 619.','resolved','sjohnson', NOW() - INTERVAL '16 days' + INTERVAL '8 hours'),
('PROJ-S251','vpn','Medium','[VPN] jmartin - VPN slow connection','jmartin VPN slow.','resolved','jmartin', NOW() - INTERVAL '15 days' + INTERVAL '8 hours'),
('PROJ-S252','vpn','High','[VPN] cdurand - VPN not connecting','cdurand VPN not connecting.','resolved','cdurand', NOW() - INTERVAL '14 days' + INTERVAL '8 hours'),
('PROJ-S253','vpn','High','[VPN] dwhite - VPN issue','dwhite VPN issue.','resolved','dwhite', NOW() - INTERVAL '13 days' + INTERVAL '8 hours'),
('PROJ-S254','vpn','High','[VPN] jdoe - VPN not working','jdoe VPN not working.','resolved','jdoe', NOW() - INTERVAL '12 days' + INTERVAL '8 hours'),
('PROJ-S255','vpn','Critical','[VPN] mwilson - VPN outage','mwilson VPN outage.','escalated','mwilson', NOW() - INTERVAL '11 days' + INTERVAL '8 hours'),
('PROJ-S256','vpn','High','[VPN] bjones - VPN not connecting','bjones VPN not connecting.','resolved','bjones', NOW() - INTERVAL '10 days' + INTERVAL '8 hours'),
('PROJ-S257','vpn','Medium','[VPN] asmith - VPN slow','asmith VPN slow.','resolved','asmith', NOW() - INTERVAL '9 days' + INTERVAL '8 hours'),
('PROJ-S258','vpn','High','[VPN] ebrown - VPN authentication','ebrown VPN auth.','resolved','ebrown', NOW() - INTERVAL '8 days' + INTERVAL '8 hours'),
('PROJ-S259','vpn','High','[VPN] sjohnson - VPN not working','sjohnson VPN not working.','resolved','sjohnson', NOW() - INTERVAL '7 days' + INTERVAL '8 hours'),
('PROJ-S260','vpn','High','[VPN] jmartin - VPN error','jmartin VPN error.','resolved','jmartin', NOW() - INTERVAL '6 days' + INTERVAL '8 hours'),
('PROJ-S261','vpn','Medium','[VPN] cdurand - VPN slow','cdurand VPN slow.','resolved','cdurand', NOW() - INTERVAL '5 days' + INTERVAL '8 hours'),
('PROJ-S262','vpn','High','[VPN] dwhite - VPN not connecting','dwhite VPN not connecting.','resolved','dwhite', NOW() - INTERVAL '4 days' + INTERVAL '8 hours'),
('PROJ-S263','vpn','High','[VPN] jdoe - VPN blocked','jdoe VPN blocked.','resolved','jdoe', NOW() - INTERVAL '3 days' + INTERVAL '8 hours'),
('PROJ-S264','vpn','Critical','[VPN] mwilson - Cannot connect','mwilson cannot connect.','escalated','mwilson', NOW() - INTERVAL '2 days' + INTERVAL '8 hours'),
('PROJ-S265','vpn','High','[VPN] bjones - VPN not working','bjones VPN not working.','resolved','bjones', NOW() - INTERVAL '1 day' + INTERVAL '8 hours'),
('PROJ-S266','vpn','High','[VPN] asmith - VPN issue','asmith VPN issue.','resolved','asmith', NOW() - INTERVAL '30 days' + INTERVAL '14 hours'),
('PROJ-S267','vpn','Medium','[VPN] ebrown - VPN slow connection','ebrown VPN slow.','resolved','ebrown', NOW() - INTERVAL '28 days' + INTERVAL '14 hours'),
('PROJ-S268','vpn','High','[VPN] sjohnson - VPN not connecting','sjohnson VPN not connecting.','resolved','sjohnson', NOW() - INTERVAL '26 days' + INTERVAL '14 hours'),
('PROJ-S269','vpn','High','[VPN] jmartin - VPN error','jmartin VPN error.','resolved','jmartin', NOW() - INTERVAL '24 days' + INTERVAL '14 hours'),
('PROJ-S270','vpn','Critical','[VPN] cdurand - VPN blocked','cdurand VPN blocked.','escalated','cdurand', NOW() - INTERVAL '22 days' + INTERVAL '14 hours'),
('PROJ-S271','vpn','High','[VPN] dwhite - VPN not working','dwhite VPN not working.','resolved','dwhite', NOW() - INTERVAL '20 days' + INTERVAL '14 hours'),
('PROJ-S272','vpn','High','[VPN] jdoe - VPN authentication failed','jdoe VPN auth failed.','resolved','jdoe', NOW() - INTERVAL '18 days' + INTERVAL '14 hours'),
('PROJ-S273','vpn','Medium','[VPN] mwilson - VPN slow','mwilson VPN slow.','resolved','mwilson', NOW() - INTERVAL '16 days' + INTERVAL '14 hours'),
('PROJ-S274','vpn','High','[VPN] bjones - VPN not connecting','bjones VPN not connecting.','resolved','bjones', NOW() - INTERVAL '14 days' + INTERVAL '14 hours'),
('PROJ-S275','vpn','High','[VPN] asmith - VPN error','asmith VPN error.','resolved','asmith', NOW() - INTERVAL '12 days' + INTERVAL '14 hours'),
('PROJ-S276','vpn','Critical','[VPN] ebrown - Cannot work remotely','ebrown cannot work.','escalated','ebrown', NOW() - INTERVAL '10 days' + INTERVAL '14 hours'),
('PROJ-S277','vpn','High','[VPN] sjohnson - VPN not working','sjohnson VPN not working.','resolved','sjohnson', NOW() - INTERVAL '8 days' + INTERVAL '14 hours'),
('PROJ-S278','vpn','High','[VPN] jmartin - VPN disconnects','jmartin VPN disconnects.','resolved','jmartin', NOW() - INTERVAL '6 days' + INTERVAL '14 hours'),
('PROJ-S279','vpn','Medium','[VPN] cdurand - VPN slow','cdurand VPN slow.','resolved','cdurand', NOW() - INTERVAL '4 days' + INTERVAL '14 hours'),
('PROJ-S280','vpn','High','[VPN] dwhite - VPN not connecting','dwhite VPN not connecting.','resolved','dwhite', NOW() - INTERVAL '2 days' + INTERVAL '14 hours'),
('PROJ-S281','vpn','High','[VPN] jdoe - VPN error 619','jdoe VPN error 619.','open','jdoe', NOW() - INTERVAL '20 hours'),
('PROJ-S282','vpn','High','[VPN] mwilson - VPN not working','mwilson VPN not working.','open','mwilson', NOW() - INTERVAL '16 hours'),
('PROJ-S283','vpn','Critical','[VPN] bjones - VPN blocked','bjones VPN blocked.','open','bjones', NOW() - INTERVAL '12 hours'),
('PROJ-S284','vpn','High','[VPN] asmith - VPN not connecting','asmith VPN not connecting.','open','asmith', NOW() - INTERVAL '8 hours'),
('PROJ-S285','vpn','High','[VPN] ebrown - Cannot connect to VPN','ebrown cannot connect.','open','ebrown', NOW() - INTERVAL '4 hours'),
('PROJ-S286','vpn','Medium','[VPN] sjohnson - VPN slow','sjohnson VPN slow.','resolved','sjohnson', NOW() - INTERVAL '30 days' + INTERVAL '18 hours'),
('PROJ-S287','vpn','High','[VPN] jmartin - VPN not connecting','jmartin VPN not connecting.','resolved','jmartin', NOW() - INTERVAL '27 days' + INTERVAL '18 hours'),
('PROJ-S288','vpn','High','[VPN] cdurand - VPN error','cdurand VPN error.','resolved','cdurand', NOW() - INTERVAL '24 days' + INTERVAL '18 hours'),
('PROJ-S289','vpn','Critical','[VPN] dwhite - VPN outage','dwhite VPN outage.','escalated','dwhite', NOW() - INTERVAL '21 days' + INTERVAL '18 hours'),
('PROJ-S290','vpn','High','[VPN] jdoe - VPN not working','jdoe VPN not working.','resolved','jdoe', NOW() - INTERVAL '18 days' + INTERVAL '18 hours'),
('PROJ-S291','vpn','High','[VPN] mwilson - VPN authentication','mwilson VPN auth.','resolved','mwilson', NOW() - INTERVAL '15 days' + INTERVAL '18 hours'),
('PROJ-S292','vpn','Medium','[VPN] bjones - VPN slow connection','bjones VPN slow.','resolved','bjones', NOW() - INTERVAL '12 days' + INTERVAL '18 hours'),
('PROJ-S293','vpn','High','[VPN] asmith - VPN not connecting','asmith VPN not connecting.','resolved','asmith', NOW() - INTERVAL '9 days' + INTERVAL '18 hours'),
('PROJ-S294','vpn','High','[VPN] ebrown - VPN blocked','ebrown VPN blocked.','resolved','ebrown', NOW() - INTERVAL '6 days' + INTERVAL '18 hours'),
('PROJ-S295','vpn','Critical','[VPN] sjohnson - Cannot work remotely','sjohnson cannot work.','escalated','sjohnson', NOW() - INTERVAL '3 days' + INTERVAL '18 hours'),
('PROJ-S296','vpn','High','[VPN] jmartin - VPN error 800','jmartin VPN error.','resolved','jmartin', NOW() - INTERVAL '30 days' + INTERVAL '22 hours'),
('PROJ-S297','vpn','High','[VPN] cdurand - VPN not working','cdurand VPN not working.','resolved','cdurand', NOW() - INTERVAL '25 days' + INTERVAL '22 hours'),
('PROJ-S298','vpn','Medium','[VPN] dwhite - VPN slow','dwhite VPN slow.','resolved','dwhite', NOW() - INTERVAL '20 days' + INTERVAL '22 hours'),
('PROJ-S299','vpn','High','[VPN] jdoe - VPN not connecting','jdoe VPN not connecting.','resolved','jdoe', NOW() - INTERVAL '15 days' + INTERVAL '22 hours'),
('PROJ-S300','vpn','Critical','[VPN] mwilson - VPN blocked','mwilson VPN blocked.','open','mwilson', NOW() - INTERVAL '2 hours'),

-- ── ACCESS REQUESTS (100) ─────────────────────────────────────────────────────
('PROJ-S301','access_request','Medium','[ACCESS] jdoe - Access request for SharePoint','jdoe needs SharePoint access.','resolved','jdoe', NOW() - INTERVAL '30 days' + INTERVAL '3 hours'),
('PROJ-S302','access_request','Medium','[ACCESS] mwilson - Access request for VPN','mwilson needs VPN access.','resolved','mwilson', NOW() - INTERVAL '29 days' + INTERVAL '3 hours'),
('PROJ-S303','access_request','Medium','[ACCESS] bjones - Access request for SAP ERP','bjones needs SAP access.','resolved','bjones', NOW() - INTERVAL '28 days' + INTERVAL '3 hours'),
('PROJ-S304','access_request','High','[ACCESS] asmith - Access request for Salesforce','asmith needs Salesforce access.','resolved','asmith', NOW() - INTERVAL '27 days' + INTERVAL '3 hours'),
('PROJ-S305','access_request','Medium','[ACCESS] ebrown - Access request for GitHub','ebrown needs GitHub access.','resolved','ebrown', NOW() - INTERVAL '26 days' + INTERVAL '3 hours'),
('PROJ-S306','access_request','Medium','[ACCESS] sjohnson - Access request for HR Portal','sjohnson needs HR portal access.','resolved','sjohnson', NOW() - INTERVAL '25 days' + INTERVAL '3 hours'),
('PROJ-S307','access_request','Medium','[ACCESS] jmartin - Access request for Teams','jmartin needs Teams access.','resolved','jmartin', NOW() - INTERVAL '24 days' + INTERVAL '3 hours'),
('PROJ-S308','access_request','Medium','[ACCESS] cdurand - Access request for SharePoint','cdurand needs SharePoint access.','resolved','cdurand', NOW() - INTERVAL '23 days' + INTERVAL '3 hours'),
('PROJ-S309','access_request','High','[ACCESS] dwhite - Access request for ERP','dwhite needs ERP access.','resolved','dwhite', NOW() - INTERVAL '22 days' + INTERVAL '3 hours'),
('PROJ-S310','access_request','Medium','[ACCESS] jdoe - Access request for CRM','jdoe needs CRM access.','resolved','jdoe', NOW() - INTERVAL '21 days' + INTERVAL '3 hours'),
('PROJ-S311','access_request','Medium','[ACCESS] mwilson - Access request for SharePoint','mwilson needs SharePoint access.','resolved','mwilson', NOW() - INTERVAL '20 days' + INTERVAL '3 hours'),
('PROJ-S312','access_request','Medium','[ACCESS] bjones - Access request for VPN','bjones needs VPN access.','resolved','bjones', NOW() - INTERVAL '19 days' + INTERVAL '3 hours'),
('PROJ-S313','access_request','Medium','[ACCESS] asmith - Access request for GitHub','asmith needs GitHub access.','resolved','asmith', NOW() - INTERVAL '18 days' + INTERVAL '3 hours'),
('PROJ-S314','access_request','High','[ACCESS] ebrown - Access request for SAP','ebrown needs SAP access.','resolved','ebrown', NOW() - INTERVAL '17 days' + INTERVAL '3 hours'),
('PROJ-S315','access_request','Medium','[ACCESS] sjohnson - Access request for Teams','sjohnson needs Teams access.','resolved','sjohnson', NOW() - INTERVAL '16 days' + INTERVAL '3 hours'),
('PROJ-S316','access_request','Medium','[ACCESS] jmartin - Access request for Salesforce','jmartin needs Salesforce access.','resolved','jmartin', NOW() - INTERVAL '15 days' + INTERVAL '3 hours'),
('PROJ-S317','access_request','Medium','[ACCESS] cdurand - Access request for VPN','cdurand needs VPN access.','resolved','cdurand', NOW() - INTERVAL '14 days' + INTERVAL '3 hours'),
('PROJ-S318','access_request','Medium','[ACCESS] dwhite - Access request for CRM','dwhite needs CRM access.','resolved','dwhite', NOW() - INTERVAL '13 days' + INTERVAL '3 hours'),
('PROJ-S319','access_request','High','[ACCESS] jdoe - Access request for ERP','jdoe needs ERP access.','resolved','jdoe', NOW() - INTERVAL '12 days' + INTERVAL '3 hours'),
('PROJ-S320','access_request','Medium','[ACCESS] mwilson - Access request for GitHub','mwilson needs GitHub access.','resolved','mwilson', NOW() - INTERVAL '11 days' + INTERVAL '3 hours'),
('PROJ-S321','access_request','Medium','[ACCESS] bjones - Access request for Outlook','bjones needs Outlook access.','resolved','bjones', NOW() - INTERVAL '10 days' + INTERVAL '3 hours'),
('PROJ-S322','access_request','Medium','[ACCESS] asmith - Access request for Teams','asmith needs Teams access.','resolved','asmith', NOW() - INTERVAL '9 days' + INTERVAL '3 hours'),
('PROJ-S323','access_request','Medium','[ACCESS] ebrown - Access request for SharePoint','ebrown needs SharePoint access.','resolved','ebrown', NOW() - INTERVAL '8 days' + INTERVAL '3 hours'),
('PROJ-S324','access_request','High','[ACCESS] sjohnson - Access request for SAP','sjohnson needs SAP access.','resolved','sjohnson', NOW() - INTERVAL '7 days' + INTERVAL '3 hours'),
('PROJ-S325','access_request','Medium','[ACCESS] jmartin - Access request for HR Portal','jmartin needs HR portal access.','resolved','jmartin', NOW() - INTERVAL '6 days' + INTERVAL '3 hours'),
('PROJ-S326','access_request','Medium','[ACCESS] cdurand - Access request for GitHub','cdurand needs GitHub access.','resolved','cdurand', NOW() - INTERVAL '5 days' + INTERVAL '3 hours'),
('PROJ-S327','access_request','Medium','[ACCESS] dwhite - Access request for Teams','dwhite needs Teams access.','resolved','dwhite', NOW() - INTERVAL '4 days' + INTERVAL '3 hours'),
('PROJ-S328','access_request','High','[ACCESS] jdoe - Access request for SharePoint','jdoe needs SharePoint access.','resolved','jdoe', NOW() - INTERVAL '3 days' + INTERVAL '3 hours'),
('PROJ-S329','access_request','Medium','[ACCESS] mwilson - Access request for ERP','mwilson needs ERP access.','resolved','mwilson', NOW() - INTERVAL '2 days' + INTERVAL '3 hours'),
('PROJ-S330','access_request','Medium','[ACCESS] bjones - Access request for CRM','bjones needs CRM access.','resolved','bjones', NOW() - INTERVAL '1 day' + INTERVAL '3 hours'),
('PROJ-S331','access_request','Medium','[ACCESS] asmith - Access request for VPN','asmith needs VPN access.','open','asmith', NOW() - INTERVAL '22 hours'),
('PROJ-S332','access_request','High','[ACCESS] ebrown - Access request for SAP','ebrown needs SAP access.','open','ebrown', NOW() - INTERVAL '16 hours'),
('PROJ-S333','access_request','Medium','[ACCESS] sjohnson - Access request for GitHub','sjohnson needs GitHub access.','open','sjohnson', NOW() - INTERVAL '12 hours'),
('PROJ-S334','access_request','Medium','[ACCESS] jmartin - Access request for SharePoint','jmartin needs SharePoint access.','open','jmartin', NOW() - INTERVAL '8 hours'),
('PROJ-S335','access_request','Medium','[ACCESS] cdurand - Access request for Teams','cdurand needs Teams access.','open','cdurand', NOW() - INTERVAL '4 hours'),
('PROJ-S336','access_request','Medium','[ACCESS] jdoe - Access request for Outlook','jdoe needs Outlook access.','resolved','jdoe', NOW() - INTERVAL '30 days' + INTERVAL '9 hours'),
('PROJ-S337','access_request','High','[ACCESS] mwilson - Access request for SAP','mwilson needs SAP access.','resolved','mwilson', NOW() - INTERVAL '27 days' + INTERVAL '9 hours'),
('PROJ-S338','access_request','Medium','[ACCESS] bjones - Access request for Salesforce','bjones needs Salesforce access.','resolved','bjones', NOW() - INTERVAL '24 days' + INTERVAL '9 hours'),
('PROJ-S339','access_request','Medium','[ACCESS] asmith - Access request for HR Portal','asmith needs HR portal.','resolved','asmith', NOW() - INTERVAL '21 days' + INTERVAL '9 hours'),
('PROJ-S340','access_request','High','[ACCESS] ebrown - Access request for ERP','ebrown needs ERP access.','resolved','ebrown', NOW() - INTERVAL '18 days' + INTERVAL '9 hours'),
('PROJ-S341','access_request','Medium','[ACCESS] sjohnson - Access request for VPN','sjohnson needs VPN access.','resolved','sjohnson', NOW() - INTERVAL '15 days' + INTERVAL '9 hours'),
('PROJ-S342','access_request','Medium','[ACCESS] jmartin - Access request for GitHub','jmartin needs GitHub access.','resolved','jmartin', NOW() - INTERVAL '12 days' + INTERVAL '9 hours'),
('PROJ-S343','access_request','Medium','[ACCESS] cdurand - Access request for Salesforce','cdurand needs Salesforce.','resolved','cdurand', NOW() - INTERVAL '9 days' + INTERVAL '9 hours'),
('PROJ-S344','access_request','High','[ACCESS] dwhite - Access request for SharePoint','dwhite needs SharePoint.','resolved','dwhite', NOW() - INTERVAL '6 days' + INTERVAL '9 hours'),
('PROJ-S345','access_request','Medium','[ACCESS] jdoe - Access request for Teams','jdoe needs Teams access.','resolved','jdoe', NOW() - INTERVAL '3 days' + INTERVAL '9 hours'),
('PROJ-S346','access_request','Medium','[ACCESS] mwilson - Access request for CRM','mwilson needs CRM access.','resolved','mwilson', NOW() - INTERVAL '30 days' + INTERVAL '15 hours'),
('PROJ-S347','access_request','Medium','[ACCESS] bjones - Access request for ERP','bjones needs ERP access.','resolved','bjones', NOW() - INTERVAL '26 days' + INTERVAL '15 hours'),
('PROJ-S348','access_request','High','[ACCESS] asmith - Access request for SAP','asmith needs SAP access.','resolved','asmith', NOW() - INTERVAL '22 days' + INTERVAL '15 hours'),
('PROJ-S349','access_request','Medium','[ACCESS] ebrown - Access request for GitHub','ebrown needs GitHub.','resolved','ebrown', NOW() - INTERVAL '18 days' + INTERVAL '15 hours'),
('PROJ-S350','access_request','Medium','[ACCESS] sjohnson - Access request for SharePoint','sjohnson needs SharePoint.','resolved','sjohnson', NOW() - INTERVAL '14 days' + INTERVAL '15 hours'),
('PROJ-S351','access_request','Medium','[ACCESS] jmartin - Access request for VPN','jmartin needs VPN access.','resolved','jmartin', NOW() - INTERVAL '10 days' + INTERVAL '15 hours'),
('PROJ-S352','access_request','High','[ACCESS] cdurand - Access request for ERP','cdurand needs ERP access.','resolved','cdurand', NOW() - INTERVAL '6 days' + INTERVAL '15 hours'),
('PROJ-S353','access_request','Medium','[ACCESS] dwhite - Access request for Salesforce','dwhite needs Salesforce.','resolved','dwhite', NOW() - INTERVAL '2 days' + INTERVAL '15 hours'),
('PROJ-S354','access_request','Medium','[ACCESS] jdoe - Access request for HR Portal','jdoe needs HR portal.','resolved','jdoe', NOW() - INTERVAL '30 days' + INTERVAL '20 hours'),
('PROJ-S355','access_request','Medium','[ACCESS] mwilson - Access request for Teams','mwilson needs Teams.','resolved','mwilson', NOW() - INTERVAL '25 days' + INTERVAL '20 hours'),
('PROJ-S356','access_request','High','[ACCESS] bjones - Access request for GitHub','bjones needs GitHub.','resolved','bjones', NOW() - INTERVAL '20 days' + INTERVAL '20 hours'),
('PROJ-S357','access_request','Medium','[ACCESS] asmith - Access request for Outlook','asmith needs Outlook.','resolved','asmith', NOW() - INTERVAL '15 days' + INTERVAL '20 hours'),
('PROJ-S358','access_request','Medium','[ACCESS] ebrown - Access request for VPN','ebrown needs VPN.','resolved','ebrown', NOW() - INTERVAL '10 days' + INTERVAL '20 hours'),
('PROJ-S359','access_request','Medium','[ACCESS] sjohnson - Access request for CRM','sjohnson needs CRM.','resolved','sjohnson', NOW() - INTERVAL '5 days' + INTERVAL '20 hours'),
('PROJ-S360','access_request','High','[ACCESS] jmartin - Access request for SAP','jmartin needs SAP.','resolved','jmartin', NOW() - INTERVAL '1 day' + INTERVAL '20 hours'),
('PROJ-S361','access_request','Medium','[ACCESS] cdurand - Access request for HR Portal','cdurand needs HR portal.','open','cdurand', NOW() - INTERVAL '21 hours'),
('PROJ-S362','access_request','Medium','[ACCESS] dwhite - Access request for GitHub','dwhite needs GitHub.','open','dwhite', NOW() - INTERVAL '17 hours'),
('PROJ-S363','access_request','High','[ACCESS] jdoe - Access request for SAP ERP','jdoe needs SAP ERP access.','open','jdoe', NOW() - INTERVAL '13 hours'),
('PROJ-S364','access_request','Medium','[ACCESS] mwilson - Access request for Salesforce','mwilson needs Salesforce.','open','mwilson', NOW() - INTERVAL '9 hours'),
('PROJ-S365','access_request','Medium','[ACCESS] bjones - Access request for Teams','bjones needs Teams.','open','bjones', NOW() - INTERVAL '5 hours'),
('PROJ-S366','access_request','Medium','[ACCESS] asmith - Access request for SharePoint','asmith needs SharePoint.','resolved','asmith', NOW() - INTERVAL '29 days' + INTERVAL '5 hours'),
('PROJ-S367','access_request','High','[ACCESS] ebrown - Access request for ERP','ebrown needs ERP.','resolved','ebrown', NOW() - INTERVAL '27 days' + INTERVAL '5 hours'),
('PROJ-S368','access_request','Medium','[ACCESS] sjohnson - Access request for GitHub','sjohnson needs GitHub.','resolved','sjohnson', NOW() - INTERVAL '25 days' + INTERVAL '5 hours'),
('PROJ-S369','access_request','Medium','[ACCESS] jmartin - Access request for CRM','jmartin needs CRM.','resolved','jmartin', NOW() - INTERVAL '23 days' + INTERVAL '5 hours'),
('PROJ-S370','access_request','High','[ACCESS] cdurand - Access request for SAP','cdurand needs SAP.','resolved','cdurand', NOW() - INTERVAL '21 days' + INTERVAL '5 hours'),
('PROJ-S371','access_request','Medium','[ACCESS] dwhite - Access request for VPN','dwhite needs VPN.','resolved','dwhite', NOW() - INTERVAL '19 days' + INTERVAL '5 hours'),
('PROJ-S372','access_request','Medium','[ACCESS] jdoe - Access request for Outlook','jdoe needs Outlook.','resolved','jdoe', NOW() - INTERVAL '17 days' + INTERVAL '5 hours'),
('PROJ-S373','access_request','Medium','[ACCESS] mwilson - Access request for HR Portal','mwilson needs HR portal.','resolved','mwilson', NOW() - INTERVAL '15 days' + INTERVAL '5 hours'),
('PROJ-S374','access_request','High','[ACCESS] bjones - Access request for SharePoint','bjones needs SharePoint.','resolved','bjones', NOW() - INTERVAL '13 days' + INTERVAL '5 hours'),
('PROJ-S375','access_request','Medium','[ACCESS] asmith - Access request for Teams','asmith needs Teams.','resolved','asmith', NOW() - INTERVAL '11 days' + INTERVAL '5 hours'),
('PROJ-S376','access_request','Medium','[ACCESS] ebrown - Access request for CRM','ebrown needs CRM.','resolved','ebrown', NOW() - INTERVAL '9 days' + INTERVAL '5 hours'),
('PROJ-S377','access_request','Medium','[ACCESS] sjohnson - Access request for Outlook','sjohnson needs Outlook.','resolved','sjohnson', NOW() - INTERVAL '7 days' + INTERVAL '5 hours'),
('PROJ-S378','access_request','High','[ACCESS] jmartin - Access request for ERP','jmartin needs ERP.','resolved','jmartin', NOW() - INTERVAL '5 days' + INTERVAL '5 hours'),
('PROJ-S379','access_request','Medium','[ACCESS] cdurand - Access request for GitHub','cdurand needs GitHub.','resolved','cdurand', NOW() - INTERVAL '3 days' + INTERVAL '5 hours'),
('PROJ-S380','access_request','Medium','[ACCESS] dwhite - Access request for SAP','dwhite needs SAP.','resolved','dwhite', NOW() - INTERVAL '1 day' + INTERVAL '5 hours'),
('PROJ-S381','access_request','Medium','[ACCESS] jdoe - Access request for VPN','jdoe needs VPN.','resolved','jdoe', NOW() - INTERVAL '28 days' + INTERVAL '11 hours'),
('PROJ-S382','access_request','High','[ACCESS] mwilson - Access request for SharePoint','mwilson needs SharePoint.','resolved','mwilson', NOW() - INTERVAL '24 days' + INTERVAL '11 hours'),
('PROJ-S383','access_request','Medium','[ACCESS] bjones - Access request for GitHub','bjones needs GitHub.','resolved','bjones', NOW() - INTERVAL '20 days' + INTERVAL '11 hours'),
('PROJ-S384','access_request','Medium','[ACCESS] asmith - Access request for CRM','asmith needs CRM.','resolved','asmith', NOW() - INTERVAL '16 days' + INTERVAL '11 hours'),
('PROJ-S385','access_request','High','[ACCESS] ebrown - Access request for SAP','ebrown needs SAP.','resolved','ebrown', NOW() - INTERVAL '12 days' + INTERVAL '11 hours'),
('PROJ-S386','access_request','Medium','[ACCESS] sjohnson - Access request for Teams','sjohnson needs Teams.','resolved','sjohnson', NOW() - INTERVAL '8 days' + INTERVAL '11 hours'),
('PROJ-S387','access_request','Medium','[ACCESS] jmartin - Access request for VPN','jmartin needs VPN.','resolved','jmartin', NOW() - INTERVAL '4 days' + INTERVAL '11 hours'),
('PROJ-S388','access_request','Medium','[ACCESS] cdurand - Access request for Outlook','cdurand needs Outlook.','resolved','cdurand', NOW() - INTERVAL '30 days' + INTERVAL '16 hours'),
('PROJ-S389','access_request','High','[ACCESS] dwhite - Access request for ERP','dwhite needs ERP.','resolved','dwhite', NOW() - INTERVAL '25 days' + INTERVAL '16 hours'),
('PROJ-S390','access_request','Medium','[ACCESS] jdoe - Access request for Teams','jdoe needs Teams.','resolved','jdoe', NOW() - INTERVAL '20 days' + INTERVAL '16 hours'),
('PROJ-S391','access_request','Medium','[ACCESS] mwilson - Access request for GitHub','mwilson needs GitHub.','resolved','mwilson', NOW() - INTERVAL '15 days' + INTERVAL '16 hours'),
('PROJ-S392','access_request','High','[ACCESS] bjones - Access request for SAP','bjones needs SAP.','resolved','bjones', NOW() - INTERVAL '10 days' + INTERVAL '16 hours'),
('PROJ-S393','access_request','Medium','[ACCESS] asmith - Access request for Salesforce','asmith needs Salesforce.','resolved','asmith', NOW() - INTERVAL '5 days' + INTERVAL '16 hours'),
('PROJ-S394','access_request','Medium','[ACCESS] ebrown - Access request for SharePoint','ebrown needs SharePoint.','resolved','ebrown', NOW() - INTERVAL '30 days' + INTERVAL '21 hours'),
('PROJ-S395','access_request','Medium','[ACCESS] sjohnson - Access request for VPN','sjohnson needs VPN.','resolved','sjohnson', NOW() - INTERVAL '23 days' + INTERVAL '21 hours'),
('PROJ-S396','access_request','High','[ACCESS] jmartin - Access request for CRM','jmartin needs CRM.','resolved','jmartin', NOW() - INTERVAL '16 days' + INTERVAL '21 hours'),
('PROJ-S397','access_request','Medium','[ACCESS] cdurand - Access request for Teams','cdurand needs Teams.','resolved','cdurand', NOW() - INTERVAL '9 days' + INTERVAL '21 hours'),
('PROJ-S398','access_request','Medium','[ACCESS] dwhite - Access request for GitHub','dwhite needs GitHub.','resolved','dwhite', NOW() - INTERVAL '2 days' + INTERVAL '21 hours'),
('PROJ-S399','access_request','High','[ACCESS] jdoe - Access request for SAP','jdoe needs SAP.','open','jdoe', NOW() - INTERVAL '6 hours'),
('PROJ-S400','access_request','Medium','[ACCESS] mwilson - Access request for ERP','mwilson needs ERP.','open','mwilson', NOW() - INTERVAL '1 hour'),

-- ── APP ERRORS (100) ──────────────────────────────────────────────────────────
('PROJ-S401','app_error','High','[APP ERROR] jdoe - Outlook not syncing emails','jdoe Outlook not syncing.','resolved','jdoe', NOW() - INTERVAL '30 days' + INTERVAL '4 hours'),
('PROJ-S402','app_error','High','[APP ERROR] mwilson - Teams blank screen','mwilson Teams blank screen.','resolved','mwilson', NOW() - INTERVAL '29 days' + INTERVAL '4 hours'),
('PROJ-S403','app_error','Medium','[APP ERROR] bjones - SAP login error','bjones SAP login error.','resolved','bjones', NOW() - INTERVAL '28 days' + INTERVAL '4 hours'),
('PROJ-S404','app_error','High','[APP ERROR] asmith - Salesforce not loading','asmith Salesforce not loading.','resolved','asmith', NOW() - INTERVAL '27 days' + INTERVAL '4 hours'),
('PROJ-S405','app_error','Medium','[APP ERROR] ebrown - SharePoint access denied','ebrown SharePoint denied.','resolved','ebrown', NOW() - INTERVAL '26 days' + INTERVAL '4 hours'),
('PROJ-S406','app_error','High','[APP ERROR] sjohnson - Printer offline','sjohnson printer offline.','resolved','sjohnson', NOW() - INTERVAL '25 days' + INTERVAL '4 hours'),
('PROJ-S407','app_error','Critical','[APP ERROR] jmartin - BSOD on workstation','jmartin blue screen.','escalated','jmartin', NOW() - INTERVAL '24 days' + INTERVAL '4 hours'),
('PROJ-S408','app_error','High','[APP ERROR] cdurand - GitHub access denied','cdurand GitHub access denied.','resolved','cdurand', NOW() - INTERVAL '23 days' + INTERVAL '4 hours'),
('PROJ-S409','app_error','Medium','[APP ERROR] dwhite - HR portal not loading','dwhite HR portal error.','resolved','dwhite', NOW() - INTERVAL '22 days' + INTERVAL '4 hours'),
('PROJ-S410','app_error','High','[APP ERROR] jdoe - Teams crash on startup','jdoe Teams crashes.','resolved','jdoe', NOW() - INTERVAL '21 days' + INTERVAL '4 hours'),
('PROJ-S411','app_error','Medium','[APP ERROR] mwilson - Outlook calendar sync','mwilson Outlook calendar.','resolved','mwilson', NOW() - INTERVAL '20 days' + INTERVAL '4 hours'),
('PROJ-S412','app_error','High','[APP ERROR] bjones - SAP transaction error','bjones SAP error.','resolved','bjones', NOW() - INTERVAL '19 days' + INTERVAL '4 hours'),
('PROJ-S413','app_error','Medium','[APP ERROR] asmith - Slow computer','asmith computer slow.','resolved','asmith', NOW() - INTERVAL '18 days' + INTERVAL '4 hours'),
('PROJ-S414','app_error','High','[APP ERROR] ebrown - Windows update failed','ebrown Windows update.','resolved','ebrown', NOW() - INTERVAL '17 days' + INTERVAL '4 hours'),
('PROJ-S415','app_error','Medium','[APP ERROR] sjohnson - MFA not working','sjohnson MFA issue.','resolved','sjohnson', NOW() - INTERVAL '16 days' + INTERVAL '4 hours'),
('PROJ-S416','app_error','Critical','[APP ERROR] jmartin - Server unreachable','jmartin server unreachable.','escalated','jmartin', NOW() - INTERVAL '15 days' + INTERVAL '4 hours'),
('PROJ-S417','app_error','High','[APP ERROR] cdurand - Salesforce data error','cdurand Salesforce error.','resolved','cdurand', NOW() - INTERVAL '14 days' + INTERVAL '4 hours'),
('PROJ-S418','app_error','Medium','[APP ERROR] dwhite - SharePoint permissions','dwhite SharePoint permissions.','resolved','dwhite', NOW() - INTERVAL '13 days' + INTERVAL '4 hours'),
('PROJ-S419','app_error','High','[APP ERROR] jdoe - WiFi not connecting','jdoe WiFi not connecting.','resolved','jdoe', NOW() - INTERVAL '12 days' + INTERVAL '4 hours'),
('PROJ-S420','app_error','High','[APP ERROR] mwilson - Outlook crash','mwilson Outlook crash.','resolved','mwilson', NOW() - INTERVAL '11 days' + INTERVAL '4 hours'),
('PROJ-S421','app_error','Medium','[APP ERROR] bjones - Printer not printing','bjones printer issue.','resolved','bjones', NOW() - INTERVAL '10 days' + INTERVAL '4 hours'),
('PROJ-S422','app_error','High','[APP ERROR] asmith - Teams audio issue','asmith Teams audio.','resolved','asmith', NOW() - INTERVAL '9 days' + INTERVAL '4 hours'),
('PROJ-S423','app_error','Medium','[APP ERROR] ebrown - SAP performance slow','ebrown SAP slow.','resolved','ebrown', NOW() - INTERVAL '8 days' + INTERVAL '4 hours'),
('PROJ-S424','app_error','Critical','[APP ERROR] sjohnson - BSOD after update','sjohnson BSOD.','escalated','sjohnson', NOW() - INTERVAL '7 days' + INTERVAL '4 hours'),
('PROJ-S425','app_error','High','[APP ERROR] jmartin - Salesforce login failed','jmartin Salesforce login.','resolved','jmartin', NOW() - INTERVAL '6 days' + INTERVAL '4 hours'),
('PROJ-S426','app_error','Medium','[APP ERROR] cdurand - GitHub repo not found','cdurand GitHub repo.','resolved','cdurand', NOW() - INTERVAL '5 days' + INTERVAL '4 hours'),
('PROJ-S427','app_error','High','[APP ERROR] dwhite - Network drive disconnected','dwhite network drive.','resolved','dwhite', NOW() - INTERVAL '4 days' + INTERVAL '4 hours'),
('PROJ-S428','app_error','High','[APP ERROR] jdoe - Outlook not opening','jdoe Outlook not opening.','resolved','jdoe', NOW() - INTERVAL '3 days' + INTERVAL '4 hours'),
('PROJ-S429','app_error','Critical','[APP ERROR] mwilson - Server down','mwilson server down.','escalated','mwilson', NOW() - INTERVAL '2 days' + INTERVAL '4 hours'),
('PROJ-S430','app_error','High','[APP ERROR] bjones - Windows update stuck','bjones Windows update stuck.','resolved','bjones', NOW() - INTERVAL '1 day' + INTERVAL '4 hours'),
('PROJ-S431','app_error','High','[APP ERROR] asmith - Teams not working','asmith Teams not working.','open','asmith', NOW() - INTERVAL '23 hours'),
('PROJ-S432','app_error','Medium','[APP ERROR] ebrown - SAP login error','ebrown SAP login.','open','ebrown', NOW() - INTERVAL '19 hours'),
('PROJ-S433','app_error','High','[APP ERROR] sjohnson - Outlook crash','sjohnson Outlook crash.','open','sjohnson', NOW() - INTERVAL '15 hours'),
('PROJ-S434','app_error','Critical','[APP ERROR] jmartin - BSOD','jmartin BSOD.','open','jmartin', NOW() - INTERVAL '11 hours'),
('PROJ-S435','app_error','High','[APP ERROR] cdurand - SharePoint error','cdurand SharePoint error.','open','cdurand', NOW() - INTERVAL '7 hours'),
('PROJ-S436','app_error','High','[APP ERROR] dwhite - Network issue','dwhite network issue.','open','dwhite', NOW() - INTERVAL '3 hours'),
('PROJ-S437','app_error','Medium','[APP ERROR] jdoe - Printer offline','jdoe printer offline.','resolved','jdoe', NOW() - INTERVAL '30 days' + INTERVAL '12 hours'),
('PROJ-S438','app_error','High','[APP ERROR] mwilson - WiFi disconnecting','mwilson WiFi issue.','resolved','mwilson', NOW() - INTERVAL '27 days' + INTERVAL '12 hours'),
('PROJ-S439','app_error','Medium','[APP ERROR] bjones - MFA issue','bjones MFA issue.','resolved','bjones', NOW() - INTERVAL '24 days' + INTERVAL '12 hours'),
('PROJ-S440','app_error','High','[APP ERROR] asmith - Outlook not syncing','asmith Outlook not syncing.','resolved','asmith', NOW() - INTERVAL '21 days' + INTERVAL '12 hours'),
('PROJ-S441','app_error','Critical','[APP ERROR] ebrown - BSOD workstation','ebrown BSOD.','escalated','ebrown', NOW() - INTERVAL '18 days' + INTERVAL '12 hours'),
('PROJ-S442','app_error','High','[APP ERROR] sjohnson - SAP not responding','sjohnson SAP not responding.','resolved','sjohnson', NOW() - INTERVAL '15 days' + INTERVAL '12 hours'),
('PROJ-S443','app_error','Medium','[APP ERROR] jmartin - Teams video issue','jmartin Teams video.','resolved','jmartin', NOW() - INTERVAL '12 days' + INTERVAL '12 hours'),
('PROJ-S444','app_error','High','[APP ERROR] cdurand - Salesforce error','cdurand Salesforce error.','resolved','cdurand', NOW() - INTERVAL '9 days' + INTERVAL '12 hours'),
('PROJ-S445','app_error','Medium','[APP ERROR] dwhite - Computer slow','dwhite computer slow.','resolved','dwhite', NOW() - INTERVAL '6 days' + INTERVAL '12 hours'),
('PROJ-S446','app_error','High','[APP ERROR] jdoe - GitHub error','jdoe GitHub error.','resolved','jdoe', NOW() - INTERVAL '3 days' + INTERVAL '12 hours'),
('PROJ-S447','app_error','High','[APP ERROR] mwilson - SharePoint down','mwilson SharePoint down.','resolved','mwilson', NOW() - INTERVAL '30 days' + INTERVAL '18 hours'),
('PROJ-S448','app_error','Medium','[APP ERROR] bjones - Outlook calendar','bjones Outlook calendar.','resolved','bjones', NOW() - INTERVAL '26 days' + INTERVAL '18 hours'),
('PROJ-S449','app_error','High','[APP ERROR] asmith - SAP error','asmith SAP error.','resolved','asmith', NOW() - INTERVAL '22 days' + INTERVAL '18 hours'),
('PROJ-S450','app_error','Critical','[APP ERROR] ebrown - Network outage','ebrown network outage.','escalated','ebrown', NOW() - INTERVAL '18 days' + INTERVAL '18 hours'),
('PROJ-S451','app_error','High','[APP ERROR] sjohnson - Teams not loading','sjohnson Teams not loading.','resolved','sjohnson', NOW() - INTERVAL '14 days' + INTERVAL '18 hours'),
('PROJ-S452','app_error','Medium','[APP ERROR] jmartin - Printer queue stuck','jmartin printer stuck.','resolved','jmartin', NOW() - INTERVAL '10 days' + INTERVAL '18 hours'),
('PROJ-S453','app_error','High','[APP ERROR] cdurand - Windows BSOD','cdurand BSOD.','resolved','cdurand', NOW() - INTERVAL '6 days' + INTERVAL '18 hours'),
('PROJ-S454','app_error','Medium','[APP ERROR] dwhite - Salesforce slow','dwhite Salesforce slow.','resolved','dwhite', NOW() - INTERVAL '2 days' + INTERVAL '18 hours'),
('PROJ-S455','app_error','High','[APP ERROR] jdoe - Outlook send error','jdoe Outlook send error.','resolved','jdoe', NOW() - INTERVAL '29 days' + INTERVAL '7 hours'),
('PROJ-S456','app_error','High','[APP ERROR] mwilson - SAP client error','mwilson SAP client.','resolved','mwilson', NOW() - INTERVAL '25 days' + INTERVAL '7 hours'),
('PROJ-S457','app_error','Medium','[APP ERROR] bjones - HR portal error','bjones HR portal.','resolved','bjones', NOW() - INTERVAL '21 days' + INTERVAL '7 hours'),
('PROJ-S458','app_error','High','[APP ERROR] asmith - Teams meeting error','asmith Teams meeting.','resolved','asmith', NOW() - INTERVAL '17 days' + INTERVAL '7 hours'),
('PROJ-S459','app_error','Critical','[APP ERROR] ebrown - Server unreachable','ebrown server unreachable.','escalated','ebrown', NOW() - INTERVAL '13 days' + INTERVAL '7 hours'),
('PROJ-S460','app_error','High','[APP ERROR] sjohnson - SharePoint not loading','sjohnson SharePoint.','resolved','sjohnson', NOW() - INTERVAL '9 days' + INTERVAL '7 hours'),
('PROJ-S461','app_error','Medium','[APP ERROR] jmartin - WiFi not connecting','jmartin WiFi.','resolved','jmartin', NOW() - INTERVAL '5 days' + INTERVAL '7 hours'),
('PROJ-S462','app_error','High','[APP ERROR] cdurand - Outlook not opening','cdurand Outlook.','resolved','cdurand', NOW() - INTERVAL '1 day' + INTERVAL '7 hours'),
('PROJ-S463','app_error','Medium','[APP ERROR] dwhite - Printer offline','dwhite printer offline.','open','dwhite', NOW() - INTERVAL '20 hours'),
('PROJ-S464','app_error','High','[APP ERROR] jdoe - SAP transaction failed','jdoe SAP transaction.','open','jdoe', NOW() - INTERVAL '16 hours'),
('PROJ-S465','app_error','High','[APP ERROR] mwilson - Teams crash','mwilson Teams crash.','open','mwilson', NOW() - INTERVAL '12 hours'),
('PROJ-S466','app_error','Critical','[APP ERROR] bjones - BSOD critical','bjones BSOD critical.','open','bjones', NOW() - INTERVAL '8 hours'),
('PROJ-S467','app_error','High','[APP ERROR] asmith - Outlook not loading','asmith Outlook.','open','asmith', NOW() - INTERVAL '5 hours'),
('PROJ-S468','app_error','Medium','[APP ERROR] ebrown - GitHub 403 error','ebrown GitHub 403.','open','ebrown', NOW() - INTERVAL '2 hours'),
('PROJ-S469','app_error','High','[APP ERROR] sjohnson - Network drive error','sjohnson network drive.','resolved','sjohnson', NOW() - INTERVAL '28 days' + INTERVAL '16 hours'),
('PROJ-S470','app_error','High','[APP ERROR] jmartin - SAP performance','jmartin SAP slow.','resolved','jmartin', NOW() - INTERVAL '23 days' + INTERVAL '16 hours'),
('PROJ-S471','app_error','Medium','[APP ERROR] cdurand - MFA not working','cdurand MFA.','resolved','cdurand', NOW() - INTERVAL '18 days' + INTERVAL '16 hours'),
('PROJ-S472','app_error','High','[APP ERROR] dwhite - Outlook calendar sync','dwhite Outlook calendar.','resolved','dwhite', NOW() - INTERVAL '13 days' + INTERVAL '16 hours'),
('PROJ-S473','app_error','Critical','[APP ERROR] jdoe - Full workstation failure','jdoe workstation failure.','escalated','jdoe', NOW() - INTERVAL '8 days' + INTERVAL '16 hours'),
('PROJ-S474','app_error','High','[APP ERROR] mwilson - Salesforce login','mwilson Salesforce login.','resolved','mwilson', NOW() - INTERVAL '3 days' + INTERVAL '16 hours'),
('PROJ-S475','app_error','Medium','[APP ERROR] bjones - Computer slow performance','bjones slow.','resolved','bjones', NOW() - INTERVAL '30 days' + INTERVAL '23 hours'),
('PROJ-S476','app_error','High','[APP ERROR] asmith - GitHub access error','asmith GitHub.','resolved','asmith', NOW() - INTERVAL '24 days' + INTERVAL '23 hours'),
('PROJ-S477','app_error','High','[APP ERROR] ebrown - Teams video freeze','ebrown Teams video.','resolved','ebrown', NOW() - INTERVAL '18 days' + INTERVAL '23 hours'),
('PROJ-S478','app_error','Medium','[APP ERROR] sjohnson - Windows slow boot','sjohnson slow boot.','resolved','sjohnson', NOW() - INTERVAL '12 days' + INTERVAL '23 hours'),
('PROJ-S479','app_error','High','[APP ERROR] jmartin - Outlook not responding','jmartin Outlook.','resolved','jmartin', NOW() - INTERVAL '6 days' + INTERVAL '23 hours'),
('PROJ-S480','app_error','Critical','[APP ERROR] cdurand - Critical system error','cdurand critical error.','escalated','cdurand', NOW() - INTERVAL '29 days' + INTERVAL '1 hour'),
('PROJ-S481','app_error','High','[APP ERROR] dwhite - SAP not loading','dwhite SAP.','resolved','dwhite', NOW() - INTERVAL '22 days' + INTERVAL '1 hour'),
('PROJ-S482','app_error','Medium','[APP ERROR] jdoe - Printer driver error','jdoe printer driver.','resolved','jdoe', NOW() - INTERVAL '15 days' + INTERVAL '1 hour'),
('PROJ-S483','app_error','High','[APP ERROR] mwilson - Network unreachable','mwilson network.','resolved','mwilson', NOW() - INTERVAL '8 days' + INTERVAL '1 hour'),
('PROJ-S484','app_error','High','[APP ERROR] bjones - Salesforce sync error','bjones Salesforce sync.','resolved','bjones', NOW() - INTERVAL '1 day' + INTERVAL '1 hour'),
('PROJ-S485','app_error','Medium','[APP ERROR] asmith - HR portal timeout','asmith HR portal.','open','asmith', NOW() - INTERVAL '22 hours'),
('PROJ-S486','app_error','High','[APP ERROR] ebrown - Teams not starting','ebrown Teams.','open','ebrown', NOW() - INTERVAL '17 hours'),
('PROJ-S487','app_error','High','[APP ERROR] sjohnson - Outlook password prompt','sjohnson Outlook.','open','sjohnson', NOW() - INTERVAL '13 hours'),
('PROJ-S488','app_error','Critical','[APP ERROR] jmartin - Workstation crash','jmartin crash.','open','jmartin', NOW() - INTERVAL '9 hours'),
('PROJ-S489','app_error','High','[APP ERROR] cdurand - SAP not responding','cdurand SAP.','open','cdurand', NOW() - INTERVAL '5 hours'),
('PROJ-S490','app_error','Medium','[APP ERROR] dwhite - WiFi dropping','dwhite WiFi.','open','dwhite', NOW() - INTERVAL '2 hours'),
('PROJ-S491','app_error','High','[APP ERROR] jdoe - GitHub pipeline error','jdoe GitHub pipeline.','resolved','jdoe', NOW() - INTERVAL '27 days' + INTERVAL '3 hours'),
('PROJ-S492','app_error','Medium','[APP ERROR] mwilson - Slow network performance','mwilson network slow.','resolved','mwilson', NOW() - INTERVAL '20 days' + INTERVAL '3 hours'),
('PROJ-S493','app_error','High','[APP ERROR] bjones - Teams meeting crash','bjones Teams meeting.','resolved','bjones', NOW() - INTERVAL '13 days' + INTERVAL '3 hours'),
('PROJ-S494','app_error','High','[APP ERROR] asmith - SharePoint upload error','asmith SharePoint upload.','resolved','asmith', NOW() - INTERVAL '6 days' + INTERVAL '3 hours'),
('PROJ-S495','app_error','Critical','[APP ERROR] ebrown - ERP system down','ebrown ERP down.','escalated','ebrown', NOW() - INTERVAL '30 days' + INTERVAL '19 hours'),
('PROJ-S496','app_error','High','[APP ERROR] sjohnson - Outlook rules error','sjohnson Outlook rules.','resolved','sjohnson', NOW() - INTERVAL '21 days' + INTERVAL '19 hours'),
('PROJ-S497','app_error','Medium','[APP ERROR] jmartin - Printer paper jam','jmartin printer jam.','resolved','jmartin', NOW() - INTERVAL '12 days' + INTERVAL '19 hours'),
('PROJ-S498','app_error','High','[APP ERROR] cdurand - GitHub CI error','cdurand GitHub CI.','resolved','cdurand', NOW() - INTERVAL '4 days' + INTERVAL '19 hours'),
('PROJ-S499','app_error','High','[APP ERROR] dwhite - Teams screen share error','dwhite Teams screen share.','open','dwhite', NOW() - INTERVAL '10 hours'),
('PROJ-S500','app_error','Critical','[APP ERROR] jdoe - Full system failure','jdoe system failure.','open','jdoe', NOW() - INTERVAL '30 minutes');

SELECT 'Database initialization complete — ' || COUNT(*) || ' tickets loaded' AS result FROM tickets;
