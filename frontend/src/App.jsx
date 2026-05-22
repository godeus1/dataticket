import { useApp, AppProvider } from './AppContext.jsx'
import { PERM } from './data.js'
import { Toast } from './components.jsx'
import { Sidebar, Topbar } from './layout.jsx'
import LoginScreen from './screens/Login.jsx'
import * as Sentry from '@sentry/react'
import Dashboard from './screens/Dashboard.jsx'
import { TicketList, NewTicket, TicketDetail } from './screens/Tickets.jsx'
import { CalendarView, KnowledgeBase, Reports } from './screens/Other.jsx'
import {
  SettingsUsers, SettingsProfiles, SettingsCategories,
  SettingsPriorities, SettingsQueues, SettingsHolidays,
  SettingsAudit, SettingsSystem, MyProfile,
} from './screens/Settings.jsx'

function AppInner() {
  const { currentUser, screen, setScreen, toast, setToast, showToast, sidebar, setSidebar } = useApp()

  if (!currentUser) return <LoginScreen />

  const p = PERM[currentUser.role]

  function renderScreen() {
    // Redirect user role away from dashboard
    if (currentUser.role === 'user' && screen === 'dashboard') return <NewTicket />

    switch (screen) {
      case 'dashboard':         return <Dashboard />
      case 'tickets':           return <TicketList />
      case 'new-ticket':        return p.createTicket ? <NewTicket /> : <TicketList />
      case 'ticket-detail':     return <TicketDetail />
      case 'calendar':          return p.calendar ? <CalendarView /> : <TicketList />
      case 'kb':                return <KnowledgeBase />
      case 'reports':           return p.reports ? <Reports /> : <TicketList />
      case 'settings-users':    return p.settings ? <SettingsUsers /> : <TicketList />
      case 'settings-profiles': return p.settings ? <SettingsProfiles /> : <TicketList />
      case 'settings-categories':return p.settings ? <SettingsCategories /> : <TicketList />
      case 'settings-priorities':return p.settings ? <SettingsPriorities /> : <TicketList />
      case 'settings-queues':   return p.settings ? <SettingsQueues /> : <TicketList />
      case 'settings-holidays': return p.settings ? <SettingsHolidays /> : <TicketList />
      case 'settings-audit':    return p.settings ? <SettingsAudit /> : <TicketList />
      case 'settings-system':   return p.settings ? <SettingsSystem /> : <TicketList />
      case 'profile':           return <MyProfile />
      default:                  return <Dashboard />
    }
  }

  return (
    <div className="app">
      {/* Backdrop mobile: fecha sidebar ao clicar fora */}
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
  return (
    <Sentry.ErrorBoundary fallback={({ error, resetError }) => <ErrorFallback error={error} resetError={resetError} />}>
      <AppProvider>
        <AppInner />
      </AppProvider>
    </Sentry.ErrorBoundary>
  )
}
