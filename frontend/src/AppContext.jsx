import { createContext, useContext, useState, useEffect, useRef, useCallback, useMemo } from 'react'
import { useNavigate, useLocation } from 'react-router-dom'
import * as Sentry from '@sentry/react'
import { api, getToken, setToken, setOn401Handler, getCurrentOrg, setCurrentOrg, setActiveOrg } from './api.js'
import {
  mapUser, mapTicket, mapPriority, mapCategory, mapQueue,
  mapHoliday, mapArticle, mapNotification, mapAuditLog, mapOrganization, mapComment,
} from './mapper.js'
import { INITIAL_SYSTEM_CONFIG } from './data.js'

export const AppCtx = createContext(null)
export const useApp = () => useContext(AppCtx)

// ── Screen ↔ URL mapping ──────────────────────────────────────────────────

export const SCREEN_TO_PATH = {
  'dashboard':              '/painel',
  'tickets':               '/tickets',
  'new-ticket':            '/novo-ticket',
  'ticket-detail':         '/tickets',   // use setSelectedTicket(id) for the real path
  'calendar':              '/calendario',
  'kb':                    '/base-de-conhecimento',
  'reports':               '/relatorios',
  'settings-users':        '/usuarios',
  'settings-profiles':     '/perfis',
  'settings-categories':   '/categoria',
  'settings-priorities':   '/prioridades',
  'settings-queues':       '/filas',
  'settings-holidays':     '/feriados',
  'settings-audit':        '/log-de-auditoria',
  'settings-system':       '/config-sistema',
  'settings-trash':        '/lixeira',
  'settings-companies':    '/empresas',
  'settings-emails':       '/emails',
  'profile':               '/perfil',
}

function pathToScreen(pathname) {
  if (/^\/tickets\/.+$/.test(pathname)) return 'ticket-detail'
  const MAP = {
    '/':                          'dashboard',
    '/painel':                    'dashboard',
    '/tickets':                   'tickets',
    '/novo-ticket':               'new-ticket',
    '/calendario':                'calendar',
    '/base-de-conhecimento':      'kb',
    '/relatorios':                'reports',
    '/usuarios':                  'settings-users',
    '/perfis':                    'settings-profiles',
    '/categoria':                 'settings-categories',
    '/prioridades':               'settings-priorities',
    '/filas':                     'settings-queues',
    '/feriados':                  'settings-holidays',
    '/log-de-auditoria':          'settings-audit',
    '/config-sistema':            'settings-system',
    '/lixeira':                   'settings-trash',
    '/empresas':                  'settings-companies',
    '/emails':                    'settings-emails',
    '/perfil':                    'profile',
  }
  return MAP[pathname] ?? 'dashboard'
}

// ── localStorage helpers ──────────────────────────────────────────────────
function ls(key, fallback) {
  try { const r = localStorage.getItem(key); return r ? JSON.parse(r) : fallback } catch { return fallback }
}
function lsSave(key, val) {
  try { localStorage.setItem(key, JSON.stringify(val)) } catch {}
}

