import { useState, useMemo } from 'react'
import { useApp } from '../AppContext.jsx'
import { PT, EN } from '../data.js'
import { Avatar } from '../components.jsx'
import {
  BarChart, Bar, LineChart, Line, XAxis, YAxis, CartesianGrid,
  Tooltip, ResponsiveContainer, PieChart, Pie, Cell, Legend,
} from 'recharts'

// ── Date range helpers ────────────────────────────────────────────────────────

function getDateRange(period) {
  const now    = new Date()
  const sol    = d => { const x = new Date(d); x.setHours(0, 0, 0, 0);       return x }
  const eol    = d => { const x = new Date(d); x.setHours(23, 59, 59, 999);  return x }
  const addD   = (d, n) => { const x = new Date(d); x.setDate(x.getDate() + n); return x }

  switch (period) {
    case 'dia':
      return { from: sol(now), to: eol(now) }

    case 'semana': {
      const dow = now.getDay() === 0 ? 6 : now.getDay() - 1   // 0=Mon…6=Sun
      return { from: sol(addD(now, -dow)), to: eol(now) }
    }

    case 'semana_passada': {
      const dow     = now.getDay() === 0 ? 6 : now.getDay() - 1
      const thisMon = addD(now, -dow)
      const lastMon = addD(thisMon, -7)
      const lastSun = addD(thisMon, -1)
      return { from: sol(lastMon), to: eol(lastSun) }
    }

    case 'mes':
      return { from: sol(new Date(now.getFullYear(), now.getMonth(), 1)), to: eol(now) }

    case 'mes_passado': {
      const first = new Date(now.getFullYear(), now.getMonth() - 1, 1)
      const last  = new Date(now.getFullYear(), now.getMonth(), 0)
      return { from: sol(first), to: eol(last) }
    }

    default:
      return { from: sol(new Date(now.getFullYear(), now.getMonth(), 1)), to: eol(now) }
  }
}

function buildOpeningData(tickets, period) {
  const { from, to } = getDateRange(period)

  if (period === 'dia') {
    return Array.from({ length: 24 }, (_, h) => ({
      label: `${String(h).padStart(2, '0')}h`,
      count: tickets.filter(tk => {
        const d = new Date(tk.createdAt)
        return d >= from && d <= to && d.getHours() === h
      }).length,
    }))
  }

  const days = []
  const cur  = new Date(from)
  while (cur <= to) {
    const ds = new Date(cur); ds.setHours(0, 0, 0, 0)
    const de = new Date(cur); de.setHours(23, 59, 59, 999)
    days.push({
      label: `${cur.getDate()}/${cur.getMonth() + 1}`,
      count: tickets.filter(tk => {
        const d = new Date(tk.createdAt)
        return d >= ds && d <= de
      }).length,
    })
    cur.setDate(cur.getDate() + 1)
  }
  return days
}

// ── Constants ─────────────────────────────────────────────────────────────────

const PERIODS = [
  { key: 'dia',           label: 'Dia' },
  { key: 'semana',        label: 'Semana' },
  { key: 'semana_passada',label: 'Sem. passada' },
  { key: 'mes',           label: 'Mês' },
  { key: 'mes_passado',   label: 'Mês passado' },
]

const IN_PROGRESS_STATUSES = ['Em andamento', 'Aguardando terceiros', 'Aguardando solicitante']
const RESOLVED_STATUSES    = ['Resolvido', 'Fechado']

function fmtH(h) { return h > 0 ? `${h}h` : '0h' }

// ── Sub-component: Assignee multi-select ──────────────────────────────────────

