// ── API Client — centraliza todas as chamadas ao Rails API ────────────────
// Em dev: proxy Vite redireciona /api → http://localhost:3001
// Em prod: VITE_API_URL deve apontar para a URL do Railway

const BASE = import.meta.env.VITE_API_URL ?? '/api/v1'
const TOKEN_KEY = 'dt_token'
const ORG_KEY   = 'dt_current_org'

export const getToken  = ()  => localStorage.getItem(TOKEN_KEY)
export const setToken  = (t) => t ? localStorage.setItem(TOKEN_KEY, t) : localStorage.removeItem(TOKEN_KEY)
export const clearToken = () => localStorage.removeItem(TOKEN_KEY)

// Empresa selecionada (só msp_admin troca; o backend ignora o header para os demais).
export const getCurrentOrg = ()   => localStorage.getItem(ORG_KEY)
export const setCurrentOrg = (id) => id ? localStorage.setItem(ORG_KEY, String(id)) : localStorage.removeItem(ORG_KEY)

// Callback chamado quando qualquer request retorna 401 — registrado pelo AppContext
let _on401 = null
export const setOn401Handler = (fn) => { _on401 = fn }

// ── Core fetch wrapper ─────────────────────────────────────────────────────
async function req(path, opts = {}) {
  const token = getToken()
  const orgId = getCurrentOrg()
  const headers = {
    'Content-Type': 'application/json',
    ...(token ? { Authorization: `Bearer ${token}` } : {}),
    ...(orgId ? { 'X-Organization-Id': orgId } : {}),
    ...opts.headers,
  }

  const res = await fetch(`${BASE}${path}`, { ...opts, headers })

  // Capture JWT from response header (set by Devise JWT on login/refresh)
  const authHeader = res.headers.get('Authorization')
  if (authHeader) {
    const newToken = authHeader.replace(/^Bearer\s+/i, '').trim()
    if (newToken) setToken(newToken)
  }

  if (res.status === 204) return null

  let data
  try { data = await res.json() } catch { data = {} }

  if (res.status === 401) {
    clearToken()
    _on401?.()
    const err = new Error('Sessão expirada. Faça login novamente.')
    err.status = 401
    throw err
  }

  if (!res.ok) {
    const err = new Error(data?.error ?? `HTTP ${res.status}`)
    err.status  = res.status
    err.data    = data
    throw err
  }

  return data
}

const j = (body) => JSON.stringify(body)

