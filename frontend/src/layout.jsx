import { useState, useMemo } from 'react'
import { useApp } from './AppContext.jsx'
import { PT, EN, PERM, formatDate } from './data.js'
import { Avatar } from './components.jsx'

const CHANGELOG = [
  { date: '19/05/2026', title: 'Banco de dados compartilhado (Supabase)', desc: 'Todos os usuários agora acessam os mesmos dados em tempo real, independente do navegador ou máquina.' },
  { date: '19/05/2026', title: 'Notificações navegáveis', desc: 'Clicar em uma notificação do sino agora abre o ticket correspondente diretamente.' },
  { date: '19/05/2026', title: 'Status renomeado', desc: '"Em triagem" passou a ser "Triado, aguardando atendimento" para mais clareza.' },
  { date: '19/05/2026', title: 'Capacidade dinâmica no dashboard', desc: 'O card de Capacidade Total agora considera o período selecionado (dia, semana, mês, ano).' },
  { date: '19/05/2026', title: 'Exportar CSV e PDF funcionando', desc: 'Relatórios e log de auditoria podem ser exportados para CSV. Relatórios também geram PDF para impressão.' },
  { date: '19/05/2026', title: 'Validação de e-mail duplicado', desc: 'O sistema impede criar dois usuários com o mesmo endereço de e-mail.' },
  { date: '18/05/2026', title: 'Sessão com expiração de 6h', desc: 'Login expira automaticamente após 6 horas, com modal de aviso.' },
  { date: '18/05/2026', title: 'Backup diário automático', desc: 'Backup em JSON baixado automaticamente todo dia às 23h (horário de Brasília).' },
  { date: '18/05/2026', title: 'Responsivo para mobile', desc: 'Sidebar com overlay, hamburger menu e tabelas com scroll horizontal em telas pequenas.' },
  { date: '17/05/2026', title: 'Recuperação de senha por e-mail', desc: 'Fluxo "Esqueci minha senha" envia código de 6 dígitos por e-mail para redefinição segura.' },
  { date: '17/05/2026', title: 'Autenticação real com hash SHA-256', desc: 'Senhas armazenadas com hash seguro — modo demo removido, pronto para uso em produção.' },
  { date: '17/05/2026', title: 'Anexos de tickets (Supabase Storage)', desc: 'Upload e download de arquivos diretamente no ticket.' },
]

export function Sidebar({ screen, setScreen }) {
  const { currentUser, lang, notifications, sidebar, setSidebar } = useApp()
  const t = lang === 'pt' ? PT : EN
  const p = PERM[currentUser.role]
  const collapsed = sidebar === 'collapsed'

  const items = [
    { key: 'dashboard',  icon: '📊', label: t.dashboard,  show: currentUser.role !== 'user' },
    { key: 'tickets',    icon: '🎫', label: t.tickets,    show: true },
    { key: 'new-ticket', icon: '➕', label: t.newTicket,  show: p.createTicket },
    { key: 'calendar',   icon: '📅', label: t.calendar,   show: p.calendar },
    { key: 'kb',         icon: '📚', label: t.kb,         show: true },
    { key: 'reports',    icon: '📈', label: t.reports,    show: p.reports },
  ]

  const settingsItems = p.settings ? [
    { key: 'settings-users',      label: t.users,       icon: '👥' },
    { key: 'settings-profiles',   label: t.profiles,    icon: '🔑' },
    { key: 'settings-categories', label: t.categories,  icon: '🏷️' },
    { key: 'settings-priorities', label: t.priorities,  icon: '🚦' },
    { key: 'settings-queues',     label: t.queues,      icon: '📋' },
    { key: 'settings-holidays',   label: t.holidays,    icon: '🎉' },
    { key: 'settings-audit',      label: t.auditLog,    icon: '📝' },
    { key: 'settings-system',     label: t.systemConfig,icon: '⚙️' },
  ] : []

  return (
    <div className={`sidebar ${collapsed ? 'collapsed' : ''}`}>
      <div className="logo">
        <span style={{ fontSize: 20, flexShrink: 0 }}>🎯</span>
        <span className="logo-text">DataTicket</span>
        <button
          style={{ marginLeft: 'auto', background: 'none', border: 'none', cursor: 'pointer', color: 'var(--text2)', fontSize: 14, flexShrink: 0 }}
          onClick={() => setSidebar(collapsed ? 'open' : 'collapsed')}
        >
          {collapsed ? '▶' : '◀'}
        </button>
      </div>

      <div className="sidebar-nav">
        {items.filter(x => x.show).map(i => (
          <div
            key={i.key}
            className={`nav-item ${screen === i.key ? 'active' : ''}`}
            onClick={() => { setScreen(i.key); if (window.innerWidth <= 768) setSidebar('collapsed') }}
            title={collapsed ? i.label : ''}
          >
            <span className="nav-icon">{i.icon}</span>
            <span className="nav-label">{i.label}</span>
          </div>
        ))}

        {settingsItems.length > 0 && (
          <>
            <div className="nav-section">{t.settings}</div>
            {settingsItems.map(i => (
              <div
                key={i.key}
                className={`nav-item ${screen === i.key ? 'active' : ''}`}
                onClick={() => { setScreen(i.key); if (window.innerWidth <= 768) setSidebar('collapsed') }}
                title={collapsed ? i.label : ''}
              >
                <span className="nav-icon">{i.icon}</span>
                <span className="nav-label">{i.label}</span>
              </div>
            ))}
          </>
        )}
      </div>

      <div className="sidebar-footer">
        <div className="nav-item" onClick={() => setScreen('profile')} title={collapsed ? 'Meu Perfil' : ''}>
          <Avatar user={currentUser} size={26} />
          <span className="nav-label" style={{ fontSize: 13 }}>{currentUser.firstName}</span>
        </div>
        {!collapsed && (
          <div style={{ padding: '8px 14px 4px', fontSize: 9.5, color: 'var(--text2)', lineHeight: 1.4, borderTop: '1px solid var(--border)', marginTop: 4 }}>
            Desenvolvido por<br />
            <strong style={{ fontSize: 10 }}>DataTry Tecnologia e Negócios</strong>
          </div>
        )}
      </div>
    </div>
  )
}