function AssigneeFilter({ analysts, selected, onToggle, onClear }) {
  const [open, setOpen] = useState(false)
  const label = selected.length === 0
    ? 'Responsável'
    : `${selected.length} selecionado${selected.length > 1 ? 's' : ''}`

  return (
    <div style={{ position: 'relative' }}>
      <button
        className={`tab ${selected.length > 0 ? 'active' : ''}`}
        onClick={() => setOpen(o => !o)}
        style={{ minWidth: 130 }}
      >
        👤 {label} ▾
      </button>
      {open && (
        <>
          <div style={{ position: 'fixed', inset: 0, zIndex: 199 }} onClick={() => setOpen(false)} />
          <div className="dropdown" style={{ top: '110%', right: 0, minWidth: 210, zIndex: 200 }}>
            <div style={{ padding: '8px 12px', borderBottom: '1px solid var(--border)', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <span style={{ fontSize: 12, fontWeight: 600 }}>Responsáveis</span>
              {selected.length > 0 && (
                <button style={{ background: 'none', border: 'none', color: 'var(--accent)', cursor: 'pointer', fontSize: 11 }} onClick={onClear}>
                  Limpar
                </button>
              )}
            </div>
            {analysts.map(u => (
              <div
                key={u.id}
                className="dropdown-item"
                style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '7px 12px', cursor: 'pointer' }}
                onClick={() => onToggle(u.id)}
              >
                <input type="checkbox" readOnly checked={selected.includes(u.id)} style={{ cursor: 'pointer', flexShrink: 0 }} />
                <Avatar user={u} size={20} />
                <span style={{ fontSize: 13 }}>{u.firstName} {u.lastName}</span>
              </div>
            ))}
            {analysts.length === 0 && (
              <div style={{ padding: '10px 12px', fontSize: 12, color: 'var(--text2)' }}>Sem analistas</div>
            )}
          </div>
        </>
      )}
    </div>
  )
}

// ── Main component ────────────────────────────────────────────────────────────