export function AppProvider({ children }) {
  // ── Boot / loading state ──────────────────────────────────────────────
  const [dbReady,      setDbReady]      = useState(false)
  const [loadingData,  setLoadingData]  = useState(false)
  const [apiError,     setApiError]     = useState(null)

  // ── Data state ────────────────────────────────────────────────────────
  const [users,         setUsers]         = useState([])
  const [tickets,       setTickets]       = useState([])
  const [categories,    setCategories]    = useState([])
  const [priorities,    setPriorities]    = useState([])
  const [queues,        setQueues]        = useState([])
  const [holidays,      setHolidays]      = useState([])
  const [articles,      setArticles]      = useState([])
  const [notifications, setNotifications] = useState([])
  const [auditLog,      setAuditLog]      = useState([])
  const [savedViews,    setSavedViews]    = useState([])
  const [systemConfig,  setSystemConfig]  = useState(() => ls('dt_config', INITIAL_SYSTEM_CONFIG))

  // ── Session state ─────────────────────────────────────────────────────
  const [currentUserState,   setCurrentUserState]   = useState(null)
  const [sessionExpiredMsg,  setSessionExpiredMsg]  = useState(false)
  const [welcomeUser,        setWelcomeUser]        = useState(null)  // popup de boas-vindas pós-login

  // ── Multi-empresa (msp_admin troca entre empresas) ────────────────────
  const [availableOrgs, setAvailableOrgs] = useState([])
  const [currentOrgId,  setCurrentOrgId]  = useState(() => getCurrentOrg())

  // Mantém o header X-Organization-Id atrelado ao estado DESTA aba (e não ao
  // localStorage compartilhado), evitando que abas com empresas diferentes
  // enviem requisições para a empresa errada. Roda já na montagem.
  if (typeof window !== 'undefined') setActiveOrg(currentOrgId)
  useEffect(() => { setActiveOrg(currentOrgId) }, [currentOrgId])

  // ── Routing ───────────────────────────────────────────────────────────
  const navigate = useNavigate()
  const location = useLocation()

  // screen e selectedTicket são derivados da URL — não há useState para eles
  const screen = useMemo(() => pathToScreen(location.pathname), [location.pathname])
  const selectedTicket = useMemo(() => {
    const m = location.pathname.match(/^\/tickets\/(.+)$/)
    return m ? m[1] : null
  }, [location.pathname])

  function setScreen(key) {
    navigate(SCREEN_TO_PATH[key] ?? '/dashboard')
  }

  function setSelectedTicket(id) {
    if (id) navigate(`/tickets/${id}`)
    else navigate('/tickets')
  }

  // ── UI state ──────────────────────────────────────────────────────────
  const [lang,          setLang]          = useState(() => ls('dt_lang',  'pt'))
  const [theme,         setTheme]         = useState(() => ls('dt_theme', 'light'))
  const [sidebar,       setSidebar]       = useState(() => typeof window !== 'undefined' && window.innerWidth <= 768 ? 'collapsed' : 'open')
  const [globalSearch,  setGlobalSearch]  = useState('')
  const [toast,         setToast]         = useState(null)

  // ── Load all application data from Rails API ──────────────────────────
  // Usa settle() para que um 403 em /users ou /queues (role:user não tem
  // acesso) não cancele o Promise.all inteiro e deixe categorias vazias.
  // 401 ainda expira a sessão; qualquer outro erro vira array vazio.
  const loadData = useCallback(async () => {
    const settle = (p) => p.then(v => ({ ok: true, value: v })).catch(e => ({ ok: false, error: e }))

    const [
      usersRes, ticketsRes, catsRes, prisRes,
      queuesRes, holidaysRes, articlesRes, notifRes, orgRes, auditRes, orgsRes, viewsRes,
    ] = await Promise.all([
      settle(api.users()),
      settle(api.tickets()),
      settle(api.categories()),
      settle(api.priorities()),
      settle(api.queues()),
      settle(api.holidays()),
      settle(api.articles()),
      settle(api.notifications()),
      settle(api.organization()),
      settle(api.auditLogs()),
      settle(api.organizations()),
      settle(api.savedViews()),
    ])

    // Se qualquer endpoint retornar 401 a sessão expirou
    const allRes = [usersRes, ticketsRes, catsRes, prisRes, queuesRes, holidaysRes, articlesRes, notifRes, orgRes]
    const expired = allRes.find(r => !r.ok && r.error?.status === 401)
    if (expired) {
      setToken(null)
      setCurrentUserState(null)
      setSessionExpiredMsg(true)
      return
    }

    const val = (r, fallback = []) => (r.ok ? r.value : fallback)

    const usersData    = val(usersRes)
    const ticketsData  = val(ticketsRes)
    const catsData     = val(catsRes)
    const prisData     = val(prisRes)
    const queuesData   = val(queuesRes)
    const holidaysData = val(holidaysRes)
    const articlesData = val(articlesRes)
    const notifData    = val(notifRes)
    const orgData      = val(orgRes, null)
    const auditData    = val(auditRes)

    setUsers(         (usersData  ?? []).map(mapUser))
    setTickets(       (ticketsData?.tickets ?? ticketsData ?? []).map(mapTicket))
    setCategories(    (catsData   ?? []).map(mapCategory))
    setPriorities(    (prisData   ?? []).map(mapPriority))
    setQueues(        (queuesData ?? []).map(mapQueue))
    setHolidays(      (holidaysData ?? []).map(mapHoliday))
    setArticles(      (articlesData ?? []).map(mapArticle))
    setNotifications( (notifData  ?? []).map(mapNotification))
    setAuditLog(      (auditData  ?? []).map(mapAuditLog))
    if (orgData) setSystemConfig(mapOrganization(orgData))
    setAvailableOrgs(val(orgsRes, []) ?? [])
    setSavedViews(val(viewsRes, []) ?? [])
  }, [])

  // ── Interceptor global de 401 — desloga automaticamente ─────────────
  // O aviso "Sessão expirada" só deve aparecer quando uma sessão ATIVA expira
  // de verdade — nunca durante um logout intencional (requisições em voo com
  // o token já revogado devolvem 401) nem quando não há usuário logado.
  const loggingOutRef   = useRef(false)
  const currentUserRef  = useRef(null)
  useEffect(() => { currentUserRef.current = currentUserState }, [currentUserState])
  useEffect(() => {
    setOn401Handler(() => {
      if (loggingOutRef.current || !currentUserRef.current) return
      setToken(null)
      setCurrentUserState(null)
      setSessionExpiredMsg(true)
    })
  }, [])

  // ── Restore session on app boot ───────────────────────────────────────
  // Tenta restaurar até 4x com backoff para suportar cold-start do Railway.
  // Só apaga o token em 401 genuíno — nunca em erros de rede ou 5xx.
  useEffect(() => {
    const token = getToken()
    if (!token) { setDbReady(true); return }

    let cancelled = false

    async function restore(attempt) {
      try {
        const userData = await api.me()
        if (cancelled) return
        const user = mapUser(userData)
        setCurrentUserState(user)
        Sentry.setUser({ id: String(user.id), email: user.email, username: `${user.firstName} ${user.lastName}`, role: user.role })
        await loadData()
        if (!cancelled) setDbReady(true)
      } catch (err) {
        if (cancelled) return
        if (err?.status === 401) {
          // Token genuinamente expirado ou inválido — faz logout imediatamente
          setToken(null)
          setDbReady(true)
        } else if (attempt < 4) {
          // Erro transitório (servidor acordando, rede instável) — aguarda e tenta novamente
          setTimeout(() => restore(attempt + 1), 1500 * attempt)
        } else {
          // Esgotou tentativas — mantém o token (pode ser só o servidor dormindo)
          // e exibe tela normal; próxima ação do usuário vai reautenticar
          setApiError('Servidor indisponível. Verifique sua conexão e recarregue.')
          setDbReady(true)
        }
      }
    }

    restore(1)
    return () => { cancelled = true }
  }, [loadData])

  // ── Carrega a lista de empresas do seletor de forma INDEPENDENTE ─────────
  // Não fica acoplada ao loadData (onde um mapper que falhe poderia pular a
  // etapa). Sempre que houver usuário logado, busca /organizations direto.
  useEffect(() => {
    if (!currentUserState) { setAvailableOrgs([]); return }
    let cancelled = false
    api.organizations()
      .then(orgs => { if (!cancelled) setAvailableOrgs(Array.isArray(orgs) ? orgs : []) })
      .catch(() => {})
    return () => { cancelled = true }
  }, [currentUserState])

  // ── Sync currentUser when users list changes ──────────────────────────
  useEffect(() => {
    if (currentUserState) {
      const fresh = users.find(u => u.id === currentUserState.id)
      if (fresh && JSON.stringify(fresh) !== JSON.stringify(currentUserState))
        setCurrentUserState(fresh)
    }
  }, [users]) // eslint-disable-line

  // ── Theme / lang / config persistence ────────────────────────────────
  useEffect(() => { document.body.className = theme === 'dark' ? 'dark' : '' }, [theme])
  useEffect(() => { lsSave('dt_lang',  lang)   }, [lang])
  useEffect(() => { lsSave('dt_theme', theme)  }, [theme])
  useEffect(() => { lsSave('dt_config', systemConfig) }, [systemConfig])

  // ── Helpers ───────────────────────────────────────────────────────────
  function showToast(msg) { setToast(msg); setTimeout(() => setToast(null), 3200) }

  function addNotification(n) {
    setNotifications(prev => [{ id: Date.now(), ...n, read: false, date: new Date().toISOString() }, ...prev])
  }

  function addAudit(a) {
    setAuditLog(prev => [{ ...a, date: new Date().toISOString() }, ...prev])
  }

  function notifyEmail(to, subject, html) {
    if (!systemConfig?.enableEmails || !to) return
    const secret  = import.meta.env.VITE_SEND_EMAIL_SECRET
    const headers = { 'Content-Type': 'application/json', ...(secret ? { 'x-api-secret': secret } : {}) }
    fetch('/api/send-email', { method: 'POST', headers, body: JSON.stringify({ to, subject, html }) })
      .catch(() => {})
  }

  // ── setCurrentUser (login / logout) ──────────────────────────────────
  const setCurrentUser = useCallback(async (user) => {
    if (user) {
      setCurrentUserState(user)
      setLoadingData(true)
      Sentry.setUser({ id: String(user.id), email: user.email, username: `${user.firstName} ${user.lastName}`, role: user.role })
      try {
        await loadData()
      } finally {
        setLoadingData(false)
      }
      // Boas-vindas — só no LOGIN real (o restore de sessão não passa por aqui)
      setWelcomeUser(user)
    } else {
      // Logout intencional: silencia o interceptor de 401 enquanto o token é
      // revogado (requisições em voo não devem abrir "Sessão expirada").
      loggingOutRef.current = true
      try {
        try { await api.logout() } catch {}
        setToken(null)
        setCurrentOrg(null); setActiveOrg(null); setCurrentOrgId(null); setAvailableOrgs([])
        setCurrentUserState(null)
        setSessionExpiredMsg(false)
        setTickets([]); setUsers([]); setCategories([]); setPriorities([])
        setQueues([]); setHolidays([]); setArticles([]); setNotifications([]); setAuditLog([])
        Sentry.setUser(null)
        navigate(SCREEN_TO_PATH['dashboard'])
      } finally {
        // pequeno atraso para requisições em voo terminarem antes de reativar
        setTimeout(() => { loggingOutRef.current = false }, 1500)
      }
    }
  }, [loadData, navigate])

  // ── Troca de empresa (msp_admin) ───────────────────────────────────────
  // Grava a empresa em localStorage (→ header X-Organization-Id) e recarrega
  // todos os dados da empresa selecionada. Volta ao painel para não exibir um
  // ticket da empresa anterior.
  const switchOrg = useCallback(async (orgId, { redirect = true } = {}) => {
    setCurrentOrg(orgId)        // persistência entre recarregamentos (localStorage)
    setActiveOrg(orgId)         // header desta aba já no reload abaixo (antes do re-render)
    setCurrentOrgId(String(orgId))
    setLoadingData(true)
    if (redirect) navigate(SCREEN_TO_PATH['dashboard'])
    try { await loadData() } finally { setLoadingData(false) }
  }, [loadData, navigate])

  // msp_admin pode abrir tickets de QUALQUER empresa (link de e-mail, nova aba,
  // notificação). Alinha a empresa ativa ao prefixo do ticket aberto para que o
  // header/escopo batam com a empresa do ticket (sem isso: "Ticket não
  // encontrado" e responsáveis vazios ao agir num ticket de outra empresa).
  useEffect(() => {
    if (currentUserState?.role !== 'msp_admin') return
    if (!selectedTicket || availableOrgs.length === 0) return
    const prefix = String(selectedTicket).split('-')[0]
    const target = availableOrgs.find(o => (o.ticket_prefix ?? o.ticketPrefix) === prefix)
    if (target && String(target.id) !== String(currentOrgId)) {
      switchOrg(target.id, { redirect: false })
    }
  }, [selectedTicket, availableOrgs, currentUserState, currentOrgId, switchOrg])

  // Cria uma empresa nova (msp_admin) e a adiciona à lista do seletor.
  const createOrganizationAction = useCallback(async (data) => {
    const org = await api.createOrganization(data)
    setAvailableOrgs(prev => [...prev, org].sort((a, b) => a.name.localeCompare(b.name)))
    return org
  }, [])

  // Edita nome / status (ativa) de uma empresa (msp_admin).
  const updateCompanyAction = useCallback(async (id, data) => {
    const org = await api.updateCompany(id, data)
    setAvailableOrgs(prev => prev.map(o => (o.id === org.id ? org : o)))
    return org
  }, [])

  // ── Backup ────────────────────────────────────────────────────────────
  const backupRef = useRef(null)
  useEffect(() => {
    backupRef.current = { users, tickets, categories, priorities, queues, holidays, articles, notifications, auditLog, systemConfig }
  }, [users, tickets, categories, priorities, queues, holidays, articles, notifications, auditLog, systemConfig])

  const downloadBackup = useCallback(() => {
    const payload = { exportedAt: new Date().toISOString(), version: '2.0', ...backupRef.current }
    const blob  = new Blob([JSON.stringify(payload, null, 2)], { type: 'application/json' })
    const url   = URL.createObjectURL(blob)
    const a     = document.createElement('a')
    const dateStr = new Intl.DateTimeFormat('pt-BR', { timeZone: 'America/Sao_Paulo', dateStyle: 'short' })
      .format(new Date()).replace(/\//g, '-')
    a.href = url; a.download = `dataticket-backup-${dateStr}.json`
    document.body.appendChild(a); a.click()
    document.body.removeChild(a); URL.revokeObjectURL(url)
  }, [])

  // ── API Action Functions ──────────────────────────────────────────────
  // Use these for any mutation that must persist to the backend.

  // Tickets
  const createTicketAction = useCallback(async (data) => {
    const res = await api.createTicket(data)
    const tk  = mapTicket(res)
    setTickets(prev => [tk, ...prev])
    return tk
  }, [])

  const updateTicketAction = useCallback(async (id, data) => {
    const res = await api.updateTicket(id, data)
    const tk  = mapTicket(res)
    setTickets(prev => prev.map(t => t.id === id ? tk : t))
    return tk
  }, [])

  const changeStatusAction = useCallback(async (id, status, additionalHours) => {
    const res = await api.changeStatus(id, status, additionalHours)
    const tk  = mapTicket(res)
    setTickets(prev => prev.map(t => t.id === id ? tk : t))
    return tk
  }, [])

  const triageAction = useCallback(async (id, data) => {
    // data must be snake_case for the API
    const res = await api.triage(id, data)
    const tk  = mapTicket(res)
    setTickets(prev => prev.map(t => t.id === id ? tk : t))
    return tk
  }, [])

  // ── Esforço adicional ("+ Horas") ──────────────────────────────────────
  const addEffortAction = useCallback(async (ticketId, hours, reason) => {
    await api.addEffort(ticketId, { hours, reason })
    const res = await api.ticket(ticketId)          // recarrega ticket (esforço + comentário + lista)
    const tk  = mapTicket(res)
    setTickets(prev => prev.map(t => t.id === ticketId ? tk : t))
    return tk
  }, [])

  const deleteEffortAction = useCallback(async (ticketId, additionId) => {
    await api.deleteEffort(ticketId, additionId)
    const res = await api.ticket(ticketId)
    const tk  = mapTicket(res)
    setTickets(prev => prev.map(t => t.id === ticketId ? tk : t))
    return tk
  }, [])

  // ── Listas salvas de filtros (por usuário e empresa, no servidor) ──────
  const createSavedViewAction = useCallback(async (name, filters) => {
    const v = await api.createSavedView({ name, filters })
    setSavedViews(prev => [...prev, v])
    return v
  }, [])

  const deleteSavedViewAction = useCallback(async (id) => {
    await api.deleteSavedView(id)
    setSavedViews(prev => prev.filter(v => v.id !== id))
  }, [])

  const assignAction = useCallback(async (id, userId) => {
    const res = await api.assign(id, userId)
    const tk  = mapTicket(res)
    setTickets(prev => prev.map(t => t.id === id ? tk : t))
    return tk
  }, [])

  const addCommentAction = useCallback(async (ticketId, body, kind = 'public') => {
    const res     = await api.createComment(ticketId, { body, kind })
    const comment = mapComment(res)
    setTickets(prev => prev.map(t => t.id === ticketId
      ? { ...t, comments: [...(t.comments ?? []), comment] }
      : t
    ))
    return comment
  }, [])

  const deleteCommentAction = useCallback(async (ticketId, commentId) => {
    await api.deleteComment(ticketId, commentId)
    setTickets(prev => prev.map(t => t.id === ticketId
      ? { ...t, comments: (t.comments ?? []).filter(c => c.id !== commentId) }
      : t
    ))
  }, [])

  // Users
  const createUserAction = useCallback(async (data) => {
    const res  = await api.createUser(data)
    const user = mapUser(res)
    setUsers(prev => [...prev, user])
    return user
  }, [])

  const updateUserAction = useCallback(async (id, data) => {
    const res  = await api.updateUser(id, data)
    const user = mapUser(res)
    setUsers(prev => prev.map(u => u.id === id ? user : u))
    return user
  }, [])

  const deleteUserAction = useCallback(async (id) => {
    await api.deleteUser(id)
    setUsers(prev => prev.filter(u => u.id !== id))
  }, [])

  const toggleUserAction = useCallback(async (id) => {
    const res  = await api.toggleUser(id)
    const user = mapUser(res)
    setUsers(prev => prev.map(u => u.id === id ? user : u))
    return user
  }, [])

  // Categories
  const createCategoryAction = useCallback(async (data) => {
    const res = await api.createCategory(data)
    const cat = mapCategory(res)
    setCategories(prev => [...prev, cat])
    return cat
  }, [])

  const updateCategoryAction = useCallback(async (id, data) => {
    const res = await api.updateCategory(id, data)
    const cat = mapCategory(res)
    setCategories(prev => prev.map(c => c.id === id ? cat : c))
    return cat
  }, [])

  const deleteCategoryAction = useCallback(async (id) => {
    await api.deleteCategory(id)
    setCategories(prev => prev.filter(c => c.id !== id))
  }, [])

  // Priorities
  const createPriorityAction = useCallback(async (data) => {
    const res = await api.createPriority(data)
    const pri = mapPriority(res)
    setPriorities(prev => [...prev, pri])
    return pri
  }, [])

  const updatePriorityAction = useCallback(async (id, data) => {
    const res = await api.updatePriority(id, data)
    const pri = mapPriority(res)
    setPriorities(prev => prev.map(p => p.id === id ? pri : p))
    return pri
  }, [])

  const deletePriorityAction = useCallback(async (id) => {
    await api.deletePriority(id)
    setPriorities(prev => prev.filter(p => p.id !== id))
  }, [])

  // Queues
  const createQueueAction = useCallback(async (data) => {
    const res = await api.createQueue(data)
    const q   = mapQueue(res)
    setQueues(prev => [...prev, q])
    return q
  }, [])

  const updateQueueAction = useCallback(async (id, data) => {
    const res = await api.updateQueue(id, data)
    const q   = mapQueue(res)
    setQueues(prev => prev.map(x => x.id === id ? q : x))
    return q
  }, [])

  const deleteQueueAction = useCallback(async (id) => {
    await api.deleteQueue(id)
    setQueues(prev => prev.filter(q => q.id !== id))
  }, [])

  // Holidays
  const createHolidayAction = useCallback(async (data) => {
    const res = await api.createHoliday(data)
    const h   = mapHoliday(res)
    setHolidays(prev => [...prev, h])
    return h
  }, [])

  const updateHolidayAction = useCallback(async (id, data) => {
    const res = await api.updateHoliday(id, data)
    const h   = mapHoliday(res)
    setHolidays(prev => prev.map(x => x.id === id ? h : x))
    return h
  }, [])

  const deleteHolidayAction = useCallback(async (id) => {
    await api.deleteHoliday(id)
    setHolidays(prev => prev.filter(h => h.id !== id))
  }, [])

  // Articles
  const createArticleAction = useCallback(async (data) => {
    const res = await api.createArticle(data)
    const a   = mapArticle(res)
    setArticles(prev => [...prev, a])
    return a
  }, [])

  const updateArticleAction = useCallback(async (id, data) => {
    const res = await api.updateArticle(id, data)
    const a   = mapArticle(res)
    setArticles(prev => prev.map(x => x.id === id ? a : x))
    return a
  }, [])

  const deleteArticleAction = useCallback(async (id) => {
    await api.deleteArticle(id)
    setArticles(prev => prev.filter(a => a.id !== id))
  }, [])

  // Recarrega um único artigo (ex.: após anexar/remover documentos).
  const refreshArticleAction = useCallback(async (id) => {
    const res = await api.article(id)
    const a   = mapArticle(res)
    setArticles(prev => prev.map(x => x.id === id ? a : x))
    return a
  }, [])

  // Trash
  const deleteTicketAction = useCallback(async (id) => {
    await api.deleteTicket(id)
    setTickets(prev => prev.filter(t => t.id !== id))
  }, [])

  const restoreTicketAction = useCallback(async (id) => {
    const res = await api.restoreTicket(id)
    const tk  = mapTicket(res)
    setTickets(prev => prev.some(t => t.id === id) ? prev.map(t => t.id === id ? tk : t) : [tk, ...prev])
    return tk
  }, [])

  const purgeTicketAction = useCallback(async (id) => {
    await api.purgeTicket(id)
  }, [])

  // Notifications
  const markReadAction = useCallback(async (id) => {
    try { await api.markRead(id) } catch {}
    setNotifications(prev => prev.map(n => n.id === id ? { ...n, read: true } : n))
  }, [])

  const markAllReadAction = useCallback(async () => {
    try { await api.markAllRead() } catch {}
    setNotifications(prev => prev.map(n => ({ ...n, read: true })))
  }, [])

  // ── Context value ─────────────────────────────────────────────────────
  const value = {
    // Auth
    currentUser: currentUserState, setCurrentUser,
    dbReady, loadingData, apiError,
    supabaseOk: true, supabaseError: null, // backward compat

    // Multi-empresa
    availableOrgs, currentOrgId, switchOrg, createOrganizationAction, updateCompanyAction,

    // UI
    lang, setLang, theme, setTheme,
    screen, setScreen,
    selectedTicket, setSelectedTicket,
    sidebar, setSidebar,
    globalSearch, setGlobalSearch,
    toast, setToast, showToast,
    sessionExpiredMsg, setSessionExpiredMsg,

    // Data (read)
    tickets, users, categories, priorities, queues,
    holidays, articles, notifications, auditLog, savedViews, systemConfig,

    // Raw setters (local-only — prefer action functions for persistence)
    setTickets, setUsers, setCategories, setPriorities, setQueues,
    setHolidays, setArticles, setNotifications, setAuditLog, setSystemConfig,

    // API action functions
    createTicketAction, updateTicketAction, changeStatusAction,
    triageAction, assignAction, addCommentAction, deleteCommentAction,
    addEffortAction, deleteEffortAction,
    createSavedViewAction, deleteSavedViewAction,
    deleteTicketAction, restoreTicketAction, purgeTicketAction,
    createUserAction, updateUserAction, deleteUserAction, toggleUserAction,
    createCategoryAction, updateCategoryAction, deleteCategoryAction,
    createPriorityAction, updatePriorityAction, deletePriorityAction,
    createQueueAction, updateQueueAction, deleteQueueAction,
    createHolidayAction, updateHolidayAction, deleteHolidayAction,
    createArticleAction, updateArticleAction, deleteArticleAction, refreshArticleAction,
    markReadAction, markAllReadAction,

    // Helpers
    addNotification, addAudit, notifyEmail, downloadBackup,
    reloadData: loadData,
  }

  const isLoading = !dbReady || loadingData

  return (
    <AppCtx.Provider value={value}>
      {isLoading ? (
        <div style={{ minHeight: '100vh', background: 'var(--bg2)', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 16 }}>
          <div style={{ fontSize: 40 }}>🎯</div>
          <div style={{ fontWeight: 800, fontSize: 22, color: 'var(--accent)' }}>DataTicket</div>
          <div style={{ fontSize: 13, color: 'var(--text2)' }}>Carregando aplicação…</div>
          <div style={{ width: 200, height: 3, background: 'var(--bg3)', borderRadius: 2, overflow: 'hidden', marginTop: 8 }}>
            <div style={{ height: '100%', background: 'var(--accent)', borderRadius: 2, animation: 'loadingBar 1.5s ease-in-out infinite' }} />
          </div>
          <style>{`@keyframes loadingBar { 0%{width:0%;margin-left:0} 50%{width:60%;margin-left:20%} 100%{width:0%;margin-left:100%} }`}</style>
          {apiError && (
            <div style={{ marginTop: 12, padding: '10px 20px', background: '#fef2f2', border: '1px solid #fecaca', borderRadius: 8, fontSize: 13, color: '#991b1b', maxWidth: 400, textAlign: 'center' }}>
              ⚠️ {apiError}
              <br /><button className="btn btn-secondary btn-sm" style={{ marginTop: 8 }} onClick={() => { setApiError(null); setDbReady(true) }}>Continuar offline</button>
            </div>
          )}
        </div>
      ) : (
        children
      )}

      {/* Modal de sessão expirada */}
      {/* Boas-vindas pós-login */}
      {welcomeUser && (
        <div style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,.45)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 9998 }}
          onClick={() => setWelcomeUser(null)}>
          <div style={{ background: 'var(--bg)', border: '1px solid var(--border)', borderRadius: 16, padding: 36, maxWidth: 400, textAlign: 'center', boxShadow: '0 8px 40px rgba(0,0,0,.18)' }}
            onClick={e => e.stopPropagation()}>
            <div style={{ fontSize: 40, marginBottom: 12 }}>🎯</div>
            <h3 style={{ fontWeight: 700, fontSize: 18, marginBottom: 8 }}>Olá, {welcomeUser.firstName}!</h3>
            <p style={{ color: 'var(--text2)', fontSize: 14, marginBottom: 24, lineHeight: 1.6 }}>
              Seja bem-vindo ao <strong>DataTicket</strong>.<br />
              Você está na organização <strong>{systemConfig?.companyName || '—'}</strong>.
            </p>
            <button className="btn btn-primary" style={{ width: '100%', padding: 11 }} onClick={() => setWelcomeUser(null)}>
              Começar
            </button>
          </div>
        </div>
      )}

      {sessionExpiredMsg && (
        <div style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,.55)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 9999 }}>
          <div style={{ background: 'var(--bg)', border: '1px solid var(--border)', borderRadius: 16, padding: 36, maxWidth: 360, textAlign: 'center', boxShadow: '0 8px 40px rgba(0,0,0,.18)' }}>
            <div style={{ fontSize: 40, marginBottom: 12 }}>⏰</div>
            <h3 style={{ fontWeight: 700, fontSize: 18, marginBottom: 8 }}>Sessão expirada</h3>
            <p style={{ color: 'var(--text2)', fontSize: 14, marginBottom: 24, lineHeight: 1.6 }}>
              Sua sessão expirou.<br />Faça login novamente para continuar.
            </p>
            <button className="btn btn-primary" style={{ width: '100%', padding: 11 }}
              onClick={() => { setSessionExpiredMsg(false); setToken(null); setCurrentUserState(null) }}>
              Ir para o Login
            </button>
          </div>
        </div>
      )}
    </AppCtx.Provider>
  )
}
