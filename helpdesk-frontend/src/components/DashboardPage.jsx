import React, { useState, useEffect } from 'react'
import { useNavigate } from 'react-router-dom'

const LDAP_API = `${window.location.origin}/api`

const PRIORITY_COLORS = { critical:'#ef4444', high:'#f97316', medium:'#eab308', low:'#22c55e' }
const STATUS_COLORS = {
  open:'#f97316', in_progress:'#3b82f6', resolved:'#22c55e',
  success:'#22c55e', failure:'#ef4444', pending:'#eab308',
  escalated:'#ef4444', warning:'#f97316', critical:'#ef4444', info:'#60a5fa'
}
const ACTION_COLORS = {
  UNLOCK_ACCOUNT:'#8b5cf6', RESET_PASSWORD:'#22d3ee', VPN_DIAGNOSTIC:'#f59e0b',
  ACCESS_REQUEST:'#4ade80', ACCESS_PROVISION:'#34d399', SEARCH_KB:'#60a5fa',
  LOGIN:'#a78bfa', SEND_OTP:'#f472b6', VERIFY_OTP:'#fb923c',
  ESCALATION:'#ef4444', RESOLVE_APP_ERROR:'#e879f9', AGENT_ACTION:'#6b7280',
}

// ── Styles ────────────────────────────────────────────────────────────────────
const shell   = { display:'flex', width:'100vw', height:'100dvh', overflow:'hidden', background:'var(--bg-void)', fontFamily:'var(--font-ui)' }
const sidebar = { width:220, flexShrink:0, background:'rgba(9,7,20,0.98)', borderRight:'1px solid var(--border-1)', display:'flex', flexDirection:'column' }
const sbHeader = { padding:'20px 16px 16px', borderBottom:'1px solid var(--border-1)' }
const sbLogo = { display:'flex', alignItems:'center', gap:10 }
const logoMark = { width:32, height:32, borderRadius:8, background:'linear-gradient(135deg,#7c3aed,#4c1d95)', display:'flex', alignItems:'center', justifyContent:'center', fontSize:16, fontWeight:900, color:'#fff', flexShrink:0 }
const logoTitle = { fontSize:15, fontWeight:800, color:'var(--text-1)' }
const logoSub = { fontSize:9, color:'var(--text-3)', textTransform:'uppercase', letterSpacing:'1px' }
const nav = { flex:1, padding:'12px 10px', display:'flex', flexDirection:'column', gap:2, overflowY:'auto' }
const navBtn = { display:'flex', alignItems:'center', gap:9, padding:'9px 12px', background:'transparent', border:'none', borderRadius:8, color:'var(--text-2)', fontSize:13, cursor:'pointer', fontFamily:'var(--font-ui)', textAlign:'left', width:'100%', position:'relative' }
const navActive = { background:'rgba(139,92,246,0.12)', color:'var(--purple-bright)', border:'1px solid var(--border-2)' }
const navIcon = { fontSize:14, width:18, textAlign:'center' }
const badge = { marginLeft:'auto', background:'#ef4444', color:'#fff', borderRadius:99, fontSize:10, fontWeight:700, padding:'1px 6px', minWidth:18, textAlign:'center' }
const sbFooter = { padding:'12px 10px', borderTop:'1px solid var(--border-1)', display:'flex', flexDirection:'column', gap:4 }
const sbBtn = { padding:'8px 12px', background:'transparent', border:'none', borderRadius:6, color:'var(--text-2)', fontSize:12, cursor:'pointer', fontFamily:'var(--font-ui)', textAlign:'left' }
const mainWrap = { flex:1, display:'grid', gridTemplateRows:'64px 1fr', overflow:'hidden' }
const header = { display:'flex', alignItems:'center', justifyContent:'space-between', padding:'0 24px', background:'rgba(9,7,20,0.92)', borderBottom:'1px solid var(--border-1)', backdropFilter:'blur(20px)' }
const pageTitle = { fontSize:20, fontWeight:800, color:'var(--text-1)', margin:0 }
const pageSub = { fontSize:11, color:'var(--text-3)', fontFamily:'monospace', margin:'2px 0 0' }
const hRight = { display:'flex', alignItems:'center', gap:12 }
const refreshBtn = { background:'var(--bg-elevated)', border:'1px solid var(--border-2)', borderRadius:8, color:'var(--text-2)', fontSize:12, padding:'7px 14px', cursor:'pointer' }
const userChip = { display:'flex', alignItems:'center', gap:8 }
const avatar = { width:30, height:30, borderRadius:'50%', background:'linear-gradient(135deg,#7c3aed,#4c1d95)', border:'1.5px solid var(--purple-mid)', display:'flex', alignItems:'center', justifyContent:'center', fontSize:12, fontWeight:700, color:'#fff' }
const userName = { fontSize:12, fontWeight:600, color:'var(--text-1)' }
const userDept = { fontSize:10, color:'var(--purple-bright)', fontFamily:'monospace' }
const content = { overflowY:'auto', padding:'20px 24px' }
const loading = { display:'flex', alignItems:'center', gap:10, color:'var(--text-3)', padding:40, justifyContent:'center' }
const overviewWrap = { display:'flex', flexDirection:'column', gap:18 }
const kpiGrid = { display:'grid', gridTemplateColumns:'repeat(4,1fr)', gap:12 }
const kpiCard = { background:'var(--bg-surface)', border:'1px solid var(--border-1)', borderRadius:12, padding:'16px 18px', display:'flex', flexDirection:'column', gap:6 }
const kpiLabel = { fontSize:10, color:'var(--text-3)', textTransform:'uppercase', letterSpacing:'1px', fontFamily:'monospace' }
const chartsRow = { display:'grid', gridTemplateColumns:'1fr 1fr 1fr', gap:14 }
const chartCard = { background:'var(--bg-surface)', border:'1px solid var(--border-1)', borderRadius:12, padding:'16px 18px' }
const barRow = { display:'flex', alignItems:'center', gap:8, marginBottom:8 }
const barLabel = { fontSize:10, color:'var(--text-2)', fontFamily:'monospace', width:140, flexShrink:0, textOverflow:'ellipsis', overflow:'hidden', whiteSpace:'nowrap' }
const barTrack = { flex:1, height:5, background:'var(--bg-deep)', borderRadius:99, overflow:'hidden' }
const barFill = { height:'100%', borderRadius:99, transition:'width .4s' }
const barCount = { fontSize:11, color:'var(--text-2)', fontFamily:'monospace', width:28, textAlign:'right' }
const statRow = { display:'flex', alignItems:'center', gap:10, marginBottom:8 }
const dot = { width:8, height:8, borderRadius:'50%', flexShrink:0 }
const statLabel = { flex:1, fontSize:13, color:'var(--text-2)' }
const statBadge = { borderRadius:99, padding:'2px 10px', fontSize:12, fontFamily:'monospace', fontWeight:700 }
const barChart = { display:'flex', gap:4, alignItems:'flex-end', height:80, paddingTop:8 }
const barCol = { flex:1, display:'flex', flexDirection:'column', alignItems:'center', gap:3, height:'100%' }
const barColInner = { flex:1, display:'flex', alignItems:'flex-end', width:'100%' }
const barColFill = { width:'100%', background:'linear-gradient(180deg,#8b5cf6,#4c1d95)', borderRadius:'3px 3px 0 0', minHeight:2 }
const barColLabel = { fontSize:8, color:'var(--text-3)', fontFamily:'monospace' }
const tableCard = { background:'var(--bg-surface)', border:'1px solid var(--border-1)', borderRadius:12, padding:'18px 20px' }
const cardTitle = { fontSize:13, fontWeight:700, color:'var(--text-1)', marginBottom:4, textTransform:'uppercase', letterSpacing:'1px', fontFamily:'monospace' }
const cardHeader = { marginBottom:16 }
const cardSubtitle = { fontSize:12, color:'var(--text-3)', marginTop:2 }
const empty = { color:'var(--text-3)', fontSize:13, padding:'24px 0', textAlign:'center' }
const tableWrap = { overflowX:'auto', marginTop:12 }
const table = { width:'100%', borderCollapse:'collapse' }
const th = { padding:'8px 12px', textAlign:'left', fontSize:10, color:'var(--text-3)', fontFamily:'monospace', textTransform:'uppercase', letterSpacing:'1px', borderBottom:'1px solid var(--border-1)', whiteSpace:'nowrap' }
const tr = { borderBottom:'1px solid rgba(139,92,246,0.05)' }
const td = { padding:'10px 12px', fontSize:13, color:'var(--text-1)', verticalAlign:'middle' }
const ticketChip = { background:'rgba(139,92,246,0.1)', color:'var(--purple-bright)', borderRadius:4, padding:'2px 6px', fontSize:10, fontFamily:'monospace' }
const ticketLink = { background:'rgba(139,92,246,0.1)', color:'var(--purple-bright)', borderRadius:4, padding:'2px 6px', fontSize:10, fontFamily:'monospace', textDecoration:'none', cursor:'pointer' }
const escGrid = { display:'flex', flexDirection:'column', gap:14, marginTop:16 }
const escCard = { background:'var(--bg-deep)', border:'1px solid var(--border-1)', borderRadius:10, padding:'16px 20px' }
const escHeader = { display:'flex', alignItems:'center', justifyContent:'space-between', marginBottom:10 }
const escLeft = { display:'flex', alignItems:'center', gap:8 }
const escMeta = { display:'flex', gap:16, fontSize:12, color:'var(--text-2)', marginBottom:12 }
const escSection = { marginBottom:10 }
const escLabel = { fontSize:10, color:'var(--text-3)', textTransform:'uppercase', letterSpacing:'1px', fontFamily:'monospace', marginBottom:4 }
const escText = { fontSize:13, color:'var(--text-1)', lineHeight:1.5 }
const escActions = { marginTop:14, display:'flex', gap:8 }
const btnPrimary = { background:'rgba(59,130,246,0.1)', border:'1px solid rgba(59,130,246,0.3)', borderRadius:6, color:'#3b82f6', fontSize:12, padding:'6px 14px', cursor:'pointer' }
const btnSuccess = { background:'rgba(34,197,94,0.1)', border:'1px solid rgba(34,197,94,0.3)', borderRadius:6, color:'#22c55e', fontSize:12, padding:'6px 14px', cursor:'pointer' }
const btnDanger = { background:'rgba(239,68,68,0.1)', border:'1px solid rgba(239,68,68,0.3)', borderRadius:6, color:'#ef4444', fontSize:12, padding:'6px 14px', cursor:'pointer' }
const detailBtn = { background:'rgba(139,92,246,0.1)', border:'1px solid var(--border-2)', borderRadius:6, color:'var(--purple-bright)', fontSize:11, padding:'4px 10px', cursor:'pointer' }
const filterRow = { display:'flex', gap:8, marginBottom:14, marginTop:8 }
const filterInput = { flex:1, background:'var(--bg-elevated)', border:'1px solid var(--border-1)', borderRadius:8, padding:'8px 12px', color:'var(--text-1)', fontSize:13, fontFamily:'monospace', outline:'none' }
const clearBtn = { background:'var(--bg-elevated)', border:'1px solid var(--border-2)', borderRadius:8, color:'var(--text-2)', fontSize:12, padding:'8px 14px', cursor:'pointer', flexShrink:0 }
const pagination = { display:'flex', alignItems:'center', justifyContent:'center', gap:14, marginTop:14 }
const pageBtn = { background:'var(--bg-elevated)', border:'1px solid var(--border-2)', borderRadius:8, color:'var(--text-2)', fontSize:12, padding:'6px 14px', cursor:'pointer' }
const modalOverlay = { position:'fixed', inset:0, background:'rgba(0,0,0,0.75)', backdropFilter:'blur(4px)', zIndex:1000, display:'flex', alignItems:'center', justifyContent:'center', padding:20 }
const modal = { background:'var(--bg-surface)', border:'1px solid var(--border-1)', borderRadius:16, width:'100%', maxWidth:680, maxHeight:'85vh', overflow:'hidden', display:'flex', flexDirection:'column' }
const modalHeader = { display:'flex', alignItems:'flex-start', justifyContent:'space-between', padding:'20px 24px 16px', borderBottom:'1px solid var(--border-1)' }
const modalTitle = { fontSize:18, fontWeight:800, color:'var(--text-1)' }
const modalClose = { background:'transparent', border:'none', color:'var(--text-3)', fontSize:20, cursor:'pointer', lineHeight:1 }
const modalBody = { overflowY:'auto', padding:'20px 24px', display:'flex', flexDirection:'column', gap:20 }
const modalMeta = { display:'grid', gridTemplateColumns:'1fr 1fr', gap:12 }
const modalMetaItem = { display:'flex', flexDirection:'column', gap:3 }
const metaLabel = { fontSize:10, color:'var(--text-3)', textTransform:'uppercase', letterSpacing:'1px', fontFamily:'monospace' }
const modalSection = { display:'flex', flexDirection:'column', gap:8 }
const modalSectionTitle = { fontSize:11, fontWeight:700, color:'var(--text-2)', textTransform:'uppercase', letterSpacing:'1px', fontFamily:'monospace' }
const modalText = { fontSize:13, color:'var(--text-1)', lineHeight:1.6, background:'var(--bg-deep)', borderRadius:8, padding:'12px 14px' }
const timeline = { display:'flex', flexDirection:'column', gap:10 }
const timelineItem = { display:'flex', gap:12, alignItems:'flex-start' }
const timelineDot = { width:8, height:8, borderRadius:'50%', background:'var(--purple-bright)', flexShrink:0, marginTop:4 }
const timelineContent = { flex:1 }
const timelineAction = { fontSize:13, color:'var(--text-1)' }
const timelineTs = { fontSize:10, color:'var(--text-3)', fontFamily:'monospace', marginTop:2 }

