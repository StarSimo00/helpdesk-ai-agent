import React, { useState, useEffect } from 'react'
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom'
import LoginPage from './components/LoginPage'
import ChatPage from './components/ChatPage'
import DashboardPage from './components/DashboardPage.jsx'

function genSessionId(username) {
  const r = Math.random().toString(36).slice(2, 8)
  const t = Date.now().toString(36)
  return `${username || 'anon'}-${t}-${r}`
}

export default function App() {
  const [user, setUser] = useState(null)

  useEffect(() => {
    try {
      // AD users: persist across browser sessions via localStorage
      const s = localStorage.getItem('hb_identity')
      if (s) {
        const identity = JSON.parse(s)
        // Always fresh sessionId (new chat) but keep identity
        setUser({ ...identity, sessionId: genSessionId(identity.username) })
      }
    } catch {}
  }, [])

  function handleLogin(data) {
    const identity = {
      username: data.username,
      displayName: data.displayName,
      department: data.department,
      email: data.email,
      title: data.title,
      isAnonymous: data.isAnonymous,
    }
    if (!data.isAnonymous) {
      // Persist AD identity in localStorage so refresh = auto-login
      localStorage.setItem('hb_identity', JSON.stringify(identity))
    }
    setUser({ ...identity, sessionId: genSessionId(data.username) })
  }

  function handleLogout() {
    localStorage.removeItem('hb_identity')
    sessionStorage.removeItem('hb_identity')
    setUser(null)
  }

  return (
    <BrowserRouter>
      <Routes>
        <Route path="/login" element={
          user ? <Navigate to="/chat" replace /> : <LoginPage onLogin={handleLogin} />
        } />
        <Route path="/chat" element={
          user ? <ChatPage user={user} onLogout={handleLogout} /> : <Navigate to="/login" replace />
        } />
        <Route path="/dashboard" element={
          user && !user.isAnonymous && user.department === 'IT'
            ? <DashboardPage user={user} onLogout={handleLogout} />
            : <Navigate to="/chat" replace />
        } />
        <Route path="*" element={<Navigate to={user ? "/chat" : "/login"} replace />} />
      </Routes>
    </BrowserRouter>
  )
}
