import { useState, useMemo, useEffect, useRef } from 'react'
import { api } from '../api.js'
import { mapAttachment, mapTicket, mapTimerSession } from '../mapper.js'
import { useApp } from '../AppContext.jsx'
import { PT, EN, PERM, STATUS_LIST, ALLOWED_TRANSITIONS, isExpired, formatDate, formatDateTime, isAdmin } from '../data.js'
import { Avatar, Badge, PriBadge, CatChip, ModalOverlay, EmptyState } from '../components.jsx'

// ── Formatação de esforço em H:MM ─────────────────────────────────────────
function fmtHM(hours) {
  const totalMins = Math.round((hours ?? 0) * 60)
  const h = Math.floor(totalMins / 60)
  const m = totalMins % 60
  return `${h}:${String(m).padStart(2, '0')}`
}
function fmtMinsHM(mins) {
  return fmtHM((mins ?? 0) / 60)
}

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
  const { currentUser, lang, tickets, priorities, categories, users, queues, setScreen, setSelectedTicket, triageAction, showToast,
          savedViews, createSavedViewAction, deleteSavedViewAction } = useApp()
  const t = lang === 'pt' ? PT : EN
  const p = PERM[currentUser.role] || PERM.user
  const canUseViews = currentUser.role !== 'user'

  const [search, setSearch] = useState('')
  const [filterStatus, setFilterStatus] = useState([])
  const [filterPri, setFilterPri] = useState([])
  const [filterCat, setFilterCat] = useState([])
  const [filterAssignee, setFilterAssignee] = useState([])
  const [openFilter, setOpenFilter] = useState(null) // 'status'|'pri'|'cat'|'assignee'|null
  const [sortBy, setSortBy] = useState('createdAt')
  const [sortDir, setSortDir] = useState('desc')
  const [page, setPage] = useState(0)
  const PER = 25

  // ── Saved Views (persistidas no servidor, por usuário e empresa) ─────────
  const [activeViewId, setActiveViewId] = useState('all')
  const [savingView,  setSavingView]  = useState(false)
  const [newViewName, setNewViewName] = useState('')
  const [hoveredView, setHoveredView] = useState(null)

  function applyView(view) {
    setActiveViewId(view.id)
    setSearch(view.filters.search || '')
    setFilterStatus(view.filters.status || [])
    setFilterPri(view.filters.priority || [])
    setFilterCat(view.filters.category || [])
    setFilterAssignee(view.filters.assignee || [])
    setPage(0)
  }

  function clearAllFilters() {
    setActiveViewId('all')
    setSearch(''); setFilterStatus([]); setFilterPri([]); setFilterCat([]); setFilterAssignee([])
    setPage(0)
  }

  async function saveCurrentView() {
    if (!newViewName.trim()) return
    const filters = { search, status: filterStatus, priority: filterPri, category: filterCat, assignee: filterAssignee }
    try {
      const view = await createSavedViewAction(newViewName.trim(), filters)
      setActiveViewId(view.id)
      setSavingView(false)
      setNewViewName('')
      showToast(`Lista "${view.name}" salva!`)
    } catch (e) {
      showToast(`Erro ao salvar lista: ${e.message}`)
    }
  }

  async function deleteView(id) {
    try {
      await deleteSavedViewAction(id)
      if (activeViewId === id) clearAllFilters()
    } catch (e) {
      showToast(`Erro ao excluir lista: ${e.message}`)
    }
  }

  // Open ticket in new tab — middle-click
  function openTicketNewTab(tk) {
    const base = window.location.href.split('#')[0]
    window.open(`${base}#ticket/${tk.id}`, '_blank')
  }

  const [showInlineTriage, setShowInlineTriage] = useState(false)
  const [triageTarget, setTriageTarget] = useState(null)
  const [inlineTriageForm, setInlineTriageForm] = useState({ priorityId: '', categoryId: '', effortEstimated: '', queueId: '', assigneeId: '', coAssigneeIds: [] })

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
    if (filterAssignee.length) tks = tks.filter(tk => filterAssignee.includes(tk.assigneeId))
    tks.sort((a, b) => {
      let av = a[sortBy], bv = b[sortBy]
      if (typeof av === 'string') av = av.toLowerCase(); bv = bv?.toLowerCase?.() ?? ''
      return sortDir === 'asc' ? (av > bv ? 1 : -1) : (av < bv ? 1 : -1)
    })
    return tks
  }, [tickets, currentUser, search, filterStatus, filterPri, filterCat, filterAssignee, sortBy, sortDir])

  const paged = filtered.slice(page * PER, (page + 1) * PER)
  const totalPages = Math.ceil(filtered.length / PER)

  function sort(col) {
    if (sortBy === col) setSortDir(d => d === 'asc' ? 'desc' : 'asc')
    else { setSortBy(col); setSortDir('asc') }
  }
  const sortIcon = (col) => sortBy === col ? (sortDir === 'asc' ? ' ↑' : ' ↓') : ''

  function openTicket(tk) { setSelectedTicket(tk.id) }

  async function doInlineTriage() {
    if (!inlineTriageForm.priorityId || !inlineTriageForm.queueId) { alert('Preencha prioridade e fila.'); return }
    const tk = tickets.find(x => x.id === triageTarget)
    if (!tk) return
    const assigneeId = inlineTriageForm.assigneeId ? Number(inlineTriageForm.assigneeId) : null
    try {
      await triageAction(triageTarget, {
        priority_id:      Number(inlineTriageForm.priorityId) || null,
        category_id:      inlineTriageForm.categoryId ? Number(inlineTriageForm.categoryId) : (tk.categoryId || null),
        queue_id:         Number(inlineTriageForm.queueId) || null,
        assignee_id:      assigneeId,
        co_assignee_ids:  (inlineTriageForm.coAssigneeIds ?? []).map(Number),
        effort_estimated: inlineTriageForm.effortEstimated ? parseFloat(inlineTriageForm.effortEstimated) : 0,
      })
      showToast('Triagem realizada com sucesso!')
    } catch (e) {
      alert(`Erro ao triar: ${e.message}`)
    }
    setShowInlineTriage(false)
    setTriageTarget(null)
    setInlineTriageForm({ priorityId: '', categoryId: '', effortEstimated: '', queueId: '', assigneeId: '', coAssigneeIds: [] })
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

      {/* ── Saved Views bar (admin / analyst / manager) ─────────────────── */}
      {canUseViews && (
        <div style={{ marginBottom: 10, display: 'flex', alignItems: 'center', gap: 8, flexWrap: 'wrap' }}>
          <button
            className="btn btn-secondary btn-sm"
            style={{
              borderRadius: 20, padding: '4px 14px', fontSize: 12,
              fontWeight: activeViewId === 'all' ? 700 : 400,
              background: activeViewId === 'all' ? 'var(--accent)' : 'var(--bg2)',
              color: activeViewId === 'all' ? '#fff' : 'var(--text)',
              border: '1px solid ' + (activeViewId === 'all' ? 'var(--accent)' : 'var(--border)'),
            }}
            onClick={clearAllFilters}
          >📋 Todos</button>

          {savedViews.map(view => (
            <div key={view.id} style={{ position: 'relative', display: 'inline-flex' }}
              onMouseEnter={() => setHoveredView(view.id)}
              onMouseLeave={() => setHoveredView(null)}
            >
              <button
                className="btn btn-secondary btn-sm"
                style={{
                  borderRadius: 20, padding: '4px 14px', fontSize: 12,
                  fontWeight: activeViewId === view.id ? 700 : 400,
                  background: activeViewId === view.id ? 'var(--accent)' : 'var(--bg2)',
                  color: activeViewId === view.id ? '#fff' : 'var(--text)',
                  border: '1px solid ' + (activeViewId === view.id ? 'var(--accent)' : 'var(--border)'),
                  paddingRight: hoveredView === view.id ? 28 : 14,
                  transition: 'padding 0.15s',
                }}
                onClick={() => applyView(view)}
              >🔖 {view.name}</button>
              {hoveredView === view.id && (
                <button onClick={e => { e.stopPropagation(); deleteView(view.id) }}
                  style={{
                    position: 'absolute', right: 6, top: '50%', transform: 'translateY(-50%)',
                    background: 'none', border: 'none', cursor: 'pointer',
                    color: activeViewId === view.id ? 'rgba(255,255,255,0.8)' : 'var(--danger)',
                    fontSize: 12, padding: 0, lineHeight: 1,
                  }}
                  title="Remover lista"
                >✕</button>
              )}
            </div>
          ))}

          {!savingView ? (
            <button className="btn btn-secondary btn-sm"
              style={{ borderRadius: 20, padding: '4px 12px', fontSize: 12 }}
              onClick={() => { setSavingView(true); setNewViewName('') }}
              title="Salvar filtros atuais como lista"
            >💾 Salvar filtro</button>
          ) : (
            <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
              <input autoFocus className="input" placeholder="Nome da lista…"
                value={newViewName} onChange={e => setNewViewName(e.target.value)}
                onKeyDown={e => { if (e.key === 'Enter') saveCurrentView(); if (e.key === 'Escape') { setSavingView(false); setNewViewName('') } }}
                style={{ padding: '4px 10px', fontSize: 12, height: 28, width: 160 }}
              />
              <button className="btn btn-primary btn-sm" style={{ fontSize: 12, padding: '4px 10px' }} onClick={saveCurrentView}>Salvar</button>
              <button className="btn btn-secondary btn-sm" style={{ fontSize: 12, padding: '4px 8px' }} onClick={() => { setSavingView(false); setNewViewName('') }}>✕</button>
            </div>
          )}
        </div>
      )}

      <div className="card" style={{ marginBottom: 12 }}>
        <div style={{ display: 'flex', gap: 10, flexWrap: 'wrap', alignItems: 'center' }}>
          <div className="search-box" style={{ flex: '1 1 200px' }}>
            <span>🔍</span>
            <input placeholder="Buscar por título ou ID…" value={search} onChange={e => { setSearch(e.target.value); setPage(0) }} />
          </div>
          <MultiFilter
            label="Status" filterKey="status" selected={filterStatus} setSelected={v => { setFilterStatus(v); setPage(0); setActiveViewId('') }}
            options={STATUS_LIST.map(s => ({ value: s, label: s }))}
          />
          <MultiFilter
            label="Prioridade" filterKey="pri" selected={filterPri} setSelected={v => { setFilterPri(v); setPage(0); setActiveViewId('') }}
            options={priorities.map(p => ({ value: p.id, label: p.name }))}
          />
          <MultiFilter
            label="Categoria" filterKey="cat" selected={filterCat} setSelected={v => { setFilterCat(v); setPage(0); setActiveViewId('') }}
            options={categories.map(c => ({ value: c.id, label: c.name }))}
          />
          <MultiFilter
            label="Responsável" filterKey="assignee" selected={filterAssignee} setSelected={v => { setFilterAssignee(v); setPage(0); setActiveViewId('') }}
            options={users.filter(u => u.role !== 'user').map(u => ({ value: u.id, label: `${u.firstName} ${u.lastName}` }))}
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
              <th>Responsável</th>
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
              <tr><td colSpan={11} style={{ textAlign: 'center', color: 'var(--text2)', padding: 32 }}>Nenhum ticket encontrado</td></tr>
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
                  onMouseDown={e => { if (e.button === 1) { e.preventDefault(); openTicketNewTab(tk) } }}
                >
                  <td style={{ color: 'var(--accent)', fontWeight: 600 }} onClick={e => e.stopPropagation()}>
                    <a
                      href={`${window.location.href.split('#')[0]}#ticket/${tk.id}`}
                      style={{ color: 'var(--accent)', fontWeight: 600, textDecoration: 'none' }}
                      onClick={e => { e.preventDefault(); openTicket(tk) }}
                    >{tk.id}</a>
                  </td>
                  <td style={{ maxWidth: 220, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                    {expired && <span style={{ color: 'var(--danger)', marginRight: 5 }}>⚠</span>}
                    {tk.title}
                  </td>
                  <td style={{ color: 'var(--text2)', fontSize: 12 }}>{req ? req.firstName + ' ' + req.lastName : '—'}</td>
                  <td style={{ fontSize: 12 }}>
                    {(() => {
                      const asgn = users.find(u => u.id === tk.assigneeId)
                      return asgn ? (
                        <span style={{ display: 'flex', alignItems: 'center', gap: 5 }}>
                          <Avatar user={asgn} size={20} />
                          <span style={{ color: 'var(--text)' }}>{asgn.firstName} {asgn.lastName}</span>
                        </span>
                      ) : <span style={{ color: 'var(--text2)' }}>—</span>
                    })()}
                  </td>
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
                        {fmtHM(tk.effortUsed)}/{fmtHM(tk.effortEstimated)}
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
                  onChange={e => setInlineTriageForm(f => ({ ...f, assigneeId: e.target.value, coAssigneeIds: [] }))}>
                  <option value="">— Deixar sem responsável —</option>
                  {(() => {
                    const q = queues.find(x => x.id === Number(inlineTriageForm.queueId))
                    return users.filter(u => (q?.members ?? []).includes(u.id))
                      .map(u => <option key={u.id} value={u.id}>{u.firstName} {u.lastName}</option>)
                  })()}
                </select>
              </div>
              <div style={{ gridColumn: '1 / -1' }}>
                <label className="label">Co-responsáveis <span style={{ fontWeight: 400, color: 'var(--text2)' }}>(opcional — membros da fila)</span></label>
                {!inlineTriageForm.queueId ? (
                  <div style={{ fontSize: 12, color: 'var(--text2)', padding: '4px 0' }}>Selecione uma fila primeiro.</div>
                ) : (() => {
                  const q = queues.find(x => x.id === Number(inlineTriageForm.queueId))
                  const qMembers = users.filter(u => (q?.members ?? []).includes(u.id) && String(u.id) !== String(inlineTriageForm.assigneeId))
                  if (qMembers.length === 0) return <div style={{ fontSize: 12, color: 'var(--text2)', padding: '4px 0' }}>Nenhum outro membro disponível na fila.</div>
                  return (
                    <div style={{ display: 'flex', flexDirection: 'column', gap: 6, padding: '8px 10px', background: 'var(--bg2)', borderRadius: 8, border: '1px solid var(--border)' }}>
                      {qMembers.map(u => {
                        const checked = (inlineTriageForm.coAssigneeIds ?? []).includes(u.id)
                        return (
                          <label key={u.id} style={{ display: 'flex', alignItems: 'center', gap: 8, cursor: 'pointer', fontSize: 13 }}>
                            <input
                              type="checkbox"
                              checked={checked}
                              onChange={() => setInlineTriageForm(f => {
                                const cur = f.coAssigneeIds ?? []
                                return { ...f, coAssigneeIds: checked ? cur.filter(id => id !== u.id) : [...cur, u.id] }
                              })}
                            />
                            {u.firstName} {u.lastName}
                          </label>
                        )
                      })}
                    </div>
                  )
                })()}
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
  const { currentUser, lang, categories, articles, setScreen, addNotification, showToast, notifyEmail, createTicketAction, updateTicketAction, systemConfig } = useApp()
  const t = lang === 'pt' ? PT : EN
  const todayISO = new Date().toISOString().slice(0, 10)
  const [form, setForm] = useState({ title: '', description: '', categoryId: '', openingDate: todayISO, attachments: [] })
  const [errors, setErrors] = useState({})
  const [files, setFiles] = useState([])
  const [fileError, setFileError] = useState(null)
  const [uploading, setUploading] = useState(false)

  const MAX_FILES = 3
  const MAX_FILE_SIZE = 5 * 1024 * 1024 // 5 MB

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
      // Admin: sobrescreve created_at se diferente de hoje
      if (isAdmin(currentUser.role) && form.openingDate && form.openingDate !== todayISO) {
        await updateTicketAction(ticket.id, { created_at: form.openingDate })
      }
      addNotification({ title: `Ticket ${ticket.id} criado`, desc: form.title, type: 'create', ticketId: ticket.id })
      notifyEmail(
        currentUser.email,
        `[DataTicket #${ticket.id}] Ticket aberto: ${form.title}`,
        `<div style="font-family:sans-serif;max-width:600px;margin:0 auto">
          <div style="background:#2383e2;padding:20px;border-radius:8px 8px 0 0">
            <h2 style="color:#fff;margin:0">🎯 DataTicket</h2>
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
        {isAdmin(currentUser.role) && (
          <div className="form-row">
            <label className="label">
              📅 Data de Abertura
              <span style={{ fontSize: 10, color: 'var(--accent)', marginLeft: 6, fontWeight: 400 }}>admin</span>
            </label>
            <input
              type="date"
              className="input"
              style={{ maxWidth: 200 }}
              value={form.openingDate}
              max={todayISO}
              onChange={e => setForm(f => ({ ...f, openingDate: e.target.value }))}
            />
            <p style={{ fontSize: 11, color: 'var(--text2)', marginTop: 4 }}>
              Padrão: hoje. Altere apenas para registrar tickets de datas anteriores.
            </p>
          </div>
        )}
        <div className="form-row">
          <label className="label">📎 Anexos (PDF, PNG, JPG, DOCX — máx. {MAX_FILES} arquivos, 5 MB cada)</label>
          <>
            <input type="file" multiple accept=".pdf,.png,.jpg,.jpeg,.doc,.docx,.txt,.xlsx,.zip"
              style={{ fontSize: 13, color: 'var(--text)', padding: '6px 0' }}
              onChange={e => {
                const selected = Array.from(e.target.files)
                if (selected.length > MAX_FILES) {
                  setFileError(`Máximo de ${MAX_FILES} arquivos permitidos.`)
                  e.target.value = ''
                  return
                }
                const oversized = selected.filter(f => f.size > MAX_FILE_SIZE)
                if (oversized.length > 0) {
                  setFileError(`Arquivo(s) muito grandes: ${oversized.map(f => f.name).join(', ')}. Máximo de 5 MB por arquivo.`)
                  e.target.value = ''
                  return
                }
                setFileError(null)
                setFiles(selected)
              }} />
            {fileError && (
              <div style={{ marginTop: 6, color: 'var(--danger)', fontSize: 12, fontWeight: 500 }}>
                ⚠ {fileError}
              </div>
            )}
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
  const { currentUser, lang, tickets, setTickets, priorities, categories, users, queues, setScreen, addNotification, showToast, selectedTicket, notifyEmail, changeStatusAction, addCommentAction, updateTicketAction, triageAction, assignAction, deleteTicketAction, addEffortAction, deleteEffortAction, systemConfig } = useApp()
  const t = lang === 'pt' ? PT : EN
  const tk = tickets.find(x => x.id === selectedTicket)

  // "+ Horas": SuperAdmin, admin, gestor e analista podem adicionar esforço.
  const canAddEffort = ['msp_admin', 'admin', 'manager', 'analyst'].includes(currentUser.role)
  const isSuper      = currentUser.role === 'msp_admin'

  const [commentText, setCommentText] = useState('')
  const [commentType, setCommentType] = useState('public')
  const [showTriage, setShowTriage] = useState(false)
  const [showEffort, setShowEffort] = useState(false)
  const [effortHours, setEffortHours] = useState('')
  const [effortReason, setEffortReason] = useState('')
  const [effortSaving, setEffortSaving] = useState(false)
  const [triageForm, setTriageForm] = useState({ priorityId: '', categoryId: '', effortEstimated: '', queueId: '', assigneeId: '', coAssigneeIds: [], deadline: '' })
  const [deadlineSuggestion, setDeadlineSuggestion] = useState(null)  // prazo sugerido (ISO) pelas regras
  const [capacityMap, setCapacityMap] = useState({})   // userId → { load_pct, free_hours, scheduled_hours }
  const [timerRunning, setTimerRunning] = useState(false)
  const [timerStart, setTimerStart] = useState(null)
  const [sessions, setSessions] = useState([])
  const [showReopenModal, setShowReopenModal] = useState(false)
  const [reopenHours, setReopenHours] = useState('')

  // Carrega sessões do banco (via tk.timerSessions) e retoma timer ativo
  useEffect(() => {
    if (!tk) return
    const allSessions = tk.timerSessions ?? []
    setSessions(allSessions)

    // ── Prioridade 1: sessão 'running' no banco (sobrevive a page refresh / crash) ─
    const runningInDB = allSessions.find(
      s => s.status === 'running' && s.userId === currentUser.id
    )
    if (runningInDB) {
      const startTime = runningInDB.start instanceof Date ? runningInDB.start : new Date(runningInDB.start)
      setTimerStart(startTime)
      setTimerRunning(true)
      setActiveTimer(currentUser.id, {
        ticketId:    tk.id,
        ticketTitle: tk.title,
        startTime:   startTime.toISOString(),
        sessionId:   runningInDB.id,
      })
      return
    }

    // ── Prioridade 2: localStorage (ainda ativo na sessão atual do browser) ───
    const active = getActiveTimer(currentUser.id)
    if (active && active.ticketId === tk.id) {
      setTimerStart(new Date(active.startTime))
      setTimerRunning(true)
    } else {
      setTimerRunning(false)
      setTimerStart(null)
    }
  }, [tk?.id, currentUser.id]) // eslint-disable-line react-hooks/exhaustive-deps

  // Mantém sessions sincronizado quando o ticket é atualizado externamente
  useEffect(() => {
    if (!tk || timerRunning) return   // não sobrescreve enquanto timer ativo
    const allSessions = tk.timerSessions ?? []
    setSessions(allSessions)
  }, [tk?.timerSessions]) // eslint-disable-line react-hooks/exhaustive-deps

  // ── Ref para auto-stop (evita stale closure no setTimeout) ───────────────
  const toggleTimerRef = useRef(null)

  // Helper: minutos já registrados HOJE neste ticket (apenas sessões concluídas)
  function todaySessionMins() {
    const today = new Date().toDateString()
    return sessions
      .filter(s => {
        if (s.status && s.status !== 'completed') return false
        const d = s.start instanceof Date ? s.start : new Date(s.start)
        return d.toDateString() === today
      })
      .reduce((acc, s) => acc + (s.mins ?? 0), 0)
  }

  // Auto-stop quando atinge Máx. horas/ticket/dia do usuário
  useEffect(() => {
    toggleTimerRef.current = toggleTimerRef._fn  // será preenchido abaixo
  })

  useEffect(() => {
    if (!timerRunning || !timerStart) return
    const maxMins = (currentUser.maxHoursPerTicket ?? 4) * 60
    const usedMins = todaySessionMins()
    const remainingMs = Math.max(0, (maxMins - usedMins) * 60 * 1000)
    if (remainingMs <= 0) return
    const timeout = setTimeout(() => {
      toggleTimerRef._fn?.()
      showToast(`⏱ Cronômetro pausado: limite de ${fmtMinsHM(maxMins)} por ticket/dia atingido.`)
    }, remainingMs)
    return () => clearTimeout(timeout)
  }, [timerRunning, timerStart]) // eslint-disable-line react-hooks/exhaustive-deps

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

  // Carrega capacidade dos usuários ao abrir o form de triagem
  useEffect(() => {
    if (!showTriage) return
    const today = new Date().toISOString().slice(0, 10)
    const end   = new Date(Date.now() + 6 * 86400000).toISOString().slice(0, 10)
    api.usersCapacity(today, end)
      .then(data => {
        const map = {}
        data.forEach(row => { map[String(row.user_id)] = row })
        setCapacityMap(map)
      })
      .catch(() => {}) // silently ignore — badge is optional
  }, [showTriage]) // eslint-disable-line react-hooks/exhaustive-deps

  // Sugestão de prazo (pelas regras) — recalcula quando prioridade/esforço/
  // responsável/categoria mudam no modal de triagem.
  useEffect(() => {
    if (!showTriage || !triageForm.priorityId) { setDeadlineSuggestion(null); return }
    let live = true
    const id = setTimeout(() => {
      api.suggestDeadline(tk.id, {
        priority_id:      triageForm.priorityId || undefined,
        category_id:      triageForm.categoryId || tk.categoryId || undefined,
        queue_id:         triageForm.queueId || undefined,
        assignee_id:      triageForm.assigneeId || undefined,
        effort_estimated: triageForm.effortEstimated ? parseFloat(triageForm.effortEstimated) : undefined,
      }).then(r => { if (live) setDeadlineSuggestion(r?.deadline ?? null) }).catch(() => { if (live) setDeadlineSuggestion(null) })
    }, 350)
    return () => { live = false; clearTimeout(id) }
  }, [showTriage, triageForm.priorityId, triageForm.categoryId, triageForm.queueId, triageForm.assigneeId, triageForm.effortEstimated]) // eslint-disable-line react-hooks/exhaustive-deps

  // Tick a cada 10s para mostrar duração ao vivo das sessões em andamento
  const [liveNow, setLiveNow] = useState(() => Date.now())
  useEffect(() => {
    if (!timerRunning) return
    const id = setInterval(() => setLiveNow(Date.now()), 10_000)
    return () => clearInterval(id)
  }, [timerRunning])

  const [showMoreComments, setShowMoreComments] = useState(false)
  const [showMoreHistory, setShowMoreHistory] = useState(false)
  const [showMoreSessions, setShowMoreSessions] = useState(false)
  const [moreCommentsPage, setMoreCommentsPage] = useState(0)
  const [moreHistoryPage, setMoreHistoryPage] = useState(0)
  const [moreSessionsPage, setMoreSessionsPage] = useState(0)
  const MORE_PER = 25
  const [newAttFile, setNewAttFile] = useState(null)
  const [addingAtt, setAddingAtt] = useState(false)
  const [attUploadError, setAttUploadError] = useState(null)
  const [localAttachments, setLocalAttachments] = useState(null) // null = not loaded yet
  const [trashedAtts, setTrashedAtts] = useState([])             // anexos na lixeira (só gestor)
  const ATT_MAX_COUNT = 3
  const ATT_MAX_SIZE  = 5 * 1024 * 1024 // 5 MB
  // Mover anexo para a lixeira / restaurar: somente gestor (manager) e admin/msp_admin
  const canManageAtt  = ['admin', 'manager', 'msp_admin'].includes(currentUser.role)
  const [openingDateEdit, setOpeningDateEdit] = useState(null)   // admin: data de abertura editada
  const [titleEdit,       setTitleEdit]       = useState(null)   // admin/manager: título editado
  const [descEdit,        setDescEdit]        = useState(null)   // admin/manager: descrição editada

  const canEditHeader = isAdmin(currentUser.role) || currentUser.role === 'manager'

  useEffect(() => { setTitleEdit(null); setDescEdit(null) }, [tk?.id])

  async function saveTitle() {
    const val = (titleEdit ?? '').trim()
    setTitleEdit(null)
    if (!val || val === tk.title) return
    try {
      await updateTicketAction(tk.id, { title: val })
      showToast('Título atualizado.')
    } catch (e) { alert(`Erro: ${e.message}`) }
  }

  async function saveDesc() {
    const val = descEdit ?? ''
    setDescEdit(null)
    if (val === (tk.description ?? '')) return
    try {
      await updateTicketAction(tk.id, { description: val })
      showToast('Descrição atualizada.')
    } catch (e) { alert(`Erro: ${e.message}`) }
  }

  async function saveRequester(requesterId) {
    if (!requesterId || requesterId === String(tk.requesterId)) return
    try {
      await updateTicketAction(tk.id, { requester_id: requesterId })
      showToast('Solicitante atualizado.')
    } catch (e) { alert(`Erro: ${e.message}`) }
  }

  // Prazo editável por admin (da org) e super admin. A data-só é normalizada
  // no backend para o fim do dia (Brasília).
  async function saveDeadline(dateStr) {
    if (!dateStr) return
    try {
      await updateTicketAction(tk.id, { deadline: dateStr })
      showToast('Prazo atualizado.')
    } catch (e) { alert(`Erro: ${e.message}`) }
  }

  // Converte ISO para YYYY-MM-DD respeitando o fuso horário local
  function toLocalDateInput(iso) {
    const d = iso ? new Date(iso) : new Date()
    return [
      d.getFullYear(),
      String(d.getMonth() + 1).padStart(2, '0'),
      String(d.getDate()).padStart(2, '0'),
    ].join('-')
  }

  // Reseta o campo quando muda de ticket
  useEffect(() => { setOpeningDateEdit(null) }, [tk?.id])

  async function saveOpeningDate() {
    const newVal = openingDateEdit
    setOpeningDateEdit(null)
    if (!newVal || newVal === toLocalDateInput(tk.createdAt)) return
    try {
      await updateTicketAction(tk.id, { created_at: newVal })
      showToast('Data de abertura atualizada.')
    } catch (e) {
      alert(`Erro ao atualizar data de abertura: ${e.message}`)
    }
  }

  // Carrega o ticket completo (view :full) ao abrir o detalhe.
  // O index retorna apenas :summary (sem comments nem attachments),
  // por isso precisamos buscar o ticket individual via GET /tickets/:id.
  useEffect(() => {
    if (!tk) return
    api.ticket(tk.id)
      .then(data => {
        const full = mapTicket(data)
        setTickets(prev => prev.map(t => t.id === full.id
          ? { ...t,
              description:  full.description,
              comments:     full.comments,
              attachments:  full.attachments,
              coAssignees:  full.coAssignees,
              timerSessions: full.timerSessions,
            }
          : t
        ))
      })
      .catch(console.error)

    api.histories(tk.id)
      .then(histories => {
        const history = (histories ?? []).map(h => ({
          field:  h.field,
          from:   h.from_value,
          to:     h.to_value,
          date:   h.created_at,
          userId: h.user?.id ?? null,
        }))
        setTickets(prev => prev.map(t => t.id === tk.id ? { ...t, history } : t))
      })
      .catch(console.error)
  }, [tk?.id]) // eslint-disable-line

  useEffect(() => {
    if (!tk) return
    api.attachments(tk.id)
      .then(data => setLocalAttachments((data ?? []).map(mapAttachment)))
      .catch(() => setLocalAttachments(tk.attachments ?? []))
    if (canManageAtt) {
      api.trashedAttachments(tk.id)
        .then(data => setTrashedAtts((data ?? []).map(mapAttachment)))
        .catch(() => setTrashedAtts([]))
    }
  }, [tk?.id])

  const p = PERM[currentUser.role] || PERM.user

  if (!tk) return <EmptyState icon="🎫" title="Ticket não encontrado" desc="O ticket pode ter sido removido." />

  const pri = priorities.find(x => x.id === tk.priorityId)
  const cat = categories.find(x => x.id === tk.categoryId)
  const req = users.find(x => x.id === tk.requesterId)
  const assignee = users.find(x => x.id === tk.assigneeId)
  const expired = isExpired(tk.deadline) && !['Resolvido', 'Fechado'].includes(tk.status)
  // No cabeçalho, não mostramos os botões de "Triado, aguardando atendimento"
  // (isso é feito pela triagem) nem "Aguardando solicitante" — só "Aguardando
  // terceiros" e as ações de andamento/resolução.
  const HIDDEN_STATUS_BTNS = ['Triado, aguardando atendimento', 'Aguardando solicitante']
  const transitions = (ALLOWED_TRANSITIONS[tk.status] || []).filter(s => !HIDDEN_STATUS_BTNS.includes(s))

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
              <h2 style="color:#fff;margin:0">🎯 DataTicket</h2>
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
              <h2 style="color:#fff;margin:0">🎯 DataTicket</h2>
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
        effort_estimated: triageForm.effortEstimated ? parseFloat(triageForm.effortEstimated) : 0,
        ...(triageForm.deadline ? { deadline: triageForm.deadline } : {}),  // prazo manual sobrepõe o cálculo
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
            <h2 style="color:#fff;margin:0">🎯 DataTicket</h2>
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
            <h2 style="color:#fff;margin:0">🎯 DataTicket</h2>
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

  async function doReopen() {
    const hours = parseFloat(reopenHours) || 0
    try {
      await changeStatusAction(tk.id, 'Reaberto', hours || undefined)
      showToast(`Ticket ${tk.id} reaberto${hours > 0 ? ` com +${hours}h de esforço estimado.` : '.'}`)
      setShowReopenModal(false)
      setReopenHours('')
    } catch (e) {
      alert(`Erro ao reabrir: ${e.message}`)
    }
  }

  async function doAddEffort() {
    const hours = parseFloat(String(effortHours).replace(',', '.'))
    if (!hours || hours <= 0) { showToast('Informe as horas de esforço (maior que zero).'); return }
    if (!effortReason.trim()) { showToast('Descreva brevemente o que será feito (prova do esforço).'); return }
    setEffortSaving(true)
    try {
      await addEffortAction(tk.id, hours, effortReason.trim())
      setShowEffort(false); setEffortHours(''); setEffortReason('')
      showToast(`+${hours}h de esforço adicionadas.`)
    } catch (e) {
      showToast(`Erro ao adicionar horas: ${e.message}`)
    } finally {
      setEffortSaving(false)
    }
  }

  async function doDeleteEffort(additionId) {
    if (!window.confirm('Apagar esta adição de esforço? As horas serão estornadas do esforço estimado.')) return
    try {
      await deleteEffortAction(tk.id, additionId)
      showToast('Adição de esforço removida.')
    } catch (e) {
      showToast(`Erro ao remover: ${e.message}`)
    }
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
    // Registra referência para o auto-stop sem stale closure
    toggleTimerRef._fn = toggleTimer

    if (!timerRunning) {
      // ── Bloqueia timer duplo — leitura direta do localStorage ──────────
      const active = getActiveTimer(currentUser.id)
      if (active && active.ticketId !== tk.id) {
        if (!window.confirm(`⚠️ Cronômetro ativo no ticket #${active.ticketId}.\n\nAo iniciar aqui, o timer anterior será pausado automaticamente. Deseja continuar?`)) return
      }

      // ── Verifica limite Máx. horas/ticket/dia ──────────────────────────
      const maxMins  = (currentUser.maxHoursPerTicket ?? 4) * 60
      const usedMins = todaySessionMins()
      if (usedMins >= maxMins) {
        alert(`⏱ Limite diário atingido!\n\nVocê já registrou ${fmtMinsHM(usedMins)} neste ticket hoje.\nMáx. permitido: ${fmtMinsHM(maxMins)}.`)
        return
      }

      const start = new Date()
      setTimerStart(start)
      setTimerRunning(true)

      if (typeof Notification !== 'undefined' && Notification.permission === 'default') {
        Notification.requestPermission()
      }

      // ── Cria sessão 'running' no backend (backend muda status + cancela outros timers) ─
      api.startTimerSession(tk.id)
        .then(data => {
          // Nova API retorna { session, ticket_status }; fallback para formato antigo
          const sessionData = data?.session ?? data
          setActiveTimer(currentUser.id, {
            ticketId:    tk.id,
            ticketTitle: tk.title,
            startTime:   start.toISOString(),
            sessionId:   sessionData?.id,
          })
          // Atualiza status do ticket localmente se o backend mudou
          if (data?.ticket_status) {
            setTickets(prev => prev.map(x => x.id === tk.id ? { ...x, status: data.ticket_status } : x))
          }
        })
        .catch(() => {
          // Fallback: armazena sem sessionId
          setActiveTimer(currentUser.id, { ticketId: tk.id, ticketTitle: tk.title, startTime: start.toISOString() })
        })
    } else {
      // ── Pausa — para sessão no backend (backend calcula duração e esforço) ─
      const end  = new Date()
      const mins = (end - timerStart) / 60000

      // Limpa o timer ativo do localStorage imediatamente
      const active = getActiveTimer(currentUser.id)
      setActiveTimer(currentUser.id, null)
      setTimerRunning(false)
      setTimerStart(null)

      // Atualiza estado local imediatamente (otimista)
      const newEffortOptimistic = +(tk.effortUsed + mins / 60).toFixed(2)
      const newSessionOptimistic = {
        id:       null,
        start:    timerStart,
        end,
        mins,
        status:   'completed',
        userId:   currentUser.id,
        userName: `${currentUser.firstName} ${currentUser.lastName}`.trim(),
      }
      setSessions(prev => [...prev, newSessionOptimistic])
      setTickets(prev => prev.map(x => x.id === tk.id ? { ...x, effortUsed: newEffortOptimistic } : x))

      const sessionId = active?.sessionId

      if (sessionId) {
        // ── Endpoint novo: PATCH /stop ─────────────────────────────────────
        api.stopTimerSession(tk.id, sessionId)
          .then(data => {
            const sessionData = data?.session ?? data
            const saved = mapTimerSession(sessionData)
            setTickets(prev => prev.map(x => {
              if (x.id !== tk.id) return x
              // Substitui a sessão otimista pela real
              const existing = x.timerSessions ?? []
              const newSessions = [...existing.filter(s => s.id !== null), saved]
              const updates = { timerSessions: newSessions }
              if (data?.effort_used !== undefined) updates.effortUsed = data.effort_used
              if (data?.ticket_status) updates.status = data.ticket_status
              return { ...x, ...updates }
            }))
            setSessions(prev => {
              const next = [...prev]
              next[next.length - 1] = saved
              return next
            })
            // Recarrega histórico do ticket para incluir entrada de cronômetro
            api.histories(tk.id)
              .then(histories => {
                const history = (histories ?? []).map(h => ({
                  field:  h.field,
                  from:   h.from_value,
                  to:     h.to_value,
                  date:   h.created_at,
                  userId: h.user?.id ?? null,
                }))
                setTickets(prev => prev.map(t => t.id === tk.id ? { ...t, history } : t))
              })
              .catch(() => {})
          })
          .catch(() => {})
      } else {
        // ── Fallback legado: POST sessão completa ──────────────────────────
        api.createTimerSession(tk.id, {
          started_at:    timerStart.toISOString(),
          stopped_at:    end.toISOString(),
          duration_mins: mins,
        })
          .then(data => {
            const saved = mapTimerSession(data)
            setTickets(prev => prev.map(x => {
              if (x.id !== tk.id) return x
              const newSessions = [...(x.timerSessions ?? []).filter(s => s.id !== null), saved]
              return { ...x, timerSessions: newSessions }
            }))
            setSessions(prev => {
              const next = [...prev]
              next[next.length - 1] = saved
              return next
            })
          })
          .catch(() => {})

        api.updateTicket(tk.id, { effort_used: newEffortOptimistic }).catch(() => {})
      }
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
            {tk.csatScore != null && (
              <span
                title={tk.csatComment || 'Avaliação de satisfação'}
                style={{ background: '#fce7f3', color: '#be185d', padding: '2px 8px', borderRadius: 20, fontSize: 11, fontWeight: 600 }}
              >
                ⭐ NPS: {tk.csatScore}/5
              </span>
            )}
          </div>
          {canEditHeader ? (
            <input
              className="input"
              style={{ fontSize: 17, fontWeight: 700, marginTop: 4, width: '100%', border: '1px solid transparent', background: 'transparent', padding: '2px 6px', borderRadius: 6, cursor: 'text' }}
              value={titleEdit ?? tk.title}
              onChange={e => setTitleEdit(e.target.value)}
              onFocus={e => { if (titleEdit === null) setTitleEdit(tk.title); e.target.style.border = '1px solid var(--accent)'; e.target.style.background = 'var(--bg)' }}
              onBlur={e => { e.target.style.border = '1px solid transparent'; e.target.style.background = 'transparent'; saveTitle() }}
              onKeyDown={e => { if (e.key === 'Enter') e.target.blur() }}
              title="Clique para editar o título"
            />
          ) : (
            <div style={{ fontSize: 17, fontWeight: 700, marginTop: 4 }}>{tk.title}</div>
          )}
        </div>
        <div style={{ display: 'flex', gap: 7, flexWrap: 'wrap' }}>
          {p.triage && <button className="btn btn-primary btn-sm" onClick={() => setShowTriage(true)}>{tk.triaged ? '↺ Retriar Ticket' : t.triageBtn}</button>}
          {canAddEffort && tk.status !== 'Fechado' && <button className="btn btn-secondary btn-sm" onClick={() => { setEffortHours(''); setEffortReason(''); setShowEffort(true) }}>➕ Horas</button>}
          {transitions.map(s => <button key={s} className="btn btn-secondary btn-sm" onClick={() => changeStatus(s)}>→ {s}</button>)}
          {p.closeTicket && !['Fechado', 'Resolvido'].includes(tk.status) && <button className="btn btn-danger btn-sm" onClick={() => changeStatus('Fechado')}>{t.closeTicket}</button>}
          {p.reopenTicket && tk.status === 'Fechado' && (
            <button className="btn btn-secondary btn-sm" onClick={() => { setReopenHours(''); setShowReopenModal(true) }}>
              {t.reopenTicket}
            </button>
          )}
          {p.deleteTicket && <button className="btn btn-danger btn-sm" onClick={handleDelete} style={{ marginLeft: 4 }}>🗑 Excluir</button>}
        </div>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: '1fr 300px', gap: 16 }}>
        {/* Left column */}
        <div>
          {/* Description */}
          <div className="card" style={{ marginBottom: 14 }}>
            <div style={{ fontWeight: 600, marginBottom: 8 }}>
              Descrição
              {canEditHeader && <span style={{ fontSize: 10, color: 'var(--accent)', marginLeft: 6, fontWeight: 400 }}>✏️ clique para editar</span>}
            </div>
            {canEditHeader ? (
              <textarea
                className="textarea"
                rows={5}
                style={{ width: '100%', fontSize: 14, lineHeight: 1.7, border: '1px solid transparent', background: 'transparent', resize: 'vertical', cursor: 'text', borderRadius: 6, padding: '4px 6px', color: 'var(--text2)', boxSizing: 'border-box' }}
                value={descEdit ?? (tk.description ?? '')}
                onChange={e => setDescEdit(e.target.value)}
                onFocus={e => { if (descEdit === null) setDescEdit(tk.description ?? ''); e.target.style.border = '1px solid var(--accent)'; e.target.style.background = 'var(--bg)' }}
                onBlur={e => { e.target.style.border = '1px solid transparent'; e.target.style.background = 'transparent'; saveDesc() }}
                title="Clique para editar a descrição"
              />
            ) : (
              <div style={{ fontSize: 14, color: 'var(--text2)', lineHeight: 1.7 }}>{tk.description}</div>
            )}
          </div>

          {/* Timer — botão visível apenas para quem pode registrar esforço */}
          {p.logEffort && (
            <div className="card" style={{ marginBottom: 14 }}>
              <div style={{ fontWeight: 600, marginBottom: 10 }}>⏱ {t.timer}</div>
              <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 10, flexWrap: 'wrap' }}>
                {['Fechado', 'Resolvido'].includes(tk.status) ? (
                  <span style={{ fontSize: 12, color: 'var(--text2)', fontStyle: 'italic' }}>
                    🔒 Ticket {tk.status.toLowerCase()} — cronômetro desativado
                  </span>
                ) : (
                  <button className={`btn btn-sm ${timerRunning ? 'btn-danger' : 'btn-primary'}`} onClick={toggleTimer}>
                    {timerRunning ? `⏸ ${t.pause}` : `▶ ${t.start}`}
                  </button>
                )}
                <span style={{ fontSize: 13, color: 'var(--text2)' }}>
                  Utilizado: <strong style={{ color: 'var(--text)' }}>{fmtHM(tk.effortUsed)}</strong>
                  {' '}/ Estimado: <strong>{fmtHM(tk.effortEstimated)}</strong>
                </span>
                {tk.effortUsed >= tk.effortEstimated && tk.effortEstimated > 0 && (
                  <span style={{ color: 'var(--danger)', fontSize: 12, fontWeight: 600 }}>⚠ Limite atingido</span>
                )}
              </div>
              {timerRunning && timerStart && (
                <div style={{ fontSize: 12, color: '#16a34a', fontWeight: 500, marginBottom: 8, display: 'flex', alignItems: 'center', gap: 6 }}>
                  <span style={{ width: 8, height: 8, borderRadius: '50%', background: '#16a34a', display: 'inline-block', animation: 'pulse 1.5s infinite' }} />
                  Em andamento · {fmtMinsHM((liveNow - timerStart.getTime()) / 60000)} decorrido · Iniciado em {formatDateTime(timerStart.toISOString())}
                </div>
              )}
              <div className="progress">
                <div className="progress-bar" style={{ width: `${Math.min(100, (tk.effortUsed / Math.max(tk.effortEstimated, 1)) * 100)}%` }} />
              </div>
            </div>
          )}

          {/* Histórico de execuções — visível para admin, gestor e analista */}
          {currentUser.role !== 'user' && (() => {
            const completedSessions = sessions.filter(s => s.status === 'completed' || (!s.status && s.mins > 0))
            const runningSession = timerRunning && timerStart ? {
              id: 'live', start: timerStart, end: null, mins: (liveNow - timerStart.getTime()) / 60000,
              userId: currentUser.id,
              userName: `${currentUser.firstName} ${currentUser.lastName}`.trim(),
              live: true,
            } : null
            const allVisible = runningSession ? [runningSession, ...completedSessions] : completedSessions
            if (allVisible.length === 0) return null
            return (
              <div className="card" style={{ marginBottom: 14 }}>
                <div style={{ fontWeight: 600, marginBottom: 10 }}>🕐 Histórico de execuções</div>
                {runningSession && (
                  <div style={{ fontSize: 12, padding: '8px', marginBottom: 6, background: '#f0fdf4', border: '1px solid #bbf7d0', borderRadius: 8 }}>
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                      <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                        <span style={{ width: 7, height: 7, borderRadius: '50%', background: '#16a34a', display: 'inline-block', animation: 'pulse 1.5s infinite' }} />
                        <span style={{ fontWeight: 600, color: '#16a34a' }}>Em andamento</span>
                        <span style={{ color: 'var(--text2)' }}>· Iniciado {formatDateTime(timerStart.toISOString())}</span>
                      </div>
                      <span style={{ fontWeight: 700, color: '#16a34a', fontSize: 11 }}>{fmtMinsHM(runningSession.mins)} ao vivo</span>
                    </div>
                    <div style={{ fontSize: 11, color: 'var(--text2)', marginTop: 3 }}>👤 {runningSession.userName}</div>
                  </div>
                )}
                {completedSessions.slice(0, showMoreSessions ? undefined : 5).map((s, i) => (
                  <div key={s.id ?? i} style={{ fontSize: 12, padding: '8px 0', borderBottom: '1px solid var(--border)' }}>
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 8 }}>
                      <div style={{ color: 'var(--text2)' }}>
                        <span style={{ fontWeight: 500, color: 'var(--text)' }}>{formatDateTime(s.start instanceof Date ? s.start.toISOString() : s.start)}</span>
                        <span style={{ margin: '0 5px' }}>→</span>
                        <span style={{ fontWeight: 500, color: 'var(--text)' }}>{s.end ? formatDateTime(s.end instanceof Date ? s.end.toISOString() : s.end) : '—'}</span>
                      </div>
                      <span style={{ fontSize: 11, background: 'var(--bg2)', padding: '2px 8px', borderRadius: 10, fontWeight: 600, flexShrink: 0 }}>
                        {fmtMinsHM(s.mins)}
                      </span>
                    </div>
                    {s.userName && (
                      <div style={{ fontSize: 11, color: 'var(--text2)', marginTop: 2 }}>👤 {s.userName}</div>
                    )}
                  </div>
                ))}
                {!showMoreSessions && completedSessions.length > 5 && (
                  <button className="btn btn-secondary btn-sm" style={{ marginTop: 6, fontSize: 11 }} onClick={() => setShowMoreSessions(true)}>
                    Ver mais ({completedSessions.length - 5} restantes)
                  </button>
                )}
                {showMoreSessions && completedSessions.length > 5 && (
                  <button className="btn btn-secondary btn-sm" style={{ marginTop: 6, fontSize: 11 }} onClick={() => setShowMoreSessions(false)}>
                    Ver menos
                  </button>
                )}
              </div>
            )
          })()}

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
                            {c.source === 'email' && (
                              <span style={{ fontSize: 10, fontWeight: 600, color: '#0369a1', background: '#e0f2fe', padding: '1px 6px', borderRadius: 10 }}>✉️ via e-mail</span>
                            )}
                            <span style={{ fontSize: 11, color: 'var(--text2)', marginLeft: 'auto' }}>{formatDate(c.date)}</span>
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
              {
                label: 'Solicitante',
                val: canEditHeader ? (
                  <select
                    className="select"
                    style={{ fontSize: 12, padding: '2px 6px', minWidth: 130 }}
                    value={tk.requesterId ?? ''}
                    onChange={e => saveRequester(e.target.value)}
                  >
                    <option value="">— Sem solicitante —</option>
                    {[...users]
                      .sort((a, b) => `${a.firstName} ${a.lastName}`.localeCompare(`${b.firstName} ${b.lastName}`))
                      .map(u => (
                        <option key={u.id} value={u.id}>{u.firstName} {u.lastName}</option>
                      ))
                    }
                  </select>
                ) : (req ? `${req.firstName} ${req.lastName}` : '—'),
              },
              { label: 'Responsável', val: assignee ? `${assignee.firstName} ${assignee.lastName}` : 'Não atribuído' },
              { label: 'Categoria', val: <CatChip category={cat} /> },
              { label: 'Prioridade', val: <PriBadge priority={pri} /> },
              {
                label: 'Prazo',
                val: isAdmin(currentUser.role) ? (
                  <input
                    type="date"
                    className="input"
                    style={{ fontSize: 12, padding: '2px 6px', maxWidth: 150 }}
                    value={tk.deadline ? toLocalDateInput(tk.deadline) : ''}
                    onChange={e => saveDeadline(e.target.value)}
                    title="Editar prazo"
                  />
                ) : (
                  <span style={{ color: expired ? 'var(--danger)' : 'var(--text)', fontWeight: expired ? 600 : 400 }}>{formatDate(tk.deadline)}</span>
                ),
              },
              { label: 'Esforço est.', val: fmtHM(tk.effortEstimated) },
              { label: 'Esforço usado', val: fmtHM(tk.effortUsed) },
              ...(tk.resolvedAt ? [
                { label: 'Concluído em', val: formatDate(tk.resolvedAt) },
                { label: 'Dias p/ resolver', val: tk.daysToResolve != null ? `${tk.daysToResolve} dia${tk.daysToResolve === 1 ? '' : 's'}` : '—' },
              ] : []),
              ...(tk.effortEstimated > 0 ? [{
                label: 'Esforço disponível',
                val: (() => {
                  const avail = tk.effortEstimated - tk.effortUsed
                  const neg   = avail < 0
                  return (
                    <span style={{ color: neg ? 'var(--danger)' : 'var(--text)', fontWeight: neg ? 700 : 500 }}>
                      {neg ? '−' : ''}{fmtHM(Math.abs(avail))}{neg ? ' ⚠' : ''}
                    </span>
                  )
                })()
              }] : []),
            ].map(r => (
              <div key={r.label} style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '6px 0', borderBottom: '1px solid var(--border)', fontSize: 13 }}>
                <span style={{ color: 'var(--text2)' }}>{r.label}</span>
                <span style={{ fontWeight: 500 }}>{r.val}</span>
              </div>
            ))}
            {/* Data de abertura — admin pode editar manualmente */}
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '6px 0', borderBottom: '1px solid var(--border)', fontSize: 13 }}>
              <span style={{ color: 'var(--text2)' }}>
                Abertura
                {isAdmin(currentUser.role) && (
                  <span style={{ fontSize: 10, color: 'var(--accent)', marginLeft: 5, fontWeight: 500 }}>✏️ editável</span>
                )}
              </span>
              {isAdmin(currentUser.role) ? (
                <input
                  type="date"
                  value={openingDateEdit ?? toLocalDateInput(tk.createdAt)}
                  max={new Date().toISOString().slice(0, 10)}
                  onChange={e => setOpeningDateEdit(e.target.value)}
                  onBlur={saveOpeningDate}
                  title="Clique para alterar a data de abertura do ticket"
                  style={{
                    border: '1px solid var(--accent)',
                    borderRadius: 6,
                    padding: '3px 8px',
                    fontSize: 12,
                    color: 'var(--text)',
                    background: 'var(--bg)',
                    cursor: 'pointer',
                    fontWeight: 500,
                  }}
                />
              ) : (
                <span style={{ fontWeight: 500 }}>{formatDate(tk.createdAt)}</span>
              )}
            </div>
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
                  {canManageAtt && (
                    <button className="btn btn-danger btn-sm" style={{ flexShrink: 0, padding: '2px 6px' }}
                      title="Mover para a lixeira"
                      onClick={async () => {
                        if (!confirm(`Mover "${att.name}" para a lixeira? Poderá ser restaurado em até 30 dias.`)) return
                        try {
                          await api.deleteAttachment(tk.id, att.id)
                          setLocalAttachments(prev => prev.filter(a => a.id !== att.id))
                          api.trashedAttachments(tk.id).then(d => setTrashedAtts((d ?? []).map(mapAttachment))).catch(() => {})
                          showToast('Anexo movido para a lixeira.')
                        } catch (e) { alert(`Erro: ${e.message}`) }
                      }}>🗑</button>
                  )}
                </div>
              ))}
              {/* Upload de novo anexo */}
              {p.createTicket && (
                <div style={{ marginTop: 10 }}>
                  {(localAttachments ?? []).length >= ATT_MAX_COUNT ? (
                    <div style={{ fontSize: 12, color: 'var(--danger)', fontWeight: 500 }}>
                      ⚠ Limite de {ATT_MAX_COUNT} anexos atingido. Remova um antes de enviar outro.
                    </div>
                  ) : (
                    <div style={{ display: 'flex', gap: 6, alignItems: 'center', flexWrap: 'wrap' }}>
                      <input type="file" style={{ fontSize: 11, flex: 1, minWidth: 0 }}
                        accept=".pdf,.png,.jpg,.jpeg,.doc,.docx,.txt,.xlsx,.zip"
                        onChange={e => {
                          const f = e.target.files[0] || null
                          if (f && f.size > ATT_MAX_SIZE) {
                            setAttUploadError(`"${f.name}" excede 5 MB. Escolha um arquivo menor.`)
                            e.target.value = ''
                            setNewAttFile(null)
                          } else {
                            setAttUploadError(null)
                            setNewAttFile(f)
                          }
                        }} />
                      <button className="btn btn-secondary btn-sm" disabled={!newAttFile || addingAtt}
                        onClick={async () => {
                          if (!newAttFile) return
                          setAddingAtt(true)
                          setAttUploadError(null)
                          try {
                            const att = await api.uploadAttachment(tk.id, newAttFile)
                            setLocalAttachments(prev => [...(prev ?? []), mapAttachment(att)])
                            setNewAttFile(null)
                            showToast('Anexo enviado!')
                          } catch (e) {
                            setAttUploadError(`Erro no upload: ${e.message}`)
                          } finally {
                            setAddingAtt(false)
                          }
                        }}>
                        {addingAtt ? '⏳ Enviando...' : '➕ Enviar'}
                      </button>
                    </div>
                  )}
                  {attUploadError && (
                    <div style={{ marginTop: 5, fontSize: 12, color: 'var(--danger)', fontWeight: 500 }}>
                      ⚠ {attUploadError}
                    </div>
                  )}
                </div>
              )}

              {/* Lixeira de anexos (só gestor) — restaurável em até 30 dias */}
              {canManageAtt && trashedAtts.length > 0 && (
                <div style={{ marginTop: 14, paddingTop: 10, borderTop: '1px dashed var(--border)' }}>
                  <div style={{ fontWeight: 600, marginBottom: 8, fontSize: 12, color: 'var(--text2)' }}>🗑 Lixeira de anexos</div>
                  {trashedAtts.map(att => {
                    const daysLeft = att.restorableUntil
                      ? Math.max(0, Math.ceil((new Date(att.restorableUntil) - new Date()) / 86400000))
                      : null
                    return (
                      <div key={att.id} style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '5px 0', borderBottom: '1px solid var(--border)', fontSize: 12 }}>
                        <span style={{ opacity: 0.6 }}>📄</span>
                        <span style={{ flex: 1, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap', textDecoration: 'line-through', color: 'var(--text2)' }}>{att.name}</span>
                        {daysLeft != null && (
                          <span style={{ fontSize: 11, color: daysLeft <= 5 ? 'var(--danger)' : 'var(--text2)', flexShrink: 0 }}>{daysLeft}d p/ restaurar</span>
                        )}
                        <button className="btn btn-secondary btn-sm" style={{ flexShrink: 0 }}
                          onClick={async () => {
                            try {
                              await api.restoreAttachment(tk.id, att.id)
                              setTrashedAtts(prev => prev.filter(a => a.id !== att.id))
                              api.attachments(tk.id).then(d => setLocalAttachments((d ?? []).map(mapAttachment))).catch(() => {})
                              showToast('Anexo restaurado.')
                            } catch (e) { alert(`Erro ao restaurar: ${e.message}`) }
                          }}>↩ Restaurar</button>
                      </div>
                    )
                  })}
                </div>
              )}
            </div>
          )}

          {/* Esforço adicional ("+ Horas") */}
          {(tk.effortAdditions ?? []).length > 0 && (
            <div className="card" style={{ marginBottom: 12 }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 10 }}>
                <span style={{ fontWeight: 600 }}>⏱️ Esforço adicional</span>
                <span style={{ fontSize: 12, color: 'var(--text2)' }}>
                  +{(tk.effortAdditions.reduce((a, x) => a + (x.hours || 0), 0)).toFixed(1).replace('.0', '')} h
                </span>
              </div>
              {tk.effortAdditions.map(ea => {
                const srcLabel = { manual: 'Manual', triage: 'Triagem', reopen: 'Reabertura' }[ea.source] || ea.source
                return (
                  <div key={ea.id} style={{ display: 'flex', alignItems: 'flex-start', gap: 8, padding: '6px 0', borderBottom: '1px solid var(--border)', fontSize: 12 }}>
                    <span style={{ fontWeight: 700, color: '#7c3aed', flexShrink: 0 }}>+{ea.hours}h</span>
                    <div style={{ flex: 1, minWidth: 0 }}>
                      <div style={{ color: 'var(--text2)' }}>{formatDate(ea.date)} · {srcLabel}</div>
                      {isSuper && ea.reason && (
                        <div style={{ color: 'var(--text)', marginTop: 2, whiteSpace: 'pre-wrap' }}>{ea.reason}{ea.userName ? ` — ${ea.userName}` : ''}</div>
                      )}
                    </div>
                    {isSuper && (
                      <button className="btn btn-danger btn-sm" style={{ flexShrink: 0, padding: '2px 6px' }}
                        title="Apagar (estorna as horas)" onClick={() => doDeleteEffort(ea.id)}>🗑</button>
                    )}
                  </div>
                )
              })}
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

          {/* Plano de execução */}
          {(() => {
            const plan = (tk.scheduledDays ?? [])
              .filter(sd => sd.date >= new Date().toISOString().slice(0, 10))
              .sort((a, b) => a.date.localeCompare(b.date))
            const pastPlan = (tk.scheduledDays ?? [])
              .filter(sd => sd.date < new Date().toISOString().slice(0, 10))
              .sort((a, b) => a.date.localeCompare(b.date))
            if ((tk.scheduledDays ?? []).length === 0) return null
            return (
              <div className="card" style={{ marginBottom: 12 }}>
                <div style={{ fontWeight: 600, marginBottom: 10 }}>📅 Plano de execução</div>
                {plan.length === 0 && pastPlan.length === 0 && (
                  <div style={{ fontSize: 12, color: 'var(--text2)' }}>Sem dias agendados.</div>
                )}
                {plan.map(sd => {
                  const d    = new Date(sd.date + 'T12:00:00')
                  const isToday = sd.date === new Date().toISOString().slice(0, 10)
                  return (
                    <div key={sd.date} style={{
                      display: 'flex', justifyContent: 'space-between', alignItems: 'center',
                      padding: '5px 0', borderBottom: '1px solid var(--border)', fontSize: 12,
                    }}>
                      <span style={{ color: isToday ? 'var(--accent)' : 'var(--text)', fontWeight: isToday ? 700 : 400 }}>
                        {isToday ? '▶ ' : ''}{d.toLocaleDateString('pt-BR', { weekday: 'short', day: '2-digit', month: '2-digit' })}
                      </span>
                      <span style={{ background: 'var(--bg2)', padding: '2px 8px', borderRadius: 10, fontWeight: 500 }}>
                        {fmtHM(sd.hours)}
                      </span>
                    </div>
                  )
                })}
                {pastPlan.length > 0 && (
                  <details style={{ marginTop: 6 }}>
                    <summary style={{ fontSize: 11, color: 'var(--text2)', cursor: 'pointer' }}>
                      {pastPlan.length} dia{pastPlan.length !== 1 ? 's' : ''} já executado{pastPlan.length !== 1 ? 's' : ''}
                    </summary>
                    {pastPlan.map(sd => {
                      const d = new Date(sd.date + 'T12:00:00')
                      return (
                        <div key={sd.date} style={{
                          display: 'flex', justifyContent: 'space-between', alignItems: 'center',
                          padding: '4px 0', fontSize: 11, color: 'var(--text2)',
                        }}>
                          <span>{d.toLocaleDateString('pt-BR', { weekday: 'short', day: '2-digit', month: '2-digit' })}</span>
                          <span>{fmtHM(sd.hours)}</span>
                        </div>
                      )
                    })}
                  </details>
                )}
              </div>
            )
          })()}

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
              <div key={s.id ?? i} style={{ fontSize: 12, padding: '10px 0', borderBottom: '1px solid var(--border)' }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', gap: 8 }}>
                  <div>
                    {s.userName && (
                      <div style={{ fontWeight: 600, color: 'var(--text)', marginBottom: 4 }}>👤 {s.userName}</div>
                    )}
                    <div style={{ marginBottom: 2 }}>
                      <span style={{ color: '#16a34a', fontWeight: 500 }}>▶ Iniciado: </span>
                      <span style={{ color: 'var(--text)' }}>{formatDateTime(s.start instanceof Date ? s.start.toISOString() : s.start)}</span>
                    </div>
                    <div>
                      <span style={{ color: '#dc2626', fontWeight: 500 }}>⏸ Pausado: </span>
                      <span style={{ color: 'var(--text)' }}>{formatDateTime(s.end instanceof Date ? s.end.toISOString() : s.end)}</span>
                    </div>
                  </div>
                  <span style={{ fontSize: 12, background: 'var(--bg2)', padding: '3px 10px', borderRadius: 10, color: 'var(--text2)', flexShrink: 0 }}>
                    {fmtMinsHM(s.mins)}
                  </span>
                </div>
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

      {/* Modal "+ Horas" — esforço adicional com prova */}
      {showEffort && (
        <ModalOverlay onClose={() => !effortSaving && setShowEffort(false)}>
          <div className="modal">
            <h3 style={{ fontWeight: 700, marginBottom: 6 }}>⏱️ Adicionar horas de esforço</h3>
            <p style={{ fontSize: 13, color: 'var(--text2)', marginBottom: 16 }}>
              Esforço estimado atual: <strong>{tk.effortEstimated} h</strong>. A justificativa abaixo será registrada como comentário no ticket.
            </p>
            <div className="form-row">
              <label className="label">Horas a adicionar *</label>
              <input className="input" type="number" min="0" step="0.5" value={effortHours}
                onChange={e => setEffortHours(e.target.value)} placeholder="ex: 2" />
            </div>
            <div className="form-row">
              <label className="label">O que será feito (prova do esforço) * — até 255 caracteres</label>
              <textarea className="input" rows={4} value={effortReason} maxLength={255}
                onChange={e => setEffortReason(e.target.value.slice(0, 255))}
                placeholder="Descreva brevemente o trabalho que justifica as horas adicionais…" />
              <div style={{ fontSize: 11, color: 'var(--text2)', textAlign: 'right', marginTop: 2 }}>
                {effortReason.length}/255
              </div>
            </div>
            <div style={{ display: 'flex', gap: 10, justifyContent: 'flex-end' }}>
              <button className="btn btn-secondary" disabled={effortSaving} onClick={() => setShowEffort(false)}>Cancelar</button>
              <button className="btn btn-primary" disabled={effortSaving} onClick={doAddEffort}>{effortSaving ? 'Salvando…' : '➕ Adicionar'}</button>
            </div>
          </div>
        </ModalOverlay>
      )}

      {/* Triage modal */}
      {showTriage && (
        <ModalOverlay onClose={() => setShowTriage(false)}>
          <div className="modal">
            <h3 style={{ fontWeight: 700, marginBottom: 18 }}>🎯 {tk.triaged ? '↺ Retriar Ticket' : t.triageBtn}</h3>
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
                <label className="label">
                  {tk.triaged && tk.effortEstimated > 0 ? 'Horas adicionais de esforço' : 'Horas de esforço estimadas'}
                </label>
                <input className="input" type="number" min="0" step="0.5" value={triageForm.effortEstimated} onChange={e => setTriageForm(f => ({ ...f, effortEstimated: e.target.value }))} />
                {tk.triaged && tk.effortEstimated > 0 && (
                  <div style={{ marginTop: 6, fontSize: 12, color: 'var(--text2)', display: 'flex', flexDirection: 'column', gap: 2 }}>
                    <span>Esforço atual: <strong>{tk.effortEstimated} h</strong></span>
                    {triageForm.effortEstimated > 0 && (
                      <span style={{ color: 'var(--primary)' }}>
                        Total após re-triagem: {tk.effortEstimated} + {parseFloat(triageForm.effortEstimated) || 0} = <strong>{(tk.effortEstimated + (parseFloat(triageForm.effortEstimated) || 0)).toFixed(1)} h</strong>
                      </span>
                    )}
                  </div>
                )}
              </div>
              <div>
                <label className="label">Fila *</label>
                <select className="select" style={{ width: '100%' }} value={triageForm.queueId}
                  onChange={e => {
                    const newQueueId = e.target.value
                    // Auto-select the least-loaded member of the new queue
                    const q       = queues.find(x => x.id === Number(newQueueId))
                    const qUsers  = users.filter(u => (q?.members ?? []).includes(u.id))
                    const best    = qUsers.length > 0
                      ? qUsers.reduce((b, u) => {
                          const cb = capacityMap[String(b?.id)]
                          const cu = capacityMap[String(u.id)]
                          if (!cu) return b
                          if (!cb) return u
                          if (cu.load_pct !== cb.load_pct) return cu.load_pct < cb.load_pct ? u : b
                          return cu.scheduled_hours < cb.scheduled_hours ? u : b
                        }, null)
                      : null
                    setTriageForm(f => ({ ...f, queueId: newQueueId, assigneeId: best ? String(best.id) : '', coAssigneeIds: [] }))
                  }}>
                  <option value="">Selecione…</option>
                  {queues.map(q => <option key={q.id} value={q.id}>{q.name}</option>)}
                </select>
              </div>
              <div>
                <label className="label">Responsável</label>
                <select className="select" style={{ width: '100%' }} value={triageForm.assigneeId || ''}
                  onChange={e => setTriageForm(f => ({ ...f, assigneeId: e.target.value, coAssigneeIds: [] }))}>
                  <option value="">— Deixar sem responsável —</option>
                  {(() => {
                    const q      = queues.find(x => x.id === Number(triageForm.queueId))
                    const qUsers = users.filter(u => (q?.members ?? []).includes(u.id))
                    // Sugestão: membro da fila com menor carga (load_pct) → menor scheduled_hours como desempate
                    const suggested = qUsers.length > 0
                      ? qUsers.reduce((best, u) => {
                          const cb = capacityMap[String(best?.id)]
                          const cu = capacityMap[String(u.id)]
                          if (!cu) return best
                          if (!cb) return u
                          if (cu.load_pct !== cb.load_pct) return cu.load_pct < cb.load_pct ? u : best
                          return cu.scheduled_hours < cb.scheduled_hours ? u : best
                        }, null)
                      : null
                    return qUsers.map(u => {
                      const cap     = capacityMap[String(u.id)]
                      const isBest  = suggested && String(u.id) === String(suggested.id)
                      const loadTxt = cap
                        ? ` — ${cap.load_pct}% ocupado (${fmtHM(Math.max(cap.free_hours, 0))} livres)`
                        : ''
                      const star = isBest ? '⭐ ' : ''
                      return (
                        <option key={u.id} value={u.id}>
                          {star}{u.firstName} {u.lastName}{loadTxt}
                        </option>
                      )
                    })
                  })()}
                </select>
                {/* Barra de carga do responsável selecionado */}
                {triageForm.assigneeId && (() => {
                  const cap = capacityMap[String(triageForm.assigneeId)]
                  if (!cap) return null
                  const pct   = Math.min(cap.load_pct, 100)
                  const color = cap.load_pct >= 100 ? '#ef4444' : cap.load_pct >= 75 ? '#f59e0b' : '#22c55e'
                  return (
                    <div style={{ marginTop: 6 }}>
                      <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: 11, color: 'var(--text2)', marginBottom: 3 }}>
                        <span>Carga nos próximos 7 dias</span>
                        <span style={{ color, fontWeight: 600 }}>{cap.load_pct}% — {fmtHM(Math.max(cap.free_hours, 0))} livres</span>
                      </div>
                      <div style={{ height: 6, background: 'var(--border)', borderRadius: 4, overflow: 'hidden' }}>
                        <div style={{ width: `${pct}%`, height: '100%', background: color, borderRadius: 4, transition: 'width 0.3s' }} />
                      </div>
                    </div>
                  )
                })()}
              </div>
              <div style={{ gridColumn: '1 / -1' }}>
                <label className="label">Co-responsáveis <span style={{ fontWeight: 400, color: 'var(--text2)' }}>(opcional — membros da fila)</span></label>
                {!triageForm.queueId ? (
                  <div style={{ fontSize: 12, color: 'var(--text2)', padding: '8px 0' }}>Selecione uma fila primeiro.</div>
                ) : (() => {
                  const q = queues.find(x => x.id === Number(triageForm.queueId))
                  const qMembers = users.filter(u => (q?.members ?? []).includes(u.id) && String(u.id) !== String(triageForm.assigneeId))
                  if (qMembers.length === 0) return <div style={{ fontSize: 12, color: 'var(--text2)', padding: '8px 0' }}>Nenhum outro membro disponível na fila.</div>
                  return (
                    <div style={{ display: 'flex', flexDirection: 'column', gap: 6, padding: '8px 10px', background: 'var(--bg2)', borderRadius: 8, border: '1px solid var(--border)' }}>
                      {qMembers.map(u => {
                        const checked = (triageForm.coAssigneeIds ?? []).includes(u.id)
                        return (
                          <label key={u.id} style={{ display: 'flex', alignItems: 'center', gap: 8, cursor: 'pointer', fontSize: 13 }}>
                            <input
                              type="checkbox"
                              checked={checked}
                              onChange={() => setTriageForm(f => {
                                const cur = f.coAssigneeIds ?? []
                                return { ...f, coAssigneeIds: checked ? cur.filter(id => id !== u.id) : [...cur, u.id] }
                              })}
                            />
                            {u.firstName} {u.lastName}
                          </label>
                        )
                      })}
                    </div>
                  )
                })()}
              </div>
              <div style={{ gridColumn: '1 / -1' }}>
                <label className="label">Prazo <span style={{ fontWeight: 400, color: 'var(--text2)' }}>(quem tria define — sobrepõe a sugestão)</span></label>
                <div style={{ display: 'flex', gap: 8, alignItems: 'center', flexWrap: 'wrap' }}>
                  <input className="input" type="date" style={{ maxWidth: 190 }}
                    value={triageForm.deadline || ''}
                    onChange={e => setTriageForm(f => ({ ...f, deadline: e.target.value }))} />
                  {deadlineSuggestion && (
                    <span style={{ fontSize: 12, color: 'var(--text2)' }}>
                      💡 Sugestão: <strong>{formatDate(deadlineSuggestion)}</strong>
                      <button type="button" className="btn btn-secondary btn-sm" style={{ marginLeft: 8 }}
                        onClick={() => setTriageForm(f => ({ ...f, deadline: String(deadlineSuggestion).slice(0, 10) }))}>
                        Usar sugestão
                      </button>
                    </span>
                  )}
                </div>
                {!triageForm.deadline && (
                  <div style={{ fontSize: 11, color: 'var(--text2)', marginTop: 4 }}>Se deixar em branco, o prazo é calculado automaticamente pelas regras.</div>
                )}
              </div>
            </div>
            <div style={{ display: 'flex', gap: 10, justifyContent: 'flex-end', marginTop: 18 }}>
              <button className="btn btn-secondary" onClick={() => setShowTriage(false)}>{t.cancel}</button>
              <button className="btn btn-primary" onClick={doTriage}>Confirmar Triagem</button>
            </div>
          </div>
        </ModalOverlay>
      )}

      {/* Modal de reabertura com horas adicionais */}
      {showReopenModal && (
        <ModalOverlay onClose={() => setShowReopenModal(false)}>
          <div className="modal" style={{ maxWidth: 440 }}>
            <h3 style={{ fontWeight: 700, marginBottom: 6 }}>🔄 Reabrir Ticket</h3>
            <p style={{ fontSize: 13, color: 'var(--text2)', marginBottom: 18, lineHeight: 1.6 }}>
              Informe quantas horas adicionais serão necessárias para resolver esta reabertura.
              O valor será somado ao esforço estimado atual.
            </p>

            {/* Resumo do esforço atual */}
            <div style={{ background: 'var(--bg2)', borderRadius: 8, padding: '10px 14px', marginBottom: 18, fontSize: 13 }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 4 }}>
                <span style={{ color: 'var(--text2)' }}>Esforço estimado atual</span>
                <strong>{fmtHM(tk.effortEstimated)}</strong>
              </div>
              <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 4 }}>
                <span style={{ color: 'var(--text2)' }}>Esforço já utilizado</span>
                <strong>{fmtHM(tk.effortUsed)}</strong>
              </div>
              {parseFloat(reopenHours) > 0 && (
                <>
                  <div style={{ borderTop: '1px solid var(--border)', margin: '8px 0' }} />
                  <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 4 }}>
                    <span style={{ color: 'var(--accent)' }}>+ Horas desta reabertura</span>
                    <strong style={{ color: 'var(--accent)' }}>+{fmtHM(parseFloat(reopenHours))}</strong>
                  </div>
                  <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                    <span style={{ color: 'var(--text2)' }}>Novo esforço estimado</span>
                    <strong>{fmtHM(tk.effortEstimated + parseFloat(reopenHours))}</strong>
                  </div>
                  <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 4 }}>
                    <span style={{ color: 'var(--text2)' }}>Disponível após reabrir</span>
                    <strong style={{ color: '#16a34a' }}>{fmtHM(tk.effortEstimated + parseFloat(reopenHours) - tk.effortUsed)}</strong>
                  </div>
                </>
              )}
            </div>

            <label style={{ fontSize: 13, fontWeight: 600, display: 'block', marginBottom: 6 }}>
              Horas adicionais necessárias
            </label>
            <input
              type="number"
              className="input"
              min="0"
              step="0.5"
              placeholder="Ex: 2 (ou 0.5 para 30 min)"
              value={reopenHours}
              onChange={e => setReopenHours(e.target.value)}
              onKeyDown={e => { if (e.key === 'Enter') doReopen() }}
              autoFocus
              style={{ marginBottom: 18 }}
            />

            <div style={{ display: 'flex', gap: 10 }}>
              <button className="btn btn-primary" onClick={doReopen} style={{ flex: 1 }}>
                🔄 Reabrir Ticket
              </button>
              <button className="btn btn-secondary" onClick={() => setShowReopenModal(false)}>
                Cancelar
              </button>
            </div>
          </div>
        </ModalOverlay>
      )}
    </div>
  )
}
