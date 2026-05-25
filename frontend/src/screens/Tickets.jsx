import { useState, useMemo, useEffect } from 'react'
import { api } from '../api.js'
import { mapAttachment, mapTicket } from '../mapper.js'
import { useApp } from '../AppContext.jsx'
import { PT, EN, PERM, STATUS_LIST, ALLOWED_TRANSITIONS, isExpired, formatDate, formatDateTime } from '../data.js'
import { Avatar, Badge, PriBadge, CatChip, ModalOverlay, EmptyState } from '../components.jsx'

// ── Timer utils (fora do componente — sobrevivem a desmontagem) ───────────
function timerActiveKey(userId)   { return `dt_active_timer_${userId}` }
function timerSessionsKey(userId, ticketId) { return `dt_sessions_${userId}_${ticketId}` }

function getActiveTimer(userId) {
  try { return JSON.parse(localStorage.getItem(timerActiveKey(userId)) || 'null') }
  catch { return null }
}
function setActiveTimer(userId, val) {
  const key = timerActiveKey(userId)
  if (val) localStorage.setItem(key, JSON.stringify(val))
  else     localStorage.removeItem(key)
}
function loadSessions(userId, ticketId) {
  try {
    return JSON.parse(localStorage.getItem(timerSessionsKey(userId, ticketId)) || '[]')
      .map(s => ({ start: new Date(s.start), end: new Date(s.end), mins: s.mins }))
  } catch { return [] }
}
function saveSessions(userId, ticketId, sessions) {
  try {
    localStorage.setItem(
      timerSessionsKey(userId, ticketId),
      JSON.stringify(sessions.map(s => ({
        start: s.start.toISOString(),
        end:   s.end.toISOString(),
        mins:  s.mins,
      })))
    )
  } catch { /* quota */ }
}