// ── API methods ────────────────────────────────────────────────────────────
export const api = {
  // ── Auth ──────────────────────────────────────────────────────────────
  login:                (email, password)        => req('/login',                  { method: 'POST', body: j({ user: { email, password } }) }),
  logout:               ()                       => req('/logout',                 { method: 'DELETE' }),
  me:                   ()                       => req('/me'),
  requestPasswordReset:  (email)                 => req('/password_reset_request', { method: 'POST', body: j({ email }) }),
  confirmPasswordReset:  (email, code, password) => req('/password_reset_confirm', { method: 'POST', body: j({ email, code, password }) }),

  // ── Tickets ───────────────────────────────────────────────────────────
  tickets:            (params = {}) => req(`/tickets?${new URLSearchParams({ per_page: 500, ...params })}`),
  ticket:             (id)          => req(`/tickets/${id}`),
  createTicket:       (d)           => req('/tickets',        { method: 'POST',   body: j({ ticket: d }) }),
  updateTicket:  (id, d)       => req(`/tickets/${id}`,  { method: 'PATCH',  body: j({ ticket: d }) }),
  deleteTicket:  (id)          => req(`/tickets/${id}`,  { method: 'DELETE' }),          // soft delete → lixeira
  restoreTicket: (id)          => req(`/tickets/${id}/restore`, { method: 'PATCH' }),
  purgeTicket:   (id)          => req(`/tickets/${id}/purge`,   { method: 'DELETE' }),   // exclusão permanente
  trash:         ()            => req('/tickets/trash'),
  triage:        (id, d)       => req(`/tickets/${id}/triage`,        { method: 'PATCH', body: j(d) }),
  changeStatus:  (id, status, additionalHours) => req(`/tickets/${id}/change_status`, { method: 'PATCH', body: j({ status, ...(additionalHours ? { additional_hours: additionalHours } : {}) }) }),
  assign:        (id, uid)     => req(`/tickets/${id}/assign`,        { method: 'PATCH', body: j({ assignee_id: uid }) }),
  histories:          (id)      => req(`/tickets/${id}/histories`),
  timerSessions:      (id)        => req(`/tickets/${id}/timer_sessions`),
  createTimerSession: (id, d)     => req(`/tickets/${id}/timer_sessions`,            { method: 'POST',  body: j(d) }),
  startTimerSession:  (id)        => req(`/tickets/${id}/timer_sessions/start`,      { method: 'POST' }),
  stopTimerSession:   (id, sid)   => req(`/tickets/${id}/timer_sessions/${sid}/stop`,{ method: 'PATCH' }),

  // ── Comments ──────────────────────────────────────────────────────────
  comments:      (tid)      => req(`/tickets/${tid}/comments`),
  createComment: (tid, d)   => req(`/tickets/${tid}/comments`,     { method: 'POST',   body: j({ ticket_comment: d }) }),
  deleteComment: (tid, cid) => req(`/tickets/${tid}/comments/${cid}`, { method: 'DELETE' }),

  // ── Users ─────────────────────────────────────────────────────────────
  users:           ()           => req('/users'),
  usersCapacity:   (from, to)  => req(`/users/capacity${from ? `?from=${from}&to=${to ?? from}` : ''}`),
  createUser:      (d)         => req('/users',           { method: 'POST',   body: j({ user: d }) }),
  updateUser:      (id, d)     => req(`/users/${id}`,     { method: 'PATCH',  body: j({ user: d }) }),
  deleteUser:      (id)        => req(`/users/${id}`,     { method: 'DELETE' }),
  toggleUser:      (id)        => req(`/users/${id}/toggle_active`,  { method: 'PATCH' }),
  resetPassword:   (id)        => req(`/users/${id}/reset_password`, { method: 'POST' }),

  // ── Categories ────────────────────────────────────────────────────────
  categories:      ()       => req('/categories'),
  createCategory:  (d)      => req('/categories',     { method: 'POST',   body: j({ category: d }) }),
  updateCategory:  (id, d)  => req(`/categories/${id}`, { method: 'PATCH', body: j({ category: d }) }),
  deleteCategory:  (id)     => req(`/categories/${id}`, { method: 'DELETE' }),

  // ── Priorities ────────────────────────────────────────────────────────
  priorities:      ()       => req('/priorities'),
  createPriority:  (d)      => req('/priorities',     { method: 'POST',   body: j({ priority: d }) }),
  updatePriority:  (id, d)  => req(`/priorities/${id}`, { method: 'PATCH', body: j({ priority: d }) }),
  deletePriority:  (id)     => req(`/priorities/${id}`, { method: 'DELETE' }),

  // ── Queues ────────────────────────────────────────────────────────────
  queues:        ()         => req('/queues'),
  createQueue:   (d)        => req('/queues',          { method: 'POST',   body: j({ queue: d }) }),
  updateQueue:   (id, d)    => req(`/queues/${id}`,    { method: 'PATCH',  body: j({ queue: d }) }),
  deleteQueue:   (id)       => req(`/queues/${id}`,    { method: 'DELETE' }),
  addMember:     (id, uid)  => req(`/queues/${id}/add_member`,    { method: 'POST',   body: j({ user_id: uid }) }),
  removeMember:  (id, uid)  => req(`/queues/${id}/remove_member`, { method: 'DELETE', body: j({ user_id: uid }) }),

  // ── Holidays ──────────────────────────────────────────────────────────
  holidays:      ()       => req('/holidays'),
  createHoliday: (d)      => req('/holidays',       { method: 'POST',   body: j({ holiday: d }) }),
  updateHoliday: (id, d)  => req(`/holidays/${id}`, { method: 'PATCH',  body: j({ holiday: d }) }),
  deleteHoliday: (id)     => req(`/holidays/${id}`, { method: 'DELETE' }),

  // ── Articles (KB) ─────────────────────────────────────────────────────
  articles:      ()       => req('/articles'),
  createArticle: (d)      => req('/articles',       { method: 'POST',   body: j({ article: d }) }),
  updateArticle: (id, d)  => req(`/articles/${id}`, { method: 'PATCH',  body: j({ article: d }) }),
  deleteArticle: (id)     => req(`/articles/${id}`, { method: 'DELETE' }),

  // ── Notifications ─────────────────────────────────────────────────────
  notifications:  ()   => req('/notifications'),
  markRead:       (id) => req(`/notifications/${id}`, { method: 'PATCH', body: j({ notification: { read: true } }) }),
  markAllRead:    ()   => req('/notifications/mark_all_read', { method: 'PATCH' }),

  // ── Organization ──────────────────────────────────────────────────────
  organization:       ()  => req('/organization'),
  updateOrganization: (d) => req('/organization', { method: 'PATCH', body: j({ organization: d }) }),
  // Gestão de empresas (multi-tenant)
  organizations:       ()  => req('/organizations'),
  createOrganization:  (d) => req('/organizations', { method: 'POST', body: j({ organization: d }) }),
  updateCompany:    (id, d) => req(`/organizations/${id}`, { method: 'PATCH', body: j({ organization: d }) }),

  // ── Audit log ─────────────────────────────────────────────────────────

  // -- Attachments
  attachments: (ticketId) => req(`/tickets/${ticketId}/attachments`),

  uploadAttachment: (ticketId, file) => {
    const fd = new FormData()
    fd.append('file', file)
    const token = getToken()
    const orgId = getCurrentOrg()
    return fetch(`${BASE}/tickets/${ticketId}/attachments`, {
      method: 'POST',
      headers: {
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
        ...(orgId ? { 'X-Organization-Id': orgId } : {}),
      },
      body: fd,
    }).then(async res => {
      if (res.status === 204) return null
      let data
      try { data = await res.json() } catch { data = {} }
      if (!res.ok) {
        const err = new Error(data?.error ?? `HTTP ${res.status}`)
        err.status = res.status
        throw err
      }
      return data
    })
  },

  deleteAttachment: (ticketId, attId) =>
    req(`/tickets/${ticketId}/attachments/${attId}`, { method: 'DELETE' }),
  trashedAttachments: (ticketId) =>
    req(`/tickets/${ticketId}/attachments/trash`),
  restoreAttachment: (ticketId, attId) =>
    req(`/tickets/${ticketId}/attachments/${attId}/restore`, { method: 'PATCH' }),

  downloadAttachment: async (ticketId, attId, filename) => {
    const token = getToken()
    const res = await fetch(`${BASE}/tickets/${ticketId}/attachments/${attId}/download`, {
      headers: token ? { Authorization: `Bearer ${token}` } : {},
    })
    if (!res.ok) throw new Error(`HTTP ${res.status}`)
    const blob = await res.blob()
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = filename || 'arquivo'
    document.body.appendChild(a)
    a.click()
    document.body.removeChild(a)
    URL.revokeObjectURL(url)
  },
  auditLogs: (params = {}) => req(`/audit_logs?${new URLSearchParams(params)}`),
}