function calcResolutionTime(created, updated) {
  const diff = new Date(updated) - new Date(created)
  const mins = Math.floor(diff / 60000)
  return mins < 60 ? mins + 'm' : Math.floor(mins/60) + 'h ' + (mins%60) + 'm'
}

function KpiCard({ label, value, icon, color, sub }) {
  return (
    <div style={{...kpiCard, borderColor:`${color}30`}}>
      <div style={{fontSize:22}}>{icon}</div>
      <div style={{fontSize:28, fontWeight:800, color, lineHeight:1}}>{value}</div>
      <div style={kpiLabel}>{label}</div>
      {sub && <div style={{fontSize:10, color, opacity:0.8}}>{sub}</div>}
    </div>
  )
}

function StatusBadge({ status }) {
  const color = STATUS_COLORS[status] || '#6b7280'
  return <span style={{background:`${color}18`, color, border:`1px solid ${color}40`, borderRadius:99, padding:'2px 8px', fontSize:10, fontFamily:'monospace', whiteSpace:'nowrap'}}>{status}</span>
}

function PriorityBadge({ priority }) {
  const color = PRIORITY_COLORS[priority?.toLowerCase()] || '#6b7280'
  return <span style={{background:`${color}18`, color, border:`1px solid ${color}40`, borderRadius:4, padding:'2px 6px', fontSize:10, fontWeight:700, textTransform:'uppercase'}}>{priority}</span>
}