// ── Ticket List ───────────────────────────────────────────────────────────
export function TicketList() {
  const { currentUser, lang, tickets, priorities, categories, users, queues, setScreen, setSelectedTicket, triageAction, showToast } = useApp()
  const t = lang === 'pt' ? PT : EN
  const p = PERM[currentUser.role]
  const [search, setSearch] = useState('')
  const [filterStatus, setFilterStatus] = useState([])
  const [filterPri, setFilterPri] = useState([])
  const [filterCat, setFilterCat] = useState([])
  const [openFilter, setOpenFilter] = useState(null) // 'status'|'pri'|'cat'|null
  const [sortBy, setSortBy] = useState('createdAt')
  const [sortDir, setSortDir] = useState('desc')
  const [page, setPage] = useState(0)
  const PER = 25

  const [showInlineTriage, setShowInlineTriage] = useState(false)
  const [triageTarget, setTriageTarget] = useState(null)
  const [inlineTriageForm, setInlineTriageForm] = useState({ priorityId: '', categoryId: '', effortEstimated: '', queueId: '', assigneeId: '' })

  const filtered = useMemo(() => {
    let tks = [...tickets]
    // Filtragem local como fallback (o backend ja filtra por escopo no servidor)
    if (currentUser.role === 'user') tks = tks.filter(tk => tk.requesterId === currentUser.id)
    else if (currentUser.role === 'analyst') tks = tks.filter(tk => tk.assigneeId === currentUser.id)
    // manager e admin: veem todos os tickets (sem filtro adicional)
    if (search) tks = tks.filter(tk => tk.title.toLowerCase().includes(search.toLowerCase()) || tk.id.toLowerCase().includes(search.toLowerCase()))
    if (filterStatus.length) tks = tks.filter(tk => filterStatus.includes(tk.status))
    if (filterPri.length) tks = tks.filter(tk => filterPri.includes(tk.priorityId))
    if (filterCat.length) tks = tks.filter(tk => filterCat.includes(tk.categoryId))
    tks.sort((a, b) => {
      let av = a[sortBy], bv = b[sortBy]
      if (typeof av === 'string') av = av.toLowerCase(); bv = bv?.toLowerCase?.() ?? ''
      return sortDir === 'asc' ? (av > bv ? 1 : -1) : (av < bv ? 1 : -1)
    })
    return tks
  }, [tickets, currentUser, search, filterStatus, filterPri, filterCat, sortBy, sortDir])

  const paged = filtered.slice(page * PER, (page + 1) * PER)
  const totalPages = Math.ceil(filtered.length / PER)

  function sort(col) {
    if (sortBy === col) setSortDir(d => d === 'asc' ? 'desc' : 'asc')
    else { setSortBy(col); setSortDir('asc') }
  }
  const sortIcon = (col) => sortBy === col ? (sortDir === 'asc' ? ' ↑' : ' ↓') : ''

  function openTicket(tk) { setSelectedTicket(tk.id); setScreen('ticket-detail') }

  async function doInlineTriage() {
    if (!inlineTriageForm.priorityId || !inlineTriageForm.queueId) { alert('Preencha prioridade e fila.'); return }
    const tk = tickets.find(x => x.id === triageTarget)
    if (!tk) return
    const q = queues.find(x => x.id === Number(inlineTriageForm.queueId))
    const assigneeId = inlineTriageForm.assigneeId ? Number(inlineTriageForm.assigneeId) : (q?.members[0] ?? null)
    try {
      await triageAction(triageTarget, {
        priority_id: Number(inlineTriageForm.priorityId) || null,
        category_id: inlineTriageForm.categoryId ? Number(inlineTriageForm.categoryId) : (tk.categoryId || null),
        queue_id:    Number(inlineTriageForm.queueId) || null,
        assignee_id: assigneeId,
      })
      showToast('Triagem realizada com sucesso!')
    } catch (e) {
      alert(`Erro ao triar: ${e.message}`)
    }
    setShowInlineTriage(false)
    setTriageTarget(null)
    setInlineTriageForm({ priorityId: '', categoryId: '', effortEstimated: '', queueId: '', assigneeId: '' })
  }

  function MultiFilter({ label, options, selected, setSelected, filterKey }) {
    const isOpen = openFilter === filterKey
    return (
      <div style={{ position: 'relative' }}>
        <button
          className="btn btn-secondary btn-sm"
          style={{ minWidth: 120, justifyContent: 'space-between', display: 'flex', alignItems: 'center', gap: 6 }}
          onClick={() => setOpenFilter(isOpen ? null : filterKey)}
        >
          <span>{label}{selected.length > 0 ? ` (${selected.length})` : ''}</span>
          <span style={{ fontSize: 10 }}>{isOpen ? '▲' : '▼'}</span>
        </button>
        {isOpen && (
          <div style={{
            position: 'absolute', top: '100%', left: 0, zIndex: 200,
            background: 'var(--bg)', border: '1px solid var(--border)', borderRadius: 8,
            boxShadow: '0 8px 24px rgba(0,0,0,.12)', minWidth: 180, padding: '6px 0', marginTop: 4
          }}>
            {selected.length > 0 && (
              <div
                onClick={() => setSelected([])}
                style={{ padding: '6px 14px', fontSize: 12, color: 'var(--danger)', cursor: 'pointer', borderBottom: '1px solid var(--border)', marginBottom: 4 }}
              >
                Limpar seleção
              </div>
            )}
            {options.map(opt => (
              <label key={opt.value} style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '6px 14px', cursor: 'pointer', fontSize: 13 }}
                onMouseEnter={e => e.currentTarget.style.background = 'var(--bg2)'}
                onMouseLeave={e => e.currentTarget.style.background = 'transparent'}
              >
                <input
                  type="checkbox"
                  checked={selected.includes(opt.value)}
                  onChange={() => setSelected(prev =>
                    prev.includes(opt.value) ? prev.filter(x => x !== opt.value) : [...prev, opt.value]
                  )}
                  onClick={e => e.stopPropagation()}
                />
                {opt.label}
              </label>
            ))}
          </div>
        )}
      </div>
    )
  }

  return (
    <div>
      {openFilter && <div style={{ position: 'fixed', inset: 0, zIndex: 199 }} onClick={() => setOpenFilter(null)} />}
      <div className="page-header">
        <h2 className="page-title">{t.tickets}</h2>
        {p.createTicket && (
          <button className="btn btn-primary" onClick={() => setScreen('new-ticket')}>➕ {t.newTicket}</button>
        )}
      </div>

      <div className="card" style={{ marginBottom: 12 }}>
        <div style={{ display: 'flex', gap: 10, flexWrap: 'wrap', alignItems: 'center' }}>
          <div className="search-box" style={{ flex: '1 1 200px' }}>
            <span>🔍</span>
            <input placeholder="Buscar por título ou ID…" value={search} onChange={e => { setSearch(e.target.value); setPage(0) }} />
          </div>
          <MultiFilter
            label="Status" filterKey="status" selected={filterStatus} setSelected={v => { setFilterStatus(v); setPage(0) }}
            options={STATUS_LIST.map(s => ({ value: s, label: s }))}
          />
          <MultiFilter
            label="Prioridade" filterKey="pri" selected={filterPri} setSelected={v => { setFilterPri(v); setPage(0) }}
            options={priorities.map(p => ({ value: p.id, label: p.name }))}
          />
          <MultiFilter
            label="Categoria" filterKey="cat" selected={filterCat} setSelected={v => { setFilterCat(v); setPage(0) }}
            options={categories.map(c => ({ value: c.id, label: c.name }))}
          />
        </div>
      </div>

      <div className="card" style={{ overflowX: 'auto' }}>
        <table className="table">
          <thead>
            <tr>
              <th style={{ cursor: 'pointer' }} onClick={() => sort('id')}>ID{sortIcon('id')}</th>
              <th style={{ cursor: 'pointer' }} onClick={() => sort('title')}>Título{sortIcon('title')}</th>
              <th>Solicitante</th>
              <th>Prioridade</th>
              <th>Status</th>
              <th>Categoria</th>
              <th style={{ cursor: 'pointer' }} onClick={() => sort('createdAt')}>Abertura{sortIcon('createdAt')}</th>
              <th style={{ cursor: 'pointer' }} onClick={() => sort('deadline')}>Prazo{sortIcon('deadline')}</th>
              <th>Esforço</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {paged.length === 0 && (
              <tr><td colSpan={10} style={{ textAlign: 'center', color: 'var(--text2)', padding: 32 }}>Nenhum ticket encontrado</td></tr>
            )}
            {paged.map(tk => {
              const pri = priorities.find(p => p.id === tk.priorityId)
              const cat = categories.find(c => c.id === tk.categoryId)
              const req = users.find(u => u.id === tk.requesterId)
              const expired = isExpired(tk.deadline) && !['Resolvido', 'Fechado'].includes(tk.status)
              return (
                <tr
                  key={tk.id}
                  style={{
                    cursor: 'pointer',
                    borderLeft: `3px solid ${pri?.color || 'transparent'}`,
                    background: expired ? '#fef2f2' : undefined,
                  }}
                  onClick={() => openTicket(tk)}
                >
                  <td style={{ color: 'var(--accent)', fontWeight: 600 }}>{tk.id}</td>
                  <td style={{ maxWidth: 220, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                    {expired && <span style={{ color: 'var(--danger)', marginRight: 5 }}>⚠</span>}
                    {tk.title}
                  </td>
                  <td style={{ color: 'var(--text2)', fontSize: 12 }}>{req ? req.firstName + ' ' + req.lastName : '—'}</td>
                  <td><PriBadge priority={pri} /></td>
                  <td><Badge status={tk.status} /></td>
                  <td><CatChip category={cat} /></td>
                  <td style={{ fontSize: 12, color: 'var(--text2)' }}>{formatDate(tk.createdAt)}</td>
                  <td style={{ fontSize: 12, color: expired ? 'var(--danger)' : 'var(--text)', fontWeight: expired ? 600 : 400 }}>
                    {formatDate(tk.deadline)}
                  </td>
                  <td style={{ fontSize: 12, whiteSpace: 'nowrap' }}>
                    {tk.effortEstimated > 0 ? (
                      <span style={{ color: tk.effortUsed > tk.effortEstimated ? 'var(--danger)' : 'var(--text2)' }}>
                        {tk.effortUsed > tk.effortEstimated && '⏱ '}
                        {tk.effortUsed.toFixed(1)}/{tk.effortEstimated}h
                      </span>
                    ) : <span style={{ color: 'var(--text2)' }}>—</span>}
                  </td>
                  <td onClick={e => e.stopPropagation()}>
                    {p.triage && !tk.triaged && (
                      <button
                        className="btn btn-secondary btn-sm"
                        style={{ fontSize: 11, padding: '2px 8px' }}
                        onClick={() => { setTriageTarget(tk.id); setShowInlineTriage(true) }}
                      >
                        🎯 Triar
                      </button>
                    )}
                  </td>
                </tr>
              )
            })}
          </tbody>
        </table>

        {totalPages > 1 && (
          <div style={{ display: 'flex', justifyContent: 'center', alignItems: 'center', gap: 8, paddingTop: 14, borderTop: '1px solid var(--border)', marginTop: 4 }}>
            <button className="btn btn-secondary btn-sm" disabled={page === 0} onClick={() => setPage(p => p - 1)}>◀</button>
            <span style={{ fontSize: 13, color: 'var(--text2)' }}>{page + 1} / {totalPages}</span>
            <button className="btn btn-secondary btn-sm" disabled={page >= totalPages - 1} onClick={() => setPage(p => p + 1)}>▶</button>
          </div>
        )}
      </div>

      {showInlineTriage && (
        <ModalOverlay onClose={() => setShowInlineTriage(false)}>
          <div className="modal">
            <h3 style={{ fontWeight: 700, marginBottom: 18 }}>🎯 Triagem — {triageTarget}</h3>
            <div className="form-grid">
              <div>
                <label className="label">Prioridade *</label>
                <select className="select" style={{ width: '100%' }} value={inlineTriageForm.priorityId} onChange={e => setInlineTriageForm(f => ({ ...f, priorityId: e.target.value }))}>
                  <option value="">Selecione…</option>
                  {priorities.map(p => <option key={p.id} value={p.id}>{p.name} ({p.slaHours}h SLA)</option>)}
                </select>
              </div>
              <div>
                <label className="label">Categoria</label>
                <select className="select" style={{ width: '100%' }} value={inlineTriageForm.categoryId || tickets.find(x => x.id === triageTarget)?.categoryId || ''} onChange={e => setInlineTriageForm(f => ({ ...f, categoryId: e.target.value }))}>
                  {categories.map(c => <option key={c.id} value={c.id}>{c.name}</option>)}
                </select>
              </div>
              <div>
                <label className="label">Horas de esforço estimadas</label>
                <input className="input" type="number" min="0" step="0.5" value={inlineTriageForm.effortEstimated} onChange={e => setInlineTriageForm(f => ({ ...f, effortEstimated: e.target.value }))} />
              </div>
              <div>
                <label className="label">Fila *</label>
                <select className="select" style={{ width: '100%' }} value={inlineTriageForm.queueId}
                  onChange={e => setInlineTriageForm(f => ({ ...f, queueId: e.target.value, assigneeId: '' }))}>
                  <option value="">Selecione…</option>
                  {queues.map(q => <option key={q.id} value={q.id}>{q.name}</option>)}
                </select>
              </div>
              <div>
                <label className="label">Responsável</label>
                <select className="select" style={{ width: '100%' }} value={inlineTriageForm.assigneeId}
                  onChange={e => setInlineTriageForm(f => ({ ...f, assigneeId: e.target.value }))}>
                  <option value="">— Selecione o responsável —</option>
                  {(() => {
                    const q = queues.find(x => x.id === Number(inlineTriageForm.queueId))
                    return users.filter(u => (q?.members ?? []).includes(u.id))
                      .map(u => <option key={u.id} value={u.id}>{u.firstName} {u.lastName}</option>)
                  })()}
                </select>
              </div>
            </div>
            <div style={{ display: 'flex', gap: 10, justifyContent: 'flex-end', marginTop: 18 }}>
              <button className="btn btn-secondary" onClick={() => setShowInlineTriage(false)}>Cancelar</button>
              <button className="btn btn-primary" onClick={doInlineTriage}>Confirmar Triagem</button>
            </div>
          </div>
        </ModalOverlay>
      )}
    </div>
  )
}

// ── New Ticket ────────────────────────────────────────────────────────────
export function NewTicket() {
  const { currentUser, lang, categories, articles, setScreen, addNotification, addAudit, showToast, notifyEmail, createTicketAction, systemConfig } = useApp()
  const t = lang === 'pt' ? PT : EN
  const [form, setForm] = useState({ title: '', description: '', categoryId: '', attachments: [] })
  const [errors, setErrors] = useState({})
  const [files, setFiles] = useState([])
  const [uploading, setUploading] = useState(false)

  const suggestedArticles = useMemo(() => {
    if (!form.categoryId) return []
    return articles.filter(a => a.active && a.categoryId === Number(form.categoryId)).slice(0, 5)
  }, [articles, form.categoryId])

  function validate() {
    const e = {}
    if (!form.title.trim()) e.title = 'Título é obrigatório'
    if (!form.description.trim()) e.description = 'Descrição é obrigatória'
    if (!form.categoryId) e.categoryId = 'Categoria é obrigatória'
    return e
  }

  async function submit() {
    const e = validate()
    if (Object.keys(e).length) { setErrors(e); return }
    setUploading(true)
    try {
      const ticket = await createTicketAction({
        title:       form.title,
        description: form.description,
        category_id: Number(form.categoryId) || null,
      })
      addNotification({ title: `Ticket ${ticket.id} criado`, desc: form.title, type: 'create', ticketId: ticket.id })
      addAudit({ action: 'Ticket criado', entity: ticket.id, userId: currentUser.id, newVal: form.title })
      notifyEmail(
        currentUser.email,
        `[DataTicket #${ticket.id}] Ticket aberto: ${form.title}`,
        `<div style="font-family:sans-serif;max-width:600px;margin:0 auto">
          <div style="background:#2383e2;padding:20px;border-radius:8px 8px 0 0">
            <h2 style="color:#fff;margin:0">🎯 DataTicket · Salvabras</h2>
          </div>
          <div style="border:1px solid #e5e7eb;border-top:none;padding:24px;border-radius:0 0 8px 8px">
            <p>Olá <strong>${currentUser.firstName}</strong>,</p>
            <p>Seu ticket foi aberto com sucesso e está na fila de atendimento.</p>
            <table style="width:100%;border-collapse:collapse;margin:16px 0">
              <tr><td style="padding:8px;background:#f9fafb;font-weight:600;width:100px">Nº</td><td style="padding:8px;border-bottom:1px solid #e5e7eb"><strong>${ticket.id}</strong></td></tr>
              <tr><td style="padding:8px;background:#f9fafb;font-weight:600">Título</td><td style="padding:8px;border-bottom:1px solid #e5e7eb">${form.title}</td></tr>
              <tr><td style="padding:8px;background:#f9fafb;font-weight:600">Status</td><td style="padding:8px">Não iniciado</td></tr>
            </table>
            <p style="color:#6b7280;font-size:12px">Você receberá atualizações por e-mail conforme o ticket for atendido.</p>
          </div>
        </div>`
      )
      // Upload de anexos (se houver)
      if (files.length > 0) {
        const uploadResults = await Promise.allSettled(
          files.map(f => api.uploadAttachment(ticket.id, f))
        )
        const failed = uploadResults.filter(r => r.status === 'rejected')
        if (failed.length > 0) {
          showToast(`Ticket criado, mas ${failed.length} anexo(s) falharam no upload.`)
        }
      }
      showToast(`Ticket ${ticket.id} aberto!`)
      setScreen('tickets')
    } catch (err) {
      alert(`Erro ao criar ticket: ${err.message}`)
    } finally {
      setUploading(false)
    }
  }

  return (
    <div style={{ maxWidth: 680, margin: '0 auto' }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 22 }}>
        <button className="btn btn-secondary" onClick={() => setScreen('tickets')}>← {t.back}</button>
        <h2 className="page-title">{t.newTicket}</h2>
      </div>
      <div className="card">
        <div className="form-row">
          <label className="label">{t.title} *</label>
          <input className="input" value={form.title} onChange={e => setForm(f => ({ ...f, title: e.target.value }))} />
          {errors.title && <p style={{ color: 'var(--danger)', fontSize: 12, marginTop: 4 }}>{errors.title}</p>}
        </div>
        <div className="form-row">
          <label className="label">{t.description} *</label>
          <textarea className="input" rows={5} value={form.description} onChange={e => setForm(f => ({ ...f, description: e.target.value }))} />
          {errors.description && <p style={{ color: 'var(--danger)', fontSize: 12, marginTop: 4 }}>{errors.description}</p>}
        </div>
        <div className="form-row">
          <label className="label">{t.category} *</label>
          <select className="select" style={{ width: '100%' }} value={form.categoryId} onChange={e => setForm(f => ({ ...f, categoryId: e.target.value }))}>
            <option value="">Selecione uma categoria…</option>
            {categories.map(c => <option key={c.id} value={c.id}>{c.name}</option>)}
          </select>
          {errors.categoryId && <p style={{ color: 'var(--danger)', fontSize: 12, marginTop: 4 }}>{errors.categoryId}</p>}
          {suggestedArticles.length > 0 && (
            <div style={{ marginTop: 8, padding: '10px 14px', background: 'var(--bg2)', borderRadius: 8, border: '1px solid var(--border)' }}>
              <div style={{ fontSize: 12, fontWeight: 600, color: 'var(--text2)', marginBottom: 8 }}>
                📚 Artigos relacionados da base de conhecimento:
              </div>
              {suggestedArticles.map(a => (
                <div key={a.id} style={{ fontSize: 13, padding: '4px 0', borderBottom: '1px solid var(--border)', display: 'flex', alignItems: 'center', gap: 8 }}>
                  <span style={{ color: 'var(--accent)', cursor: 'pointer' }} onClick={() => setScreen('kb')}>🔗</span>
                  <span>{a.name}</span>
                </div>
              ))}
              <button
                className="btn btn-secondary btn-sm"
                style={{ marginTop: 8, fontSize: 11 }}
                onClick={() => setScreen('kb')}
              >
                Ver todos da base de conhecimento →
              </button>
            </div>
          )}
        </div>
        <div className="form-row">
          <label className="label">📎 Anexos (PDF, PNG, JPG, DOCX — máx. 20 MB cada)</label>
          <>
            <input type="file" multiple accept=".pdf,.png,.jpg,.jpeg,.doc,.docx,.txt,.xlsx,.zip"
              style={{ fontSize: 13, color: 'var(--text)', padding: '6px 0' }}
              onChange={e => setFiles(Array.from(e.target.files))} />
            {files.length > 0 && (
              <div style={{ marginTop: 8, display: 'flex', flexWrap: 'wrap', gap: 6 }}>
                {files.map((f, i) => (
                  <span key={i} style={{ background: 'var(--bg2)', border: '1px solid var(--border)', borderRadius: 6, padding: '2px 8px', fontSize: 12, display: 'flex', alignItems: 'center', gap: 4 }}>
                    📎 {f.name}
                    <button style={{ background: 'none', border: 'none', cursor: 'pointer', color: 'var(--danger)', fontSize: 13, padding: 0 }}
                      onClick={() => setFiles(prev => prev.filter((_, j) => j !== i))}>x</button>
                  </span>
                ))}
              </div>
            )}
          </>
        </div>
        <div style={{ display: 'flex', gap: 10, justifyContent: 'flex-end', marginTop: 8 }}>
          <button className="btn btn-secondary" onClick={() => setScreen('tickets')}>{t.cancel}</button>
          <button className="btn btn-primary" onClick={submit} disabled={uploading}>
            {uploading ? '⏳ Enviando anexos...' : 'Criar Ticket'}
          </button>
        </div>
      </div>
    </div>
  )
}

