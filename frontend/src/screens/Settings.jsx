import { useState, useEffect } from 'react'
import { useApp } from '../AppContext.jsx'
import { PT, EN, PERM } from '../data.js'
import { Avatar, CatChip, PriBadge, ModalOverlay } from '../components.jsx'
import { formatDateTime } from '../data.js'
import { api } from '../api.js'
import { mapAuditLog } from '../mapper.js'


// ── Users ──────────────────────────────────────────────────────────────────
export function SettingsUsers() {
  const { lang, users, showToast, notifyEmail, systemConfig, createUserAction, updateUserAction, toggleUserAction } = useApp()
  const t = lang === 'pt' ? PT : EN
  const [showForm, setShowForm] = useState(false)
  const [editUser, setEditUser] = useState(null)
  const [form, setForm] = useState({ firstName: '', lastName: '', email: '', role: 'user', active: true, availableHours: 8, maxHoursPerTicket: 4, password: '', newPassword: '' })
  const [savingPw, setSavingPw] = useState(false)
  const [resetingId, setResetingId] = useState(null)

  async function sendPasswordReset(u) {
    if (!window.confirm(`Enviar e-mail de redefinição de senha para ${u.firstName} ${u.lastName} (${u.email})?`)) return
    setResetingId(u.id)
    try {
      await api.requestPasswordReset(u.email)
      showToast(`E-mail de redefinição enviado para ${u.email}.`)
    } catch (e) {
      alert(`Erro ao enviar reset: ${e.message}`)
    } finally {
      setResetingId(null)
    }
  }

  // Gera uma nova senha e envia ao usuário um e-mail com o e-mail de acesso + a senha.
  async function sendLoginInfo(u) {
    if (!window.confirm(`Enviar informações de login para ${u.firstName} ${u.lastName} (${u.email})?\n\nUma NOVA senha será gerada e enviada por e-mail (a senha atual deixará de funcionar).`)) return
    setResetingId(u.id)
    try {
      await api.resetPassword(u.id)
      showToast(`Informações de login enviadas para ${u.email}.`)
    } catch (e) {
      alert(`Erro ao enviar login: ${e.message}`)
    } finally {
      setResetingId(null)
    }
  }

  const ROLE_COLORS  = { admin: '#2383e2', manager: '#0891b2', analyst: '#7c3aed', user: '#6b7280' }
  const ROLE_LABELS  = { admin: 'Admin', manager: 'Gestor', analyst: 'Analista', user: 'Usuário' }

  function openCreate() { setEditUser(null); setForm({ firstName: '', lastName: '', email: '', role: 'user', active: true, availableHours: 8, maxHoursPerTicket: 4, password: '', newPassword: '' }); setShowForm(true) }
  function openEdit(u) { setEditUser(u); setForm({ ...u, password: '', newPassword: '' }); setShowForm(true) }

  async function save() {
    setSavingPw(true)
    try {
      if (editUser) {
        if (form.newPassword && form.newPassword.length < 12) {
          alert('A nova senha deve ter pelo menos 12 caracteres (regra de segurança válida para todas as empresas).'); return
        }
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
        if (form.password.length < 12) { alert('A senha inicial deve ter pelo menos 12 caracteres (regra de segurança válida para todas as empresas).'); return }
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
              <h2 style="color:#fff;margin:0">🎯 DataTicket</h2>
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
                <td><span style={{ background: (ROLE_COLORS[u.role] ?? '#6b7280') + '22', color: ROLE_COLORS[u.role] ?? '#6b7280', padding: '2px 8px', borderRadius: 20, fontSize: 11, fontWeight: 600 }}>{ROLE_LABELS[u.role] ?? u.role}</span></td>
                <td><span style={{ color: u.active ? 'var(--success)' : 'var(--danger)', fontWeight: 500 }}>{u.active ? t.active : t.inactive}</span></td>
                <td>{u.availableHours}h</td>
                <td>
                  <div style={{ display: 'flex', gap: 5, flexWrap: 'wrap' }}>
                    <button className="btn btn-secondary btn-sm" onClick={() => openEdit(u)}>{t.edit}</button>
                    <button
                      className="btn btn-secondary btn-sm"
                      disabled={resetingId === u.id}
                      onClick={() => sendPasswordReset(u)}
                      title="Envia e-mail com código de redefinição de senha para o usuário"
                    >
                      {resetingId === u.id ? '⏳' : '🔑'} Reset senha
                    </button>
                    <button
                      className="btn btn-secondary btn-sm"
                      disabled={resetingId === u.id}
                      onClick={() => sendLoginInfo(u)}
                      title="Gera uma nova senha e envia e-mail com login e senha para o usuário"
                    >
                      {resetingId === u.id ? '⏳' : '📧'} Enviar login
                    </button>
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
                  <option value="manager">Gestor</option>
                  <option value="analyst">{t.analyst}</option>
                  <option value="user">{t.user}</option>
                </select>
              </div>
              {/* Horas só fazem sentido para a equipe (admin/gestor/analista) — o perfil Usuário não atende tickets */}
              {form.role !== 'user' && (
                <>
                  <div><label className="label">Horas disponíveis/dia</label><input className="input" type="number" value={form.availableHours} onChange={e => setForm(f => ({ ...f, availableHours: Number(e.target.value) }))} /></div>
                  <div><label className="label">Máx. horas/ticket/dia</label><input className="input" type="number" value={form.maxHoursPerTicket} onChange={e => setForm(f => ({ ...f, maxHoursPerTicket: Number(e.target.value) }))} /></div>
                </>
              )}
              {!editUser && (
                <div style={{ gridColumn: '1/-1' }}>
                  <label className="label">Senha inicial *</label>
                  <input className="input" type="password" value={form.password} onChange={e => setForm(f => ({ ...f, password: e.target.value }))} placeholder="Mínimo 12 caracteres" />
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
    { key: 'admin',   name: 'Administrador', desc: 'Acesso total + configurações de sistema',  color: '#2383e2' },
    { key: 'manager', name: 'Gestor',         desc: 'Visão total, tria e gerencia tickets',    color: '#0891b2' },
    { key: 'analyst', name: 'Analista',        desc: 'Trabalha nos tickets atribuídos a ele',  color: '#7c3aed' },
    { key: 'user',    name: 'Usuário',         desc: 'Abre e acompanha seus próprios tickets', color: '#6b7280' },
  ]
  const permLabels = {
    createTicket:    'Criar ticket',
    editTicket:      'Editar ticket',
    deleteTicket:    'Excluir ticket',
    reassign:        'Reatribuir ticket',
    closeTicket:     'Fechar ticket',
    reopenTicket:    'Reabrir ticket',
    comment:         'Comentar',
    internalComment: 'Ver comentário interno',
    calendar:        'Acessar calendário',
    allTickets:      'Ver todos os tickets',
    reports:         'Acessar relatórios',
    logEffort:       'Registrar esforço (timer)',
    settings:        'Acessar configurações',
    triage:          'Triar ticket',
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
                <span style={{ color: (PERM[r.key] || {})[k] ? 'var(--success)' : 'var(--border)', fontSize: 15, flexShrink: 0 }}>{(PERM[r.key] || {})[k] ? '✓' : '✗'}</span>
                <span style={{ color: (PERM[r.key] || {})[k] ? 'var(--text)' : 'var(--text2)' }}>{permLabels[k] || k}</span>
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
  const [saving, setSaving] = useState(false)

  async function save() {
    const data = {
      name:        form.name,
      active:      form.active,
      category_id: Number(form.categoryId) || null,
    }
    setSaving(true)
    try {
      const newMembers = form.members.map(String)

      if (editItem) {
        await updateQueueAction(editItem.id, data)
        // Diff members: add new ones, remove dropped ones
        const oldMembers = (editItem.members || []).map(String)
        const toAdd    = newMembers.filter(id => !oldMembers.includes(id))
        const toRemove = oldMembers.filter(id => !newMembers.includes(id))
        await Promise.all([
          ...toAdd.map(uid    => api.addMember(editItem.id, uid)),
          ...toRemove.map(uid => api.removeMember(editItem.id, uid)),
        ])
      } else {
        const created = await createQueueAction(data)
        // Add all selected members to the freshly created queue
        await Promise.all(newMembers.map(uid => api.addMember(created.id, uid)))
      }
      setShowForm(false)
    } catch (e) { alert(`Erro: ${e.message}`) }
    finally { setSaving(false) }
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
              <button className="btn btn-secondary" onClick={() => setShowForm(false)} disabled={saving}>{t.cancel}</button>
              <button className="btn btn-primary" onClick={save} disabled={saving}>
                {saving ? '⏳ Salvando...' : t.save}
              </button>
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
// ── Helpers para log de auditoria ─────────────────────────────────────────
const ACTION_ICONS = {
  'Ticket criado':                  { icon: '➕', color: '#16a34a' },
  'Status alterado':                { icon: '🔄', color: '#2383e2' },
  'Ticket triado':                  { icon: '🎯', color: '#7c3aed' },
  'Ticket excluído (lixeira)':      { icon: '🗑️', color: '#dc2626' },
  'Ticket restaurado':              { icon: '↩',  color: '#16a34a' },
  'Ticket excluído permanentemente':{ icon: '💀', color: '#7f1d1d' },
  'Artigo KB criado':               { icon: '📗', color: '#16a34a' },
  'Artigo KB atualizado':           { icon: '📝', color: '#d97706' },
  'Artigo KB excluído':             { icon: '📕', color: '#dc2626' },
}

function formatAuditDetails(changes = {}) {
  if (!changes || Object.keys(changes).length === 0) return '—'
  return Object.entries(changes)
    .filter(([, v]) => v != null && v !== '')
    .map(([k, v]) => {
      const label = {
        titulo: 'Título', categoria: 'Categoria', solicitante: 'Solicitante',
        de: 'De', para: 'Para', responsavel: 'Responsável', fila: 'Fila',
        prioridade: 'Prioridade', publicado: 'Publicado',
        titulo_anterior: 'Título anterior',
      }[k] || k
      return `${label}: ${v}`
    })
    .join(' · ')
}

const AUDIT_TYPE_LABELS = {
  ticket_created:  'Criação de Ticket',
  ticket_changed:  'Mudança de Ticket (status / triagem)',
  ticket_deleted:  'Exclusão de Ticket',
  ticket_restored: 'Restauração de Ticket',
  kb_changed:      'Base de Conhecimento',
}

export function SettingsAudit() {
  const { lang, auditLog, setAuditLog, users, showToast } = useApp()
  const t = lang === 'pt' ? PT : EN
  const [filterAction, setFilterAction] = useState('')
  const [filterEntity, setFilterEntity] = useState('')
  const [page, setPage]   = useState(0)
  const PER = 30

  // ── Configuração: quais tipos de evento registrar (caixas de seleção) ──
  const [auditTypes, setAuditTypes] = useState([])
  const [auditCfg, setAuditCfg]     = useState({})   // { tipo: bool }
  const [savingCfg, setSavingCfg]   = useState(false)

  useEffect(() => {
    let live = true
    // Recarrega os logs ao abrir a tela (a lista do login fica desatualizada
    // conforme novos eventos vão sendo registrados).
    api.auditLogs().then(rows => {
      if (live && Array.isArray(rows)) setAuditLog(rows.map(mapAuditLog))
    }).catch(() => {})
    api.organization().then(o => {
      if (!live) return
      const types = o.audit_types || []
      setAuditTypes(types)
      const cfg = {}
      types.forEach(ty => { cfg[ty] = (o.audit_settings?.[ty] ?? true) !== false })
      setAuditCfg(cfg)
    }).catch(() => {})
    return () => { live = false }
  }, [setAuditLog])

  async function saveAuditCfg() {
    setSavingCfg(true)
    try {
      await api.updateOrganization({ audit_settings: auditCfg })
      showToast('Tipos de auditoria atualizados!')
    } catch (e) {
      showToast(`Erro ao salvar: ${e.message}`)
    } finally {
      setSavingCfg(false)
    }
  }

  const actionOptions = [...new Set(auditLog.map(a => a.action).filter(Boolean))].sort()
  const entityOptions = [...new Set(auditLog.map(a => a.entity).filter(Boolean))].sort()

  const filtered = auditLog
    .filter(a => !filterAction || a.action === filterAction)
    .filter(a => !filterEntity || a.entity === filterEntity)

  const paged      = filtered.slice(page * PER, (page + 1) * PER)
  const totalPages = Math.ceil(filtered.length / PER)

  function exportAuditCSV() {
    const headers = ['Data/Hora', 'Usuário', 'E-mail', 'Ação', 'Entidade', 'ID', 'Detalhes']
    const rows = filtered.map(a => {
      const u = users.find(x => x.id === a.userId)
      const name  = u ? `${u.firstName} ${u.lastName}` : (a.userName || '—')
      const email = u?.email || a.userEmail || ''
      return [
        formatDateTime(a.date),
        name,
        email,
        a.action || '',
        a.entity || '',
        a.entityId || '',
        `"${formatAuditDetails(a.changes).replace(/"/g, '""')}"`,
      ].join(';')
    })
    const csv  = [headers.join(';'), ...rows].join('\n')
    const blob = new Blob(['﻿' + csv], { type: 'text/csv;charset=utf-8;' })
    const url  = URL.createObjectURL(blob)
    const el   = document.createElement('a'); el.href = url
    el.download = `dataticket-auditlog-${new Date().toLocaleDateString('pt-BR').replace(/\//g,'-')}.csv`
    document.body.appendChild(el); el.click()
    document.body.removeChild(el); URL.revokeObjectURL(url)
  }

  return (
    <div>
      <div className="page-header">
        <h2 className="page-title">{t.auditLog}</h2>
        <button className="btn btn-secondary btn-sm" onClick={exportAuditCSV}>📥 {t.export} CSV</button>
      </div>

      {/* Configuração: o que registrar no log */}
      {auditTypes.length > 0 && (
        <div className="card" style={{ marginBottom: 12 }}>
          <div style={{ fontWeight: 600, fontSize: 14, marginBottom: 4 }}>⚙️ O que registrar no log</div>
          <div style={{ fontSize: 12, color: 'var(--text2)', marginBottom: 12 }}>
            Selecione os tipos de evento que devem ser gravados na auditoria desta empresa.
          </div>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(240px, 1fr))', gap: 8, marginBottom: 14 }}>
            {auditTypes.map(ty => (
              <label key={ty} style={{ display: 'flex', alignItems: 'center', gap: 8, cursor: 'pointer', fontSize: 13 }}>
                <input
                  type="checkbox"
                  checked={auditCfg[ty] !== false}
                  onChange={e => setAuditCfg(c => ({ ...c, [ty]: e.target.checked }))}
                />
                {AUDIT_TYPE_LABELS[ty] || ty}
              </label>
            ))}
          </div>
          <button className="btn btn-primary btn-sm" disabled={savingCfg} onClick={saveAuditCfg}>
            💾 {savingCfg ? 'Salvando…' : 'Salvar tipos'}
          </button>
        </div>
      )}

      {/* Filtros */}
      <div className="card" style={{ marginBottom: 12 }}>
        <div style={{ display: 'flex', gap: 10, flexWrap: 'wrap', alignItems: 'center' }}>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 4, minWidth: 180 }}>
            <label style={{ fontSize: 11, color: 'var(--text2)', fontWeight: 500 }}>Filtrar por ação</label>
            <select className="select" style={{ width: '100%' }} value={filterAction}
              onChange={e => { setFilterAction(e.target.value); setPage(0) }}>
              <option value="">Todas as ações</option>
              {actionOptions.map(a => <option key={a} value={a}>{a}</option>)}
            </select>
          </div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 4, minWidth: 160 }}>
            <label style={{ fontSize: 11, color: 'var(--text2)', fontWeight: 500 }}>Filtrar por entidade</label>
            <select className="select" style={{ width: '100%' }} value={filterEntity}
              onChange={e => { setFilterEntity(e.target.value); setPage(0) }}>
              <option value="">Todas as entidades</option>
              {entityOptions.map(e => <option key={e} value={e}>{e}</option>)}
            </select>
          </div>
          {(filterAction || filterEntity) && (
            <button className="btn btn-secondary btn-sm" style={{ alignSelf: 'flex-end' }}
              onClick={() => { setFilterAction(''); setFilterEntity(''); setPage(0) }}>
              ✕ Limpar filtros
            </button>
          )}
          <span style={{ fontSize: 12, color: 'var(--text2)', alignSelf: 'flex-end', marginLeft: 'auto' }}>
            {filtered.length} registro(s)
          </span>
        </div>
      </div>

      <div className="card" style={{ padding: 0, overflow: 'hidden' }}>
        <table className="table">
          <thead>
            <tr>
              <th style={{ width: 140 }}>Data/Hora</th>
              <th>Usuário</th>
              <th>Ação</th>
              <th>Entidade</th>
              <th>Detalhes</th>
            </tr>
          </thead>
          <tbody>
            {paged.length === 0 && (
              <tr><td colSpan={5} style={{ textAlign: 'center', color: 'var(--text2)', padding: 32 }}>{t.noData}</td></tr>
            )}
            {paged.map((a, i) => {
              const u       = users.find(x => x.id === a.userId)
              const name    = u ? `${u.firstName} ${u.lastName}` : (a.userName || '—')
              const email   = u?.email || a.userEmail || null
              const style   = ACTION_ICONS[a.action] ?? { icon: '📋', color: 'var(--text2)' }
              const details = formatAuditDetails(a.changes)
              return (
                <tr key={a.id ?? i}>
                  <td style={{ fontSize: 11, color: 'var(--text2)', whiteSpace: 'nowrap' }}>{formatDateTime(a.date)}</td>
                  <td>
                    <div style={{ fontSize: 13, fontWeight: 500 }}>{name}</div>
                    {email && <div style={{ fontSize: 11, color: 'var(--text2)' }}>{email}</div>}
                  </td>
                  <td>
                    <span style={{
                      display: 'inline-flex', alignItems: 'center', gap: 5,
                      padding: '2px 8px', borderRadius: 12, fontSize: 12, fontWeight: 600,
                      background: style.color + '18', color: style.color,
                    }}>
                      {style.icon} {a.action}
                    </span>
                  </td>
                  <td>
                    <div style={{ fontSize: 12, fontWeight: 600, color: 'var(--accent)' }}>{a.entity}</div>
                    {a.entityId && <div style={{ fontSize: 11, color: 'var(--text2)' }}>#{a.entityId}</div>}
                  </td>
                  <td style={{ fontSize: 12, color: 'var(--text2)', maxWidth: 260, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }} title={details}>
                    {details}
                  </td>
                </tr>
              )
            })}
          </tbody>
        </table>

        {totalPages > 1 && (
          <div style={{ display: 'flex', justifyContent: 'center', alignItems: 'center', gap: 8, padding: '12px 0', borderTop: '1px solid var(--border)' }}>
            <button className="btn btn-secondary btn-sm" disabled={page === 0} onClick={() => setPage(p => p - 1)}>◀</button>
            <span style={{ fontSize: 13, color: 'var(--text2)' }}>{page + 1} / {totalPages}</span>
            <button className="btn btn-secondary btn-sm" disabled={page >= totalPages - 1} onClick={() => setPage(p => p + 1)}>▶</button>
          </div>
        )}
      </div>
    </div>
  )
}

// ── System Config ──────────────────────────────────────────────────────────
export function SettingsSystem() {
  const { lang, currentUser, downloadBackup, showToast } = useApp()
  const t = lang === 'pt' ? PT : EN
  const lastBackup = localStorage.getItem('dt_last_backup')

  // Fuso horário e formato de data são fixos para TODAS as empresas
  // (Brasília / DD/MM/AAAA) — não há mais seleção. "Ativar e-mails" foi
  // removido (a configuração de e-mails fica na tela de E-mails por empresa).
  const isSuper = currentUser.role === 'msp_admin'
  const [name, setName]         = useState('')
  const [maxUsers, setMaxUsers] = useState('')   // '' = ilimitado
  const [userCount, setUserCount] = useState(null)
  const [saving, setSaving]     = useState(false)

  useEffect(() => {
    let live = true
    api.organization().then(o => {
      if (!live) return
      setName(o.name || '')
      setMaxUsers(o.max_users == null ? '' : String(o.max_users))
      setUserCount(o.user_count ?? null)
    }).catch(() => {})
    return () => { live = false }
  }, [])

  async function save() {
    setSaving(true)
    try {
      const payload = { name }
      // Apenas o super admin pode alterar o limite de usuários da empresa.
      if (isSuper) payload.max_users = maxUsers === '' ? null : Number(maxUsers)
      await api.updateOrganization(payload)
      showToast('Configurações salvas!')
    } catch (e) {
      showToast(`Erro ao salvar: ${e.message}`)
    } finally {
      setSaving(false)
    }
  }

  return (
    <div style={{ maxWidth: 580 }}>
      <h2 className="page-title" style={{ marginBottom: 22 }}>{t.systemConfig}</h2>
      <div className="card">
        <div className="form-row">
          <label className="label">{t.companyName}</label>
          <input className="input" value={name} onChange={e => setName(e.target.value)} />
        </div>

        <div className="form-row">
          <label className="label">Limite de usuários da empresa</label>
          <input
            className="input"
            type="number"
            min="0"
            value={maxUsers}
            disabled={!isSuper}
            placeholder="Ilimitado"
            onChange={e => setMaxUsers(e.target.value)}
          />
          <div style={{ fontSize: 12, color: 'var(--text2)', marginTop: 6 }}>
            {userCount != null && (
              <>Usuários atuais: <strong>{userCount}</strong>{maxUsers !== '' && <> de <strong>{maxUsers}</strong></>}. </>
            )}
            {maxUsers === '' ? 'Sem limite definido.' : 'Novos usuários são bloqueados ao atingir o limite.'}
            {!isSuper && <span style={{ display: 'block', marginTop: 2 }}>Somente o Super Admin pode alterar este limite.</span>}
          </div>
        </div>

        <div style={{ fontSize: 12, color: 'var(--text2)', marginBottom: 16, lineHeight: 1.6 }}>
          🕐 Fuso horário: <strong>Brasília (America/Sao_Paulo)</strong> · 📅 Formato de data: <strong>DD/MM/AAAA</strong> — padrão para todas as empresas.
        </div>

        <button className="btn btn-primary" disabled={saving} onClick={save}>
          💾 {saving ? 'Salvando…' : t.save}
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
    if (pwFields.next.length < 12) { showToast('A nova senha deve ter pelo menos 12 caracteres.'); return }
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

// ── Empresas (multi-tenant — visível só para msp_admin) ─────────────────────
export function SettingsCompanies() {
  const { currentUser, availableOrgs, currentOrgId, switchOrg, createOrganizationAction, updateCompanyAction, showToast } = useApp()
  const [creating, setCreating] = useState(false)
  const [form, setForm]         = useState({ name: '', slug: '', ticket_prefix: '' })
  const [busy, setBusy]         = useState(false)
  const [error, setError]       = useState('')
  const [editingId, setEditingId] = useState(null)
  const [editName, setEditName]   = useState('')

  const activeId = String(currentOrgId || currentUser.organizationId || '')

  async function saveName(o) {
    if (!editName.trim()) return
    try {
      await updateCompanyAction(o.id, { name: editName.trim() })
      setEditingId(null)
      showToast('Nome atualizado.')
    } catch (e) { alert(`Erro ao renomear: ${e.message}`) }
  }

  async function toggleActive(o) {
    const inactivating = o.active !== false
    if (inactivating && !confirm(`Inativar "${o.name}"? Os usuários dessa empresa não conseguirão entrar até você reativar. A empresa NÃO é deletada.`)) return
    try {
      await updateCompanyAction(o.id, { active: !inactivating })
      showToast(inactivating ? 'Empresa inativada.' : 'Empresa reativada.')
    } catch (e) { alert(`Erro: ${e.message}`) }
  }
  const inp = { width: '100%', marginBottom: 8, padding: '8px 10px', border: '1px solid var(--border)', borderRadius: 6, fontSize: 13, background: 'var(--bg)', color: 'var(--text)' }

  function onName(name) {
    const slug = name.toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, '')
      .replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '')
    const prefix = name.replace(/[^a-zA-Z]/g, '').toUpperCase().slice(0, 3)
    setForm({ name, slug, ticket_prefix: prefix })
  }

  async function create() {
    if (!form.name.trim() || !form.slug.trim() || form.ticket_prefix.length < 2) {
      setError('Preencha nome, slug e prefixo (mín. 2 letras).'); return
    }
    setBusy(true); setError('')
    try {
      await createOrganizationAction({ name: form.name.trim(), slug: form.slug.trim(), ticket_prefix: form.ticket_prefix.toUpperCase() })
      setForm({ name: '', slug: '', ticket_prefix: '' }); setCreating(false)
      showToast('Empresa criada!')
    } catch (e) { setError(e?.message || 'Erro ao criar empresa.') } finally { setBusy(false) }
  }

  return (
    <div>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 16, flexWrap: 'wrap', gap: 10 }}>
        <h2 style={{ fontWeight: 700, fontSize: 20 }}>🏢 Empresas</h2>
        <button className="btn btn-primary" onClick={() => setCreating(c => !c)}>＋ Nova empresa</button>
      </div>

      {creating && (
        <div className="card" style={{ marginBottom: 16, maxWidth: 460 }}>
          <div style={{ fontWeight: 600, marginBottom: 10 }}>Nova empresa</div>
          <input placeholder="Nome da empresa" value={form.name} onChange={e => onName(e.target.value)} style={inp} />
          <input placeholder="slug (identificador na url)" value={form.slug} onChange={e => setForm(f => ({ ...f, slug: e.target.value }))} style={inp} />
          <input placeholder="Prefixo do ticket (ex: DAT)" maxLength={10} value={form.ticket_prefix} onChange={e => setForm(f => ({ ...f, ticket_prefix: e.target.value.toUpperCase() }))} style={inp} />
          {error && <div style={{ color: 'var(--danger)', fontSize: 12, marginBottom: 8 }}>{error}</div>}
          <div style={{ display: 'flex', gap: 8, justifyContent: 'flex-end' }}>
            <button className="btn btn-secondary" onClick={() => { setCreating(false); setError('') }}>Cancelar</button>
            <button className="btn btn-primary" disabled={busy} onClick={create}>{busy ? '…' : 'Criar empresa'}</button>
          </div>
        </div>
      )}

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(260px, 1fr))', gap: 14 }}>
        {availableOrgs.map(o => {
          const active     = String(o.id) === activeId
          const isInactive = o.active === false
          const editing    = editingId === o.id
          return (
            <div key={o.id} className="card" style={{ borderLeft: `3px solid ${isInactive ? 'var(--danger)' : active ? 'var(--accent)' : 'var(--border)'}`, opacity: isInactive ? 0.7 : 1 }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 6, flexWrap: 'wrap' }}>
                {editing ? (
                  <input value={editName} onChange={e => setEditName(e.target.value)} autoFocus
                    style={{ ...inp, marginBottom: 0, flex: 1, minWidth: 120 }}
                    onKeyDown={e => { if (e.key === 'Enter') saveName(o) }} />
                ) : (
                  <span style={{ fontWeight: 700, fontSize: 15 }}>{o.name}</span>
                )}
                {active     && <span style={{ fontSize: 10, background: 'var(--accent)', color: '#fff', padding: '1px 7px', borderRadius: 10 }}>atual</span>}
                {isInactive && <span style={{ fontSize: 10, background: 'var(--danger)', color: '#fff', padding: '1px 7px', borderRadius: 10 }}>inativa</span>}
              </div>
              <div style={{ fontSize: 12, color: 'var(--text2)', marginBottom: 12 }}>
                Prefixo <strong>{o.ticket_prefix}</strong> · {o.timezone}
              </div>
              <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}>
                {editing ? (
                  <>
                    <button className="btn btn-primary btn-sm" onClick={() => saveName(o)}>Salvar</button>
                    <button className="btn btn-secondary btn-sm" onClick={() => setEditingId(null)}>Cancelar</button>
                  </>
                ) : (
                  <>
                    {!active && !isInactive && (
                      <button className="btn btn-secondary btn-sm" onClick={() => switchOrg(o.id)}>Entrar</button>
                    )}
                    <button className="btn btn-secondary btn-sm" onClick={() => { setEditingId(o.id); setEditName(o.name) }}>✏️ Renomear</button>
                    <button className={isInactive ? 'btn btn-primary btn-sm' : 'btn btn-danger btn-sm'} onClick={() => toggleActive(o)}>
                      {isInactive ? '✓ Reativar' : '⊘ Inativar'}
                    </button>
                  </>
                )}
              </div>
            </div>
          )
        })}
      </div>
    </div>
  )
}