export function Topbar() {
  const {
    currentUser, setCurrentUser, lang, setLang, theme, setTheme,
    notifications, globalSearch, setGlobalSearch,
    tickets, articles, users, sidebar, setSidebar,
    markReadAction, markAllReadAction,
    setScreen, setSelectedTicket,
  } = useApp()
  const t = lang === 'pt' ? PT : EN
  const [showNotif, setShowNotif] = useState(false)
  const [showSearch, setShowSearch] = useState(false)
  const [showChangelog, setShowChangelog] = useState(false)
  const unread = notifications.filter(x => !x.read).length

  function markAll() { markAllReadAction().catch(() => {}) }
  function markOne(id) { markReadAction(id).catch(() => {}) }
  function openNotif(n) {
    markOne(n.id)
    setShowNotif(false)
    if (n.ticketId) { setSelectedTicket(n.ticketId); setScreen('ticket-detail') }
  }

  const searchResults = useMemo(() => {
    if (!globalSearch || globalSearch.length < 2) return []
    const q = globalSearch.toLowerCase()
    const tks = tickets
      .filter(tk => tk.title.toLowerCase().includes(q) || tk.id.toLowerCase().includes(q))
      .slice(0, 4).map(tk => ({ type: 'Ticket', id: tk.id, label: tk.title, sub: tk.id }))
    const arts = articles
      .filter(a => a.name.toLowerCase().includes(q) || a.keywords.toLowerCase().includes(q))
      .slice(0, 3).map(a => ({ type: 'Artigo', label: a.name }))
    // Admin e Manager têm acesso à lista de usuários
    const us = ['admin', 'manager'].includes(currentUser.role)
      ? users.filter(u => (u.firstName + ' ' + u.lastName).toLowerCase().includes(q) || u.email.toLowerCase().includes(q))
          .slice(0, 2).map(u => ({ type: 'Usuário', label: u.firstName + ' ' + u.lastName, sub: u.email }))
      : []
    return [...tks, ...arts, ...us]
  }, [globalSearch, tickets, articles, users, currentUser.role])

  return (
    <div className="topbar">
      {/* Botão hambúrguer — só aparece no mobile */}
      <button
        className="btn btn-secondary btn-icon mobile-menu-btn"
        style={{ flexShrink: 0 }}
        onClick={() => setSidebar(s => s === 'collapsed' ? 'open' : 'collapsed')}
        aria-label="Menu"
      >
        ☰
      </button>
      <div className="search-box" style={{ flex: '1 1 auto', maxWidth: 420, position: 'relative' }}>
        <span>🔍</span>
        <input
          placeholder={t.search + '…'}
          value={globalSearch}
          onChange={e => setGlobalSearch(e.target.value)}
          onFocus={() => setShowSearch(true)}
          onBlur={() => setTimeout(() => setShowSearch(false), 200)}
        />
        {showSearch && searchResults.length > 0 && (
          <div className="dropdown" style={{ top: '110%', left: 0, right: 0 }}>
            {searchResults.map((r, i) => (
              <div key={i} className="dropdown-item" style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
                <span style={{ fontSize: 10, background: 'var(--bg2)', padding: '1px 6px', borderRadius: 4, color: 'var(--text2)', flexShrink: 0 }}>{r.type}</span>
                <span style={{ overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{r.label}</span>
                {r.sub && <span style={{ fontSize: 11, color: 'var(--text2)', marginLeft: 'auto', flexShrink: 0 }}>{r.sub}</span>}
              </div>
            ))}
          </div>
        )}
      </div>

      <div style={{ marginLeft: 'auto', display: 'flex', alignItems: 'center', gap: 10 }}>
        {/* Indicador de conexão com a API */}
        <div
          title="Conectado ao Rails API"
          style={{ display: 'flex', alignItems: 'center', gap: 5, fontSize: 11, color: 'var(--text2)', userSelect: 'none', cursor: 'help' }}
        >
          <span style={{ width: 8, height: 8, borderRadius: '50%', flexShrink: 0, background: '#22c55e', display: 'inline-block' }} />
          <span className="hide-mobile">Online</span>
        </div>
        <button className="btn btn-secondary btn-sm" onClick={() => setLang(lang === 'pt' ? 'en' : 'pt')}>
          🌐 {lang === 'pt' ? 'EN' : 'PT'}
        </button>
        <button className="btn btn-secondary btn-sm" onClick={() => setTheme(theme === 'light' ? 'dark' : 'light')}>
          {theme === 'light' ? '🌙' : '☀️'}
        </button>

        {/* Changelog */}
        <div style={{ position: 'relative' }}>
          <button
            className="btn btn-secondary btn-sm"
            title="Novidades e atualizações"
            onClick={() => { setShowChangelog(!showChangelog); setShowNotif(false) }}
            style={{ position: 'relative' }}
          >
            🚀
          </button>
          {showChangelog && (
            <>
              <div style={{ position: 'fixed', inset: 0, zIndex: 299 }} onClick={() => setShowChangelog(false)} />
              <div className="dropdown" style={{ top: '110%', right: 0, width: 360, maxHeight: 480, overflowY: 'auto', zIndex: 300 }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '10px 14px', borderBottom: '1px solid var(--border)', position: 'sticky', top: 0, background: 'var(--bg)' }}>
                  <strong style={{ fontSize: 13 }}>🚀 Novidades do sistema</strong>
                  <span style={{ fontSize: 11, color: 'var(--text2)' }}>DataTicket</span>
                </div>
                {CHANGELOG.map((item, i) => (
                  <div key={i} style={{ padding: '10px 14px', borderBottom: '1px solid var(--border)' }}>
                    <div style={{ display: 'flex', justifyContent: 'space-between', gap: 8, marginBottom: 3 }}>
                      <strong style={{ fontSize: 12 }}>{item.title}</strong>
                      <span style={{ fontSize: 10, color: 'var(--text2)', flexShrink: 0 }}>{item.date}</span>
                    </div>
                    <div style={{ fontSize: 12, color: 'var(--text2)', lineHeight: 1.5 }}>{item.desc}</div>
                  </div>
                ))}
                <div style={{ padding: '8px 14px', fontSize: 11, color: 'var(--text2)', textAlign: 'center', borderTop: '1px solid var(--border)' }}>
                  Desenvolvido por <strong>DataTry Tecnologia e Negócios</strong>
                </div>
              </div>
            </>
          )}
        </div>

        {/* Notifications */}
        <div style={{ position: 'relative' }}>
          <button className="btn btn-secondary btn-sm" onClick={() => { setShowNotif(!showNotif); setShowChangelog(false) }} style={{ position: 'relative' }}>
            🔔
            {unread > 0 && (
              <span style={{ position: 'absolute', top: -4, right: -4, background: 'var(--danger)', color: '#fff', borderRadius: 10, padding: '1px 5px', fontSize: 9, fontWeight: 700 }}>
                {unread}
              </span>
            )}
          </button>
          {showNotif && (
            <div className="dropdown" style={{ top: '110%', right: 0, width: 320 }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '10px 12px', borderBottom: '1px solid var(--border)' }}>
                <strong style={{ fontSize: 13 }}>{t.notifications}</strong>
                <button style={{ background: 'none', border: 'none', color: 'var(--accent)', cursor: 'pointer', fontSize: 12 }} onClick={markAll}>{t.markAllRead}</button>
              </div>
              {notifications.length === 0 && <div style={{ padding: 16, color: 'var(--text2)', fontSize: 13, textAlign: 'center' }}>Sem notificações</div>}
              {notifications.slice(0, 8).map(n => (
                <div
                  key={n.id}
                  className="dropdown-item"
                  style={{ borderLeft: `3px solid ${n.read ? 'transparent' : 'var(--accent)'}`, padding: '10px 12px', cursor: n.ticketId ? 'pointer' : 'default' }}
                  onClick={() => openNotif(n)}
                >
                  <div style={{ display: 'flex', justifyContent: 'space-between', gap: 8 }}>
                    <strong style={{ fontSize: 13, color: n.read ? 'var(--text2)' : 'var(--text)' }}>{n.title}</strong>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 4, flexShrink: 0 }}>
                      {n.ticketId && <span style={{ fontSize: 9, background: 'var(--bg3)', padding: '1px 5px', borderRadius: 4, color: 'var(--text2)' }}>ver ticket</span>}
                      {!n.read && <div style={{ width: 7, height: 7, background: 'var(--accent)', borderRadius: '50%', marginTop: 1 }} />}
                    </div>
                  </div>
                  <div style={{ fontSize: 12, color: 'var(--text2)', marginTop: 2 }}>{n.desc}</div>
                  <div style={{ fontSize: 11, color: 'var(--text2)', marginTop: 4 }}>{formatDate(n.date)}</div>
                </div>
              ))}
            </div>
          )}
        </div>

        <Avatar user={currentUser} size={32} />
        <button className="btn btn-secondary btn-sm" onClick={() => { if (window.confirm('Sair do DataTicket?')) setCurrentUser(null) }}>
          ↩ {t.logout}
        </button>
      </div>
    </div>
  )
}