// ── Ticket Detail ─────────────────────────────────────────────────────────
export function TicketDetail() {
  const { currentUser, lang, tickets, setTickets, priorities, categories, users, queues, setScreen, addNotification, addAudit, showToast, selectedTicket, notifyEmail, changeStatusAction, addCommentAction, triageAction, assignAction, deleteTicketAction, updateTicketAction, systemConfig } = useApp()
  const t = lang === 'pt' ? PT : EN
  const tk = tickets.find(x => x.id === selectedTicket)

  const [commentText, setCommentText] = useState('')
  const [commentType, setCommentType] = useState('public')
  const [showTriage, setShowTriage] = useState(false)
  const [triageForm, setTriageForm] = useState({ priorityId: '', categoryId: '', effortEstimated: '', queueId: '', assigneeId: '', coAssigneeIds: [] })
  const [timerRunning, setTimerRunning] = useState(false)
  const [timerStart, setTimerStart] = useState(null)
  const [sessions, setSessions] = useState([])

  // Carrega sessões salvas e retoma timer ativo ao abrir o ticket
  useEffect(() => {
    if (!tk) return
    setSessions(loadSessions(currentUser.id, tk.id))
    const active = getActiveTimer(currentUser.id)
    if (active && active.ticketId === tk.id) {
      setTimerStart(new Date(active.startTime))
      setTimerRunning(true)
    } else {
      setTimerRunning(false)
      setTimerStart(null)
    }
  }, [tk?.id, currentUser.id]) // eslint-disable-line react-hooks/exhaustive-deps

  // Notificação a cada 15 min enquanto cronômetro ativo
  useEffect(() => {
    if (!timerRunning || !timerStart || !tk) return
    if (typeof Notification !== 'undefined' && Notification.permission === 'default') {
      Notification.requestPermission()
    }
    const interval = setInterval(() => {
      const elapsed = Math.round((Date.now() - timerStart.getTime()) / 60000)
      if (typeof Notification !== 'undefined' && Notification.permission === 'granted') {
        new Notification('⏱ Cronômetro ativo — DataTicket', {
          body: `Ticket #${tk.id}: ${tk.title}\nTempo decorrido: ${elapsed} min. Lembre-se de pausar quando terminar.`,
          icon: '/favicon.ico',
          tag: 'dt-timer-reminder',
          requireInteraction: false,
        })
      }
    }, 15 * 60 * 1000)
    return () => clearInterval(interval)
  }, [timerRunning]) // eslint-disable-line react-hooks/exhaustive-deps

  const [showMoreComments, setShowMoreComments] = useState(false)
  const [showMoreHistory, setShowMoreHistory] = useState(false)
  const [showMoreSessions, setShowMoreSessions] = useState(false)
  const [moreCommentsPage, setMoreCommentsPage] = useState(0)
  const [moreHistoryPage, setMoreHistoryPage] = useState(0)
  const [moreSessionsPage, setMoreSessionsPage] = useState(0)
  const MORE_PER = 25
  const [newAttFile, setNewAttFile] = useState(null)
  const [addingAtt, setAddingAtt] = useState(false)
  const [localAttachments, setLocalAttachments] = useState(null) // null = not loaded yet

  // Carrega o ticket completo (view :full) ao abrir o detalhe.
  // O index retorna apenas :summary (sem comments nem attachments),
  // por isso precisamos buscar o ticket individual via GET /tickets/:id.
  useEffect(() => {
    if (!tk) return
    api.ticket(tk.id)
      .then(data => {
        const full = mapTicket(data)
        setTickets(prev => prev.map(t => t.id === full.id ? { ...t, comments: full.comments, attachments: full.attachments, coAssignees: full.coAssignees } : t))
      })
      .catch(() => {})
  }, [tk?.id])

  useEffect(() => {
    if (!tk) return
    api.attachments(tk.id)
      .then(data => setLocalAttachments((data ?? []).map(mapAttachment)))
      .catch(() => setLocalAttachments(tk.attachments ?? []))
  }, [tk?.id])

  const p = PERM[currentUser.role]

  if (!tk) return <EmptyState icon="🎫" title="Ticket não encontrado" desc="O ticket pode ter sido removido." />

  const pri = priorities.find(x => x.id === tk.priorityId)
  const cat = categories.find(x => x.id === tk.categoryId)
  const req = users.find(x => x.id === tk.requesterId)
  const assignee = users.find(x => x.id === tk.assigneeId)
  const expired = isExpired(tk.deadline) && !['Resolvido', 'Fechado'].includes(tk.status)
  const transitions = ALLOWED_TRANSITIONS[tk.status] || []

  async function changeStatus(newStatus) {
    try {
      await changeStatusAction(tk.id, newStatus)
      addNotification({ title: `Status alterado: ${tk.id}`, desc: `${tk.status} → ${newStatus}`, type: 'status', ticketId: tk.id })
      if (req?.email) {
        notifyEmail(
          req.email,
          `[DataTicket #${tk.id}] Status atualizado: ${newStatus}`,
          `<div style="font-family:sans-serif;max-width:600px;margin:0 auto">
            <div style="background:#2383e2;padding:20px;border-radius:8px 8px 0 0">
              <h2 style="color:#fff;margin:0">🎯 DataTicket · Salvabras</h2>
            </div>
            <div style="border:1px solid #e5e7eb;border-top:none;padding:24px;border-radius:0 0 8px 8px">
              <p>Olá <strong>${req.firstName}</strong>,</p>
              <p>O status do seu ticket foi atualizado:</p>
              <table style="width:100%;border-collapse:collapse;margin:16px 0">
                <tr><td style="padding:8px;background:#f9fafb;font-weight:600;width:100px">Nº</td><td style="padding:8px;border-bottom:1px solid #e5e7eb">${tk.id}</td></tr>
                <tr><td style="padding:8px;background:#f9fafb;font-weight:600">Título</td><td style="padding:8px;border-bottom:1px solid #e5e7eb">${tk.title}</td></tr>
                <tr><td style="padding:8px;background:#f9fafb;font-weight:600">Novo status</td><td style="padding:8px;font-weight:700;color:#059669">${newStatus}</td></tr>
              </table>
            </div>
          </div>`
        )
      }
      showToast(`Status alterado para "${newStatus}".`)
    } catch (e) {
      alert(`Erro ao alterar status: ${e.message}`)
    }
  }

  async function addComment() {
    if (!commentText.trim()) return
    try {
      await addCommentAction(tk.id, commentText, commentType)
      addNotification({ title: `Comentário em ${tk.id}`, desc: commentText.slice(0, 60), type: 'comment', ticketId: tk.id })
      if (commentType === 'public' && req?.email && currentUser.id !== req.id) {
        notifyEmail(
          req.email,
          `[DataTicket #${tk.id}] Novo comentário: ${tk.title}`,
          `<div style="font-family:sans-serif;max-width:600px;margin:0 auto">
            <div style="background:#2383e2;padding:20px;border-radius:8px 8px 0 0">
              <h2 style="color:#fff;margin:0">🎯 DataTicket · Salvabras</h2>
            </div>
            <div style="border:1px solid #e5e7eb;border-top:none;padding:24px;border-radius:0 0 8px 8px">
              <p>Olá <strong>${req.firstName}</strong>,</p>
              <p>Há uma nova resposta no seu ticket <strong>#${tk.id} — ${tk.title}</strong>:</p>
              <div style="background:#f9fafb;border-left:3px solid #2383e2;padding:12px 16px;margin:16px 0;border-radius:0 4px 4px 0;font-size:14px">
                ${commentText.replace(/\n/g, '<br>')}
              </div>
              <p style="color:#6b7280;font-size:12px">Responda acessando o sistema DataTicket.</p>
            </div>
          </div>`
        )
        showToast('Comentário adicionado. E-mail enviado ao solicitante.')
      } else {
        showToast('Comentário adicionado.')
      }
      setCommentText('')
    } catch (e) {
      alert(`Erro ao comentar: ${e.message}`)
    }
  }

  async function doTriage() {
    if (!triageForm.priorityId || !triageForm.queueId) { alert('Preencha prioridade e fila.'); return }
    const q = queues.find(x => x.id === Number(triageForm.queueId))
    const assigneeId = triageForm.assigneeId ? Number(triageForm.assigneeId) : (q?.members[0] ?? null)
    try {
      await triageAction(tk.id, {
        priority_id:      Number(triageForm.priorityId) || null,
        category_id:      triageForm.categoryId ? Number(triageForm.categoryId) : (tk.categoryId || null),
        queue_id:         Number(triageForm.queueId) || null,
        assignee_id:      assigneeId,
        co_assignee_ids:  (triageForm.coAssigneeIds ?? []).map(Number),
      })
    } catch (e) {
      alert(`Erro ao triar: ${e.message}`)
      return
    }
    addNotification({ title: `Triagem realizada: ${tk.id}`, desc: `Responsável: ${users.find(u => u.id === assigneeId)?.firstName || '—'}`, type: 'assign', ticketId: tk.id })
    const assigneeUser = users.find(u => u.id === assigneeId)
    const deadlineStr = '—'
    // E-mail ao solicitante: ticket em triagem
    if (req?.email) {
      notifyEmail(
        req.email,
        `[DataTicket #${tk.id}] Seu ticket foi triado e está sendo atendido`,
        `<div style="font-family:sans-serif;max-width:600px;margin:0 auto">
          <div style="background:#2383e2;padding:20px;border-radius:8px 8px 0 0">
            <h2 style="color:#fff;margin:0">🎯 DataTicket · Salvabras</h2>
          </div>
          <div style="border:1px solid #e5e7eb;border-top:none;padding:24px;border-radius:0 0 8px 8px">
            <p>Olá <strong>${req.firstName}</strong>,</p>
            <p>Seu ticket foi analisado e atribuído para atendimento.</p>
            <table style="width:100%;border-collapse:collapse;margin:16px 0">
              <tr><td style="padding:8px;background:#f9fafb;font-weight:600;width:120px">Nº</td><td style="padding:8px;border-bottom:1px solid #e5e7eb">${tk.id}</td></tr>
              <tr><td style="padding:8px;background:#f9fafb;font-weight:600">Título</td><td style="padding:8px;border-bottom:1px solid #e5e7eb">${tk.title}</td></tr>
              <tr><td style="padding:8px;background:#f9fafb;font-weight:600">Responsável</td><td style="padding:8px;border-bottom:1px solid #e5e7eb">${assigneeUser ? `${assigneeUser.firstName} ${assigneeUser.lastName}` : '—'}</td></tr>
              <tr><td style="padding:8px;background:#f9fafb;font-weight:600">Prazo estimado</td><td style="padding:8px">${deadlineStr}</td></tr>
            </table>
          </div>
        </div>`
      )
    }
    // E-mail ao responsável: ticket atribuído
    if (assigneeUser?.email) {
      notifyEmail(
        assigneeUser.email,
        `[DataTicket #${tk.id}] Ticket atribuído a você: ${tk.title}`,
        `<div style="font-family:sans-serif;max-width:600px;margin:0 auto">
          <div style="background:#2383e2;padding:20px;border-radius:8px 8px 0 0">
            <h2 style="color:#fff;margin:0">🎯 DataTicket · Salvabras</h2>
          </div>
          <div style="border:1px solid #e5e7eb;border-top:none;padding:24px;border-radius:0 0 8px 8px">
            <p>Olá <strong>${assigneeUser.firstName}</strong>,</p>
            <p>Um ticket foi atribuído a você:</p>
            <table style="width:100%;border-collapse:collapse;margin:16px 0">
              <tr><td style="padding:8px;background:#f9fafb;font-weight:600;width:120px">Nº</td><td style="padding:8px;border-bottom:1px solid #e5e7eb">${tk.id}</td></tr>
              <tr><td style="padding:8px;background:#f9fafb;font-weight:600">Título</td><td style="padding:8px;border-bottom:1px solid #e5e7eb">${tk.title}</td></tr>
              <tr><td style="padding:8px;background:#f9fafb;font-weight:600">Prioridade</td><td style="padding:8px;border-bottom:1px solid #e5e7eb">${pri?.name || '—'}</td></tr>
              <tr><td style="padding:8px;background:#f9fafb;font-weight:600">Prazo</td><td style="padding:8px">${deadlineStr}</td></tr>
            </table>
          </div>
        </div>`
      )
    }
    showToast('Triagem concluída. E-mails enviados ao solicitante e responsável.')
    setShowTriage(false)
  }

  async function handleDelete() {
    if (!window.confirm(`Mover o ticket "${tk.title}" para a lixeira? Ele poderá ser restaurado em até 30 dias.`)) return
    try {
      await deleteTicketAction(tk.id)
      showToast(`Ticket ${tk.id} movido para a lixeira.`)
      setScreen('tickets')
    } catch (e) {
      alert(`Erro ao excluir: ${e.message}`)
    }
  }

  function toggleTimer() {
    if (!timerRunning) {
      // ── Bloqueia timer duplo — leitura direta do localStorage ──────────
      const active = getActiveTimer(currentUser.id)
      if (active && active.ticketId !== tk.id) {
        alert(`⚠️ Cronômetro já ativo no ticket #${active.ticketId}.\n\nPause-o antes de iniciar este.`)
        return
      }

      const start = new Date()
      setTimerStart(start)
      setTimerRunning(true)
      setActiveTimer(currentUser.id, { ticketId: tk.id, ticketTitle: tk.title, startTime: start.toISOString() })

      if (typeof Notification !== 'undefined' && Notification.permission === 'default') {
        Notification.requestPermission()
      }
      if (tk.status !== 'Em Andamento') {
        changeStatusAction(tk.id, 'Em Andamento').catch(() => {})
      }
    } else {
      // ── Pausa — salva sessão e persiste esforço no backend ─────────────
      const end        = new Date()
      const mins       = (end - timerStart) / 60000
      const updated    = [...sessions, { start: timerStart, end, mins }]
      const newEffort  = +(tk.effortUsed + mins / 60).toFixed(2)

      setSessions(updated)
      saveSessions(currentUser.id, tk.id, updated)
      setActiveTimer(currentUser.id, null)
      setTimerRunning(false)
      setTimerStart(null)

      // Atualiza estado local imediatamente
      setTickets(prev => prev.map(x => x.id === tk.id ? { ...x, effortUsed: newEffort } : x))
      // Persiste no backend para sobreviver a refresh
      api.updateTicket(tk.id, { effort_used: newEffort }).catch(() => {})
    }
  }

  return (
    <div>
      {/* Header */}
      <div style={{ display: 'flex', alignItems: 'flex-start', gap: 12, marginBottom: 22, flexWrap: 'wrap' }}>
        <button className="btn btn-secondary btn-sm" onClick={() => setScreen('tickets')}>← {t.back}</button>
        <div style={{ flex: 1 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10, flexWrap: 'wrap' }}>
            <span style={{ fontWeight: 700, fontSize: 16, color: 'var(--accent)' }}>{tk.id}</span>
            <Badge status={tk.status} />
            {pri && <PriBadge priority={pri} />}
            {expired && <span style={{ background: '#fef2f2', color: 'var(--danger)', padding: '2px 8px', borderRadius: 20, fontSize: 11, fontWeight: 600 }}>⚠ {t.slaExpired}</span>}
          </div>
          <div style={{ fontSize: 17, fontWeight: 700, marginTop: 4 }}>{tk.title}</div>
        </div>
        <div style={{ display: 'flex', gap: 7, flexWrap: 'wrap' }}>
          {p.triage && !tk.triaged && <button className="btn btn-primary btn-sm" onClick={() => setShowTriage(true)}>{t.triageBtn}</button>}
          {transitions.map(s => <button key={s} className="btn btn-secondary btn-sm" onClick={() => changeStatus(s)}>→ {s}</button>)}
          {p.closeTicket && tk.status !== 'Fechado' && <button className="btn btn-danger btn-sm" onClick={() => changeStatus('Fechado')}>{t.closeTicket}</button>}
          {p.reopenTicket && ['Fechado', 'Resolvido'].includes(tk.status) && <button className="btn btn-secondary btn-sm" onClick={() => changeStatus('Reaberto')}>{t.reopenTicket}</button>}
          {p.deleteTicket && <button className="btn btn-danger btn-sm" onClick={handleDelete} style={{ marginLeft: 4 }}>🗑 Excluir</button>}
        </div>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: '1fr 300px', gap: 16 }}>
        {/* Left column */}
        <div>
          {/* Description */}
          <div className="card" style={{ marginBottom: 14 }}>
            <div style={{ fontWeight: 600, marginBottom: 8 }}>Descrição</div>
            <div style={{ fontSize: 14, color: 'var(--text2)', lineHeight: 1.7 }}>{tk.description}</div>
          </div>

          {/* Timer */}
          {p.logEffort && (
            <div className="card" style={{ marginBottom: 14 }}>
              <div style={{ fontWeight: 600, marginBottom: 10 }}>⏱ {t.timer}</div>
              <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 10, flexWrap: 'wrap' }}>
                <button className={`btn btn-sm ${timerRunning ? 'btn-danger' : 'btn-primary'}`} onClick={toggleTimer}>
                  {timerRunning ? `⏸ ${t.pause}` : `▶ ${t.start}`}
                </button>
                <span style={{ fontSize: 13, color: 'var(--text2)' }}>
                  Utilizado: <strong style={{ color: 'var(--text)' }}>{tk.effortUsed.toFixed(1)}h</strong>
                  {' '}/ Estimado: <strong>{tk.effortEstimated}h</strong>
                </span>
                {tk.effortUsed >= tk.effortEstimated && tk.effortEstimated > 0 && (
                  <span style={{ color: 'var(--danger)', fontSize: 12, fontWeight: 600 }}>⚠ Limite atingido</span>
                )}
              </div>
              {timerRunning && timerStart && (
                <div style={{ fontSize: 12, color: '#16a34a', fontWeight: 500, marginBottom: 8, display: 'flex', alignItems: 'center', gap: 6 }}>
                  <span style={{ width: 8, height: 8, borderRadius: '50%', background: '#16a34a', display: 'inline-block', animation: 'pulse 1.5s infinite' }} />
                  Iniciado em {formatDateTime(timerStart.toISOString())}
                </div>
              )}
              <div className="progress">
                <div className="progress-bar" style={{ width: `${Math.min(100, (tk.effortUsed / Math.max(tk.effortEstimated, 1)) * 100)}%` }} />
              </div>
              {sessions.length > 0 && (
                <div style={{ marginTop: 10 }}>
                  <div style={{ fontSize: 12, color: 'var(--text2)', marginBottom: 6, fontWeight: 500 }}>{t.sessions}:</div>
                  {sessions.slice(0, 5).map((s, i) => (
                    <div key={i} style={{ fontSize: 12, padding: '6px 0', borderBottom: '1px solid var(--border)', display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 8 }}>
                      <div>
                        <span style={{ color: 'var(--text)', fontWeight: 500 }}>▶ {formatDateTime(s.start.toISOString())}</span>
                        <span style={{ color: 'var(--text2)', margin: '0 6px' }}>→</span>
                        <span style={{ color: 'var(--text)', fontWeight: 500 }}>⏸ {formatDateTime(s.end.toISOString())}</span>
                      </div>
                      <span style={{ fontSize: 11, background: 'var(--bg2)', padding: '2px 8px', borderRadius: 10, color: 'var(--text2)', flexShrink: 0 }}>
                        {s.mins.toFixed(1)} min
                      </span>
                    </div>
                  ))}
                  {sessions.length > 5 && (
                    <button className="btn btn-secondary btn-sm" style={{ marginTop: 6, fontSize: 11 }} onClick={() => { setMoreSessionsPage(0); setShowMoreSessions(true) }}>
                      Ver mais ({sessions.length - 5} restantes)
                    </button>
                  )}
                </div>
              )}
            </div>
          )}

          {/* Comments */}
          <div className="card" style={{ marginBottom: 14 }}>
            <div style={{ fontWeight: 600, marginBottom: 12 }}>💬 Comentários</div>
            {tk.comments.filter(c => c.type === 'public' || p.internalComment).length === 0 && (
              <div style={{ color: 'var(--text2)', fontSize: 13, marginBottom: 12 }}>Nenhum comentário ainda.</div>
            )}
            {(() => {
              const visibleComments = tk.comments.filter(c => c.type === 'public' || p.internalComment)
              return (
                <>
                  {visibleComments.slice(0, 5).map(c => {
                    // Usa dados embutidos no comment (independe do array users)
                    const cu = users.find(u => u.id === c.userId)
                    const authorUser = cu ?? { avatar: c.authorInitials, color: c.authorColor }
                    const authorName = cu ? `${cu.firstName} ${cu.lastName}` : (c.authorName || 'Usuário')
                    return (
                      <div key={c.id} className="timeline-item">
                        <Avatar user={authorUser} size={30} />
                        <div style={{ flex: 1 }}>
                          <div style={{ display: 'flex', gap: 8, alignItems: 'center', flexWrap: 'wrap', marginBottom: 4 }}>
                            <strong style={{ fontSize: 13 }}>{authorName}</strong>
                            {c.authorEmail && (
                              <span style={{ fontSize: 11, color: 'var(--text2)' }}>{c.authorEmail}</span>
                            )}
                            <span style={{ fontSize: 11, color: 'var(--text2)', marginLeft: 'auto' }}>{formatDate(c.date)}</span>
                            {c.type === 'internal' && (
                              <span style={{ background: '#fffbeb', color: '#92400e', padding: '1px 6px', borderRadius: 4, fontSize: 10, fontWeight: 600 }}>🔒 Interno</span>
                            )}
                          </div>
                          <div style={{ fontSize: 13, lineHeight: 1.6, whiteSpace: 'pre-wrap' }}>{c.text}</div>
                        </div>
                      </div>
                    )
                  })}
                  {visibleComments.length > 5 && (
                    <button className="btn btn-secondary btn-sm" style={{ marginTop: 6, fontSize: 11 }} onClick={() => { setMoreCommentsPage(0); setShowMoreComments(true) }}>
                      Ver mais ({visibleComments.length - 5} restantes)
                    </button>
                  )}
                </>
              )
            })()}
            {p.comment && (
              <div style={{ marginTop: 14 }}>
                <div style={{ display: 'flex', gap: 8, marginBottom: 8 }}>
                  <button className={`btn btn-sm ${commentType === 'public' ? 'btn-primary' : 'btn-secondary'}`} onClick={() => setCommentType('public')}>{t.public}</button>
                  {p.internalComment && <button className={`btn btn-sm ${commentType === 'internal' ? 'btn-primary' : 'btn-secondary'}`} onClick={() => setCommentType('internal')}>{t.internal}</button>}
                </div>
                <textarea className="input" rows={3} value={commentText} onChange={e => setCommentText(e.target.value)} placeholder="Escreva um comentário…" />
                <button className="btn btn-primary btn-sm" style={{ marginTop: 8 }} onClick={addComment}>{t.send}</button>
              </div>
            )}
          </div>

          {/* History */}
          <div className="card">
            <div style={{ fontWeight: 600, marginBottom: 12 }}>📝 {t.history}</div>
            {tk.history.length === 0 && <div style={{ color: 'var(--text2)', fontSize: 13 }}>Nenhuma alteração registrada.</div>}
            {tk.history.slice(0, 5).map((h, i) => {
              const hu = users.find(u => u.id === h.userId)
              return (
                <div key={i} className="timeline-item">
                  <div className="tl-dot" style={{ background: 'var(--bg2)', fontSize: 14 }}>📝</div>
                  <div style={{ flex: 1 }}>
                    <span style={{ fontSize: 13 }}>
                      <strong>{hu?.firstName || 'Sistema'}</strong> alterou <em style={{ color: 'var(--text2)' }}>{h.field}</em>: {h.from} → {h.to}
                    </span>
                    <div style={{ fontSize: 11, color: 'var(--text2)', marginTop: 2 }}>{formatDateTime(h.date)}</div>
                  </div>
                </div>
              )
            })}
            {tk.history.length > 5 && (
              <button className="btn btn-secondary btn-sm" style={{ marginTop: 6, fontSize: 11 }} onClick={() => { setMoreHistoryPage(0); setShowMoreHistory(true) }}>
                Ver mais ({tk.history.length - 5} restantes)
              </button>
            )}
          </div>
        </div>

        {/* Right column - details */}
        <div>
          <div className="card" style={{ marginBottom: 12 }}>
            <div style={{ fontWeight: 600, marginBottom: 12 }}>Detalhes</div>
            {[
              { label: 'Solicitante', val: req ? `${req.firstName} ${req.lastName}` : '—' },
              { label: 'Responsável', val: assignee ? `${assignee.firstName} ${assignee.lastName}` : 'Não atribuído' },
              { label: 'Categoria', val: <CatChip category={cat} /> },
              { label: 'Prioridade', val: <PriBadge priority={pri} /> },
              { label: 'Prazo', val: <span style={{ color: expired ? 'var(--danger)' : 'var(--text)', fontWeight: expired ? 600 : 400 }}>{formatDate(tk.deadline)}</span> },
              { label: 'Abertura', val: formatDate(tk.createdAt) },
              { label: 'Esforço est.', val: `${tk.effortEstimated}h` },
              { label: 'Esforço usado', val: `${tk.effortUsed.toFixed(1)}h` },
            ].map(r => (
              <div key={r.label} style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '6px 0', borderBottom: '1px solid var(--border)', fontSize: 13 }}>
                <span style={{ color: 'var(--text2)' }}>{r.label}</span>
                <span style={{ fontWeight: 500 }}>{r.val}</span>
              </div>
            ))}
          </div>

          {/* Anexos */}
          {(p.createTicket || (localAttachments ?? []).length > 0) && (
            <div className="card" style={{ marginBottom: 12 }}>
              <div style={{ fontWeight: 600, marginBottom: 10 }}>📎 Anexos</div>
              {localAttachments === null && (
                <div style={{ fontSize: 12, color: 'var(--text2)' }}>Carregando...</div>
              )}
              {localAttachments !== null && localAttachments.length === 0 && (
                <div style={{ fontSize: 12, color: 'var(--text2)' }}>Nenhum anexo.</div>
              )}
              {(localAttachments ?? []).map((att) => (
                <div key={att.id} style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '5px 0', borderBottom: '1px solid var(--border)', fontSize: 12 }}>
                  <span>📄</span>
                  <span style={{ flex: 1, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{att.name}</span>
                  <span style={{ color: 'var(--text2)', flexShrink: 0 }}>{att.size ? (att.size / 1024).toFixed(0) + ' KB' : ''}</span>
                  <button className="btn btn-secondary btn-sm" style={{ flexShrink: 0 }}
                    onClick={() => api.downloadAttachment(tk.id, att.id, att.name).catch(e => alert(`Erro no download: ${e.message}`))}>
                    ⬇ Baixar
                  </button>
                  {p.deleteTicket && (
                    <button className="btn btn-danger btn-sm" style={{ flexShrink: 0, padding: '2px 6px' }}
                      onClick={async () => {
                        if (!confirm(`Remover "${att.name}"?`)) return
                        try {
                          await api.deleteAttachment(tk.id, att.id)
                          setLocalAttachments(prev => prev.filter(a => a.id !== att.id))
                        } catch (e) { alert(`Erro ao remover: ${e.message}`) }
                      }}>✕</button>
                  )}
                </div>
              ))}
              {/* Upload de novo anexo */}
              {p.createTicket && (
                <div style={{ marginTop: 10, display: 'flex', gap: 6, alignItems: 'center', flexWrap: 'wrap' }}>
                  <input type="file" style={{ fontSize: 11, flex: 1, minWidth: 0 }}
                    onChange={e => setNewAttFile(e.target.files[0] || null)} />
                  <button className="btn btn-secondary btn-sm" disabled={!newAttFile || addingAtt}
                    onClick={async () => {
                      if (!newAttFile) return
                      setAddingAtt(true)
                      try {
                        const att = await api.uploadAttachment(tk.id, newAttFile)
                        setLocalAttachments(prev => [...(prev ?? []), mapAttachment(att)])
                        setNewAttFile(null)
                        showToast('Anexo enviado!')
                      } catch (e) {
                        alert(`Erro no upload: ${e.message}`)
                      } finally {
                        setAddingAtt(false)
                      }
                    }}>
                    {addingAtt ? '⏳ Enviando...' : '➕ Enviar'}
                  </button>
                </div>
              )}
            </div>
          )}

          {/* Co-responsáveis */}
          {(tk.coAssignees ?? []).length > 0 && (
            <div className="card" style={{ marginBottom: 12 }}>
              <div style={{ fontWeight: 600, marginBottom: 10 }}>👥 Co-responsáveis</div>
              <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
                {tk.coAssignees.map(u => (
                  <div key={u.id} style={{ display: 'flex', alignItems: 'center', gap: 6, background: 'var(--bg2)', padding: '4px 10px', borderRadius: 20, fontSize: 12 }}>
                    <Avatar user={u} size={20} />
                    <span>{u.firstName} {u.lastName}</span>
                  </div>
                ))}
              </div>
            </div>
          )}

          {p.reassign && (
            <div className="card">
              <div style={{ fontWeight: 600, marginBottom: 8 }}>Reatribuir</div>
              <select
                className="select" style={{ width: '100%' }}
                defaultValue={tk.assigneeId || ''}
                onChange={e => {
                  const uid = Number(e.target.value) || null
                  assignAction(tk.id, uid).catch(() => {})
                }}
              >
                <option value="">Sem responsável</option>
                {users.filter(u => u.role !== 'user').map(u => (
                  <option key={u.id} value={u.id}>{u.firstName} {u.lastName}</option>
                ))}
              </select>
            </div>
          )}
        </div>
      </div>

      {/* Ver mais — Sessões */}
      {showMoreSessions && (
        <ModalOverlay onClose={() => setShowMoreSessions(false)}>
          <div className="modal" style={{ maxWidth: 560 }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 16 }}>
              <h3 style={{ fontWeight: 700 }}>Histórico de Sessões</h3>
              <button className="btn btn-secondary btn-sm" onClick={() => setShowMoreSessions(false)}>✕</button>
            </div>
            {sessions.slice(moreSessionsPage * MORE_PER, (moreSessionsPage + 1) * MORE_PER).map((s, i) => (
              <div key={i} style={{ fontSize: 12, padding: '8px 0', borderBottom: '1px solid var(--border)', display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 8 }}>
                <div>
                  <div style={{ marginBottom: 2 }}>
                    <span style={{ color: '#16a34a', fontWeight: 500 }}>▶ Iniciado: </span>
                    <span style={{ color: 'var(--text)' }}>{formatDateTime(s.start.toISOString())}</span>
                  </div>
                  <div>
                    <span style={{ color: '#dc2626', fontWeight: 500 }}>⏸ Pausado: </span>
                    <span style={{ color: 'var(--text)' }}>{formatDateTime(s.end.toISOString())}</span>
                  </div>
                </div>
                <span style={{ fontSize: 12, background: 'var(--bg2)', padding: '3px 10px', borderRadius: 10, color: 'var(--text2)', flexShrink: 0 }}>
                  {s.mins.toFixed(1)} min
                </span>
              </div>
            ))}
            {Math.ceil(sessions.length / MORE_PER) > 1 && (
              <div style={{ display: 'flex', gap: 8, justifyContent: 'center', marginTop: 12 }}>
                <button className="btn btn-secondary btn-sm" disabled={moreSessionsPage === 0} onClick={() => setMoreSessionsPage(p => p - 1)}>◀</button>
                <span style={{ fontSize: 12, color: 'var(--text2)' }}>{moreSessionsPage + 1} / {Math.ceil(sessions.length / MORE_PER)}</span>
                <button className="btn btn-secondary btn-sm" disabled={moreSessionsPage >= Math.ceil(sessions.length / MORE_PER) - 1} onClick={() => setMoreSessionsPage(p => p + 1)}>▶</button>
              </div>
            )}
          </div>
        </ModalOverlay>
      )}

      {/* Ver mais — Comentários */}
      {showMoreComments && (
        <ModalOverlay onClose={() => setShowMoreComments(false)}>
          <div className="modal" style={{ maxWidth: 600 }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 16 }}>
              <h3 style={{ fontWeight: 700 }}>Todos os Comentários</h3>
              <button className="btn btn-secondary btn-sm" onClick={() => setShowMoreComments(false)}>✕</button>
            </div>
            {(() => {
              const all = tk.comments.filter(c => c.type === 'public' || p.internalComment)
              return all.slice(moreCommentsPage * MORE_PER, (moreCommentsPage + 1) * MORE_PER).map(c => {
                const cu = users.find(u => u.id === c.userId)
                const authorUser = cu ?? { avatar: c.authorInitials, color: c.authorColor }
                const authorName = cu ? `${cu.firstName} ${cu.lastName}` : (c.authorName || 'Usuário')
                return (
                  <div key={c.id} className="timeline-item">
                    <Avatar user={authorUser} size={28} />
                    <div style={{ flex: 1 }}>
                      <div style={{ display: 'flex', gap: 8, alignItems: 'center', flexWrap: 'wrap', marginBottom: 4 }}>
                        <strong style={{ fontSize: 13 }}>{authorName}</strong>
                        {c.authorEmail && (
                          <span style={{ fontSize: 11, color: 'var(--text2)' }}>{c.authorEmail}</span>
                        )}
                        <span style={{ fontSize: 11, color: 'var(--text2)', marginLeft: 'auto' }}>{formatDate(c.date)}</span>
                        {c.type === 'internal' && <span style={{ background: '#fffbeb', color: '#92400e', padding: '1px 6px', borderRadius: 4, fontSize: 10, fontWeight: 600 }}>🔒 Interno</span>}
                      </div>
                      <div style={{ fontSize: 13, lineHeight: 1.6, whiteSpace: 'pre-wrap' }}>{c.text}</div>
                    </div>
                  </div>
                )
              })
            })()}
            {(() => {
              const total = tk.comments.filter(c => c.type === 'public' || p.internalComment).length
              return Math.ceil(total / MORE_PER) > 1 ? (
                <div style={{ display: 'flex', gap: 8, justifyContent: 'center', marginTop: 12 }}>
                  <button className="btn btn-secondary btn-sm" disabled={moreCommentsPage === 0} onClick={() => setMoreCommentsPage(p => p - 1)}>◀</button>
                  <span style={{ fontSize: 12, color: 'var(--text2)' }}>{moreCommentsPage + 1} / {Math.ceil(total / MORE_PER)}</span>
                  <button className="btn btn-secondary btn-sm" disabled={moreCommentsPage >= Math.ceil(total / MORE_PER) - 1} onClick={() => setMoreCommentsPage(p => p + 1)}>▶</button>
                </div>
              ) : null
            })()}
          </div>
        </ModalOverlay>
      )}

      {/* Ver mais — Histórico */}
      {showMoreHistory && (
        <ModalOverlay onClose={() => setShowMoreHistory(false)}>
          <div className="modal" style={{ maxWidth: 600 }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 16 }}>
              <h3 style={{ fontWeight: 700 }}>Histórico Completo</h3>
              <button className="btn btn-secondary btn-sm" onClick={() => setShowMoreHistory(false)}>✕</button>
            </div>
            {tk.history.slice(moreHistoryPage * MORE_PER, (moreHistoryPage + 1) * MORE_PER).map((h, i) => {
              const hu = users.find(u => u.id === h.userId)
              return (
                <div key={i} className="timeline-item">
                  <div className="tl-dot" style={{ background: 'var(--bg2)', fontSize: 14 }}>📝</div>
                  <div style={{ flex: 1 }}>
                    <span style={{ fontSize: 13 }}>
                      <strong>{hu?.firstName || 'Sistema'}</strong> alterou <em style={{ color: 'var(--text2)' }}>{h.field}</em>: {h.from} → {h.to}
                    </span>
                    <div style={{ fontSize: 11, color: 'var(--text2)', marginTop: 2 }}>{formatDateTime(h.date)}</div>
                  </div>
                </div>
              )
            })}
            {Math.ceil(tk.history.length / MORE_PER) > 1 && (
              <div style={{ display: 'flex', gap: 8, justifyContent: 'center', marginTop: 12 }}>
                <button className="btn btn-secondary btn-sm" disabled={moreHistoryPage === 0} onClick={() => setMoreHistoryPage(p => p - 1)}>◀</button>
                <span style={{ fontSize: 12, color: 'var(--text2)' }}>{moreHistoryPage + 1} / {Math.ceil(tk.history.length / MORE_PER)}</span>
                <button className="btn btn-secondary btn-sm" disabled={moreHistoryPage >= Math.ceil(tk.history.length / MORE_PER) - 1} onClick={() => setMoreHistoryPage(p => p + 1)}>▶</button>
              </div>
            )}
          </div>
        </ModalOverlay>
      )}

      {/* Triage modal */}
      {showTriage && (
        <ModalOverlay onClose={() => setShowTriage(false)}>
          <div className="modal">
            <h3 style={{ fontWeight: 700, marginBottom: 18 }}>🎯 {t.triageBtn}</h3>
            <div className="form-grid">
              <div>
                <label className="label">Prioridade *</label>
                <select className="select" style={{ width: '100%' }} value={triageForm.priorityId} onChange={e => setTriageForm(f => ({ ...f, priorityId: e.target.value }))}>
                  <option value="">Selecione…</option>
                  {priorities.map(p => <option key={p.id} value={p.id}>{p.name} ({p.slaHours}h SLA)</option>)}
                </select>
              </div>
              <div>
                <label className="label">Categoria</label>
                <select className="select" style={{ width: '100%' }} value={triageForm.categoryId || tk.categoryId} onChange={e => setTriageForm(f => ({ ...f, categoryId: e.target.value }))}>
                  {categories.map(c => <option key={c.id} value={c.id}>{c.name}</option>)}
                </select>
              </div>
              <div>
                <label className="label">Horas de esforço estimadas</label>
                <input className="input" type="number" min="0" step="0.5" value={triageForm.effortEstimated} onChange={e => setTriageForm(f => ({ ...f, effortEstimated: e.target.value }))} />
              </div>
              <div>
                <label className="label">Fila *</label>
                <select className="select" style={{ width: '100%' }} value={triageForm.queueId}
                  onChange={e => setTriageForm(f => ({ ...f, queueId: e.target.value, assigneeId: '' }))}>
                  <option value="">Selecione…</option>
                  {queues.map(q => <option key={q.id} value={q.id}>{q.name}</option>)}
                </select>
              </div>
              <div>
                <label className="label">Responsável</label>
                <select className="select" style={{ width: '100%' }} value={triageForm.assigneeId || ''}
                  onChange={e => setTriageForm(f => ({ ...f, assigneeId: e.target.value }))}>
                  <option value="">— Selecione o responsável —</option>
                  {(() => {
                    const q = queues.find(x => x.id === Number(triageForm.queueId))
                    return users.filter(u => (q?.members ?? []).includes(u.id))
                      .map(u => <option key={u.id} value={u.id}>{u.firstName} {u.lastName}</option>)
                  })()}
                </select>
              </div>
              <div style={{ gridColumn: '1 / -1' }}>
                <label className="label">Co-responsáveis (opcional)</label>
                <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6, padding: '8px', background: 'var(--bg2)', borderRadius: 8, border: '1px solid var(--border)', minHeight: 40 }}>
                  {(() => {
                    const q = queues.find(x => x.id === Number(triageForm.queueId))
                    const qMembers = users.filter(u => (q?.members ?? []).includes(u.id) && String(u.id) !== String(triageForm.assigneeId))
                    if (!triageForm.queueId || qMembers.length === 0) return <span style={{ fontSize: 12, color: 'var(--text2)' }}>Selecione uma fila e um responsável primeiro.</span>
                    return qMembers.map(u => {
                      const selected = (triageForm.coAssigneeIds ?? []).includes(u.id)
                      return (
                        <button
                          key={u.id}
                          type="button"
                          onClick={() => setTriageForm(f => {
                            const cur = f.coAssigneeIds ?? []
                            return { ...f, coAssigneeIds: selected ? cur.filter(id => id !== u.id) : [...cur, u.id] }
                          })}
                          style={{
                            padding: '3px 10px', borderRadius: 20, fontSize: 12, cursor: 'pointer',
                            background: selected ? 'var(--accent)' : 'var(--bg)',
                            color: selected ? '#fff' : 'var(--text)',
                            border: `1px solid ${selected ? 'var(--accent)' : 'var(--border)'}`,
                            fontWeight: selected ? 600 : 400,
                          }}
                        >
                          {selected ? '✓ ' : ''}{u.firstName} {u.lastName}
                        </button>
                      )
                    })
                  })()}
                </div>
              </div>
            </div>
            <div style={{ display: 'flex', gap: 10, justifyContent: 'flex-end', marginTop: 18 }}>
              <button className="btn btn-secondary" onClick={() => setShowTriage(false)}>{t.cancel}</button>
              <button className="btn btn-primary" onClick={doTriage}>Confirmar Triagem</button>
            </div>
          </div>
        </ModalOverlay>
      )}
    </div>
  )
}