function TypeBadge({ type }) {
  return <span style={{background:'rgba(139,92,246,0.1)', color:'#a78bfa', borderRadius:4, padding:'2px 6px', fontSize:10, fontFamily:'monospace'}}>{type}</span>
}

function LogsTable({ logs, full }) {
  if (!logs || logs.length === 0) return <div style={empty}>No logs found.</div>
  return (
    <div style={tableWrap}>
      <table style={table}>
        <thead>
          <tr>{['Time','Action','User','Status',...(full?['Ticket','Details']:['Details'])].map(h=><th key={h} style={th}>{h}</th>)}</tr>
        </thead>
        <tbody>
          {logs.map((log,i) => (
            <tr key={i} style={tr}>
              <td style={{...td, fontFamily:'monospace', fontSize:10, whiteSpace:'nowrap'}}>{new Date(log.created_at).toLocaleString()}</td>
              <td style={td}><span style={{background:`${ACTION_COLORS[log.action_type]||'#6b7280'}18`, color:ACTION_COLORS[log.action_type]||'#6b7280', borderRadius:4, padding:'2px 6px', fontSize:10, fontFamily:'monospace', whiteSpace:'nowrap'}}>{log.action_type}</span></td>
              <td style={td}>{log.target_user}</td>
              <td style={td}><StatusBadge status={log.status}/></td>
              {full && <td style={td}>{log.ticket_id ? <span style={ticketChip}>{log.ticket_id}</span> : '—'}</td>}
              <td style={{...td, maxWidth:280, overflow:'hidden', textOverflow:'ellipsis', whiteSpace:'nowrap', color:'var(--text-2)', fontSize:11}}>{log.details}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}

export default function DashboardPage({ user, onLogout }) {
  const navigate = useNavigate()
  const [tab, setTab] = useState('overview')
  const [stats, setStats] = useState(null)
  const [logs, setLogs] = useState([])
  const [accessReqs, setAccessReqs] = useState([])
  const [escalations, setEscalations] = useState([])
  const [tickets, setTickets] = useState([])
  const [selectedTicket, setSelectedTicket] = useState(null)
  const [loading, setLoading] = useState(true)
  const [logsFilter, setLogsFilter] = useState({ username:'', action_type:'', ticket_id:'' })
  const [logsPage, setLogsPage] = useState(0)
  const LOGS_PER_PAGE = 20

  useEffect(() => { fetchAll() }, [])
  useEffect(() => { const i = setInterval(fetchAll, 30000); return () => clearInterval(i) }, [])

  async function fetchAll() {
    setLoading(true)
    try {
      const [s, l, a, e, t] = await Promise.all([
        fetch(`${LDAP_API}/dashboard/stats`).then(r=>r.json()),
        fetch(`${LDAP_API}/logs?limit=200`).then(r=>r.json()),
        fetch(`${LDAP_API}/access-requests`).then(r=>r.json()),
        fetch(`${LDAP_API}/escalations`).then(r=>r.json()),
        fetch(`${LDAP_API}/tickets`).then(r=>r.json()),
      ])
      if (s.success) setStats(s.data)
      if (l.success) setLogs(l.data.logs)
      if (a.success) setAccessReqs(a.data.requests)
      if (e.success) setEscalations(e.data.escalations)
      if (t.success) setTickets(t.data.tickets || [])
    } catch(err) { console.error(err) }
    setLoading(false)
  }

  async function fetchLogs() {
    const q = new URLSearchParams()
    if (logsFilter.username) q.set('username', logsFilter.username)
    if (logsFilter.action_type) q.set('action_type', logsFilter.action_type)
    if (logsFilter.ticket_id) q.set('ticket_id', logsFilter.ticket_id)
    q.set('limit', LOGS_PER_PAGE); q.set('offset', logsPage * LOGS_PER_PAGE)
    const res = await fetch(`${LDAP_API}/logs?${q}`).then(r=>r.json())
    if (res.success) setLogs(res.data.logs)
  }
  useEffect(() => { if (tab==='logs') fetchLogs() }, [logsFilter, logsPage, tab])

  async function updateAccessRequest(id, status, notes='') {
    await fetch(`${LDAP_API}/access-request/${id}`, { method:'PATCH', headers:{'Content-Type':'application/json'}, body:JSON.stringify({status,notes}) })
    fetchAll()
  }

  async function updateEscalation(id, status, notes='') {
    await fetch(`${LDAP_API}/escalation/${id}`, { method:'PATCH', headers:{'Content-Type':'application/json'}, body:JSON.stringify({status,notes}) })
    fetchAll()
  }

  const initials = user?.displayName?.charAt(0)?.toUpperCase() || '?'
  const openEscalations = escalations.filter(e=>e.status==='open').length
  const inProgressEscalations = escalations.filter(e=>e.status==='in_progress').length

  const navItems = [
    { id:'overview', icon:'⊞', label:'Overview' },
    { id:'tickets', icon:'🎫', label:'N1 Tickets' },
    { id:'escalations', icon:'🚨', label:'N2 Escalations' },
    { id:'logs', icon:'📋', label:'Action Logs' },
    { id:'access', icon:'🔑', label:'Access Requests' },
  ]

  return (
    <div style={shell}>
      <aside style={sidebar}>
        <div style={sbHeader}>
          <div style={sbLogo}>
            <div style={logoMark}>H</div>
            <div>
              <div style={logoTitle}>HelpBot</div>
              <div style={logoSub}>IT Support Intelligence</div>
            </div>
          </div>
        </div>
        <nav style={nav}>
          {navItems.map(item => (
            <button key={item.id} style={{...navBtn,...(tab===item.id?navActive:{})}} onClick={()=>setTab(item.id)}>
              <span style={navIcon}>{item.icon}</span>
              <span>{item.label}</span>
              {item.id==='escalations' && openEscalations>0 && <span style={badge}>{openEscalations}</span>}
            </button>
          ))}
        </nav>
        <div style={sbFooter}>
          <button style={sbBtn} onClick={()=>navigate('/chat')}>← Back to Chat</button>
          <button style={{...sbBtn,color:'#ef4444'}} onClick={()=>{onLogout();navigate('/login')}}>Sign Out</button>
        </div>
      </aside>

      <div style={mainWrap}>
        <header style={header}>
          <div>
            <h1 style={pageTitle}>{navItems.find(n=>n.id===tab)?.label||'Dashboard'}</h1>
            <p style={pageSub}>Last updated: {new Date().toLocaleTimeString()}</p>
          </div>
          <div style={hRight}>
            <button style={refreshBtn} onClick={fetchAll}>↻ Refresh</button>
            <div style={userChip}>
              <div style={avatar}>{initials}</div>
              <div>
                <div style={userName}>{user?.displayName}</div>
                <div style={userDept}>{user?.department}</div>
              </div>
            </div>
          </div>
        </header>

        <div style={content}>
          {loading && <div style={{color:"var(--text-3)",padding:40,textAlign:"center"}}>Loading...</div>}

          {!loading && tab==='overview' && stats && (
            <div style={overviewWrap}>
              <div style={kpiGrid}>
                <KpiCard label="Total Actions" value={stats.total_actions} icon="⚡" color="#8b5cf6"/>
                <KpiCard label="Auto-Resolution" value={`${stats.success_rate}%`} icon="✅" color="#22c55e"/>
                <KpiCard label="Avg Resolution" value={stats.avg_resolution_display||'—'} icon="⏱" color="#3b82f6"/>
                <KpiCard label="KB Searches" value={stats.kb_searches} icon="📚" color="#60a5fa"/>
                <KpiCard label="Access Requests" value={accessReqs.length} icon="🔑" color="#f59e0b"/>
                <KpiCard label="N1 Tickets" value={tickets.length} icon="🎫" color="#a78bfa"/>
                <KpiCard label="N2 Open" value={openEscalations} icon="🚨" color="#ef4444"/>
                <KpiCard label="Satisfaction" value={stats.satisfaction_score?`${stats.satisfaction_score}/5`:'—'} icon="⭐" color="#f472b6" sub={stats.satisfaction_label}/>
              </div>
              <div style={chartsRow}>
                <div style={chartCard}>
                  <div style={cardTitle}>Actions by Type</div>
                  {stats.by_action.map((a,i)=>{
                    const max=stats.by_action[0]?.count||1
                    return <div key={i} style={barRow}><div style={barLabel}>{a.action_type}</div><div style={barTrack}><div style={{...barFill,width:`${(a.count/max)*100}%`,background:ACTION_COLORS[a.action_type]||'#6b7280'}}/></div><div style={barCount}>{a.count}</div></div>
                  })}
                </div>
                <div style={chartCard}>
                  <div style={cardTitle}>Status Breakdown</div>
                  {stats.by_status.map((b,i)=>(
                    <div key={i} style={statRow}><div style={{...dot,background:STATUS_COLORS[b.status]||'#6b7280'}}/><div style={statLabel}>{b.status}</div><div style={{...statBadge,background:`${STATUS_COLORS[b.status]||'#6b7280'}20`,color:STATUS_COLORS[b.status]||'#fff'}}>{b.count}</div></div>
                  ))}
                </div>
                <div style={chartCard}>
                  <div style={cardTitle}>Daily Activity (7 days)</div>
                  <div style={barChart}>
                    {stats.daily_activity.map((d,i)=>{
                      const max=Math.max(...stats.daily_activity.map(x=>x.count),1)
                      return <div key={i} style={barCol}><div style={barColInner}><div style={{...barColFill,height:`${(d.count/max)*100}%`}}/></div><div style={barColLabel}>{d.day?.slice(5)}</div></div>
                    })}
                  </div>
                </div>
              </div>
              <div style={tableCard}>
                <div style={cardTitle}>Recent Actions</div>
                <LogsTable logs={stats.recent_logs||[]}/>
              </div>
            </div>
          )}

          {!loading && tab==='tickets' && (
            <div style={tableCard}>
              <div style={cardHeader}>
                <div style={cardTitle}>N1 Tickets ({tickets.length})</div>
                <div style={cardSubtitle}>All support tickets — click Details to see full info</div>
              </div>
              {tickets.length===0 && <div style={empty}>No tickets yet.</div>}
              <div style={tableWrap}>
                <table style={table}>
                  <thead><tr>{['ID','Jira','User','Type','Priority','Summary','Status','Created',''].map(h=><th key={h} style={th}>{h}</th>)}</tr></thead>
                  <tbody>
                    {tickets.map((t,i)=>(
                      <tr key={i} style={tr}>
                        <td style={td}>#{t.id}</td>
                        <td style={td}>{t.jira_key?<a href={`https://sasimo2003.atlassian.net/browse/${t.jira_key}`} target="_blank" rel="noopener noreferrer" style={ticketLink}>{t.jira_key}</a>:<span style={{color:'var(--text-3)',fontSize:11}}>pending</span>}</td>
                        <td style={td}>{t.username}</td>
                        <td style={td}><TypeBadge type={t.issue_type}/></td>
                        <td style={td}><PriorityBadge priority={t.priority}/></td>
                        <td style={{...td,maxWidth:240,overflow:'hidden',textOverflow:'ellipsis',whiteSpace:'nowrap',color:'var(--text-2)',fontSize:12}}>{t.summary}</td>
                        <td style={td}><StatusBadge status={t.status}/></td>
                        <td style={{...td,fontSize:10,fontFamily:'monospace',whiteSpace:'nowrap'}}>{new Date(t.created_at).toLocaleString()}</td>
                        <td style={td}><button style={detailBtn} onClick={()=>setSelectedTicket(t)}>Details</button></td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
          )}

          {!loading && tab==='escalations' && (
            <div style={tableCard}>
              <div style={cardHeader}>
                <div style={cardTitle}>N2 Escalations ({escalations.length})</div>
                <div style={cardSubtitle}>
                  <span style={{color:'#f97316'}}>{openEscalations} open</span> · <span style={{color:'#3b82f6'}}>{inProgressEscalations} in progress</span> · <span style={{color:'#22c55e'}}>{escalations.filter(e=>e.status==='resolved').length} resolved</span>
                </div>
              </div>
              {escalations.length===0 && <div style={empty}>No escalations yet 🎉</div>}
              <div style={escGrid}>
                {escalations.map((e,i)=>(
                  <div key={i} style={{...escCard,borderLeft:`3px solid ${PRIORITY_COLORS[e.priority]||'#6b7280'}`}}>
                    <div style={escHeader}>
                      <div style={escLeft}>
                        {e.ticket_id?<a href={`https://sasimo2003.atlassian.net/browse/${e.ticket_id}`} target="_blank" rel="noopener noreferrer" style={ticketLink}>{e.ticket_id}</a>:<span style={{color:'var(--text-3)',fontSize:11}}>No ticket</span>}
                        <PriorityBadge priority={e.priority}/>
                        <StatusBadge status={e.status}/>
                      </div>
                      <div style={{fontSize:10,color:'var(--text-3)',fontFamily:'monospace'}}>#{e.id} · {new Date(e.created_at).toLocaleString()}</div>
                    </div>
                    <div style={escMeta}><span>👤 {e.display_name||e.username}</span><span>🏢 {e.department}</span><span>🔧 {e.issue_type}</span></div>
                    <div style={escSection}><div style={escLabel}>Problem</div><div style={escText}>{e.summary}</div></div>
                    {e.steps_tried && <div style={escSection}><div style={escLabel}>Steps Tried</div><div style={escText}>{e.steps_tried}</div></div>}
                    {e.error_details && <div style={escSection}><div style={escLabel}>Error Details</div><div style={{...escText,fontFamily:'monospace',fontSize:11,background:'rgba(0,0,0,0.2)',padding:'6px 8px',borderRadius:4}}>{e.error_details}</div></div>}
                    {e.n2_notes && <div style={escSection}><div style={escLabel}>N2 Notes</div><div style={{...escText,color:'#22c55e'}}>{e.n2_notes}</div></div>}
                    <div style={escActions}>
                      {e.status==='open' && <button style={btnPrimary} onClick={()=>updateEscalation(e.id,'in_progress','N2 engineer assigned')}>▶ Take</button>}
                      {e.status==='in_progress' && <button style={btnSuccess} onClick={async()=>{const n=window.prompt('Resolution notes:')||'Resolved by N2';await updateEscalation(e.id,'resolved',n)}}>✓ Resolve</button>}
                      {e.status==='resolved' && <span style={{color:'#22c55e',fontSize:12,fontWeight:700}}>✅ Resolved</span>}
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}

          {!loading && tab==='logs' && (
            <div style={tableCard}>
              <div style={cardTitle}>Action Logs</div>
              <div style={filterRow}>
                {[{k:'username',p:'Filter by username'},{k:'action_type',p:'Filter by action'},{k:'ticket_id',p:'Filter by ticket'}].map(f=>(
                  <input key={f.k} style={filterInput} placeholder={f.p} value={logsFilter[f.k]} onChange={ev=>{setLogsFilter(p=>({...p,[f.k]:ev.target.value}));setLogsPage(0)}}/>
                ))}
                <button style={clearBtn} onClick={()=>{setLogsFilter({username:'',action_type:'',ticket_id:''});setLogsPage(0)}}>Clear</button>
              </div>
              <LogsTable logs={logs} full/>
              <div style={pagination}>
                <button style={pageBtn} disabled={logsPage===0} onClick={()=>setLogsPage(p=>p-1)}>← Prev</button>
                <span style={{fontSize:12,color:'var(--text-3)'}}>Page {logsPage+1}</span>
                <button style={pageBtn} disabled={logs.length<LOGS_PER_PAGE} onClick={()=>setLogsPage(p=>p+1)}>Next →</button>
              </div>
            </div>
          )}

          {!loading && tab==='access' && (
            <div style={tableCard}>
              <div style={cardTitle}>Access Requests ({accessReqs.length})</div>
              {accessReqs.length===0 && <div style={empty}>No access requests yet.</div>}
              <div style={tableWrap}>
                <table style={table}>
                  <thead><tr>{['#','User','App','Level','Reason','Ticket','Status','Date','Actions'].map(h=><th key={h} style={th}>{h}</th>)}</tr></thead>
                  <tbody>
                    {accessReqs.map((r,i)=>(
                      <tr key={i} style={tr}>
                        <td style={td}>#{r.id}</td>
                        <td style={td}>{r.username}</td>
                        <td style={td}><TypeBadge type={r.application}/></td>
                        <td style={td}>{r.access_level}</td>
                        <td style={{...td,maxWidth:180,overflow:'hidden',textOverflow:'ellipsis',whiteSpace:'nowrap',fontSize:11}}>{r.business_reason}</td>
                        <td style={td}>{r.ticket_id?<span style={ticketChip}>{r.ticket_id}</span>:'—'}</td>
                        <td style={td}><StatusBadge status={r.status}/></td>
                        <td style={{...td,fontSize:10,fontFamily:'monospace'}}>{new Date(r.created_at).toLocaleDateString()}</td>
                        <td style={td}>
                          {r.status==='pending' && <div style={{display:'flex',gap:4}}><button style={btnSuccess} onClick={()=>updateAccessRequest(r.id,'approved')}>✓</button><button style={btnDanger} onClick={()=>updateAccessRequest(r.id,'rejected')}>✕</button></div>}
                          {r.status==='approved' && <button style={btnPrimary} onClick={()=>updateAccessRequest(r.id,'provisioned','Provisioned by IT')}>Provision</button>}
                          {(r.status==='provisioned'||r.status==='rejected') && <span style={{color:'var(--text-3)',fontSize:11}}>{r.status}</span>}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
          )}
        </div>
      </div>

      {selectedTicket && (
        <div style={modalOverlay} onClick={()=>setSelectedTicket(null)}>
          <div style={modal} onClick={e=>e.stopPropagation()}>
            <div style={modalHeader}>
              <div>
                <div style={modalTitle}>Ticket Details #{selectedTicket.id}</div>
                <div style={{marginTop:4}}>
                  {selectedTicket.jira_key
                    ? <a href={`https://sasimo2003.atlassian.net/browse/${selectedTicket.jira_key}`} target="_blank" rel="noopener noreferrer" style={ticketLink}>{selectedTicket.jira_key}</a>
                    : <span style={{color:'var(--text-3)',fontSize:12}}>Jira ticket pending</span>}
                </div>
              </div>
              <button style={modalClose} onClick={()=>setSelectedTicket(null)}>✕</button>
            </div>
            <div style={modalBody}>
              <div style={modalMeta}>
                <div style={modalMetaItem}><span style={metaLabel}>User</span><span>{selectedTicket.username}</span></div>
                <div style={modalMetaItem}><span style={metaLabel}>Department</span><span>{selectedTicket.department||'—'}</span></div>
                <div style={modalMetaItem}><span style={metaLabel}>Type</span><TypeBadge type={selectedTicket.issue_type}/></div>
                <div style={modalMetaItem}><span style={metaLabel}>Priority</span><PriorityBadge priority={selectedTicket.priority}/></div>
                <div style={modalMetaItem}><span style={metaLabel}>Status</span><StatusBadge status={selectedTicket.status}/></div>
                <div style={modalMetaItem}><span style={metaLabel}>Escalated</span><span style={{color:selectedTicket.escalated?'#ef4444':'#22c55e'}}>{selectedTicket.escalated?'🚨 Yes':'—'}</span></div>
                <div style={modalMetaItem}>
                  <span style={metaLabel}>Time to Resolution</span>
                  <span>{selectedTicket.status==='resolved' && selectedTicket.updated_at ? calcResolutionTime(selectedTicket.created_at, selectedTicket.updated_at) : '—'}</span>
                </div>
                <div style={modalMetaItem}><span style={metaLabel}>Created</span><span style={{fontFamily:'monospace',fontSize:11}}>{new Date(selectedTicket.created_at).toLocaleString()}</span></div>
              </div>
              {selectedTicket.summary && (
                <div style={modalSection}>
                  <div style={modalSectionTitle}>Summary</div>
                  <div style={modalText}>{selectedTicket.summary}</div>
                </div>
              )}
              <div style={modalSection}>
                <div style={modalSectionTitle}>Actions Taken by AI</div>
                {Array.isArray(selectedTicket.actions_taken) && selectedTicket.actions_taken.length > 0 ? (
                  <div style={timeline}>
                    {selectedTicket.actions_taken.map((a,i)=>(
                      <div key={i} style={timelineItem}>
                        <div style={timelineDot}/>
                        <div style={timelineContent}>
                          <div style={timelineAction}>{typeof a==='object'?a.action:a}</div>
                          {typeof a==='object' && a.ts && <div style={timelineTs}>{new Date(a.ts).toLocaleTimeString()}</div>}
                        </div>
                      </div>
                    ))}
                  </div>
                ) : <div style={{color:'var(--text-3)',fontSize:12}}>No actions recorded yet.</div>}
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
