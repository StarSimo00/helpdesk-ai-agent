import React, { useState, useRef, useCallback, useEffect } from 'react'
import { useNavigate, Link } from 'react-router-dom'

const WEBHOOK = import.meta.env.VITE_N8N_WEBHOOK ||
  `${window.location.origin}/webhook/3d36c40f-87bd-4a47-b3cc-fbba6576dd38`

function greeting(user) {
  return user.isAnonymous
    ? `Hello! I'm **HelpBot**, your IT support assistant.\n\nHow can I help you today?`
    : `Hello **${user.displayName}**! I'm **HelpBot**.\n\nI can help you with:\n- 🔓 Unlocking accounts\n- 🔑 Password resets\n- 🛠 Technical issues (VPN, Outlook, Teams)\n- 🎫 Support tickets\n\nWhat can I do for you?`
}

// Generate a new session ID
function newSessionId(username) {
  const ts  = Date.now().toString(36)
  const rnd = Math.random().toString(36).slice(2, 7)
  return `${username}-${ts}-${rnd}`
}

export default function ChatPage({ user, onLogout }) {
  const navigate = useNavigate()

  // Session management
  const [activeSessionId, setActiveSessionId] = useState(() => {
    if (user.isAnonymous) return newSessionId('guest')
    return newSessionId(user.username)
  })
  const [ticketDbId, setTicketDbId] = useState(null)

  const [msgs, setMsgs] = useState(() => [{ id: 1, role: 'bot', text: greeting(user) }])
  const [input, setInput] = useState('')
  const [loading, setLoading] = useState(false)
  const [sidebar, setSidebar] = useState(false)
  const [conversations, setConversations] = useState([])
  const [loadingConvo, setLoadingConvo] = useState(false)

  // Load past conversations for logged-in users
  useEffect(() => {
    if (!user.isAnonymous && user.username) {
      fetch(`${window.location.origin}/api/conversations/${user.username}`)
        .then(r => r.json())
        .then(d => { if (d.success) setConversations(d.data.conversations) })
        .catch(() => {})
    }
  }, [user])

  // Load a past conversation and resume it
  async function loadConversation(sid) {
    setLoadingConvo(true)
    try {
      const res = await fetch(`${window.location.origin}/api/conversation/${encodeURIComponent(sid)}`)
      const data = await res.json()
      if (data.success && data.data.messages.length > 0) {
        const loaded = data.data.messages.map((m, i) => ({
          id: i + 1,
          role: m.role === 'ai' ? 'bot' : 'user',
          text: m.content,
          ts: m.ts
        }))
        setMsgs(loaded)
        setActiveSessionId(sid)  // resume this session
        setSidebar(false)
      }
    } catch {}
    setLoadingConvo(false)
  }

  // New conversation
  function startNewConversation() {
    setMsgs([{ id: 1, role: 'bot', text: greeting(user) }])
    setActiveSessionId(newSessionId(user.isAnonymous ? 'guest' : user.username))
    setTicketDbId(null)
    setSidebar(false)
    // Refresh conversation list
    if (!user.isAnonymous && user.username) {
      setTimeout(() => {
        fetch(`${window.location.origin}/api/conversations/${user.username}`)
          .then(r => r.json())
          .then(d => { if (d.success) setConversations(d.data.conversations) })
          .catch(() => {})
      }, 2000)
    }
  }
  const bottomRef = useRef(null)
  const taRef = useRef(null)

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: 'smooth' })
  }, [msgs, loading])

  useEffect(() => {
    const ta = taRef.current
    if (!ta) return
    ta.style.height = 'auto'
    ta.style.height = Math.min(ta.scrollHeight, 140) + 'px'
  }, [input])

  const send = useCallback(async (text) => {
    const t = text.trim()
    if (!t || loading) return
    const id = Date.now()
    setMsgs(p => [...p, { id, role: 'user', text: t }])
    setInput('')
    setLoading(true)

    // Auto-create DB ticket on first message for authenticated users
    let currentTicketDbId = ticketDbId
    if (!user.isAnonymous && !ticketDbId && msgs.length === 1) {
      try {
        const tr = await fetch(`${window.location.origin}/api/tickets`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            username: user.username,
            department: user.department || '',
            issue_type: 'Pending',
            priority: 'medium',
            summary: t.slice(0, 200),
            session_id: activeSessionId
          })
        })
        const td = await tr.json()
        if (td.success) {
          currentTicketDbId = td.data.ticket_db_id
          setTicketDbId(currentTicketDbId)
        }
      } catch {}
    }

    try {
      const res = await fetch(WEBHOOK, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          message: t,
          sessionId: activeSessionId,
          ticket_db_id: currentTicketDbId,
          user: { username: user.username, displayName: user.displayName, department: user.department, isAnonymous: user.isAnonymous },
        }),
      })
      const raw = await res.text()
      let bot = raw
      try {
        const d = JSON.parse(raw)
        bot = Array.isArray(d)
          ? (d[0]?.output || d[0]?.text || d[0]?.message || raw)
          : (d.output || d.text || d.message || d.response || raw)
      } catch {}
      setMsgs(p => [...p, { id: Date.now(), role: 'bot', text: bot }])
    } catch {
      setMsgs(p => [...p, { id: Date.now(), role: 'bot', text: '⚠️ Could not reach HelpBot. Check that n8n is running and the workflow is Published.', err: true }])
    } finally {
      setLoading(false)
      setTimeout(() => taRef.current?.focus(), 50)
    }
  }, [loading, user, activeSessionId, ticketDbId, msgs.length])

  function onKey(e) {
    if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); send(input) }
  }

  function logout() { onLogout(); navigate('/login') }

  const quick = [
    { icon: '🔓', label: 'My account is locked' },
    { icon: '🔑', label: 'I forgot my password' },
    { icon: '🌐', label: 'VPN not connecting' },
    { icon: '📧', label: 'Outlook is not working' },
  ]

  const initials = user.isAnonymous ? '?' : user.displayName.charAt(0).toUpperCase()

  return (
    <div style={s.shell}>
      {/* Sidebar overlay */}
      {sidebar && <div style={s.overlay} onClick={() => setSidebar(false)} />}

      {/* Sidebar */}
      <aside style={{ ...s.sidebar, transform: sidebar ? 'translateX(0)' : 'translateX(-100%)' }}>
        <div style={s.sbTop}>
          <div style={s.sbLogo}><Hex size={20}/><span style={s.sbLogoTxt}>HelpBot</span></div>
          <button style={s.iconBtn} onClick={() => setSidebar(false)}>✕</button>
        </div>

        <div style={s.sbCard}>
          <div style={s.avLg}>{initials}</div>
          <div style={{minWidth:0}}>
            <div style={s.sbName}>{user.displayName}</div>
            {user.department && <div style={s.sbDept}>{user.department}</div>}
            {user.title && <div style={s.sbTitle}>{user.title}</div>}
            {user.email && <div style={s.sbEmail}>{user.email}</div>}
          </div>
        </div>

        <div style={s.sbSect}>
          <div style={s.sbLabel}>Session ID</div>
          <div style={s.sbSession}>{activeSessionId.slice(-12)}</div>
        </div>

        {!user.isAnonymous && (
          <div style={s.sbSect}>
            <button style={s.newConvoBtn} onClick={startNewConversation}>
              ✏️ New Conversation
            </button>
          </div>
        )}

        {!user.isAnonymous && conversations.length > 0 && (
          <div style={{...s.sbSect, flex:1, overflowY:'auto'}}>
            <div style={s.sbLabel}>Recent Conversations</div>
            {loadingConvo && <div style={{color:'var(--text-3)',fontSize:12,padding:'8px 0'}}>Loading...</div>}
            {conversations.map((c, i) => (
              <div key={i} style={s.histItem} onClick={() => loadConversation(c.session_id)}>
                <div style={s.histTitle}>{new Date(c.last_message_at).toLocaleDateString('en-GB', {day:'2-digit',month:'short',year:'numeric'})}</div>
                <div style={s.histSub}>
                  <span style={{fontFamily:'var(--font-mono)',fontSize:10}}>{c.message_count} messages</span>
                </div>
                {c.preview && <div style={s.histSummary}>{c.preview}</div>}
              </div>
            ))}
          </div>
        )}

        <div style={s.sbFoot}>
          {!user.isAnonymous && user.department === 'IT' && (
            <button style={s.dashBtn} onClick={() => navigate('/dashboard')}>
              <DashIcon /> Dashboard
            </button>
          )}
          <button style={s.logoutBtn} onClick={logout}>
            <LogoutIcon /> {user.isAnonymous ? 'Exit' : 'Sign Out'}
          </button>
        </div>
      </aside>

      {/* Main — 3-row grid: header / messages / input */}
      <div style={s.main}>

        {/* Row 1: Header */}
        <header style={s.header}>
          <button style={s.iconBtn} onClick={() => setSidebar(v => !v)}><MenuIcon /></button>
          <div style={s.hCenter}>
            <div style={s.dot} />
            <span style={s.hTitle}>HelpBot</span>
            <span style={s.hTag}>IT Support</span>
          </div>
          <div style={s.hUser}>
            <div style={s.avSm}>{initials}</div>
            <div style={{lineHeight:1.3}}>
              <div style={s.hName}>{user.displayName}</div>
              {user.department && <div style={s.hDept}>{user.department}</div>}
            </div>
          </div>
        </header>

        {/* Row 2: Messages — scrollable */}
        <div style={s.msgs}>
          {msgs.map(m => <Bubble key={m.id} msg={m} user={user} />)}

          {msgs.length === 1 && (
            <div style={s.chips}>
              {quick.map((q, i) => (
                <button key={i} style={s.chip} onClick={() => send(q.label)}>
                  {q.icon} {q.label}
                </button>
              ))}
            </div>
          )}

          {loading && <Typing />}
          <div ref={bottomRef} />
        </div>

        {/* Row 3: Input — always at bottom */}
        <div style={s.inputWrap}>
          <div style={s.inputBox}>
            <textarea
              ref={taRef}
              style={s.ta}
              value={input}
              onChange={e => setInput(e.target.value)}
              onKeyDown={onKey}
              placeholder="Describe your issue…"
              rows={1}
              disabled={loading}
            />
            <button
              style={{ ...s.sendBtn, opacity: input.trim() && !loading ? 1 : 0.3 }}
              onClick={() => send(input)}
              disabled={!input.trim() || loading}
            >
              <SendIcon />
            </button>
          </div>
          <div style={s.hint}>
            <kbd style={s.kbd}>Enter</kbd> to send · <kbd style={s.kbd}>Shift+Enter</kbd> for newline
          </div>
        </div>

      </div>
    </div>
  )
}

