import React, { useState, useEffect, useRef } from 'react'
import { useNavigate } from 'react-router-dom'

const LDAP_API = `http://${window.location.hostname}:5001`

export default function LoginPage({ onLogin }) {
  const [mode, setMode] = useState('landing')
  const [username, setUsername] = useState('')
  const [password, setPassword] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const canvasRef = useRef(null)
  const navigate = useNavigate()

  // Particle canvas
  useEffect(() => {
    const canvas = canvasRef.current
    if (!canvas) return
    const ctx = canvas.getContext('2d')
    let raf, particles = []
    const resize = () => { canvas.width = window.innerWidth; canvas.height = window.innerHeight }
    resize()
    window.addEventListener('resize', resize)
    for (let i = 0; i < 60; i++) particles.push({
      x: Math.random() * canvas.width, y: Math.random() * canvas.height,
      r: Math.random() * 1.5 + 0.3,
      vx: (Math.random() - 0.5) * 0.3, vy: (Math.random() - 0.5) * 0.3,
      a: Math.random() * 0.5 + 0.1,
    })
    function draw() {
      ctx.clearRect(0, 0, canvas.width, canvas.height)
      particles.forEach(p => {
        p.x += p.vx; p.y += p.vy
        if (p.x < 0) p.x = canvas.width
        if (p.x > canvas.width) p.x = 0
        if (p.y < 0) p.y = canvas.height
        if (p.y > canvas.height) p.y = 0
        ctx.beginPath(); ctx.arc(p.x, p.y, p.r, 0, Math.PI * 2)
        ctx.fillStyle = `rgba(139,92,246,${p.a})`; ctx.fill()
      })
      for (let i = 0; i < particles.length; i++)
        for (let j = i + 1; j < particles.length; j++) {
          const dx = particles[i].x - particles[j].x, dy = particles[i].y - particles[j].y
          const d = Math.sqrt(dx * dx + dy * dy)
          if (d < 100) {
            ctx.beginPath(); ctx.moveTo(particles[i].x, particles[i].y); ctx.lineTo(particles[j].x, particles[j].y)
            ctx.strokeStyle = `rgba(139,92,246,${0.08 * (1 - d / 100)})`; ctx.lineWidth = 0.5; ctx.stroke()
          }
        }
      raf = requestAnimationFrame(draw)
    }
    draw()
    return () => { cancelAnimationFrame(raf); window.removeEventListener('resize', resize) }
  }, [])

  async function handleLogin(e) {
    e.preventDefault()
    if (!username.trim() || !password.trim()) { setError('Enter your credentials.'); return }
    setLoading(true); setError('')
    try {
      const res = await fetch(`${LDAP_API}/ldap-login`, {
        method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ username: username.trim().toLowerCase(), password }),
      })
      const data = await res.json()
      if (data.success) {
        const det = await fetch(`${LDAP_API}/lookup`, {
          method: 'POST', headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ username: username.trim().toLowerCase() }),
        })
        const d2 = await det.json()
        onLogin({
          username: username.trim().toLowerCase(),
          displayName: d2.success ? d2.data.displayName : username,
          department: d2.success ? d2.data.department : '',
          email: d2.success ? d2.data.email : '',
          title: d2.success ? d2.data.title : '',
          isAnonymous: false,
        })
        navigate('/chat')
      } else {
        setError('Invalid username or password.')
      }
    } catch {
      setError(`Cannot reach server. Is ldap-api running on port 5001?`)
    } finally {
      setLoading(false)
    }
  }

  function handleAnonymous() {
    onLogin({
      username: `guest_${Math.random().toString(36).slice(2, 7)}`,
      displayName: 'Anonymous', department: '', email: '', title: '', isAnonymous: true,
    })
    navigate('/chat')
  }

  return (
    <div style={s.root}>
      <canvas ref={canvasRef} style={s.canvas} />
      <div style={s.orb1} /><div style={s.orb2} /><div style={s.orb3} />

      <div style={s.wrap}>
        {/* Logo */}
        <div style={s.logo}>
          <svg width="40" height="40" viewBox="0 0 36 36" fill="none">
            <polygon points="18,2 32,10 32,26 18,34 4,26 4,10" fill="rgba(139,92,246,0.15)" stroke="#8b5cf6" strokeWidth="1.5"/>
            <circle cx="18" cy="18" r="7" fill="#8b5cf6"/>
            <circle cx="18" cy="18" r="3" fill="#f0ecff"/>
          </svg>
          <div>
            <div style={s.logoName}>HelpBot</div>
            <div style={s.logoTag}>IT Support Intelligence</div>
          </div>
        </div>

        {/* Landing */}
        {mode === 'landing' && (
          <div style={s.card}>
            <div style={s.cardHead}>
              <div style={s.cardTitle}>Welcome back</div>
              <div style={s.cardSub}>Sign in with your company account or continue as a guest.</div>
            </div>
            <button style={s.btnPrimary} onClick={() => setMode('login')}>
              <LockIcon /> Sign in with AD Account
            </button>
            <div style={s.divider}><span>or</span></div>
            <button style={s.btnGhost} onClick={handleAnonymous}>
              <GuestIcon /> Continue as Guest
            </button>
            <p style={s.notice}>⚠️ Guest mode: read-only. Cannot unlock accounts, reset passwords, or create tickets. AD login required for full access.</p>
          </div>
        )}

        {/* Login form */}
        {mode === 'login' && (
          <form style={s.card} onSubmit={handleLogin}>
            <button type="button" style={s.back} onClick={() => { setMode('landing'); setError('') }}>
              ← Back
            </button>
            <div style={s.cardHead}>
              <div style={s.cardTitle}>AD Authentication</div>
              <div style={s.cardSub}>Enter your company credentials to continue.</div>
            </div>

            <div style={s.field}>
              <label style={s.label}>Username</label>
              <div style={s.inputRow}>
                <UserIcon />
                <input style={s.input} type="text" placeholder="jdoe"
                  value={username} onChange={e => setUsername(e.target.value)}
                  autoFocus autoComplete="username" />
              </div>
            </div>

            <div style={s.field}>
              <label style={s.label}>Password</label>
              <div style={s.inputRow}>
                <KeyIcon />
                <input style={s.input} type="password" placeholder="••••••••••"
                  value={password} onChange={e => setPassword(e.target.value)}
                  autoComplete="current-password" />
              </div>
            </div>

            {error && <div style={s.err}>{error}</div>}

            <button type="submit" style={{ ...s.btnPrimary, justifyContent: 'center' }} disabled={loading}>
              {loading ? <Spin /> : <LockIcon />}
              {loading ? 'Authenticating…' : 'Sign In'}
            </button>
          </form>
        )}
      </div>
    </div>
  )
}

