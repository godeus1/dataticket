import { useState, useMemo } from 'react'
import { useApp } from '../AppContext.jsx'
import { PT, EN, PERM, isExpired, formatDate } from '../data.js'
import { CatChip, PriBadge, Badge, ModalOverlay } from '../components.jsx'
import {
  BarChart, Bar, PieChart, Pie, Cell, XAxis, YAxis, CartesianGrid,
  Tooltip, ResponsiveContainer, Legend,
} from 'recharts'

// ── Calendar ──────────────────────────────────────────────────────────────
export function CalendarView() {
  const { currentUser, lang, tickets, priorities, users, categories, setScreen, setSelectedTicket } = useApp()
  const t = lang === 'pt' ? PT : EN
  const [refDate, setRefDate] = useState(new Date())
  const [filterAssignee, setFilterAssignee] = useState('')
  const [dayPopup, setDayPopup] = useState(null)
  const [calTicketId, setCalTicketId] = useState(null)

  const myTickets = useMemo(() => {
    let tks = tickets.filter(tk => tk.deadline && !['Fechado'].includes(tk.status))
    if (currentUser.role === 'analyst') tks = tks.filter(tk => tk.assigneeId === currentUser.id)
    if (filterAssignee) tks = tks.filter(tk => tk.assigneeId === Number(filterAssignee))
    return tks
  }, [tickets, currentUser, filterAssignee])

  function getMonthDays(d) {
    const year = d.getFullYear(), month = d.getMonth()
    const first = new Date(year, month, 1)
    const last = new Date(year, month + 1, 0)
    const days = []
    for (let i = 0; i < first.getDay(); i++) days.push(null)
    for (let i = 1; i <= last.getDate(); i++) days.push(new Date(year, month, i))
    return days
  }

  const days = getMonthDays(refDate)
  const dayNames = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb']

  function getTicketsForDay(day) {
    if (!day) return []
    const ds = `${day.getFullYear()}-${String(day.getMonth()+1).padStart(2,'0')}-${String(day.getDate()).padStart(2,'0')}`
    return myTickets.filter(tk => {
      if (tk.scheduledDays && tk.scheduledDays.length > 0)
        return tk.scheduledDays.some(sd => sd.date === ds)
      if (!tk.deadline) return false
      const dl = new Date(tk.deadline)
      return dl.getDate() === day.getDate() && dl.getMonth() === day.getMonth() && dl.getFullYear() === day.getFullYear()
    })
  }

  function getScheduledHours(tk, day) {
    const ds = `${day.getFullYear()}-${String(day.getMonth()+1).padStart(2,'0')}-${String(day.getDate()).padStart(2,'0')}`
    return (tk.scheduledDays || []).find(sd => sd.date === ds)?.hours || null
  }

  function prevMonth() { const d = new Date(refDate); d.setMonth(d.getMonth() - 1); setRefDate(d) }
  function nextMonth() { const d = new Date(refDate); d.setMonth(d.getMonth() + 1); setRefDate(d) }

  return (
    <div>
      <div className="page-header">
        <h2 className="page-title">{t.calendar}</h2>
        <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
          {currentUser.role === 'admin' && (
            <select className="select" value={filterAssignee} onChange={e => setFilterAssignee(e.target.value)}>
              <option value="">Todos responsáveis</option>
              {users.filter(u => u.role !== 'user').map(u => (
                <option key={u.id} value={u.id}>{u.firstName} {u.lastName}</option>
              ))}
            </select>
          )}
          <button className="btn btn-secondary btn-sm" onClick={prevMonth}>◀</button>
          <span style={{ fontWeight: 600, minWidth: 160, textAlign: 'center', fontSize: 14 }}>
            {refDate.toLocaleDateString('pt-BR', { month: 'long', year: 'numeric' })}
          </span>
          <button className="btn btn-secondary btn-sm" onClick={nextMonth}>▶</button>
        </div>
      </div>

      <div className="card" style={{ padding: 0, overflow: 'hidden' }}>
        <div className="cal-header">
          {dayNames.map(d => <div key={d} className="cal-header-cell">{d}</div>)}
        </div>
        <div className="cal-grid">
          {days.map((day, i) => {
            const tksDay = day ? getTicketsForDay(day) : []
            const isToday = day && day.toDateString() === new Date().toDateString()
            return (
              <div key={i} className={`cal-cell ${!day ? 'empty' : ''}`}
                style={{ background: isToday ? 'var(--accent)0d' : day ? 'var(--bg)' : 'var(--bg2)' }}>
                {day && (
                  <div style={{ marginBottom: 4 }}>
                    {isToday
                      ? <span className="cal-today-badge">{day.getDate()}</span>
                      : <span style={{ fontSize: 12, fontWeight: 400, color: 'var(--text2)' }}>{day.getDate()}</span>
                    }
                  </div>
                )}
                {tksDay.slice(0, 3).map(tk => {
                  const pri = priorities.find(p => p.id === tk.priorityId)
                  const hrs = day ? getScheduledHours(tk, day) : null
                  const asgn = users.find(u => u.id === tk.assigneeId)
                  const asgnName = asgn ? `${asgn.firstName} ${asgn.lastName}` : ''
                  return (
                    <div
                      key={tk.id}
                      className="cal-event"
                      style={{ background: (pri?.color || 'var(--accent)') }}
                      onClick={() => setCalTicketId(tk.id)}
                      title={`${tk.id}: ${tk.title}${hrs ? ` · ${hrs}h` : ''}${asgnName ? ` · ${asgnName}` : ''}`}
                    >
                      <span style={{ overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                        {tk.id}: {tk.title.slice(0, 12)}
                      </span>
                      {hrs != null && (
                        <span style={{ fontSize: 10, opacity: 0.9, marginLeft: 2, flexShrink: 0 }}>{hrs}h</span>
                      )}
                    </div>
                  )
                })}
                {tksDay.length > 3 && (
                  <button
                    className="cal-more"
                    onClick={e => { e.stopPropagation(); setDayPopup({ day, tickets: tksDay }) }}
                  >
                    +{tksDay.length - 3} mais
                  </button>
                )}
              </div>
            )
          })}
        </div>
      </div>

      <div style={{ marginTop: 12, display: 'flex', gap: 8, alignItems: 'center', fontSize: 12, color: 'var(--text2)' }}>
        <span>💡 Clique num ticket para abri-lo.</span>
        <span>·</span>
        <span>🔗 Integração com Microsoft 365 e Google Calendar disponível em <strong>Meu Perfil</strong>.</span>
      </div>

      {calTicketId && (() => {
        const ctk = tickets.find(t => t.id === calTicketId)
        if (!ctk) return null
        const cpri = priorities.find(p => p.id === ctk.priorityId)
        const ccat = categories.find(c => c.id === ctk.categoryId)
        const creq = users.find(u => u.id === ctk.requesterId)
        const cassignee = users.find(u => u.id === ctk.assigneeId)
        const cexpired = ctk.deadline && new Date(ctk.deadline) < new Date() && !['Resolvido', 'Fechado'].includes(ctk.status)
        const cp = PERM[currentUser.role]
        return (
          <ModalOverlay onClose={() => setCalTicketId(null)}>
            <div className="modal" style={{ maxWidth: 560 }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: 16 }}>
                <div>
                  <div style={{ display: 'flex', gap: 8, alignItems: 'center', flexWrap: 'wrap', marginBottom: 4 }}>
                    <span style={{ fontWeight: 700, color: 'var(--accent)' }}>{ctk.id}</span>
                    <Badge status={ctk.status} />
                    {cpri && <PriBadge priority={cpri} />}
                    {cexpired && <span style={{ background: '#fef2f2', color: 'var(--danger)', padding: '2px 8px', borderRadius: 20, fontSize: 11, fontWeight: 600 }}>⚠ SLA vencido</span>}
                  </div>
                  <div style={{ fontWeight: 700, fontSize: 15 }}>{ctk.title}</div>
                </div>
                <button className="btn btn-secondary btn-sm" onClick={() => setCalTicketId(null)}>✕</button>
              </div>
              <div style={{ fontSize: 13, color: 'var(--text2)', marginBottom: 14, lineHeight: 1.6, maxHeight: 80, overflow: 'hidden', textOverflow: 'ellipsis' }}>
                {ctk.description}
              </div>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '6px 16px', fontSize: 13, marginBottom: 16 }}>
                {[
                  { label: 'Solicitante', val: creq ? `${creq.firstName} ${creq.lastName}` : '—' },
                  { label: 'Responsável', val: cassignee ? `${cassignee.firstName} ${cassignee.lastName}` : 'Não atribuído' },
                  { label: 'Categoria', val: ccat ? ccat.name : '—' },
                  { label: 'Prazo', val: ctk.deadline ? new Date(ctk.deadline).toLocaleDateString('pt-BR') : '—' },
                  { label: 'Esforço', val: `${(ctk.effortUsed || 0).toFixed(1)}/${ctk.effortEstimated || 0}h` },
                ].map(r => (
                  <div key={r.label} style={{ display: 'flex', justifyContent: 'space-between', borderBottom: '1px solid var(--border)', padding: '4px 0' }}>
                    <span style={{ color: 'var(--text2)' }}>{r.label}</span>
                    <span style={{ fontWeight: 500 }}>{r.val}</span>
                  </div>
                ))}
              </div>
              <div style={{ display: 'flex', gap: 8, justifyContent: 'flex-end' }}>
                <button className="btn btn-secondary btn-sm" onClick={() => setCalTicketId(null)}>Fechar</button>
                <button className="btn btn-primary btn-sm" onClick={() => { setSelectedTicket(ctk.id); setCalTicketId(null) }}>
                  Abrir Ticket Completo →
                </button>
              </div>
            </div>
          </ModalOverlay>
        )
      })()}

      {dayPopup && (
        <ModalOverlay onClose={() => setDayPopup(null)}>
          <div className="modal" style={{ maxWidth: 480 }}>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 16 }}>
              <h3 style={{ fontWeight: 700, fontSize: 15, textTransform: 'capitalize' }}>
                {dayPopup.day.toLocaleDateString('pt-BR', { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' })}
              </h3>
              <button className="btn btn-secondary btn-sm" onClick={() => setDayPopup(null)}>✕</button>
            </div>
            <div style={{ fontSize: 12, color: 'var(--text2)', marginBottom: 12 }}>
              {dayPopup.tickets.length} ticket{dayPopup.tickets.length !== 1 ? 's' : ''} com prazo neste dia
            </div>
            <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
              {dayPopup.tickets.map(tk => {
                const pri = priorities.find(p => p.id === tk.priorityId)
                const hrs = getScheduledHours(tk, dayPopup.day)
                return (
                  <div
                    key={tk.id}
                    className="cal-popup-row"
                    onClick={() => { setCalTicketId(tk.id); setDayPopup(null) }}
                    onMouseEnter={e => e.currentTarget.style.borderColor = 'var(--accent)'}
                    onMouseLeave={e => e.currentTarget.style.borderColor = 'var(--border)'}
                  >
                    <div style={{ width: 8, height: 8, borderRadius: '50%', background: pri?.color || 'var(--accent)', flexShrink: 0 }} />
                    <span style={{ fontSize: 11, color: 'var(--text2)', minWidth: 52, fontFamily: 'monospace' }}>#{tk.id}</span>
                    <span style={{ fontSize: 13, flex: 1, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{tk.title}</span>
                    {hrs && <span style={{ fontSize: 11, color: 'var(--text2)', whiteSpace: 'nowrap' }}>{hrs}h</span>}
                    {pri && <PriBadge priority={pri} />}
                  </div>
                )
              })}
            </div>
          </div>
        </ModalOverlay>
      )}
    </div>
  )
}

// ── Knowledge Base ────────────────────────────────────────────────────────
export function KnowledgeBase() {
  const { currentUser, lang, articles, createArticleAction, categories } = useApp()
  const t = lang === 'pt' ? PT : EN
  const [search, setSearch] = useState('')
  const [selected, setSelected] = useState(null)
  const [showForm, setShowForm] = useState(false)
  const [form, setForm] = useState({ name: '', categoryId: '', description: '', keywords: '' })
  const p = PERM[currentUser.role]
  const canManage = p.settings || currentUser.role === 'analyst'

  const filtered = articles.filter(a =>
    a.active &&
    (a.name.toLowerCase().includes(search.toLowerCase()) ||
      a.keywords.toLowerCase().includes(search.toLowerCase()))
  )

  if (selected) {
    const art = articles.find(a => a.id === selected)
    const cat = categories.find(c => c.id === art?.categoryId)
    return (
      <div style={{ maxWidth: 760, margin: '0 auto' }}>
        <button className="btn btn-secondary" style={{ marginBottom: 18 }} onClick={() => setSelected(null)}>← Voltar</button>
        <div className="card">
          <div style={{ marginBottom: 10 }}><CatChip category={cat} /></div>
          <h2 style={{ fontWeight: 700, fontSize: 22, marginBottom: 8 }}>{art?.name}</h2>
          <div style={{ fontSize: 12, color: 'var(--text2)', marginBottom: 18 }}>
            Criado em {formatDate(art?.createdAt)} · 🏷️ {art?.keywords}
          </div>
          <div style={{ divider: 'var(--border)', borderTop: '1px solid var(--border)', paddingTop: 16 }}>
            <div style={{ fontSize: 15, lineHeight: 1.8, color: 'var(--text)', whiteSpace: 'pre-wrap' }}>{art?.description}</div>
          </div>
        </div>
      </div>
    )
  }

  return (
    <div>
      <div className="page-header">
        <h2 className="page-title">{t.kb}</h2>
        {canManage && (
          <button className="btn btn-primary" onClick={() => { setForm({ name: '', categoryId: '', description: '', keywords: '' }); setShowForm(true) }}>
            ➕ Novo Artigo
          </button>
        )}
      </div>

      <div className="search-box" style={{ marginBottom: 18, maxWidth: 460 }}>
        <span>🔍</span>
        <input placeholder="Buscar artigos por título ou palavra-chave…" value={search} onChange={e => setSearch(e.target.value)} />
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(280px, 1fr))', gap: 14 }}>
        {filtered.map(a => {
          const cat = categories.find(c => c.id === a.categoryId)
          return (
            <div key={a.id} className="card" style={{ cursor: 'pointer', transition: 'border-color .15s' }}
              onClick={() => setSelected(a.id)}
              onMouseEnter={e => e.currentTarget.style.borderColor = 'var(--accent)'}
              onMouseLeave={e => e.currentTarget.style.borderColor = 'var(--border)'}
            >
              <div style={{ marginBottom: 6 }}><CatChip category={cat} /></div>
              <div style={{ fontWeight: 600, fontSize: 14, marginBottom: 6 }}>{a.name}</div>
              <div style={{ fontSize: 12, color: 'var(--text2)', overflow: 'hidden', display: '-webkit-box', WebkitLineClamp: 2, WebkitBoxOrient: 'vertical' }}>
                {a.description}
              </div>
              <div style={{ fontSize: 11, color: 'var(--text2)', marginTop: 10 }}>🏷️ {a.keywords}</div>
            </div>
          )
        })}
        {filtered.length === 0 && (
          <div style={{ gridColumn: '1/-1', color: 'var(--text2)', fontSize: 14, textAlign: 'center', padding: 40 }}>
            Nenhum artigo encontrado.
          </div>
        )}
      </div>

      {showForm && (
        <ModalOverlay onClose={() => setShowForm(false)}>
          <div className="modal">
            <h3 style={{ fontWeight: 700, marginBottom: 16 }}>Novo Artigo</h3>
            <div className="form-row">
              <label className="label">{t.name}</label>
              <input className="input" value={form.name} onChange={e => setForm(f => ({ ...f, name: e.target.value }))} />
            </div>
            <div className="form-row">
              <label className="label">{t.category}</label>
              <select className="select" style={{ width: '100%' }} value={form.categoryId} onChange={e => setForm(f => ({ ...f, categoryId: e.target.value }))}>
                <option value="">Selecione…</option>
                {categories.map(c => <option key={c.id} value={c.id}>{c.name}</option>)}
              </select>
            </div>
            <div className="form-row">
              <label className="label">{t.keywords}</label>
              <input className="input" value={form.keywords} onChange={e => setForm(f => ({ ...f, keywords: e.target.value }))} placeholder="ex: vpn, acesso, remoto" />
            </div>
            <div className="form-row">
              <label className="label">Descrição</label>
              <textarea className="input" rows={6} value={form.description} onChange={e => setForm(f => ({ ...f, description: e.target.value }))} />
            </div>
            <div style={{ display: 'flex', gap: 10, justifyContent: 'flex-end' }}>
              <button className="btn btn-secondary" onClick={() => setShowForm(false)}>{t.cancel}</button>
              <button className="btn btn-primary" onClick={async () => {
                try {
                  await createArticleAction({ title: form.name, body: form.description, keywords: form.keywords, published: true })
                  setShowForm(false)
                } catch (e) { alert(`Erro: ${e.message}`) }
              }}>{t.save}</button>
            </div>
          </div>
        </ModalOverlay>
      )}
    </div>
  )
}

// ── Reports ───────────────────────────────────────────────────────────────
const PERIODS = { dia: 1, semana: 7, mês: 30, ano: 365 }

export function Reports() {
  const { lang, tickets, categories, priorities, users } = useApp()
  const t = lang === 'pt' ? PT : EN
  const [period, setPeriod] = useState('mês')

  const filtered = useMemo(() => {
    const cutoff = new Date()
    cutoff.setDate(cutoff.getDate() - (PERIODS[period] || 30))
    return tickets.filter(tk => new Date(tk.createdAt) >= cutoff)
  }, [tickets, period])

  const catData = categories.map(c => ({
    name: c.name,
    value: filtered.filter(tk => tk.categoryId === c.id).length,
    color: c.color,
  })).filter(c => c.value > 0)

  const priData = priorities.map(p => ({
    name: p.name,
    resolvidos: filtered.filter(tk => tk.priorityId === p.id && ['Resolvido', 'Fechado'].includes(tk.status)).length,
    color: p.color,
  }))

  const onTime = filtered.filter(tk => ['Resolvido', 'Fechado'].includes(tk.status) && (!tk.deadline || !isExpired(tk.deadline))).length
  const late = filtered.filter(tk => ['Resolvido', 'Fechado'].includes(tk.status) && tk.deadline && isExpired(tk.deadline)).length
  const slaData = [
    { name: 'No prazo', value: onTime, color: '#38a169' },
    { name: 'Fora do prazo', value: late, color: '#e53e3e' },
  ]

  const reopened = filtered.filter(tk => tk.history.some(h => h.to === 'Reaberto')).length
  const reopenRate = filtered.length ? ((reopened / filtered.length) * 100).toFixed(1) : 0

  const topCats = [...catData].sort((a, b) => b.value - a.value).slice(0, 5)

  const statusBarData = [
    { name: 'Não iniciado',  qtd: filtered.filter(t => t.status === 'Não iniciado').length },
    { name: 'Triado',        qtd: filtered.filter(t => t.status === 'Triado, aguardando atendimento').length },
    { name: 'Em andamento',  qtd: filtered.filter(t => t.status === 'Em andamento').length },
    { name: 'Aguardando',    qtd: filtered.filter(t => t.status === 'Aguardando terceiros').length },
    { name: 'Resolvido',     qtd: filtered.filter(t => t.status === 'Resolvido').length },
    { name: 'Fechado',       qtd: filtered.filter(t => t.status === 'Fechado').length },
  ]

  function exportCSV() {
    const headers = ['ID','Título','Status','Prioridade','Categoria','Responsável','Solicitante','Criado em','Prazo','Esforço (h)']
    const rows = filtered.map(tk => {
      const pri = priorities.find(p => p.id === tk.priorityId)?.name || ''
      const cat = categories.find(c => c.id === tk.categoryId)?.name || ''
      const assignee = users.find(u => u.id === tk.assigneeId)
      const requester = users.find(u => u.id === tk.requesterId)
      return [
        tk.id,
        `"${(tk.title || '').replace(/"/g, '""')}"`,
        tk.status,
        pri,
        cat,
        assignee ? `${assignee.firstName} ${assignee.lastName}` : '',
        requester ? `${requester.firstName} ${requester.lastName}` : '',
        formatDate(tk.createdAt),
        formatDate(tk.deadline),
        tk.effortEstimated || 0,
      ].join(';')
    })
    const csv = [headers.join(';'), ...rows].join('\n')
    const blob = new Blob(['﻿' + csv], { type: 'text/csv;charset=utf-8;' })
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a'); a.href = url
    const dateStr = new Date().toLocaleDateString('pt-BR').replace(/\//g, '-')
    a.download = `dataticket-relatorio-${period}-${dateStr}.csv`
    document.body.appendChild(a); a.click()
    document.body.removeChild(a); URL.revokeObjectURL(url)
  }

  function exportPDF() {
    const dateStr = new Date().toLocaleDateString('pt-BR', { dateStyle: 'full' })
    const rows = filtered.map(tk => {
      const pri = priorities.find(p => p.id === tk.priorityId)?.name || '—'
      const cat = categories.find(c => c.id === tk.categoryId)?.name || '—'
      const assignee = users.find(u => u.id === tk.assigneeId)
      return `<tr>
        <td>${tk.id}</td>
        <td>${tk.title}</td>
        <td>${tk.status}</td>
        <td>${pri}</td>
        <td>${cat}</td>
        <td>${assignee ? assignee.firstName + ' ' + assignee.lastName : '—'}</td>
        <td>${formatDate(tk.deadline)}</td>
      </tr>`
    }).join('')
    const html = `<!DOCTYPE html><html><head><meta charset="utf-8"><title>Relatório DataTicket</title>
    <style>body{font-family:sans-serif;font-size:12px;margin:24px}h1{color:#2383e2;font-size:18px}
    p{color:#6b7280;font-size:11px}table{width:100%;border-collapse:collapse;margin-top:16px}
    th{background:#f3f4f6;padding:8px;text-align:left;font-size:11px;color:#374151;border-bottom:2px solid #e5e7eb}
    td{padding:7px 8px;border-bottom:1px solid #f3f4f6;font-size:11px}
    .footer{margin-top:24px;font-size:10px;color:#9ca3af;text-align:center;border-top:1px solid #e5e7eb;padding-top:12px}
    </style></head><body>
    <h1>🎯 DataTicket · Relatório de Tickets</h1>
    <p>Período: ${period} &nbsp;|&nbsp; Total: ${filtered.length} tickets &nbsp;|&nbsp; Gerado em ${dateStr}</p>
    <table><thead><tr><th>ID</th><th>Título</th><th>Status</th><th>Prioridade</th><th>Categoria</th><th>Responsável</th><th>Prazo</th></tr></thead>
    <tbody>${rows}</tbody></table>
    <div class="footer">Desenvolvido por DataTry Tecnologia e Negócios &nbsp;|&nbsp; dataticket.vercel.app</div>
    </body></html>`
    const w = window.open('', '_blank')
    w.document.write(html)
    w.document.close()
    w.focus()
    setTimeout(() => { w.print(); w.close() }, 500)
  }

  return (
    <div>
      <div className="page-header">
        <h2 className="page-title">{t.reports}</h2>
        <div style={{ display: 'flex', gap: 6 }}>
          {Object.keys(PERIODS).map(p => (
            <div key={p} className={`tab ${period === p ? 'active' : ''}`} onClick={() => setPeriod(p)}>
              {p.charAt(0).toUpperCase() + p.slice(1)}
            </div>
          ))}
          <button className="btn btn-secondary btn-sm" onClick={exportCSV}>📥 CSV</button>
          <button className="btn btn-secondary btn-sm" onClick={exportPDF}>📄 PDF</button>
        </div>
      </div>

      {/* KPI row */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(160px, 1fr))', gap: 12, marginBottom: 20 }}>
        {[
          { label: 'Total de tickets', val: filtered.length, color: 'var(--accent)' },
          { label: 'Resolvidos', val: filtered.filter(t => ['Resolvido', 'Fechado'].includes(t.status)).length, color: 'var(--success)' },
          { label: 'SLA vencido', val: filtered.filter(t => isExpired(t.deadline) && !['Resolvido', 'Fechado'].includes(t.status)).length, color: 'var(--danger)' },
          { label: 'Taxa reabertura', val: reopenRate + '%', color: 'var(--warning)' },
        ].map(m => (
          <div key={m.label} className="metric-card">
            <div className="metric-num" style={{ color: m.color }}>{m.val}</div>
            <div className="metric-label">{m.label}</div>
          </div>
        ))}
      </div>

      {/* Charts row 1 */}
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 16, marginBottom: 16 }}>
        <div className="card">
          <div style={{ fontWeight: 600, fontSize: 13, marginBottom: 12 }}>Distribuição por Categoria</div>
          {catData.length === 0
            ? <div style={{ color: 'var(--text2)', fontSize: 13, textAlign: 'center', padding: 40 }}>Sem dados</div>
            : (
              <ResponsiveContainer width="100%" height={220}>
                <PieChart>
                  <Pie data={catData} dataKey="value" nameKey="name" cx="50%" cy="50%" outerRadius={80} paddingAngle={2}>
                    {catData.map((c, i) => <Cell key={i} fill={c.color + 'bb'} />)}
                  </Pie>
                  <Tooltip contentStyle={{ background: 'var(--bg)', border: '1px solid var(--border)', borderRadius: 8, fontSize: 12 }} />
                  <Legend iconSize={10} wrapperStyle={{ fontSize: 11 }} />
                </PieChart>
              </ResponsiveContainer>
            )}
        </div>
        <div className="card">
          <div style={{ fontWeight: 600, fontSize: 13, marginBottom: 12 }}>Resolvidos por Prioridade</div>
          <ResponsiveContainer width="100%" height={220}>
            <BarChart data={priData} layout="vertical">
              <CartesianGrid strokeDasharray="3 3" stroke="var(--border)" />
              <XAxis type="number" tick={{ fontSize: 11, fill: 'var(--text2)' }} allowDecimals={false} />
              <YAxis type="category" dataKey="name" tick={{ fontSize: 11, fill: 'var(--text2)' }} width={55} />
              <Tooltip contentStyle={{ background: 'var(--bg)', border: '1px solid var(--border)', borderRadius: 8, fontSize: 12 }} />
              <Bar dataKey="resolvidos" radius={[0, 4, 4, 0]}>
                {priData.map((p, i) => <Cell key={i} fill={p.color + '99'} />)}
              </Bar>
            </BarChart>
          </ResponsiveContainer>
        </div>
      </div>

      {/* Charts row 2 */}
      <div style={{ display: 'grid', gridTemplateColumns: '2fr 1fr', gap: 16, marginBottom: 16 }}>
        <div className="card">
          <div style={{ fontWeight: 600, fontSize: 13, marginBottom: 12 }}>Tickets por Status</div>
          <ResponsiveContainer width="100%" height={200}>
            <BarChart data={statusBarData}>
              <CartesianGrid strokeDasharray="3 3" stroke="var(--border)" />
              <XAxis dataKey="name" tick={{ fontSize: 10, fill: 'var(--text2)' }} />
              <YAxis tick={{ fontSize: 11, fill: 'var(--text2)' }} allowDecimals={false} />
              <Tooltip contentStyle={{ background: 'var(--bg)', border: '1px solid var(--border)', borderRadius: 8, fontSize: 12 }} />
              <Bar dataKey="qtd" fill="#2383e288" radius={[4, 4, 0, 0]} />
            </BarChart>
          </ResponsiveContainer>
        </div>
        <div className="card">
          <div style={{ fontWeight: 600, fontSize: 13, marginBottom: 12 }}>Prazo (Resolvidos)</div>
          {(onTime + late) === 0
            ? <div style={{ color: 'var(--text2)', fontSize: 13, textAlign: 'center', padding: 40 }}>Sem dados</div>
            : (
              <ResponsiveContainer width="100%" height={200}>
                <PieChart>
                  <Pie data={slaData} dataKey="value" nameKey="name" cx="50%" cy="45%" outerRadius={70} innerRadius={35} paddingAngle={3}>
                    {slaData.map((s, i) => <Cell key={i} fill={s.color + 'aa'} />)}
                  </Pie>
                  <Tooltip contentStyle={{ background: 'var(--bg)', border: '1px solid var(--border)', borderRadius: 8, fontSize: 12 }} />
                  <Legend iconSize={10} wrapperStyle={{ fontSize: 11 }} />
                </PieChart>
              </ResponsiveContainer>
            )}
        </div>
      </div>

      {/* Top categories */}
      <div className="card">
        <div style={{ fontWeight: 600, fontSize: 13, marginBottom: 14 }}>Top 5 Categorias</div>
        {topCats.length === 0 && <div style={{ color: 'var(--text2)', fontSize: 13 }}>Sem dados no período.</div>}
        {topCats.map(({ name, value, color }) => (
          <div key={name} style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 10 }}>
            <span style={{ minWidth: 100, fontSize: 13 }}>{name}</span>
            <div className="progress" style={{ flex: 1 }}>
              <div className="progress-bar" style={{ width: `${filtered.length ? Math.round((value / filtered.length) * 100) : 0}%`, background: color }} />
            </div>
            <span style={{ fontSize: 13, minWidth: 30, textAlign: 'right', fontWeight: 600 }}>{value}</span>
          </div>
        ))}
      </div>
    </div>
  )
}