// ── Bubble ────────────────────────────────────────────────────

const s = {
  shell: {
    display: 'flex',
    width: '100vw',
    height: '100dvh',
    overflow: 'hidden',
    background: 'var(--bg-void)',
    position: 'relative',
  },
  overlay: { position:'fixed', inset:0, background:'rgba(0,0,0,0.55)', zIndex:90, backdropFilter:'blur(3px)' },

  // Sidebar
  newConvoBtn: { width:'100%', background:'rgba(139,92,246,0.12)', border:'1px solid var(--border-2)', borderRadius:8, color:'var(--purple-bright)', fontSize:13, padding:'10px 14px', cursor:'pointer', fontFamily:'var(--font-ui)', textAlign:'left', fontWeight:600 },
  histItem: { background:'rgba(139,92,246,0.06)', border:'1px solid var(--border-1)', borderRadius:8, padding:'8px 10px', marginBottom:6, cursor:'default' },
  histTitle: { fontSize:12, fontWeight:600, color:'var(--text-1)', marginBottom:2 },
  histSub: { fontSize:10, color:'var(--text-3)', fontFamily:'var(--font-mono)', marginBottom:3, display:'flex', gap:6, alignItems:'center' },
  histTicket: { background:'rgba(139,92,246,0.15)', color:'var(--purple-bright)', borderRadius:4, padding:'1px 5px', fontSize:10 },
  histSummary: { fontSize:10, color:'var(--text-3)', lineHeight:1.4 },
  sidebar: {
    position: 'fixed', left:0, top:0, bottom:0, width:272,
    background: 'rgba(9,7,20,0.97)', borderRight:'1px solid var(--border-1)',
    backdropFilter: 'blur(20px)', zIndex:100,
    display: 'flex', flexDirection:'column',
    transition: 'transform .28s cubic-bezier(.4,0,.2,1)',
  },
  sbTop: { padding:'16px 18px', borderBottom:'1px solid var(--border-1)', display:'flex', alignItems:'center', justifyContent:'space-between' },
  sbLogo: { display:'flex', alignItems:'center', gap:10 },
  sbLogoTxt: { fontSize:17, fontWeight:800, background:'linear-gradient(135deg,#c4b5fd,#8b5cf6)', WebkitBackgroundClip:'text', WebkitTextFillColor:'transparent' },
  sbCard: { margin:14, padding:14, background:'var(--bg-surface)', border:'1px solid var(--border-1)', borderRadius:12, display:'flex', gap:12, alignItems:'flex-start' },
  avLg: { width:40, height:40, borderRadius:'50%', flexShrink:0, background:'linear-gradient(135deg,#7c3aed,#4c1d95)', border:'2px solid var(--purple-vivid)', display:'flex', alignItems:'center', justifyContent:'center', fontSize:16, fontWeight:700, color:'#fff' },
  sbName: { fontSize:13, fontWeight:700, color:'var(--text-1)' },
  sbDept: { fontSize:11, color:'var(--purple-bright)', marginTop:2, fontFamily:'var(--font-mono)' },
  sbTitle: { fontSize:10, color:'var(--text-3)', marginTop:1, fontFamily:'var(--font-mono)' },
  sbEmail: { fontSize:10, color:'var(--text-3)', marginTop:1, fontFamily:'var(--font-mono)' },
  sbSect: { padding:'0 14px 14px' },
  sbLabel: { fontSize:9, color:'var(--text-3)', textTransform:'uppercase', letterSpacing:'2px', fontFamily:'var(--font-mono)', marginBottom:8, paddingTop:6 },
  sbSession: { fontSize:9, color:'var(--text-3)', fontFamily:'var(--font-mono)', wordBreak:'break-all', background:'var(--bg-deep)', padding:'7px 10px', borderRadius:6, border:'1px solid var(--border-1)' },
  sbQuick: { display:'flex', alignItems:'center', gap:8, width:'100%', padding:'8px 10px', background:'transparent', border:'1px solid var(--border-1)', borderRadius:6, color:'var(--text-2)', fontSize:12, cursor:'pointer', marginBottom:5, fontFamily:'var(--font-ui)', textAlign:'left' },
  sbFoot: { marginTop:'auto', padding:14, borderTop:'1px solid var(--border-1)' },
  dashBtn: { display:'flex', alignItems:'center', gap:8, width:'100%', padding:'10px 14px', background:'rgba(139,92,246,0.08)', border:'1px solid var(--border-2)', borderRadius:8, color:'var(--purple-bright)', fontSize:13, cursor:'pointer', fontFamily:'var(--font-ui)', marginBottom:6 },
  logoutBtn: { display:'flex', alignItems:'center', gap:8, width:'100%', padding:'10px 14px', background:'transparent', border:'1px solid rgba(248,113,113,0.2)', borderRadius:8, color:'var(--red)', fontSize:13, cursor:'pointer', fontFamily:'var(--font-ui)' },

  // Main — CSS grid for perfect layout
  main: {
    flex: 1,
    display: 'grid',
    gridTemplateRows: '60px 1fr auto',
    height: '100dvh',
    overflow: 'hidden',
    position: 'relative',
    zIndex: 1,
  },

  // Header — row 1
  header: {
    display: 'flex', alignItems: 'center', padding: '0 18px', gap: 12,
    background: 'rgba(9,7,20,0.92)', borderBottom: '1px solid var(--border-1)',
    backdropFilter: 'blur(20px)',
  },
  iconBtn: { background:'none', border:'none', color:'var(--text-2)', cursor:'pointer', padding:7, borderRadius:8, display:'flex', alignItems:'center' },
  hCenter: { flex:1, display:'flex', alignItems:'center', gap:8 },
  dot: { width:8, height:8, borderRadius:'50%', background:'var(--green)', boxShadow:'0 0 8px rgba(74,222,128,.7)' },
  hTitle: { fontSize:15, fontWeight:700, color:'var(--text-1)' },
  hTag: { fontSize:10, color:'var(--text-3)', fontFamily:'var(--font-mono)', background:'var(--bg-surface)', padding:'2px 8px', borderRadius:99, border:'1px solid var(--border-1)' },
  hUser: { display:'flex', alignItems:'center', gap:9 },
  avSm: { width:30, height:30, borderRadius:'50%', background:'linear-gradient(135deg,#7c3aed,#4c1d95)', border:'1.5px solid var(--purple-mid)', display:'flex', alignItems:'center', justifyContent:'center', fontSize:12, fontWeight:700, color:'#fff', flexShrink:0 },
  hName: { fontSize:12, fontWeight:600, color:'var(--text-1)' },
  hDept: { fontSize:10, color:'var(--purple-bright)', fontFamily:'var(--font-mono)' },

  // Messages — row 2, scrollable
  msgs: {
    overflowY: 'auto',
    padding: '16px 14px',
    display: 'flex',
    flexDirection: 'column',
    gap: 12,
  },

  row: { display:'flex', alignItems:'flex-end', gap:7 },
  botAv: { width:28, height:28, flexShrink:0, display:'flex', alignItems:'center', justifyContent:'center', background:'var(--bg-surface)', border:'1px solid var(--border-2)', borderRadius:'50%', marginBottom:2 },
  userAv: { width:28, height:28, flexShrink:0, display:'flex', alignItems:'center', justifyContent:'center', background:'linear-gradient(135deg,#7c3aed,#4c1d95)', border:'1.5px solid var(--purple-mid)', borderRadius:'50%', fontSize:11, fontWeight:700, color:'#fff', marginBottom:2 },
  bubble: { maxWidth:'min(540px,74%)', padding:'10px 14px', borderRadius:16, lineHeight:1.7, fontSize:14 },
  bBubble: { background:'var(--bg-elevated)', border:'1px solid var(--border-1)', color:'var(--text-1)', borderBottomLeftRadius:4 },
  uBubble: { background:'linear-gradient(135deg,#6d28d9,#5b21b6)', color:'#fff', borderBottomRightRadius:4, boxShadow:'0 3px 14px rgba(109,40,217,.35)' },
  errBubble: { background:'rgba(248,113,113,0.07)', border:'1px solid rgba(248,113,113,0.2)' },
  time: { fontSize:10, color:'rgba(255,255,255,0.2)', fontFamily:'var(--font-mono)', marginTop:4 },
  codeWrap: { background:'var(--bg-deep)', border:'1px solid var(--border-2)', borderRadius:6, padding:'8px 12px', margin:'6px 0' },
  code: { fontFamily:'var(--font-mono)', fontSize:12, color:'var(--purple-glow)', whiteSpace:'pre-wrap', wordBreak:'break-all' },
  chips: { display:'flex', flexWrap:'wrap', gap:8, paddingTop:4 },
  chip: { padding:'8px 14px', background:'var(--bg-elevated)', border:'1px solid var(--border-2)', borderRadius:99, color:'var(--text-2)', fontSize:12, cursor:'pointer', fontFamily:'var(--font-ui)' },

  // Input — row 3, always pinned
  inputWrap: {
    padding: '10px 14px 14px',
    background: 'rgba(9,7,20,0.94)',
    borderTop: '1px solid var(--border-1)',
    backdropFilter: 'blur(20px)',
  },
  inputBox: { display:'flex', alignItems:'flex-end', gap:8, background:'var(--bg-surface)', border:'1px solid var(--border-2)', borderRadius:14, padding:'4px 4px 4px 14px' },
  ta: { flex:1, background:'none', border:'none', outline:'none', color:'var(--text-1)', fontSize:14, fontFamily:'var(--font-ui)', resize:'none', padding:'9px 0', lineHeight:1.55, maxHeight:140, overflowY:'auto' },
  sendBtn: { width:36, height:36, flexShrink:0, background:'linear-gradient(135deg,#7c3aed,#5b21b6)', border:'none', borderRadius:10, color:'#fff', cursor:'pointer', display:'flex', alignItems:'center', justifyContent:'center', transition:'opacity .15s', boxShadow:'0 2px 10px rgba(109,40,217,.4)' },
  hint: { fontSize:10, color:'var(--text-4)', fontFamily:'var(--font-mono)', textAlign:'center', marginTop:6 },
  kbd: { background:'var(--bg-elevated)', border:'1px solid var(--border-1)', borderRadius:3, padding:'1px 5px', fontSize:9 },
}