const LockIcon = () => <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><rect x="3" y="11" width="18" height="11" rx="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/></svg>
const GuestIcon = () => <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/></svg>
const UserIcon = () => <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" style={{color:'var(--text-3)',flexShrink:0}}><path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/></svg>
const KeyIcon = () => <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" style={{color:'var(--text-3)',flexShrink:0}}><circle cx="7.5" cy="15.5" r="5.5"/><path d="M21 2l-9.6 9.6M15.5 7.5l3 3"/></svg>
const Spin = () => <div style={{width:14,height:14,border:'2px solid rgba(255,255,255,0.2)',borderTopColor:'#fff',borderRadius:'50%',animation:'spin .7s linear infinite'}}/>

const s = {
  root: { position:'fixed', inset:0, display:'flex', alignItems:'center', justifyContent:'center', background:'var(--bg-void)', overflow:'hidden' },
  canvas: { position:'absolute', inset:0, pointerEvents:'none' },
  orb1: { position:'absolute', width:700, height:700, borderRadius:'50%', background:'radial-gradient(circle, rgba(109,40,217,0.2) 0%, transparent 65%)', top:-300, left:-200, pointerEvents:'none' },
  orb2: { position:'absolute', width:500, height:500, borderRadius:'50%', background:'radial-gradient(circle, rgba(139,92,246,0.12) 0%, transparent 65%)', bottom:-200, right:-100, pointerEvents:'none' },
  orb3: { position:'absolute', width:350, height:350, borderRadius:'50%', background:'radial-gradient(circle, rgba(34,211,238,0.07) 0%, transparent 65%)', top:'35%', right:'15%', pointerEvents:'none' },
  wrap: { position:'relative', zIndex:10, width:'100%', maxWidth:420, padding:'0 20px', display:'flex', flexDirection:'column', alignItems:'center', gap:28 },
  logo: { display:'flex', alignItems:'center', gap:14, animation:'fadeUp .6s ease both' },
  logoName: { fontSize:30, fontWeight:800, background:'linear-gradient(135deg,#c4b5fd,#8b5cf6,#22d3ee)', WebkitBackgroundClip:'text', WebkitTextFillColor:'transparent', letterSpacing:'-0.5px' },
  logoTag: { fontSize:10, color:'var(--text-3)', textTransform:'uppercase', letterSpacing:'2.5px', fontFamily:'var(--font-mono)' },
  card: { width:'100%', background:'rgba(18,16,42,0.92)', backdropFilter:'blur(24px)', border:'1px solid var(--border-2)', borderRadius:22, padding:28, display:'flex', flexDirection:'column', gap:18, animation:'fadeUp .5s .1s ease both', boxShadow:'0 24px 64px rgba(0,0,0,0.5)' },
  cardHead: { display:'flex', flexDirection:'column', gap:6 },
  cardTitle: { fontSize:21, fontWeight:700, color:'var(--text-1)' },
  cardSub: { fontSize:13, color:'var(--text-2)', lineHeight:1.6 },
  btnPrimary: { display:'flex', alignItems:'center', gap:10, padding:'13px 20px', background:'linear-gradient(135deg,#7c3aed,#6d28d9)', border:'none', borderRadius:10, color:'#fff', fontSize:14, fontWeight:600, cursor:'pointer', fontFamily:'var(--font-ui)', boxShadow:'0 4px 20px rgba(109,40,217,0.4)', width:'100%' },
  btnGhost: { display:'flex', alignItems:'center', gap:10, padding:'13px 20px', background:'transparent', border:'1px solid var(--border-2)', borderRadius:10, color:'var(--text-2)', fontSize:14, cursor:'pointer', fontFamily:'var(--font-ui)', width:'100%' },
  divider: { textAlign:'center', color:'var(--text-3)', fontSize:11, fontFamily:'var(--font-mono)', position:'relative' },
  notice: { fontSize:11, color:'var(--text-3)', textAlign:'center', fontFamily:'var(--font-mono)', paddingTop:6, borderTop:'1px solid var(--border-1)' },
  back: { background:'none', border:'none', color:'var(--text-3)', fontSize:12, cursor:'pointer', fontFamily:'var(--font-ui)', textAlign:'left', padding:0 },
  field: { display:'flex', flexDirection:'column', gap:6 },
  label: { fontSize:10, fontWeight:600, color:'var(--text-2)', textTransform:'uppercase', letterSpacing:'1.5px', fontFamily:'var(--font-mono)' },
  inputRow: { display:'flex', alignItems:'center', gap:10, background:'var(--bg-deep)', border:'1px solid var(--border-1)', borderRadius:8, padding:'0 14px' },
  input: { flex:1, background:'none', border:'none', outline:'none', color:'var(--text-1)', fontSize:14, fontFamily:'var(--font-mono)', padding:'12px 0' },
  err: { background:'rgba(248,113,113,0.08)', border:'1px solid rgba(248,113,113,0.25)', borderRadius:8, padding:'10px 14px', fontSize:12, color:'var(--red)', fontFamily:'var(--font-mono)' },
}
