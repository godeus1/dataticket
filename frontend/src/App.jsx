import { useLocation } from 'react-router-dom'
import { useApp, AppProvider } from './AppContext.jsx'
import { PERM } from './data.js'
import { Toast } from './components.jsx'
import { Sidebar, Topbar } from './layout.jsx'
import LoginScreen from './screens/Login.jsx'
import CsatPage from './screens/Csat.jsx'
import * as Sentry from '@sentry/react'
import Dashboard from './screens/Dashboard.jsx'
import { TicketList, NewTicket, TicketDetail } from './screens/Tickets.jsx'
import { CalendarView, KnowledgeBase, Reports } from './screens/Other.jsx'
import {
  SettingsUsers, SettingsProfiles, SettingsCategories,
  SettingsPriorities, SettingsQueues, SettingsHolidays,
  SettingsAudit, SettingsSystem, MyProfile, SettingsCompanies,
} from './screens/Settings.jsx'
import { SettingsTrash } from './screens/Trash.jsx'
import { useState, useEffect, useRef } from 'react'
import { api, getToken } from './api.js'

// ── Helpers de localStorage para o timer (espelham Tickets.jsx) ───────────
function getActiveTimerGlobal(userId) {
  try { return JSON.parse(localStorage.getItem(`dt_active_timer_${userId}`) || 'null') }
  catch { return null }
}
function clearActiveTimerGlobal(userId) {
  try { localStorage.removeItem(`dt_active_timer_${userId}`) } catch {}
}

// ── Popup de inatividade (20 min sem interação) ───────────────────────────
function GlobalTimerWatcher({ currentUser, setSelectedTicket }) {
  const [popupVisible, setPopupVisible]   = useState(false)
  const [countdown, setCountdown]         = useState(20)
  const [activeInfo, setActiveInfo]       = useState(null)
  const countdownRef                      = useRef(null)
  const autoStopRef                       = useRef(null)

  // Verifica a cada 30s se há timer ativo com > 20 min
  useEffect(() => {
    if (!currentUser) return
    const CHECK_MS    = 30_000
    const WARN_MINS   = 20
    const AUTO_STOP_S = 20

    function check() {
      const active = getActiveTimerGlobal(currentUser.id)
      if (!active || !active.startTime || !active.sessionId) return
      const elapsedMins = (Date.now() - new Date(active.startTime).getTime()) / 60_000
      if (elapsedMins >= WARN_MINS && !popupVisible) {
        setActiveInfo(active)
        setCountdown(AUTO_STOP_S)
        setPopupVisible(true)
      }
    }

    const id = setInterval(check, CHECK_MS)
    check() // verifica imediatamente ao montar
    return () => clearInterval(id)
  }, [currentUser, popupVisible]) // eslint-disable-line react-hooks/exhaustive-deps

  // Contagem regressiva quando o popup está visível
  useEffect(() => {
    if (!popupVisible) return
    countdownRef.current = setInterval(() => {
      setCountdown(prev => {
        if (prev <= 1) {
          clearInterval(countdownRef.current)
          handleAutoStop()
          return 0
        }
        return prev - 1
      })
    }, 1000)
    return () => clearInterval(countdownRef.current)
  }, [popupVisible]) // eslint-disable-line react-hooks/exhaustive-deps

  function handleAutoStop() {
    const active = getActiveTimerGlobal(currentUser.id)
    if (active?.sessionId) {
      api.stopTimerSession(active.ticketId, active.sessionId).catch(() => {})
      clearActiveTimerGlobal(currentUser.id)
    }
    setPopupVisible(false)
    setActiveInfo(null)
  }

  function handleStillWorking() {
    clearInterval(countdownRef.current)
    setPopupVisible(false)
    setActiveInfo(null)
    // Reseta o startTime para "agora" para evitar novo disparo imediato
    const active = getActiveTimerGlobal(currentUser.id)
    if (active) {
      try {
        localStorage.setItem(`dt_active_timer_${currentUser.id}`, JSON.stringify({
          ...active, startTime: new Date().toISOString()
        }))
      } catch {}
    }
  }

  function handleGoToTicket() {
    clearInterval(countdownRef.current)
    setPopupVisible(false)
    if (activeInfo?.ticketId) setSelectedTicket(activeInfo.ticketId)
  }

  if (!popupVisible || !activeInfo) return null

  return (
    <div style={{
      position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.55)',
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      zIndex: 99999,
    }}>
      <div style={{
        background: 'var(--bg)', border: '1px solid var(--border)',
        borderRadius: 16, padding: 32, maxWidth: 400, width: '90%',
        textAlign: 'center', boxShadow: '0 8px 40px rgba(0,0,0,.22)',
      }}>
        <div style={{ fontSize: 40, marginBottom: 12 }}>⏱</div>
        <h3 style={{ fontWeight: 700, fontSize: 18, marginBottom: 8 }}>
          Você ainda está trabalhando?
        </h3>
        <p style={{ color: 'var(--text2)', fontSize: 13, marginBottom: 6, lineHeight: 1.6 }}>
          O cronômetro do ticket <strong style={{ color: 'var(--accent)' }}>#{activeInfo.ticketId}</strong> está ativo há mais de 20 minutos.
        </p>
        <p style={{ color: 'var(--text2)', fontSize: 12, marginBottom: 20 }}>
          {activeInfo.ticketTitle && <em>"{activeInfo.ticketTitle}"</em>}
        </p>

        {/* Countdown bar */}
        <div style={{ background: 'var(--bg2)', borderRadius: 8, height: 6, marginBottom: 8, overflow: 'hidden' }}>
          <div style={{
            height: '100%', borderRadius: 8, background: countdown > 10 ? 'var(--accent)' : 'var(--danger)',
            width: `${(countdown / 20) * 100}%`, transition: 'width 1s linear, background 0.3s',
          }} />
        </div>
        <p style={{ fontSize: 12, color: 'var(--text2)', marginBottom: 20 }}>
          Timer será pausado automaticamente em <strong style={{ color: countdown <= 5 ? 'var(--danger)' : 'var(--text)' }}>{countdown}s</strong>
        </p>

        <div style={{ display: 'flex', gap: 10, flexDirection: 'column' }}>
          <button className="btn btn-primary" onClick={handleStillWorking} style={{ width: '100%', padding: 11 }}>
            ✅ Sim, ainda estou trabalhando
          </button>
          <button className="btn btn-secondary" onClick={handleGoToTicket} style={{ width: '100%' }}>
            🎫 Ir ao ticket #{activeInfo.ticketId}
          </button>
          <button className="btn btn-danger" onClick={handleAutoStop} style={{ width: '100%' }}>
            ⏸ Pausar cronômetro agora
          </button>
        </div>
      </div>
    </div>
  )
}