function Bubble({ msg, user }) {
  const isUser = msg.role === 'user'

  function render(text) {
    return text.split(/(```[\s\S]*?```)/g).map((seg, i) => {
      if (seg.startsWith('```')) {
        const code = seg.replace(/^```\w*\n?/, '').replace(/\n?```$/, '')
        return <div key={i} style={s.codeWrap}><pre style={s.code}>{code}</pre></div>
      }
      return seg.split('\n').map((line, j, arr) => (
        <span key={`${i}-${j}`}>
          {line.split(/(\*\*[^*]+\*\*)/g).map((p, k) =>
            p.startsWith('**') && p.endsWith('**')
              ? <strong key={k}>{p.slice(2, -2)}</strong> : p
          )}
          {j < arr.length - 1 && <br />}
        </span>
      ))
    })
  }

  return (
    <div style={{ ...s.row, justifyContent: isUser ? 'flex-end' : 'flex-start' }}>
      {!isUser && <div style={s.botAv}><Hex size={15} /></div>}
      <div style={{ ...s.bubble, ...(isUser ? s.uBubble : s.bBubble), ...(msg.err ? s.errBubble : {}) }}>
        {render(msg.text)}
        <div style={{ ...s.time, textAlign: isUser ? 'right' : 'left' }}>
          {new Date(msg.id).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
        </div>
      </div>
      {isUser && (
        <div style={s.userAv}>
          {user.isAnonymous ? '?' : user.displayName.charAt(0).toUpperCase()}
        </div>
      )}
    </div>
  )
}

function Typing() {
  return (
    <div style={{ ...s.row, justifyContent: 'flex-start' }}>
      <div style={s.botAv}><Hex size={15} /></div>
      <div style={{ ...s.bubble, ...s.bBubble, padding: '14px 16px' }}>
        <div style={{ display:'flex', gap:5, alignItems:'center' }}>
          {[0,150,300].map(d => <span key={d} style={{ width:7, height:7, borderRadius:'50%', background:'var(--purple-mid)', display:'inline-block', animation:`blink 1.2s ${d}ms ease-in-out infinite` }} />)}
        </div>
      </div>
    </div>
  )
}

// ── Icons ─────────────────────────────────────────────────────
const Hex = ({ size = 28 }) => (
  <svg width={size} height={size} viewBox="0 0 36 36" fill="none">
    <polygon points="18,2 32,10 32,26 18,34 4,26 4,10" fill="rgba(139,92,246,0.15)" stroke="#8b5cf6" strokeWidth="1.5"/>
    <circle cx="18" cy="18" r="7" fill="#8b5cf6"/>
    <circle cx="18" cy="18" r="3" fill="#f0ecff"/>
  </svg>
)
const MenuIcon = () => <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><line x1="3" y1="6" x2="21" y2="6"/><line x1="3" y1="12" x2="21" y2="12"/><line x1="3" y1="18" x2="21" y2="18"/></svg>
const SendIcon = () => <svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><line x1="22" y1="2" x2="11" y2="13"/><polygon points="22 2 15 22 11 13 2 9 22 2"/></svg>
const DashIcon = () => <svg width='14' height='14' viewBox='0 0 24 24' fill='none' stroke='currentColor' strokeWidth='2'><rect x='3' y='3' width='7' height='7'/><rect x='14' y='3' width='7' height='7'/><rect x='3' y='14' width='7' height='7'/><rect x='14' y='14' width='7' height='7'/></svg>
const LogoutIcon = () => <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"/><polyline points="16 17 21 12 16 7"/><line x1="21" y1="12" x2="9" y2="12"/></svg>

// ── Styles ────────────────────────────────────────────────────
