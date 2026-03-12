import React, { useState, useEffect } from 'react'
import { useNavigate } from 'react-router-dom'

const LDAP_API = `http://${window.location.hostname}:5001`

const ACTION_COLORS = {
  UNLOCK_ACCOUNT: '#8b5cf6',
  RESET_PASSWORD: '#22d3ee',
  VPN_DIAGNOSTIC: '#f59e0b',
  ACCESS_REQUEST: '#4ade80',
  SEARCH_KB: '#60a5fa',
  LOGIN: '#a78bfa',
  AGENT_ACTION: '#6b7280',
}

const STATUS_COLORS = {
  success: '#4ade80',
  failure: '#f87171',
  pending: '#fbbf24',
  healthy: '#4ade80',
  degraded: '#f59e0b',
  critical: '#f87171',
  warning: '#fbbf24',
}

export default function DashboardPage({ user, onLogout }) {
  const navigate = useNavigate()
  const [tab, setTab] = useState('overview')
  const [stats, setStats] = useState(null)
  const [logs, setLogs] = useState([])
  const [accessReqs, setAccessReqs] = useState([])
  const [loading, setLoading] = useState(true)
  const [logsFilter, setLogsFilter] = useState({ username: '', action_type: '', ticket_id: '' })
  const [logsPage, setLogsPage] = useState(0)
  const LOGS_PER_PAGE = 20

  useEffect(() => { fetchAll() }, [])

  useEffect(() => {
    const interval = setInterval(() => { fetchAll() }, 30000)
    return () => clearInterval(interval)
  }, [])

  async function fetchAll() {
    setLoading(true)
    try {
      const [s, l, a] = await Promise.all([
        fetch(`${LDAP_API}/dashboard/stats`).then(r => r.json()),
        fetch(`${LDAP_API}/logs?limit=200`).then(r => r.json()),
        fetch(`${LDAP_API}/access-requests`).then(r => r.json()),
      ])
      if (s.success) setStats(s.data)
      if (l.success) setLogs(l.data.logs)
      if (a.success) setAccessReqs(a.data.requests)
    } catch {}
    setLoading(false)
  }

  async function fetchLogs() {
    const q = new URLSearchParams()
    if (logsFilter.username) q.set('username', logsFilter.username)
    if (logsFilter.action_type) q.set('action_type', logsFilter.action_type)
    if (logsFilter.ticket_id) q.set('ticket_id', logsFilter.ticket_id)
    q.set('limit', LOGS_PER_PAGE)
    q.set('offset', logsPage * LOGS_PER_PAGE)
    const res = await fetch(`${LDAP_API}/logs?${q}`).then(r => r.json())
    if (res.success) setLogs(res.data.logs)
  }

  useEffect(() => { if (tab === 'logs') fetchLogs() }, [logsFilter, logsPage, tab])

  async function updateAccessRequest(id, status, notes = '') {
    await fetch(`${LDAP_API}/access-request/${id}`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ status, notes })
    })
    const a = await fetch(`${LDAP_API}/access-requests`).then(r => r.json())
    if (a.success) setAccessReqs(a.data.requests)
  }

  function logout() { onLogout(); navigate('/login') }

  const initials = user?.displayName?.charAt(0)?.toUpperCase() || '?'

  return (
    <div style={s.shell}>
      {/* Sidebar */}
      <aside style={s.sidebar}>
        <div style={s.sbLogo}>
          <Hex size={22} /><span style={s.sbLogoTxt}>HelpBot</span>
        </div>
        <nav style={s.nav}>
          {[
            { id: 'overview', icon: <GridIcon />, label: 'Overview' },
            { id: 'logs', icon: <LogIcon />, label: 'Action Logs' },
            { id: 'access', icon: <KeyIcon />, label: 'Access Requests' },
          ].map(item => (
            <button key={item.id} style={{ ...s.navBtn, ...(tab === item.id ? s.navActive : {}) }}
              onClick={() => setTab(item.id)}>
              {item.icon}{item.label}
            </button>
          ))}
        </nav>
        <div style={s.sbFoot}>
          <button style={s.navBtn} onClick={() => navigate('/chat')}>
            <ChatIcon /> Back to Chat
          </button>
          <button style={{ ...s.navBtn, color: 'var(--red)' }} onClick={logout}>
            <LogoutIcon /> Sign Out
          </button>
        </div>
      </aside>

      {/* Main */}
      <div style={s.main}>
        {/* Header */}
        <header style={s.header}>
          <div>
            <div style={s.pageTitle}>
              {tab === 'overview' ? 'Dashboard' : tab === 'logs' ? 'Action Logs' : 'Access Requests'}
            </div>
            <div style={s.pageSub}>HelpBot IT Support Intelligence</div>
          </div>
          <div style={s.hRight}>
            <button style={s.refreshBtn} onClick={fetchAll}>↻ Refresh</button>
            <div style={s.hUser}>
              <div style={s.avSm}>{initials}</div>
              <div>
                <div style={s.hName}>{user?.displayName}</div>
                <div style={s.hDept}>{user?.department}</div>
              </div>
            </div>
          </div>
        </header>

        <div style={s.content}>
          {loading && <div style={s.loading}>Loading data…</div>}

          {/* ── OVERVIEW ── */}
          {!loading && tab === 'overview' && stats && (
            <div style={s.overviewGrid}>
              {/* KPI Cards */}
              <div style={s.kpiRow}>
                <KpiCard label="Total Tickets" value={stats.total_actions} icon="🎫" color="#8b5cf6" />
                <KpiCard label="Taux Résolution Auto" value={`${stats.success_rate}%`} icon="✅" color="#4ade80" />
                <KpiCard label="Temps Moyen Traitement" value={stats.avg_resolution_display || '—'} icon="⏱" color="#22d3ee" />
                <KpiCard label="Répartition KB" value={stats.kb_searches} icon="📚" color="#60a5fa" />
                <KpiCard label="Demandes Accès" value={accessReqs.length} icon="🔑" color="#f59e0b" />
                <KpiCard
                  label="Satisfaction Utilisateur"
                  value={stats.satisfaction_score ? `${stats.satisfaction_score}/5` : '—'}
                  icon="⭐"
                  color="#f472b6"
                  sub={stats.satisfaction_label}
                />
              </div>

              {/* Action breakdown */}
              <div style={s.row2}>
                <div style={s.card}>
                  <div style={s.cardTitle}>Actions by Type</div>
                  {stats.by_action.length === 0 && <div style={s.empty}>No actions yet</div>}
                  {stats.by_action.map((a, i) => {
                    const max = stats.by_action[0]?.count || 1
                    return (
                      <div key={i} style={s.barRow}>
                        <div style={s.barLabel}>{a.action_type}</div>
                        <div style={s.barTrack}>
                          <div style={{ ...s.barFill, width: `${(a.count / max) * 100}%`, background: ACTION_COLORS[a.action_type] || '#6b7280' }} />
                        </div>
                        <div style={s.barCount}>{a.count}</div>
                      </div>
                    )
                  })}
                </div>

                <div style={s.card}>
                  <div style={s.cardTitle}>Status Breakdown</div>
                  {stats.by_status.map((s2, i) => (
                    <div key={i} style={s.statRow}>
                      <div style={{ ...s.dot, background: STATUS_COLORS[s2.status] || '#6b7280' }} />
                      <div style={s.statLabel}>{s2.status}</div>
                      <div style={{ ...s.statBadge, background: `${STATUS_COLORS[s2.status]}20`, color: STATUS_COLORS[s2.status] || '#fff' }}>{s2.count}</div>
                    </div>
                  ))}
                </div>

                <div style={s.card}>
                  <div style={s.cardTitle}>Daily Activity (7 days)</div>
                  {stats.daily_activity.length === 0 && <div style={s.empty}>No recent activity</div>}
                  <div style={s.chartWrap}>
                    {stats.daily_activity.map((d, i) => {
                      const max = Math.max(...stats.daily_activity.map(x => x.count), 1)
                      return (
                        <div key={i} style={s.chartCol}>
                          <div style={s.chartBarWrap}>
                            <div style={{ ...s.chartBar, height: `${(d.count / max) * 100}%` }} />
                          </div>
                          <div style={s.chartLabel}>{d.day.slice(5)}</div>
                        </div>
                      )
                    })}
                  </div>
                </div>
              </div>

              {/* Recent logs */}
              <div style={s.card}>
                <div style={s.cardTitle}>Recent Actions</div>
                <LogTable logs={stats.recent_logs} />
              </div>
            </div>
          )}

          {/* ── LOGS ── */}
          {!loading && tab === 'logs' && (
            <div style={s.logsWrap}>
              <div style={s.filterRow}>
                {[
                  { key: 'username', placeholder: 'Filter by username' },
                  { key: 'action_type', placeholder: 'Filter by action type' },
                  { key: 'ticket_id', placeholder: 'Filter by ticket ID' },
                ].map(f => (
                  <input key={f.key} style={s.filterInput} placeholder={f.placeholder}
                    value={logsFilter[f.key]}
                    onChange={e => { setLogsFilter(p => ({ ...p, [f.key]: e.target.value })); setLogsPage(0) }} />
                ))}
                <button style={s.filterClear} onClick={() => { setLogsFilter({ username: '', action_type: '', ticket_id: '' }); setLogsPage(0) }}>Clear</button>
              </div>
              <div style={s.card}>
                <LogTable logs={logs} full />
              </div>
              <div style={s.pagination}>
                <button style={s.pageBtn} disabled={logsPage === 0} onClick={() => setLogsPage(p => p - 1)}>← Prev</button>
                <span style={s.pageInfo}>Page {logsPage + 1}</span>
                <button style={s.pageBtn} disabled={logs.length < LOGS_PER_PAGE} onClick={() => setLogsPage(p => p + 1)}>Next →</button>
              </div>
            </div>
          )}

          {/* ── ACCESS REQUESTS ── */}
          {!loading && tab === 'access' && (
            <div style={s.card}>
              <div style={s.cardTitle}>Access Requests ({accessReqs.length})</div>
              {accessReqs.length === 0 && <div style={s.empty}>No access requests yet</div>}
              <div style={s.tableWrap}>
                <table style={s.table}>
                  <thead>
                    <tr>
                      {['ID', 'User', 'Application', 'Level', 'Reason', 'Ticket', 'Status', 'Created', 'Actions'].map(h => (
                        <th key={h} style={s.th}>{h}</th>
                      ))}
                    </tr>
                  </thead>
                  <tbody>
                    {accessReqs.map((r, i) => (
                      <tr key={i} style={s.tr}>
                        <td style={s.td}>#{r.id}</td>
                        <td style={s.td}>{r.username}</td>
                        <td style={s.td}>{r.application}</td>
                        <td style={s.td}>{r.access_level}</td>
                        <td style={{ ...s.td, maxWidth: 200, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{r.business_reason}</td>
                        <td style={s.td}><span style={s.ticketTag}>{r.ticket_id || '—'}</span></td>
                        <td style={s.td}><StatusBadge status={r.status} /></td>
                        <td style={{ ...s.td, fontFamily: 'var(--font-mono)', fontSize: 10 }}>{new Date(r.created_at).toLocaleDateString()}</td>
                        <td style={s.td}>
                          {r.status === 'pending' && (
                            <div style={{ display: 'flex', gap: 5 }}>
                              <button style={s.approveBtn} onClick={() => updateAccessRequest(r.id, 'approved')}>✓</button>
                              <button style={s.rejectBtn} onClick={() => updateAccessRequest(r.id, 'rejected')}>✕</button>
                            </div>
                          )}
                          {r.status === 'approved' && (
                            <button style={s.provisionBtn} onClick={() => updateAccessRequest(r.id, 'provisioned', 'Access provisioned by IT')}>Provision</button>
                          )}
                          {(r.status === 'provisioned' || r.status === 'rejected') && (
                            <span style={{ color: 'var(--text-3)', fontSize: 11 }}>{r.status}</span>
                          )}
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
    </div>
  )
}

// ── Sub-components ─────────────────────────────────────────────────────────────
function KpiCard({ label, value, icon, color, sub }) {
  return (
    <div style={{ ...s.kpiCard, borderColor: `${color}30` }}>
      <div style={{ fontSize: 26 }}>{icon}</div>
      <div style={{ ...s.kpiValue, color }}>{value}</div>
      <div style={s.kpiLabel}>{label}</div>
      {sub && <div style={{ fontSize: 11, color, opacity: 0.8, marginTop: 2 }}>{sub}</div>}
    </div>
  )
}

function StatusBadge({ status }) {
  const color = STATUS_COLORS[status] || '#6b7280'
  return (
    <span style={{ background: `${color}18`, color, border: `1px solid ${color}40`, borderRadius: 99, padding: '2px 9px', fontSize: 11, fontFamily: 'var(--font-mono)', whiteSpace: 'nowrap' }}>
      {status}
    </span>
  )
}

function LogTable({ logs, full }) {
  if (!logs || logs.length === 0) return <div style={s.empty}>No logs found</div>
  return (
    <div style={s.tableWrap}>
      <table style={s.table}>
        <thead>
          <tr>
            {['Time', 'Action', 'User', 'Status', ...(full ? ['Ticket', 'Details'] : ['Details'])].map(h => (
              <th key={h} style={s.th}>{h}</th>
            ))}
          </tr>
        </thead>
        <tbody>
          {logs.map((log, i) => (
            <tr key={i} style={s.tr}>
              <td style={{ ...s.td, fontFamily: 'var(--font-mono)', fontSize: 10, whiteSpace: 'nowrap' }}>
                {new Date(log.created_at).toLocaleString()}
              </td>
              <td style={s.td}>
                <span style={{ background: `${ACTION_COLORS[log.action_type] || '#6b7280'}20`, color: ACTION_COLORS[log.action_type] || '#6b7280', borderRadius: 4, padding: '2px 7px', fontSize: 10, fontFamily: 'var(--font-mono)', whiteSpace: 'nowrap' }}>
                  {log.action_type}
                </span>
              </td>
              <td style={s.td}>{log.target_user}</td>
              <td style={s.td}><StatusBadge status={log.status} /></td>
              {full && <td style={s.td}><span style={s.ticketTag}>{log.ticket_id || '—'}</span></td>}
              <td style={{ ...s.td, maxWidth: 280, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap', color: 'var(--text-2)', fontSize: 12 }}>{log.details}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}

// ── Icons ──────────────────────────────────────────────────────────────────────
const Hex = ({ size = 28 }) => (
  <svg width={size} height={size} viewBox="0 0 36 36" fill="none">
    <polygon points="18,2 32,10 32,26 18,34 4,26 4,10" fill="rgba(139,92,246,0.15)" stroke="#8b5cf6" strokeWidth="1.5"/>
    <circle cx="18" cy="18" r="7" fill="#8b5cf6"/><circle cx="18" cy="18" r="3" fill="#f0ecff"/>
  </svg>
)
const GridIcon = () => <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><rect x="3" y="3" width="7" height="7"/><rect x="14" y="3" width="7" height="7"/><rect x="3" y="14" width="7" height="7"/><rect x="14" y="14" width="7" height="7"/></svg>
const LogIcon = () => <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/><line x1="16" y1="13" x2="8" y2="13"/><line x1="16" y1="17" x2="8" y2="17"/></svg>
const KeyIcon = () => <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><circle cx="7.5" cy="15.5" r="5.5"/><path d="M21 2l-9.6 9.6M15.5 7.5l3 3"/></svg>
const ChatIcon = () => <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/></svg>
const LogoutIcon = () => <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"/><polyline points="16 17 21 12 16 7"/><line x1="21" y1="12" x2="9" y2="12"/></svg>

// ── Styles ─────────────────────────────────────────────────────────────────────
const s = {
  shell: { display:'flex', width:'100vw', height:'100dvh', overflow:'hidden', background:'var(--bg-void)' },
  sidebar: { width:220, flexShrink:0, background:'rgba(9,7,20,0.97)', borderRight:'1px solid var(--border-1)', display:'flex', flexDirection:'column', padding:'0 0 16px' },
  sbLogo: { padding:'18px 18px 14px', display:'flex', alignItems:'center', gap:10, borderBottom:'1px solid var(--border-1)' },
  sbLogoTxt: { fontSize:17, fontWeight:800, background:'linear-gradient(135deg,#c4b5fd,#8b5cf6)', WebkitBackgroundClip:'text', WebkitTextFillColor:'transparent' },
  nav: { flex:1, padding:'12px 10px', display:'flex', flexDirection:'column', gap:4 },
  navBtn: { display:'flex', alignItems:'center', gap:10, padding:'9px 12px', background:'transparent', border:'none', borderRadius:8, color:'var(--text-2)', fontSize:13, cursor:'pointer', fontFamily:'var(--font-ui)', textAlign:'left', width:'100%' },
  navActive: { background:'rgba(139,92,246,0.12)', color:'var(--purple-bright)', border:'1px solid var(--border-2)' },
  sbFoot: { padding:'0 10px', display:'flex', flexDirection:'column', gap:4, borderTop:'1px solid var(--border-1)', paddingTop:12 },
  main: { flex:1, display:'grid', gridTemplateRows:'64px 1fr', overflow:'hidden' },
  header: { display:'flex', alignItems:'center', justifyContent:'space-between', padding:'0 24px', background:'rgba(9,7,20,0.92)', borderBottom:'1px solid var(--border-1)', backdropFilter:'blur(20px)' },
  pageTitle: { fontSize:20, fontWeight:800, color:'var(--text-1)' },
  pageSub: { fontSize:11, color:'var(--text-3)', fontFamily:'var(--font-mono)' },
  hRight: { display:'flex', alignItems:'center', gap:14 },
  refreshBtn: { background:'var(--bg-elevated)', border:'1px solid var(--border-2)', borderRadius:8, color:'var(--text-2)', fontSize:12, padding:'7px 14px', cursor:'pointer', fontFamily:'var(--font-ui)' },
  hUser: { display:'flex', alignItems:'center', gap:9 },
  avSm: { width:30, height:30, borderRadius:'50%', background:'linear-gradient(135deg,#7c3aed,#4c1d95)', border:'1.5px solid var(--purple-mid)', display:'flex', alignItems:'center', justifyContent:'center', fontSize:12, fontWeight:700, color:'#fff', flexShrink:0 },
  hName: { fontSize:12, fontWeight:600, color:'var(--text-1)' },
  hDept: { fontSize:10, color:'var(--purple-bright)', fontFamily:'var(--font-mono)' },
  content: { overflowY:'auto', padding:'20px 24px' },
  loading: { color:'var(--text-3)', fontSize:14, padding:40, textAlign:'center' },
  overviewGrid: { display:'flex', flexDirection:'column', gap:18 },
  kpiRow: { display:'grid', gridTemplateColumns:'repeat(3,1fr)', gap:14 },
  kpiCard: { background:'var(--bg-surface)', border:'1px solid', borderRadius:14, padding:'18px 20px', display:'flex', flexDirection:'column', gap:6 },
  kpiValue: { fontSize:30, fontWeight:800 },
  kpiLabel: { fontSize:11, color:'var(--text-3)', fontFamily:'var(--font-mono)', textTransform:'uppercase', letterSpacing:'1px' },
  row2: { display:'grid', gridTemplateColumns:'1fr 1fr 1fr', gap:14 },
  card: { background:'var(--bg-surface)', border:'1px solid var(--border-1)', borderRadius:14, padding:'18px 20px' },
  cardTitle: { fontSize:13, fontWeight:700, color:'var(--text-1)', marginBottom:14, textTransform:'uppercase', letterSpacing:'1px', fontFamily:'var(--font-mono)' },
  empty: { color:'var(--text-3)', fontSize:13, padding:'20px 0', textAlign:'center' },
  barRow: { display:'flex', alignItems:'center', gap:10, marginBottom:10 },
  barLabel: { fontSize:10, color:'var(--text-2)', fontFamily:'var(--font-mono)', width:140, flexShrink:0, textOverflow:'ellipsis', overflow:'hidden', whiteSpace:'nowrap' },
  barTrack: { flex:1, height:6, background:'var(--bg-deep)', borderRadius:99, overflow:'hidden' },
  barFill: { height:'100%', borderRadius:99, transition:'width .4s' },
  barCount: { fontSize:11, color:'var(--text-2)', fontFamily:'var(--font-mono)', width:30, textAlign:'right' },
  statRow: { display:'flex', alignItems:'center', gap:10, marginBottom:10 },
  dot: { width:8, height:8, borderRadius:'50%', flexShrink:0 },
  statLabel: { flex:1, fontSize:13, color:'var(--text-2)' },
  statBadge: { borderRadius:99, padding:'2px 10px', fontSize:12, fontFamily:'var(--font-mono)', fontWeight:700 },
  chartWrap: { display:'flex', gap:6, alignItems:'flex-end', height:90, paddingTop:10 },
  chartCol: { flex:1, display:'flex', flexDirection:'column', alignItems:'center', gap:4, height:'100%' },
  chartBarWrap: { flex:1, display:'flex', alignItems:'flex-end', width:'100%' },
  chartBar: { width:'100%', background:'linear-gradient(180deg,#8b5cf6,#4c1d95)', borderRadius:'3px 3px 0 0', minHeight:2 },
  chartLabel: { fontSize:9, color:'var(--text-3)', fontFamily:'var(--font-mono)' },
  logsWrap: { display:'flex', flexDirection:'column', gap:14 },
  filterRow: { display:'flex', gap:10 },
  filterInput: { flex:1, background:'var(--bg-surface)', border:'1px solid var(--border-1)', borderRadius:8, padding:'9px 14px', color:'var(--text-1)', fontSize:13, fontFamily:'var(--font-mono)', outline:'none' },
  filterClear: { background:'var(--bg-elevated)', border:'1px solid var(--border-2)', borderRadius:8, color:'var(--text-2)', fontSize:12, padding:'9px 16px', cursor:'pointer', fontFamily:'var(--font-ui)', flexShrink:0 },
  pagination: { display:'flex', alignItems:'center', justifyContent:'center', gap:14 },
  pageBtn: { background:'var(--bg-elevated)', border:'1px solid var(--border-2)', borderRadius:8, color:'var(--text-2)', fontSize:12, padding:'7px 16px', cursor:'pointer', fontFamily:'var(--font-ui)' },
  pageInfo: { fontSize:12, color:'var(--text-3)', fontFamily:'var(--font-mono)' },
  tableWrap: { overflowX:'auto' },
  table: { width:'100%', borderCollapse:'collapse' },
  th: { padding:'8px 12px', textAlign:'left', fontSize:10, color:'var(--text-3)', fontFamily:'var(--font-mono)', textTransform:'uppercase', letterSpacing:'1px', borderBottom:'1px solid var(--border-1)', whiteSpace:'nowrap' },
  tr: { borderBottom:'1px solid rgba(139,92,246,0.05)' },
  td: { padding:'10px 12px', fontSize:13, color:'var(--text-1)', verticalAlign:'middle' },
  ticketTag: { background:'rgba(139,92,246,0.1)', color:'var(--purple-bright)', borderRadius:4, padding:'2px 7px', fontSize:10, fontFamily:'var(--font-mono)' },
  approveBtn: { background:'rgba(74,222,128,0.1)', border:'1px solid rgba(74,222,128,0.3)', borderRadius:6, color:'#4ade80', fontSize:13, padding:'4px 10px', cursor:'pointer' },
  rejectBtn: { background:'rgba(248,113,113,0.1)', border:'1px solid rgba(248,113,113,0.3)', borderRadius:6, color:'#f87171', fontSize:13, padding:'4px 10px', cursor:'pointer' },
  provisionBtn: { background:'rgba(139,92,246,0.1)', border:'1px solid var(--border-2)', borderRadius:6, color:'var(--purple-bright)', fontSize:11, padding:'4px 10px', cursor:'pointer', fontFamily:'var(--font-ui)' },
}