// ── E-mails enviados (toggles por tipo, por empresa — Super Admin) ──────────
const EMAIL_TYPE_LABELS = {
  password_reset:  'Redefinição de senha',
  welcome:         'Boas-vindas / informações de login',
  ticket_created:  'Ticket criado',
  ticket_assigned: 'Ticket atribuído',
  status_changed:  'Mudança de status',
  new_comment:     'Novo comentário',
  escalated:       'Ticket escalado',
  csat:            'Pesquisa de satisfação (CSAT)',
  sla_digest:      'Resumo diário de SLA',
}

export function SettingsEmails() {
  const { showToast, currentUser, availableOrgs, currentOrgId } = useApp()
  const [settings, setSettings] = useState(null)  // { tipo: bool }
  const [types, setTypes]       = useState([])
  const [busy, setBusy]         = useState(false)

  const activeId  = String(currentOrgId || currentUser.organizationId || '')
  const orgName   = availableOrgs.find(o => String(o.id) === activeId)?.name || 'empresa atual'

  useEffect(() => {
    api.organization()
      .then(org => {
        setTypes(org.email_types?.length ? org.email_types : Object.keys(EMAIL_TYPE_LABELS))
        setSettings(org.email_settings || {})
      })
      .catch(() => { setTypes(Object.keys(EMAIL_TYPE_LABELS)); setSettings({}) })
  }, [activeId])

  // Tipos críticos (segurança/acesso) são SEMPRE enviados — não podem ser desligados.
  const CRITICAL = ['password_reset', 'welcome']
  const isOn   = (t) => CRITICAL.includes(t) ? true : settings?.[t] !== false  // default ligado
  const toggle = (t) => { if (CRITICAL.includes(t)) return; setSettings(s => ({ ...s, [t]: !(s?.[t] !== false) })) }

  async function save() {
    setBusy(true)
    try {
      const full = {}
      types.forEach(t => { full[t] = isOn(t) })
      await api.updateOrganization({ email_settings: full })
      showToast('Preferências de e-mail salvas.')
    } catch (e) { alert(`Erro ao salvar: ${e.message}`) } finally { setBusy(false) }
  }

  if (settings === null) return <div style={{ color: 'var(--text2)' }}>Carregando...</div>

  return (
    <div>
      <h2 style={{ fontWeight: 700, fontSize: 20, marginBottom: 4 }}>📧 E-mails enviados</h2>
      <p style={{ fontSize: 13, color: 'var(--text2)', marginBottom: 16 }}>
        Ligue ou desligue cada tipo de e-mail para a empresa <strong>{orgName}</strong>. A configuração é por empresa.
      </p>
      <div className="card" style={{ maxWidth: 560 }}>
        {types.map(t => {
          const locked = CRITICAL.includes(t)
          return (
            <label key={t} style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 12, padding: '10px 0', borderBottom: '1px solid var(--border)', cursor: locked ? 'default' : 'pointer' }}>
              <span style={{ fontSize: 14 }}>
                {EMAIL_TYPE_LABELS[t] || t}
                {locked && <span style={{ fontSize: 11, color: 'var(--text2)', marginLeft: 6 }}>(sempre ativo)</span>}
              </span>
              <input type="checkbox" checked={isOn(t)} disabled={locked} onChange={() => toggle(t)} style={{ width: 18, height: 18, cursor: locked ? 'not-allowed' : 'pointer' }} />
            </label>
          )
        })}
        <div style={{ display: 'flex', justifyContent: 'flex-end', marginTop: 14 }}>
          <button className="btn btn-primary" disabled={busy} onClick={save}>{busy ? '…' : 'Salvar'}</button>
        </div>
      </div>
    </div>
  )
}
