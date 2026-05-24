import { useState } from 'react'
import { useApp } from '../AppContext.jsx'
import { PT, EN, PERM } from '../data.js'
import { Avatar, CatChip, PriBadge, ModalOverlay } from '../components.jsx'
import { formatDateTime } from '../data.js'
import { api } from '../api.js'


// ── Users ──────────────────────────────────────────────────────────────────
export function SettingsUsers() {
  const { lang, users, showToast, notifyEmail, systemConfig, createUserAction, updateUserAction, toggleUserAction } = useApp()
  const t = lang === 'pt' ? PT : EN
  const [showForm, setShowForm] = useState(false)
  const [editUser, setEditUser] = useState(null)
  const [form, setForm] = useState({ firstName: '', lastName: '', email: '', role: 'user', active: true, availableHours: 8, maxHoursPerTicket: 4, password: '', newPassword: '' })
  const [savingPw, setSavingPw] = useState(false)

  const ROLE_COLORS = { admin: '#2383e2', analyst: '#7c3aed', user: '#6b7280' }

  function openCreate() { setEditUser(null); setForm({ firstName: '', lastName: '', email: '', role: 'user', active: true, availableHours: 8, maxHoursPerTicket: 4, password: '', newPassword: '' }); setShowForm(true) }
  function openEdit(u) { setEditUser(u); setForm({ ...u, password: '', newPassword: '' }); setShowForm(true) }

  async function save() {
    setSavingPw(true)
    try {
      if (editUser) {
        const data = {
          first_name:           form.firstName,
          last_name:            form.lastName,
          email:                form.email.trim().toLowerCase(),
          role:                 form.role,
          active:               form.active,
          available_hours:      form.availableHours,
          max_hours_per_ticket: form.maxHoursPerTicket,
          ...(form.newPassword ? { password: form.newPassword } : {}),
        }
        await updateUserAction(editUser.id, data)
        showToast('Usuário atualizado com sucesso!')
      } else {
        if (!form.password) { alert('Defina uma senha para o novo usuário.'); return }
        const av = (form.firstName[0] || '') + (form.lastName[0] || '')
        const colors = ['#2383e2', '#7c3aed', '#059669', '#d97706', '#e53e3e', '#0891b2']
        const data = {
          first_name:           form.firstName,
          last_name:            form.lastName,
          email:                form.email.trim().toLowerCase(),
          role:                 form.role,
          active:               form.active,
          available_hours:      form.availableHours,
          max_hours_per_ticket: form.maxHoursPerTicket,
          password:             form.password,
          avatar_initials:      av.toUpperCase(),
          avatar_color:         colors[users.length % colors.length],
        }
        const newUser = await createUserAction(data)
        // E-mail de boas-vindas com credenciais
        notifyEmail(
          form.email,
          'DataTicket — Bem-vindo! Suas credenciais de acesso',
          `<div style="font-family:sans-serif;max-width:520px;margin:0 auto">
            <div style="background:#2383e2;padding:20px;border-radius:8px 8px 0 0">
              <h2 style="color:#fff;margin:0">🎯 DataTicket · Salvabras</h2>
            </div>
            <div style="border:1px solid #e5e7eb;border-top:none;padding:24px;border-radius:0 0 8px 8px">
              <p>Olá <strong>${form.firstName}</strong>, bem-vindo ao DataTicket!</p>
              <p>Seu acesso foi criado. Use as credenciais abaixo para entrar no sistema:</p>
              <table style="width:100%;border-collapse:collapse;margin:16px 0">
                <tr><td style="padding:10px;background:#f9fafb;font-weight:600;width:120px;border-bottom:1px solid #e5e7eb">🔗 Link</td>
                    <td style="padding:10px;border-bottom:1px solid #e5e7eb"><a href="https://dataticket.vercel.app" style="color:#2383e2">dataticket.vercel.app</a></td></tr>
                <tr><td style="padding:10px;background:#f9fafb;font-weight:600">📧 E-mail</td>
                    <td style="padding:10px">${form.email}</td></tr>
              </table>
              <div style="background:#fffbeb;border:1px solid #fcd34d;border-radius:8px;padding:14px;margin:16px 0;font-size:13px;color:#92400e">
                🔑 <strong>Defina sua senha:</strong> Na tela de login, clique em <strong>"Esqueci minha senha"</strong> e siga as instruções para criar sua senha de acesso.
              </div>
              <p style="color:#6b7280;font-size:12px">Por segurança, senhas nunca são enviadas por e-mail. Use o fluxo de redefinição no primeiro acesso.</p>
            </div>
          </div>`
        )
        showToast(`Usuário ${newUser.firstName} criado! E-mail de boas-vindas enviado.`)
      }
      setShowForm(false)
    } catch (e) {
      alert(`Erro ao salvar: ${e.data?.details?.join(', ') || e.message}`)
    } finally {
      setSavingPw(false)
    }
  }

  return (
    <div>
      <div className="page-header">
        <h2 className="page-title">{t.users}</h2>
        <button className="btn btn-primary" onClick={openCreate}>➕ Novo Usuário</button>
      </div>
      <div className="card" style={{ overflowX: 'auto' }}>
        <table className="table">
          <thead><tr><th>Nome</th><th>E-mail</th><th>Perfil</th><th>Status</th><th>Horas/dia</th><th>Ações</th></tr></thead>
          <tbody>
            {users.map(u => (
              <tr key={u.id}>
                <td><div style={{ display: 'flex', alignItems: 'center', gap: 8 }}><Avatar user={u} size={28} />{u.firstName} {u.lastName}</div></td>
                <td style={{ color: 'var(--text2)', fontSize: 12 }}>{u.email}</td>
                <td><span style={{ background: ROLE_COLORS[u.role] + '22', color: ROLE_COLORS[u.role], padding: '2px 8px', borderRadius: 20, fontSize: 11, fontWeight: 600 }}>{u.role}</span></td>
                <td><span style={{ color: u.active ? 'var(--success)' : 'var(--danger)', fontWeight: 500 }}>{u.active ? t.active : t.inactive}</span></td>
                <td>{u.availableHours}h</td>
                <td>
                  <div style={{ display: 'flex', gap: 5, flexWrap: 'wrap' }}>
                    <button className="btn btn-secondary btn-sm" onClick={() => openEdit(u)}>{t.edit}</button>
                    <button className="btn btn-secondary btn-sm" onClick={() => showToast(`Credenciais enviadas para ${u.email}`)}>📧 Cred.</button>
                    <button className="btn btn-secondary btn-sm" onClick={() => showToast(`Reset enviado para ${u.email}`)}>🔑 Reset</button>
                    <button className="btn btn-secondary btn-sm" onClick={() => toggleUserAction(u.id).catch(e => alert(e.message))}>{u.active ? 'Inativar' : 'Ativar'}</button>
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {showForm && (
        <ModalOverlay onClose={() => setShowForm(false)}>
          <div className="modal">
            <h3 style={{ fontWeight: 700, marginBottom: 18 }}>{editUser ? 'Editar' : 'Novo'} Usuário</h3>
            <div className="form-grid">
              <div><label className="label">{t.firstName}</label><input className="input" value={form.firstName} onChange={e => setForm(f => ({ ...f, firstName: e.target.value }))} /></div>
              <div><label className="label">{t.lastName}</label><input className="input" value={form.lastName} onChange={e => setForm(f => ({ ...f, lastName: e.target.value }))} /></div>
              <div><label className="label">{t.email}</label><input className="input" type="email" value={form.email} onChange={e => setForm(f => ({ ...f, email: e.target.value }))} /></div>
              <div>
                <label className="label">{t.role}</label>
                <select className="select" style={{ width: '100%' }} value={form.role} onChange={e => setForm(f => ({ ...f, role: e.target.value }))}>
                  <option value="admin">{t.admin}</option>
                  <option value="analyst">{t.analyst}</option>
                  <option value="user">{t.user}</option>
                </select>
              </div>
              <div><label className="label">Horas disponíveis/dia</label><input className="input" type="number" value={form.availableHours} onChange={e => setForm(f => ({ ...f, availableHours: Number(e.target.value) }))} /></div>
              <div><label className="label">Máx. horas/ticket/dia</label><input className="input" type="number" value={form.maxHoursPerTicket} onChange={e => setForm(f => ({ ...f, maxHoursPerTicket: Number(e.target.value) }))} /></div>
              {!editUser && (
                <div style={{ gridColumn: '1/-1' }}>
                  <label className="label">Senha inicial *</label>
                  <input className="input" type="password" value={form.password} onChange={e => setForm(f => ({ ...f, password: e.target.value }))} placeholder="Mínimo 6 caracteres" />
                </div>
              )}
              {editUser && (
                <div style={{ gridColumn: '1/-1' }}>
                  <label className="label">Nova senha (deixe em branco para não alterar)</label>
                  <input className="input" type="password" value={form.newPassword} onChange={e => setForm(f => ({ ...f, newPassword: e.target.value }))} placeholder="Nova senha..." />
                </div>
              )}
            </div>
            <label style={{ display: 'flex', alignItems: 'center', gap: 8, cursor: 'pointer', fontSize: 13, marginTop: 12 }}>
              <input type="checkbox" checked={form.active} onChange={e => setForm(f => ({ ...f, active: e.target.checked }))} />
              {t.active}
            </label>
            <div style={{ display: 'flex', gap: 10, justifyContent: 'flex-end', marginTop: 18 }}>
              <button className="btn btn-secondary" onClick={() => setShowForm(false)}>{t.cancel}</button>
              <button className="btn btn-primary" onClick={save} disabled={savingPw}>{savingPw ? '⏳ Salvando...' : t.save}</button>
            </div>
          </div>
        </ModalOverlay>
      )}
    </div>
  )
}

// ── Profiles ──────────────────────────────────────────────────────────────
export function SettingsProfiles() {
  const { lang } = useApp()
  const t = lang === 'pt' ? PT : EN
  const roles = [
    { key: 'admin', name: 'Administrador', desc: 'Acesso total ao sistema', color: '#2383e2' },
    { key: 'analyst', name: 'Analista', desc: 'Acesso operacional', color: '#7c3aed' },
    { key: 'user', name: 'Usuário', desc: 'Acesso restrito', color: '#6b7280' },
  ]
  const permLabels = {
    createTicket: 'Criar ticket', editTicket: 'Editar ticket', reassign: 'Reatribuir ticket',
    closeTicket: 'Fechar ticket', reopenTicket: 'Reabrir ticket', comment: 'Comentar',
    internalComment: 'Ver comentário interno', calendar: 'Acessar calendário',
    allTickets: 'Ver todos os tickets', reports: 'Acessar relatórios',
    settings: 'Acessar configurações', triage: 'Triar ticket',
  }
  return (
    <div>
      <h2 className="page-title" style={{ marginBottom: 20 }}>{t.profiles}</h2>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(280px, 1fr))', gap: 16 }}>
        {roles.map(r => (
          <div key={r.key} className="card" style={{ borderTop: `3px solid ${r.color}` }}>
            <div style={{ fontWeight: 700, fontSize: 15, marginBottom: 4 }}>{r.name}</div>
            <div style={{ fontSize: 12, color: 'var(--text2)', marginBottom: 14 }}>{r.desc}</div>
            {Object.keys(PERM.admin).map(k => (
              <div key={k} style={{ display: 'flex', alignItems: 'center', gap: 8, fontSize: 13, marginBottom: 6 }}>
                <span style={{ color: PERM[r.key][k] ? 'var(--success)' : 'var(--border)', fontSize: 15, flexShrink: 0 }}>{PERM[r.key][k] ? '✓' : '✗'}</span>
                <span style={{ color: PERM[r.key][k] ? 'var(--text)' : 'var(--text2)' }}>{permLabels[k] || k}</span>
              </div>
            ))}
          </div>
        ))}
      </div>
    </div>
  )
}

// ── Categories ────────────────────────────────────────────────────────────
export function SettingsCategories() {
  const { lang, categories, createCategoryAction, updateCategoryAction, deleteCategoryAction } = useApp()
  const t = lang === 'pt' ? PT : EN
  const [showForm, setShowForm] = useState(false)
  const [editItem, setEditItem] = useState(null)
  const [form, setForm] = useState({ name: '', color: '#3b82f6', active: true })

  async function save() {
    try {
      if (editItem) await updateCategoryAction(editItem.id, { name: form.name, color: form.color })
      else await createCategoryAction({ name: form.name, color: form.color })
      setShowForm(false)
    } catch (e) { alert(`Erro: ${e.message}`) }
  }

  return (
    <div>
      <div className="page-header">
        <h2 className="page-title">{t.categories}</h2>
        <button className="btn btn-primary" onClick={() => { setEditItem(null); setForm({ name: '', color: '#3b82f6', active: true }); setShowForm(true) }}>➕ Nova Categoria</button>
      </div>
      <div className="card">
        <table className="table">
          <thead><tr><th>Categoria</th><th>Cor</th><th>Status</th><th>Ações</th></tr></thead>
          <tbody>
            {categories.map(c => (
              <tr key={c.id}>
                <td><CatChip category={c} /></td>
                <td><input type="color" value={c.color} readOnly style={{ width: 28, height: 20, border: 'none', background: 'none', cursor: 'default' }} /></td>
                <td><span style={{ color: c.active ? 'var(--success)' : 'var(--danger)', fontWeight: 500 }}>{c.active ? t.active : t.inactive}</span></td>
                <td>
                  <div style={{ display: 'flex', gap: 6 }}>
                    <button className="btn btn-secondary btn-sm" onClick={() => { setEditItem(c); setForm({ ...c }); setShowForm(true) }}>{t.edit}</button>
                    <button className="btn btn-danger btn-sm" onClick={() => { if (window.confirm(`Excluir "${c.name}"?`)) deleteCategoryAction(c.id).catch(e => alert(e.message)) }}>{t.delete}</button>
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {showForm && (
        <ModalOverlay onClose={() => setShowForm(false)}>
          <div className="modal">
            <h3 style={{ fontWeight: 700, marginBottom: 16 }}>{editItem ? 'Editar' : 'Nova'} Categoria</h3>
            <div className="form-row"><label className="label">{t.name}</label><input className="input" value={form.name} onChange={e => setForm(f => ({ ...f, name: e.target.value }))} /></div>
            <div className="form-row">
              <label className="label">{t.color}</label>
              <input type="color" value={form.color} onChange={e => setForm(f => ({ ...f, color: e.target.value }))} style={{ width: '100%', height: 40, border: '1px solid var(--border)', borderRadius: 6, cursor: 'pointer' }} />
            </div>
            <div style={{ display: 'flex', gap: 10, justifyContent: 'flex-end' }}>
              <button className="btn btn-secondary" onClick={() => setShowForm(false)}>{t.cancel}</button>
              <button className="btn btn-primary" onClick={save}>{t.save}</button>
            </div>
          </div>
        </ModalOverlay>
      )}
    </div>
  )
}

// ── Priorities ────────────────────────────────────────────────────────────
export function SettingsPriorities() {
  const { lang, priorities, createPriorityAction, updatePriorityAction, deletePriorityAction } = useApp()
  const t = lang === 'pt' ? PT : EN
  const [showForm, setShowForm] = useState(false)
  const [editItem, setEditItem] = useState(null)
  const [form, setForm] = useState({ name: '', slaHours: 48, slaDays: 2, color: '#3b82f6', active: true })

  async function save() {
    const data = { name: form.name, sla_hours: Number(form.slaHours), sla_days: Number(form.slaDays), color: form.color }
    try {
      if (editItem) await updatePriorityAction(editItem.id, data)
      else await createPriorityAction(data)
      setShowForm(false)
    } catch (e) { alert(`Erro: ${e.message}`) }
  }

  return (
    <div>
      <div className="page-header">
        <h2 className="page-title">{t.priorities}</h2>
        <button className="btn btn-primary" onClick={() => { setEditItem(null); setForm({ name: '', slaHours: 48, slaDays: 2, color: '#3b82f6', active: true }); setShowForm(true) }}>➕ Nova Prioridade</button>
      </div>
      <div className="card">
        <table className="table">
          <thead><tr><th>Prioridade</th><th>SLA (horas)</th><th>SLA (dias)</th><th>Cor</th><th>Ações</th></tr></thead>
          <tbody>
            {priorities.map(p => (
              <tr key={p.id}>
                <td><PriBadge priority={p} /></td>
                <td>{p.slaHours}h</td>
                <td>{p.slaDays}d</td>
                <td><input type="color" value={p.color} readOnly style={{ width: 28, height: 20, border: 'none', background: 'none' }} /></td>
                <td>
                  <div style={{ display: 'flex', gap: 6 }}>
                    <button className="btn btn-secondary btn-sm" onClick={() => { setEditItem(p); setForm({ ...p }); setShowForm(true) }}>{t.edit}</button>
                    <button className="btn btn-danger btn-sm" onClick={() => { if (window.confirm(`Excluir "${p.name}"?`)) deletePriorityAction(p.id).catch(e => alert(e.message)) }}>{t.delete}</button>
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {showForm && (
        <ModalOverlay onClose={() => setShowForm(false)}>
          <div className="modal">
            <h3 style={{ fontWeight: 700, marginBottom: 16 }}>{editItem ? 'Editar' : 'Nova'} Prioridade</h3>
            <div className="form-grid">
              <div><label className="label">{t.name}</label><input className="input" value={form.name} onChange={e => setForm(f => ({ ...f, name: e.target.value }))} /></div>
              <div><label className="label">SLA (horas)</label><input className="input" type="number" value={form.slaHours} onChange={e => setForm(f => ({ ...f, slaHours: e.target.value }))} /></div>
              <div><label className="label">SLA (dias)</label><input className="input" type="number" step="0.1" value={form.slaDays} onChange={e => setForm(f => ({ ...f, slaDays: e.target.value }))} /></div>
              <div><label className="label">{t.color}</label><input type="color" value={form.color} onChange={e => setForm(f => ({ ...f, color: e.target.value }))} style={{ width: '100%', height: 38, border: '1px solid var(--border)', borderRadius: 6 }} /></div>
            </div>
            <div style={{ display: 'flex', gap: 10, justifyContent: 'flex-end', marginTop: 16 }}>
              <button className="btn btn-secondary" onClick={() => setShowForm(false)}>{t.cancel}</button>
              <button className="btn btn-primary" onClick={save}>{t.save}</button>
            </div>
          </div>
        </ModalOverlay>
      )}
    </div>
  )
}

// ── Queues ────────────────────────────────────────────────────────────────
export function SettingsQueues() {
  const { lang, queues, users, categories, createQueueAction, updateQueueAction, deleteQueueAction } = useApp()
  const t = lang === 'pt' ? PT : EN
  const [showForm, setShowForm] = useState(false)
  const [editItem, setEditItem] = useState(null)
  const [form, setForm] = useState({ name: '', categoryId: '', members: [], active: true })

  async function save() {
    const data = { name: form.name, active: form.active }
    try {
      if (editItem) await updateQueueAction(editItem.id, data)
      else await createQueueAction(data)
      setShowForm(false)
    } catch (e) { alert(`Erro: ${e.message}`) }
  }

  return (
    <div>
      <div className="page-header">
        <h2 className="page-title">{t.queues}</h2>
        <button className="btn btn-primary" onClick={() => { setEditItem(null); setForm({ name: '', categoryId: '', members: [], active: true }); setShowForm(true) }}>➕ Nova Fila</button>
      </div>
      <div className="card">
        <table className="table">
          <thead><tr><th>Nome</th><th>Categoria</th><th>Membros</th><th>Ações</th></tr></thead>
          <tbody>
            {queues.map(q => {
              const cat = categories.find(c => c.id === q.categoryId)
              const mems = users.filter(u => q.members.includes(u.id))
              return (
                <tr key={q.id}>
                  <td style={{ fontWeight: 500 }}>{q.name}</td>
                  <td>{cat ? <CatChip category={cat} /> : '—'}</td>
                  <td>
                    <div style={{ display: 'flex', gap: 4 }}>
                      {mems.map(u => <span key={u.id} title={u.firstName + ' ' + u.lastName}><Avatar user={u} size={24} /></span>)}
                    </div>
                  </td>
                  <td>
                    <div style={{ display: 'flex', gap: 6 }}>
                      <button className="btn btn-secondary btn-sm" onClick={() => { setEditItem(q); setForm({ ...q, members: q.members.map(String) }); setShowForm(true) }}>{t.edit}</button>
                      <button className="btn btn-danger btn-sm" onClick={() => { if (window.confirm(`Excluir "${q.name}"?`)) deleteQueueAction(q.id).catch(e => alert(e.message)) }}>{t.delete}</button>
                    </div>
                  </td>
                </tr>
              )
            })}
          </tbody>
        </table>
      </div>

      {showForm && (
        <ModalOverlay onClose={() => setShowForm(false)}>
          <div className="modal">
            <h3 style={{ fontWeight: 700, marginBottom: 16 }}>{editItem ? 'Editar' : 'Nova'} Fila</h3>
            <div className="form-row"><label className="label">{t.name}</label><input className="input" value={form.name} onChange={e => setForm(f => ({ ...f, name: e.target.value }))} /></div>
            <div className="form-row">
              <label className="label">{t.category}</label>
              <select className="select" style={{ width: '100%' }} value={form.categoryId} onChange={e => setForm(f => ({ ...f, categoryId: e.target.value }))}>
                <option value="">Selecione…</option>
                {categories.map(c => <option key={c.id} value={c.id}>{c.name}</option>)}
              </select>
            </div>
            <div className="form-row">
              <label className="label">Membros (analistas)</label>
              <div style={{ border: '1px solid var(--border)', borderRadius: 6, padding: 10, maxHeight: 160, overflowY: 'auto' }}>
                {users.filter(u => u.role !== 'user').map(u => (
                  <label key={u.id} style={{ display: 'flex', alignItems: 'center', gap: 8, fontSize: 13, cursor: 'pointer', padding: '4px 0' }}>
                    <input type="checkbox"
                      checked={form.members.includes(String(u.id)) || form.members.includes(u.id)}
                      onChange={e => {
                        const sid = String(u.id)
                        setForm(f => ({ ...f, members: e.target.checked ? [...f.members, sid] : f.members.filter(x => x !== sid) }))
                      }} />
                    <Avatar user={u} size={22} />
                    {u.firstName} {u.lastName}
                  </label>
                ))}
              </div>
            </div>
            <div style={{ display: 'flex', gap: 10, justifyContent: 'flex-end' }}>
              <button className="btn btn-secondary" onClick={() => setShowForm(false)}>{t.cancel}</button>
              <button className="btn btn-primary" onClick={save}>{t.save}</button>
            </div>
          </div>
        </ModalOverlay>
      )}
    </div>
  )
}

// ── Holidays ──────────────────────────────────────────────────────────────
export function SettingsHolidays() {
  const { lang, holidays, createHolidayAction, updateHolidayAction, deleteHolidayAction } = useApp()
  const t = lang === 'pt' ? PT : EN
  const [showForm, setShowForm] = useState(false)
  const [editItem, setEditItem] = useState(null)
  const [form, setForm] = useState({ name: '', date: '', kind: 'Nacional' })

  async function save() {
    const data = { name: form.name, date: form.date, kind: form.kind || form.type || 'Nacional' }
    try {
      if (editItem) await updateHolidayAction(editItem.id, data)
      else await createHolidayAction(data)
      setShowForm(false)
    } catch (e) { alert(`Erro: ${e.message}`) }
  }

  return (
    <div>
      <div className="page-header">
        <h2 className="page-title">{t.holidays}</h2>
        <button className="btn btn-primary" onClick={() => { setEditItem(null); setForm({ name: '', date: '', type: 'Nacional' }); setShowForm(true) }}>➕ Novo Feriado</button>
      </div>
      <div className="card">
        <table className="table">
          <thead><tr><th>Nome</th><th>Data</th><th>Tipo</th><th>Ações</th></tr></thead>
          <tbody>
            {holidays.map(h => (
              <tr key={h.id}>
                <td>{h.name}</td>
                <td style={{ fontSize: 13 }}>{h.date}</td>
                <td><span className="badge" style={{ background: 'var(--bg2)', color: 'var(--text2)' }}>{h.type}</span></td>
                <td>
                  <div style={{ display: 'flex', gap: 6 }}>
                    <button className="btn btn-secondary btn-sm" onClick={() => { setEditItem(h); setForm({ ...h }); setShowForm(true) }}>{t.edit}</button>
                    <button className="btn btn-danger btn-sm" onClick={() => { if (window.confirm(`Excluir "${h.name}"?`)) deleteHolidayAction(h.id).catch(e => alert(e.message)) }}>{t.delete}</button>
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {showForm && (
        <ModalOverlay onClose={() => setShowForm(false)}>
          <div className="modal">
            <h3 style={{ fontWeight: 700, marginBottom: 16 }}>{editItem ? 'Editar' : 'Novo'} Feriado</h3>
            <div className="form-row"><label className="label">Nome</label><input className="input" value={form.name} onChange={e => setForm(f => ({ ...f, name: e.target.value }))} /></div>
            <div className="form-row"><label className="label">Data</label><input className="input" type="date" value={form.date} onChange={e => setForm(f => ({ ...f, date: e.target.value }))} /></div>
            <div className="form-row">
              <label className="label">Tipo</label>
              <select className="select" style={{ width: '100%' }} value={form.type} onChange={e => setForm(f => ({ ...f, type: e.target.value }))}>
                <option>Nacional</option><option>Regional</option><option>Customizado</option>
              </select>
            </div>
            <div style={{ display: 'flex', gap: 10, justifyContent: 'flex-end' }}>
              <button className="btn btn-secondary" onClick={() => setShowForm(false)}>{t.cancel}</button>
              <button className="btn btn-primary" onClick={save}>{t.save}</button>
            </div>
          </div>
        </ModalOverlay>
      )}
    </div>
  )
}

// ── Audit Log ─────────────────────────────────────────────────────────────
export function SettingsAudit() {
  const { lang, auditLog, users } = useApp()
  const t = lang === 'pt' ? PT : EN

  function exportAuditCSV() {
    const headers = ['Data/Hora','Usuário','Ação','Entidade','Valor']
    const rows = auditLog.map(a => {
      const u = users.find(x => x.id === a.userId)
      return [
        formatDateTime(a.date),
        u ? `${u.firstName} ${u.lastName}` : '—',
        a.action || '',
        a.entity || '',
        `"${(a.newVal || '').replace(/"/g, '""')}"`,
      ].join(';')
    })
    const csv = [headers.join(';'), ...rows].join('\n')
    const blob = new Blob(['﻿' + csv], { type: 'text/csv;charset=utf-8;' })
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a'); a.href = url
    a.download = `dataticket-auditlog-${new Date().toLocaleDateString('pt-BR').replace(/\//g,'-')}.csv`
    document.body.appendChild(a); a.click()
    document.body.removeChild(a); URL.revokeObjectURL(url)
  }

  return (
    <div>
      <div className="page-header">
        <h2 className="page-title">{t.auditLog}</h2>
        <button className="btn btn-secondary btn-sm" onClick={exportAuditCSV}>📥 {t.export} CSV</button>
      </div>
      <div className="card" style={{ overflowX: 'auto' }}>
        <table className="table">
          <thead><tr><th>Data/Hora</th><th>Usuário</th><th>Ação</th><th>Entidade</th><th>Novo Valor</th></tr></thead>
          <tbody>
            {auditLog.length === 0 && (
              <tr><td colSpan={5} style={{ textAlign: 'center', color: 'var(--text2)', padding: 32 }}>{t.noData}</td></tr>
            )}
            {auditLog.map((a, i) => {
              const u = users.find(x => x.id === a.userId)
              return (
                <tr key={i}>
                  <td style={{ fontSize: 12, whiteSpace: 'nowrap' }}>{formatDateTime(a.date)}</td>
                  <td style={{ fontSize: 13 }}>{u ? `${u.firstName} ${u.lastName}` : '—'}</td>
                  <td>{a.action}</td>
                  <td style={{ color: 'var(--accent)', fontWeight: 500 }}>{a.entity}</td>
                  <td style={{ color: 'var(--text2)', maxWidth: 200, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{a.newVal}</td>
                </tr>
              )
            })}
          </tbody>
        </table>
      </div>
    </div>
  )
}

// ── System Config ──────────────────────────────────────────────────────────
export function SettingsSystem() {
  const { lang, systemConfig, setSystemConfig, downloadBackup, showToast } = useApp()
  const t = lang === 'pt' ? PT : EN
  const [form, setForm] = useState({ ...systemConfig })
  const lastBackup = localStorage.getItem('dt_last_backup')

  return (
    <div style={{ maxWidth: 580 }}>
      <h2 className="page-title" style={{ marginBottom: 22 }}>{t.systemConfig}</h2>
      <div className="card">
        <div className="form-row"><label className="label">{t.companyName}</label><input className="input" value={form.companyName} onChange={e => setForm(f => ({ ...f, companyName: e.target.value }))} /></div>
        <div className="form-row">
          <label className="label">{t.timezone}</label>
          <select className="select" style={{ width: '100%' }} value={form.timezone} onChange={e => setForm(f => ({ ...f, timezone: e.target.value }))}>
            <option>America/Sao_Paulo</option>
            <option>America/New_York</option>
            <option>Europe/London</option>
            <option>UTC</option>
          </select>
        </div>
        <div className="form-row">
          <label className="label">{t.dateFormat}</label>
          <select className="select" style={{ width: '100%' }} value={form.dateFormat} onChange={e => setForm(f => ({ ...f, dateFormat: e.target.value }))}>
            <option value="DD/MM/AAAA">DD/MM/AAAA</option>
            <option value="MM/DD/AAAA">MM/DD/AAAA</option>
          </select>
        </div>
        <div style={{ marginBottom: 20 }}>
          <label style={{ display: 'flex', alignItems: 'center', gap: 8, cursor: 'pointer', fontSize: 13 }}>
            <input type="checkbox" checked={form.enableEmails} onChange={e => setForm(f => ({ ...f, enableEmails: e.target.checked }))} />
            {t.enableEmails}
          </label>
        </div>
        <button className="btn btn-primary" onClick={async () => {
          try {
            const payload = {
              name:           form.companyName,
              emails_enabled: form.enableEmails,
              timezone:       form.timezone,
              date_format:    form.dateFormat,
            }
            const updated = await api.updateOrganization(payload)
            setSystemConfig({ ...form })
            showToast('Configurações salvas!')
          } catch (e) {
            showToast(`Erro ao salvar: ${e.message}`)
          }
        }}>
          💾 {t.save}
        </button>
      </div>

      {/* Backup */}
      <div className="card" style={{ marginTop: 16 }}>
        <div style={{ fontWeight: 600, fontSize: 14, marginBottom: 4 }}>💾 Backup de dados</div>
        <div style={{ fontSize: 13, color: 'var(--text2)', marginBottom: 14, lineHeight: 1.6 }}>
          Um backup automático é gerado todo dia às <strong>23:00 (Brasília)</strong> e baixado como arquivo JSON nesta máquina.
          {lastBackup && (
            <span style={{ marginLeft: 6 }}>Último backup automático: <strong>{lastBackup}</strong>.</span>
          )}
        </div>
        <button className="btn btn-secondary" onClick={() => { downloadBackup(); showToast('Backup baixado com sucesso!') }}>
          📥 Baixar backup agora
        </button>
      </div>
    </div>
  )
}

// ── My Profile ────────────────────────────────────────────────────────────
export function MyProfile() {
  const { currentUser, updateUserAction, lang, showToast } = useApp()
  const t = lang === 'pt' ? PT : EN
  const [form, setForm] = useState({ ...currentUser })
  const [changePw, setChangePw] = useState(false)
  const [pwFields, setPwFields] = useState({ current: '', next: '', confirm: '' })
  const [pwLoading, setPwLoading] = useState(false)

  async function save() {
    try {
      await updateUserAction(currentUser.id, { first_name: form.firstName, last_name: form.lastName, email: form.email })
      showToast('Perfil atualizado com sucesso!')
    } catch (e) { showToast(`Erro: ${e.message}`) }
  }

  async function doChangePw() {
    if (!pwFields.current || !pwFields.next) { showToast('Preencha todos os campos.'); return }
    if (pwFields.next !== pwFields.confirm) { showToast('Nova senha e confirmação não conferem.'); return }
    if (pwFields.next.length < 6) { showToast('A nova senha deve ter pelo menos 6 caracteres.'); return }
    setPwLoading(true)
    try {
      await updateUserAction(currentUser.id, { password: pwFields.next })
      setPwFields({ current: '', next: '', confirm: '' })
      setChangePw(false)
      showToast('Senha alterada com sucesso!')
    } finally {
      setPwLoading(false)
    }
  }

  return (
    <div style={{ maxWidth: 580 }}>
      <h2 className="page-title" style={{ marginBottom: 22 }}>{t.myProfile}</h2>

      <div className="card" style={{ marginBottom: 14 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 16, marginBottom: 22 }}>
          <Avatar user={currentUser} size={64} />
          <div>
            <div style={{ fontWeight: 700, fontSize: 18 }}>{currentUser.firstName} {currentUser.lastName}</div>
            <div style={{ color: 'var(--text2)', fontSize: 13, marginTop: 2 }}>{currentUser.email}</div>
            <span style={{ background: 'var(--bg2)', color: 'var(--text2)', padding: '2px 8px', borderRadius: 20, fontSize: 11, fontWeight: 600, display: 'inline-block', marginTop: 6 }}>
              {currentUser.role}
            </span>
          </div>
        </div>
        <div className="form-grid">
          <div><label className="label">{t.firstName}</label><input className="input" value={form.firstName} onChange={e => setForm(f => ({ ...f, firstName: e.target.value }))} /></div>
          <div><label className="label">{t.lastName}</label><input className="input" value={form.lastName} onChange={e => setForm(f => ({ ...f, lastName: e.target.value }))} /></div>
          <div style={{ gridColumn: '1/-1' }}><label className="label">{t.email}</label><input className="input" type="email" value={form.email} onChange={e => setForm(f => ({ ...f, email: e.target.value }))} /></div>
        </div>
        <div style={{ marginTop: 12, padding: '10px 14px', background: 'var(--bg2)', borderRadius: 8, fontSize: 13, color: 'var(--text2)' }}>
          ⏱ Horas disponíveis/dia: <strong style={{ color: 'var(--text)' }}>{currentUser.availableHours}h</strong>
          {' '}· Máx/ticket: <strong style={{ color: 'var(--text)' }}>{currentUser.maxHoursPerTicket}h</strong>
          <em style={{ marginLeft: 6 }}>(configurado pelo administrador)</em>
        </div>
        <button className="btn btn-primary" style={{ marginTop: 16 }} onClick={save}>💾 {t.save}</button>
      </div>

      <div className="card" style={{ marginBottom: 14 }}>
        <div style={{ fontWeight: 600, marginBottom: 12 }}>{t.changePassword}</div>
        {!changePw ? (
          <button className="btn btn-secondary" onClick={() => setChangePw(true)}>🔑 Alterar senha</button>
        ) : (
          <div>
            <input className="input" type="password" placeholder="Senha atual" value={pwFields.current} onChange={e => setPwFields(f => ({ ...f, current: e.target.value }))} style={{ marginBottom: 8 }} />
            <input className="input" type="password" placeholder="Nova senha (mín. 6 caracteres)" value={pwFields.next} onChange={e => setPwFields(f => ({ ...f, next: e.target.value }))} style={{ marginBottom: 8 }} />
            <input className="input" type="password" placeholder="Confirmar nova senha" value={pwFields.confirm} onChange={e => setPwFields(f => ({ ...f, confirm: e.target.value }))} style={{ marginBottom: 10 }} />
            <div style={{ display: 'flex', gap: 8 }}>
              <button className="btn btn-primary btn-sm" onClick={doChangePw} disabled={pwLoading}>{pwLoading ? '⏳ Salvando...' : 'Confirmar'}</button>
              <button className="btn btn-secondary btn-sm" onClick={() => { setChangePw(false); setPwFields({ current: '', next: '', confirm: '' }) }}>{t.cancel}</button>
            </div>
          </div>
        )}
      </div>

      <div className="card">
        <div style={{ fontWeight: 600, marginBottom: 14 }}>Integrações de Calendário</div>
        {[
          { icon: '📅', name: 'Microsoft 365', desc: 'Sincronizar com Outlook Calendar', action: t.connectM365, key: 'm365' },
          { icon: '🗓️', name: 'Google Calendar', desc: 'Sincronizar com Google Calendar', action: t.connectGoogle, key: 'google' },
        ].map(item => (
          <div key={item.key} style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: 14, border: '1px solid var(--border)', borderRadius: 8, marginBottom: 10 }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
              <span style={{ fontSize: 26 }}>{item.icon}</span>
              <div>
                <div style={{ fontWeight: 500, fontSize: 14 }}>{item.name}</div>
                <div style={{ fontSize: 12, color: 'var(--text2)' }}>{item.desc}</div>
              </div>
            </div>
            <button className="btn btn-secondary btn-sm" onClick={() => showToast(`Abrindo autenticação ${item.name}…`)}>{item.action}</button>
          </div>
        ))}
      </div>
    </div>
  )
}