function AppInner() {
  const { currentUser, screen, setScreen, toast, setToast, sidebar, setSidebar, setSelectedTicket } = useApp()

  // ── Abre ticket via hash URL (#ticket/PREFIXO-xxx) — suporte ao botão do meio ─
  // Aceita qualquer prefixo de empresa (ex: TK-0001, SALV-0001, DTRY-0001).
  useEffect(() => {
    if (!currentUser) return
    const m = window.location.hash.match(/^#ticket\/([A-Z][A-Z0-9]*-\d+)$/)
    if (m) {
      setSelectedTicket(m[1])
      setScreen('ticket-detail')
      window.history.replaceState(null, '', window.location.pathname + window.location.search)
    }
  }, [currentUser]) // eslint-disable-line

  // ── Pausa o timer automaticamente ao fechar o navegador / aba ───────────
  useEffect(() => {
    if (!currentUser) return
    function handleUnload() {
      const active = getActiveTimerGlobal(currentUser.id)
      if (!active?.sessionId) return
      const token = getToken()
      const BASE   = import.meta.env.VITE_API_URL ?? '/api/v1'
      const url    = `${BASE}/tickets/${active.ticketId}/timer_sessions/${active.sessionId}/stop`
      // keepalive permite que o request complete mesmo após o unload
      fetch(url, {
        method: 'PATCH',
        keepalive: true,
        headers: {
          'Content-Type': 'application/json',
          ...(token ? { Authorization: `Bearer ${token}` } : {}),
        },
        body: JSON.stringify({}),
      }).catch(() => {})
      clearActiveTimerGlobal(currentUser.id)
    }
    window.addEventListener('beforeunload', handleUnload)
    return () => window.removeEventListener('beforeunload', handleUnload)
  }, [currentUser])

  if (!currentUser) return <LoginScreen />

  const p = PERM[currentUser.role] || PERM.user  // fallback defensivo: papel desconhecido nunca quebra o app

  function renderScreen() {
    // Redirect user role away from dashboard → ticket list (backend filters to their own tickets)
    if (currentUser.role === 'user' && screen === 'dashboard') return <TicketList />

    switch (screen) {
      case 'dashboard':          return <Dashboard />
      case 'tickets':            return <TicketList />
      case 'new-ticket':         return p.createTicket ? <NewTicket /> : <TicketList />
      case 'ticket-detail':      return <TicketDetail />
      case 'calendar':           return p.calendar ? <CalendarView /> : <TicketList />
      case 'kb':                 return <KnowledgeBase />
      case 'reports':            return p.reports ? <Reports /> : <TicketList />
      case 'settings-companies': return currentUser.role === 'msp_admin' ? <SettingsCompanies /> : <TicketList />
      case 'settings-users':     return p.settings ? <SettingsUsers /> : <TicketList />
      case 'settings-profiles':  return p.settings ? <SettingsProfiles /> : <TicketList />
      case 'settings-categories':return p.settings ? <SettingsCategories /> : <TicketList />
      case 'settings-priorities':return p.settings ? <SettingsPriorities /> : <TicketList />
      case 'settings-queues':    return p.settings ? <SettingsQueues /> : <TicketList />
      case 'settings-holidays':  return p.settings ? <SettingsHolidays /> : <TicketList />
      case 'settings-audit':     return p.settings ? <SettingsAudit /> : <TicketList />
      case 'settings-system':    return p.settings ? <SettingsSystem /> : <TicketList />
      case 'settings-trash':     return p.trash    ? <SettingsTrash /> : <TicketList />
      case 'profile':            return <MyProfile />
      default:                   return <Dashboard />
    }
  }

  return (
    <div className="app">
      {sidebar !== 'collapsed' && (
        <div className="sidebar-backdrop" onClick={() => setSidebar('collapsed')} />
      )}
      <Sidebar screen={screen} setScreen={setScreen} />
      <div className="main">
        <Topbar />
        <div className="content">
          {renderScreen()}
        </div>
      </div>
      {toast && <Toast msg={toast} onClose={() => setToast(null)} />}
      {/* Popup global de inatividade de 20min — visível em qualquer tela */}
      <GlobalTimerWatcher currentUser={currentUser} setSelectedTicket={setSelectedTicket} />
    </div>
  )
}

function ErrorFallback({ error, resetError }) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', height: '100vh', gap: 16, padding: 32, textAlign: 'center' }}>
      <div style={{ fontSize: 40 }}>⚠️</div>
      <div style={{ fontWeight: 700, fontSize: 18 }}>Algo deu errado</div>
      <div style={{ color: 'var(--text2)', fontSize: 13, maxWidth: 420 }}>
        Este erro foi registrado automaticamente. Tente recarregar a página.
      </div>
      <code style={{ background: 'var(--bg2)', padding: '8px 14px', borderRadius: 6, fontSize: 11, color: 'var(--danger)', maxWidth: 500, overflowWrap: 'break-word' }}>
        {error?.message}
      </code>
      <div style={{ display: 'flex', gap: 10 }}>
        <button className="btn btn-primary" onClick={resetError}>Tentar novamente</button>
        <button className="btn btn-secondary" onClick={() => window.location.reload()}>Recarregar página</button>
      </div>
    </div>
  )
}

export default function App() {
  const location = useLocation()

  // CSAT — página pública completamente separada do app autenticado
  if (location.pathname.startsWith('/csat/')) return <CsatPage />

  return (
    <Sentry.ErrorBoundary fallback={({ error, resetError }) => <ErrorFallback error={error} resetError={resetError} />}>
      <AppProvider>
        <AppInner />
      </AppProvider>
    </Sentry.ErrorBoundary>
  )
}
