import { useState, useMemo, useEffect, useRef } from 'react'
import { useApp } from '../AppContext.jsx'
import { PT, EN, PERM, isExpired, formatDate } from '../data.js'
import { Avatar, Badge, PriBadge, CatChip } from '../components.jsx'
import {
  BarChart, Bar, LineChart, Line, XAxis, YAxis, CartesianGrid,
  Tooltip, ResponsiveContainer, PieChart, Pie, Cell, Legend,
} from 'recharts'

const PERIODS = { dia: 1, semana: 7, mês: 30, ano: 365 }

export default function Dashboard() {
  const { currentUser, lang, tickets, users, priorities, categories, setScreen, setSelectedTicket } = useApp()
  const t = lang === 'pt' ? PT : EN
  const [period, setPeriod] = useState('mês')

  const filtered = useMemo(() => {
    const cutoff = new Date()
    cutoff.setDate(cutoff.getDate() - (PERIODS[period] || 30))
    let tks = tickets.filter(tk => new Date(tk.createdAt) >= cutoff)
    if (currentUser.role === 'analyst') tks = tks.filter(tk => tk.assigneeId === currentUser.id)
    return tks
  }, [tickets, period, currentUser])

  const metrics = useMemo(() => ({
    total: filtered.length,
    open: filtered.filter(t => t.status === 'Não iniciado').length,
    inProgress: filtered.filter(t => t.status === 'Em andamento').length,
    resolved: filtered.filter(t => ['Resolvido', 'Fechado'].includes(t.status)).length,
    triage: filtered.filter(t => t.status === 'Triado, aguardando atendimento').length,
    waiting: filtered.filter(t => t.status === 'Aguardando terceiros').length,
    effortAllocated: filtered.reduce((a, t) => a + t.effortEstimated, 0),
    effortAvailable: users.filter(u => u.role !== 'user').reduce((a, u) => a + u.availableHours * (PERIODS[period] || 30), 0),
  }), [filtered, users, period])

  const statusData = [
    { name: 'Não iniciado', value: metrics.open },
    { name: 'Triado', value: metrics.triage },
    { name: 'Em andamento', value: metrics.inProgress },
    { name: 'Aguardando', value: metrics.waiting },
    { name: 'Resolvido', value: metrics.resolved },
  ]

  const catData = categories.map(c => ({
    name: c.name,
    value: filtered.filter(tk => tk.categoryId === c.id).length,
    color: c.color,
  })).filter(c => c.value > 0)

  const analystRows = useMemo(() =>
    users.filter(u => u.role !== 'user').map(u => ({
      user: u,
      open: filtered.filter(t => t.assigneeId === u.id && t.status === 'Não iniciado').length,
      inProgress: filtered.filter(t => t.assigneeId === u.id && t.status === 'Em andamento').length,
      waiting: filtered.filter(t => t.assigneeId === u.id && t.status === 'Aguardando terceiros').length,
      done: filtered.filter(t => t.assigneeId === u.id && ['Resolvido', 'Fechado'].includes(t.status)).length,
      expired: filtered.filter(t => t.assigneeId === u.id && isExpired(t.deadline)).length,
    })),
    [filtered, users]
  )

  function openTicket(tk) { setSelectedTicket(tk.id); setScreen('ticket-detail') }

  const metricCards = [
    { label: t.total, val: metrics.total, color: 'var(--accent)' },
    { label: 'Não iniciados', val: metrics.open, color: 'var(--text2)' },
    { label: t.inProgress, val: metrics.inProgress, color: 'var(--success)' },
    { label: t.resolved, val: metrics.resolved, color: '#15803d' },
    { label: 'Triado', val: metrics.triage, color: '#3b82f6' },
    { label: 'Aguardando', val: metrics.waiting, color: 'var(--warning)' },
    { label: 'Esforço alocado', val: metrics.effortAllocated + 'h', color: '#7c3aed' },
    { label: 'Capacidade total', val: metrics.effortAvailable + 'h', color: 'var(--success)' },
  ]

  return (
    <div>
      <div className="page-header">
        <h2 className="page-title">{t.dashboard}</h2>
        <div style={{ display: 'flex', gap: 6 }}>
          {Object.keys(PERIODS).map(p => (
            <div key={p} className={`tab ${period === p ? 'active' : ''}`} onClick={() => setPeriod(p)}>
              {p.charAt(0).toUpperCase() + p.slice(1)}
            </div>
          ))}
        </div>
      </div>

      {/* Metrics */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(130px, 1fr))', gap: 12, marginBottom: 20 }}>
        {metricCards.map(m => (
          <div key={m.label} className="metric-card">
            <div className="metric-num" style={{ color: m.color }}>{m.val}</div>
            <div className="metric-label">{m.label}</div>
          </div>
        ))}
      </div>

      {/* Charts */}
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 16, marginBottom: 20 }}>
        <div className="card">
          <div style={{ fontWeight: 600, fontSize: 14, marginBottom: 12 }}>Tickets por Status</div>
          <ResponsiveContainer width="100%" height={200}>
            <BarChart data={statusData}>
              <CartesianGrid strokeDasharray="3 3" stroke="var(--border)" />
              <XAxis dataKey="name" tick={{ fontSize: 10, fill: 'var(--text2)' }} />
              <YAxis tick={{ fontSize: 11, fill: 'var(--text2)' }} allowDecimals={false} />
              <Tooltip contentStyle={{ background: 'var(--bg)', border: '1px solid var(--border)', borderRadius: 8, fontSize: 12 }} />
              <Bar dataKey="value" fill="#2383e2" radius={[4, 4, 0, 0]} />
            </BarChart>
          </ResponsiveContainer>
        </div>
        <div className="card">
          <div style={{ fontWeight: 600, fontSize: 14, marginBottom: 12 }}>Por Categoria</div>
          {catData.length === 0
            ? <div style={{ color: 'var(--text2)', fontSize: 13, textAlign: 'center', paddingTop: 40 }}>Sem dados</div>
            : (
              <ResponsiveContainer width="100%" height={200}>
                <PieChart>
                  <Pie data={catData} dataKey="value" nameKey="name" cx="50%" cy="50%" outerRadius={75} paddingAngle={2}>
                    {catData.map((c, i) => <Cell key={i} fill={c.color + 'cc'} />)}
                  </Pie>
                  <Tooltip contentStyle={{ background: 'var(--bg)', border: '1px solid var(--border)', borderRadius: 8, fontSize: 12 }} />
                  <Legend iconSize={10} wrapperStyle={{ fontSize: 11 }} />
                </PieChart>
              </ResponsiveContainer>
            )
          }
        </div>
      </div>

      {/* Analysts table */}
      {currentUser.role === 'admin' && (
        <div className="card" style={{ marginBottom: 20 }}>
          <div style={{ fontWeight: 600, fontSize: 14, marginBottom: 12 }}>Responsáveis</div>
          <table className="table">
            <thead>
              <tr>
                <th>Responsável</th>
                <th>Não iniciado</th>
                <th>Em andamento</th>
                <th>Aguardando</th>
                <th>Concluídos</th>
              </tr>
            </thead>
            <tbody>
              {analystRows.map(r => (
                <tr key={r.user.id} className={r.expired > 0 ? 'sla-expired-row' : ''}>
                  <td>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                      <Avatar user={r.user} size={26} />
                      {r.user.firstName} {r.user.lastName}
                      {r.expired > 0 && <span style={{ color: 'var(--danger)', fontSize: 11 }}>⚠ SLA</span>}
                    </div>
                  </td>
                  <td>{r.open}</td>
                  <td>{r.inProgress}</td>
                  <td>{r.waiting}</td>
                  <td>{r.done}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {/* Recent tickets */}
      <div className="card">
        <div style={{ fontWeight: 600, fontSize: 14, marginBottom: 12 }}>Tickets Recentes</div>
        <div style={{ overflowX: 'auto' }}>
          <table className="table" style={{ fontSize: 12.5 }}>
            <thead>
              <tr><th>ID</th><th>Título</th><th>Prioridade</th><th>Status</th><th>Prazo</th></tr>
            </thead>
            <tbody>
              {filtered.slice(0, 8).map(tk => {
                const pri = priorities.find(p => p.id === tk.priorityId)
                const expired = isExpired(tk.deadline) && !['Resolvido', 'Fechado'].includes(tk.status)
                return (
                  <tr key={tk.id} className={expired ? 'sla-expired-row' : ''} style={{ cursor: 'pointer' }} onClick={() => openTicket(tk)}>
                    <td style={{ color: 'var(--accent)', fontWeight: 600 }}>{tk.id}</td>
                    <td style={{ maxWidth: 240, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                      {expired && <span style={{ color: 'var(--danger)', marginRight: 4 }}>⚠</span>}{tk.title}
                    </td>
                    <td><PriBadge priority={pri} /></td>
                    <td><Badge status={tk.status} /></td>
                    <td style={{ color: expired ? 'var(--danger)' : 'var(--text)' }}>{formatDate(tk.deadline)}</td>
                  </tr>
                )
              })}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  )
}