export default function Dashboard() {
  const { currentUser, lang, tickets, users, categories } = useApp()
  const t = lang === 'pt' ? PT : EN

  const [period, setPeriod]                   = useState('mes')
  const [selectedAssignees, setSelectedAssignees] = useState([])

  const analysts = useMemo(() => users.filter(u => u.role === 'analyst'), [users])

  const { from, to } = useMemo(() => getDateRange(period), [period])

  // Tickets no intervalo de datas (sem filtro de responsável — usado no gráfico de abertura)
  const ticketsInRange = useMemo(() =>
    tickets.filter(tk => {
      const d = new Date(tk.createdAt)
      return d >= from && d <= to
    }),
    [tickets, from, to]
  )

  // Tickets filtrados (data + responsável opcional)
  const filtered = useMemo(() => {
    let tks = ticketsInRange
    if (currentUser.role === 'analyst') {
      tks = tks.filter(tk => tk.assigneeId === currentUser.id)
    } else if (selectedAssignees.length > 0) {
      tks = tks.filter(tk => selectedAssignees.includes(tk.assigneeId))
    }
    return tks
  }, [ticketsInRange, currentUser, selectedAssignees])

  // ── Métricas ──────────────────────────────────────────────────────────────
  const metrics = useMemo(() => {
    const effortAllocated = filtered.reduce((a, tk) => a + (tk.effortEstimated || 0), 0)
    const effortUsed      = filtered.reduce((a, tk) => a + (tk.effortUsed      || 0), 0)
    return {
      total:           filtered.length,
      notStarted:      filtered.filter(tk => tk.status === 'Não iniciado').length,
      triaged:         filtered.filter(tk => tk.status === 'Triado, aguardando atendimento').length,
      inProgress:      filtered.filter(tk => IN_PROGRESS_STATUSES.includes(tk.status)).length,
      resolved:        filtered.filter(tk => RESOLVED_STATUSES.includes(tk.status)).length,
      effortAllocated,
      effortAvailable: Math.max(0, effortAllocated - effortUsed),
    }
  }, [filtered])

  const metricCards = [
    { label: 'Total',              val: metrics.total,                       color: 'var(--accent)' },
    { label: 'Não iniciados',      val: metrics.notStarted,                  color: 'var(--text2)' },
    { label: 'Triado',             val: metrics.triaged,                     color: '#3b82f6' },
    { label: 'Em andamento',       val: metrics.inProgress,                  color: 'var(--success)' },
    { label: 'Resolvido',          val: metrics.resolved,                    color: '#15803d' },
    { label: 'Esforço alocado',    val: fmtH(metrics.effortAllocated),       color: '#7c3aed' },
    { label: 'Esforço disponível', val: fmtH(metrics.effortAvailable),       color: 'var(--warning)' },
  ]

  // ── Gráficos ──────────────────────────────────────────────────────────────
  const statusData = [
    { name: 'Não iniciado', value: metrics.notStarted },
    { name: 'Triado',       value: metrics.triaged },
    { name: 'Em andamento', value: metrics.inProgress },
    { name: 'Resolvido',    value: metrics.resolved },
  ]

  const openingData = useMemo(() => buildOpeningData(ticketsInRange, period), [ticketsInRange, period])

  const catData = useMemo(() =>
    categories
      .map(c => ({
        name:  c.name,
        value: filtered.filter(tk => tk.categoryId === c.id).length,
        color: c.color,
      }))
      .filter(c => c.value > 0),
    [categories, filtered]
  )

  // ── Tabela de responsáveis (analistas) ────────────────────────────────────
  const analystRows = useMemo(() =>
    analysts.map(u => {
      const uTks            = filtered.filter(tk => tk.assigneeId === u.id)
      const effortAllocated = uTks.reduce((a, tk) => a + (tk.effortEstimated || 0), 0)
      const effortUsed      = uTks.reduce((a, tk) => a + (tk.effortUsed      || 0), 0)
      return {
        user:           u,
        total:          uTks.length,
        notStarted:     uTks.filter(tk => tk.status === 'Não iniciado').length,
        triaged:        uTks.filter(tk => tk.status === 'Triado, aguardando atendimento').length,
        inProgress:     uTks.filter(tk => IN_PROGRESS_STATUSES.includes(tk.status)).length,
        resolved:       uTks.filter(tk => RESOLVED_STATUSES.includes(tk.status)).length,
        effortAllocated,
        effortAvailable: Math.max(0, effortAllocated - effortUsed),
      }
    }),
    [filtered, analysts]
  )

  const isAdmin = currentUser.role === 'admin' || currentUser.role === 'manager'

  return (
    <div>
      {/* Header + filtros */}
      <div className="page-header">
        <h2 className="page-title">{t.dashboard}</h2>
        <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap', alignItems: 'center' }}>
          {PERIODS.map(p => (
            <div
              key={p.key}
              className={`tab ${period === p.key ? 'active' : ''}`}
              onClick={() => setPeriod(p.key)}
            >
              {p.label}
            </div>
          ))}
          {isAdmin && (
            <AssigneeFilter
              analysts={analysts}
              selected={selectedAssignees}
              onToggle={id => setSelectedAssignees(prev => prev.includes(id) ? prev.filter(x => x !== id) : [...prev, id])}
              onClear={() => setSelectedAssignees([])}
            />
          )}
        </div>
      </div>

      {/* Números */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(130px, 1fr))', gap: 12, marginBottom: 20 }}>
        {metricCards.map(m => (
          <div key={m.label} className="metric-card">
            <div className="metric-num" style={{ color: m.color }}>{m.val}</div>
            <div className="metric-label">{m.label}</div>
          </div>
        ))}
      </div>

      {/* Gráficos — 3 colunas */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 16, marginBottom: 20 }}>
        {/* Tickets por Status */}
        <div className="card">
          <div style={{ fontWeight: 600, fontSize: 14, marginBottom: 12 }}>Tickets por Status</div>
          <ResponsiveContainer width="100%" height={200}>
            <BarChart data={statusData}>
              <CartesianGrid strokeDasharray="3 3" stroke="var(--border)" />
              <XAxis dataKey="name" tick={{ fontSize: 9, fill: 'var(--text2)' }} />
              <YAxis tick={{ fontSize: 11, fill: 'var(--text2)' }} allowDecimals={false} />
              <Tooltip contentStyle={{ background: 'var(--bg)', border: '1px solid var(--border)', borderRadius: 8, fontSize: 12 }} />
              <Bar dataKey="value" fill="#2383e2" radius={[4, 4, 0, 0]} />
            </BarChart>
          </ResponsiveContainer>
        </div>

        {/* Abertura de Tickets */}
        <div className="card">
          <div style={{ fontWeight: 600, fontSize: 14, marginBottom: 12 }}>Abertura de Tickets</div>
          <ResponsiveContainer width="100%" height={200}>
            <LineChart data={openingData}>
              <CartesianGrid strokeDasharray="3 3" stroke="var(--border)" />
              <XAxis
                dataKey="label"
                tick={{ fontSize: 9, fill: 'var(--text2)' }}
                interval={openingData.length > 14 ? Math.floor(openingData.length / 7) : 0}
              />
              <YAxis tick={{ fontSize: 11, fill: 'var(--text2)' }} allowDecimals={false} />
              <Tooltip contentStyle={{ background: 'var(--bg)', border: '1px solid var(--border)', borderRadius: 8, fontSize: 12 }} />
              <Line type="monotone" dataKey="count" stroke="#2383e2" strokeWidth={2} dot={false} name="Tickets" />
            </LineChart>
          </ResponsiveContainer>
        </div>

        {/* Por Categoria */}
        <div className="card">
          <div style={{ fontWeight: 600, fontSize: 14, marginBottom: 12 }}>Por Categoria</div>
          {catData.length === 0
            ? <div style={{ color: 'var(--text2)', fontSize: 13, textAlign: 'center', paddingTop: 60 }}>Sem dados</div>
            : (
              <ResponsiveContainer width="100%" height={200}>
                <PieChart>
                  <Pie data={catData} dataKey="value" nameKey="name" cx="50%" cy="50%" outerRadius={70} paddingAngle={2}>
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

      {/* Tabela de Responsáveis — admin/manager apenas */}
      {isAdmin && (
        <div className="card" style={{ marginBottom: 20 }}>
          <div style={{ fontWeight: 600, fontSize: 14, marginBottom: 12 }}>Responsáveis</div>
          <div style={{ overflowX: 'auto' }}>
            <table className="table">
              <thead>
                <tr>
                  <th>Responsável</th>
                  <th style={{ textAlign: 'center' }}>Total</th>
                  <th style={{ textAlign: 'center' }}>Não iniciados</th>
                  <th style={{ textAlign: 'center' }}>Triado</th>
                  <th style={{ textAlign: 'center' }}>Em andamento</th>
                  <th style={{ textAlign: 'center' }}>Resolvido</th>
                  <th style={{ textAlign: 'center' }}>Esforço alocado</th>
                  <th style={{ textAlign: 'center' }}>Esforço disponível</th>
                </tr>
              </thead>
              <tbody>
                {analystRows.map(r => (
                  <tr key={r.user.id}>
                    <td>
                      <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                        <Avatar user={r.user} size={26} />
                        <span>{r.user.firstName} {r.user.lastName}</span>
                      </div>
                    </td>
                    <td style={{ textAlign: 'center' }}>{r.total}</td>
                    <td style={{ textAlign: 'center' }}>{r.notStarted}</td>
                    <td style={{ textAlign: 'center' }}>{r.triaged}</td>
                    <td style={{ textAlign: 'center' }}>{r.inProgress}</td>
                    <td style={{ textAlign: 'center' }}>{r.resolved}</td>
                    <td style={{ textAlign: 'center' }}>{fmtH(r.effortAllocated)}</td>
                    <td style={{ textAlign: 'center' }}>{fmtH(r.effortAvailable)}</td>
                  </tr>
                ))}
                {analystRows.length === 0 && (
                  <tr><td colSpan={8} style={{ textAlign: 'center', color: 'var(--text2)', padding: 24 }}>Nenhum analista encontrado</td></tr>
                )}
              </tbody>
            </table>
          </div>
        </div>
      )}

    </div>
  )
}
