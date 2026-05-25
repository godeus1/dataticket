import { useState, useEffect } from 'react'
import { api } from '../api.js'
import { mapTicket } from '../mapper.js'
import { useApp } from '../AppContext.jsx'
import { formatDateTime } from '../data.js'
import { Badge, EmptyState } from '../components.jsx'

export function SettingsTrash() {
  const { restoreTicketAction, purgeTicketAction, setScreen, setSelectedTicket } = useApp()
  const [items,   setItems]   = useState([])
  const [loading, setLoading] = useState(true)
  const [error,   setError]   = useState(null)

  useEffect(() => {
    api.trash()
      .then(data => setItems((data ?? []).map(mapTicket)))
      .catch(e   => setError(e.message))
      .finally(() => setLoading(false))
  }, [])

  async function restore(id) {
    try {
      await restoreTicketAction(id)
      setItems(prev => prev.filter(t => t.id !== id))
    } catch (e) { alert(`Erro ao restaurar: ${e.message}`) }
  }

  async function purge(id, title) {
    if (!window.confirm(`Excluir permanentemente o ticket "${title}"? Esta ação não pode ser desfeita.`)) return
    try {
      await purgeTicketAction(id)
      setItems(prev => prev.filter(t => t.id !== id))
    } catch (e) { alert(`Erro: ${e.message}`) }
  }

  if (loading) return <div style={{ padding: 32, color: 'var(--text2)' }}>Carregando lixeira…</div>
  if (error)   return <div style={{ padding: 32, color: 'var(--danger)' }}>Erro: {error}</div>

  return (
    <div>
      <div className="page-header">
        <h2 className="page-title">🗑️ Lixeira</h2>
        <span style={{ fontSize: 13, color: 'var(--text2)' }}>Tickets excluídos são mantidos por 30 dias e podem ser restaurados.</span>
      </div>

      {items.length === 0 ? (
        <EmptyState icon="🗑️" title="Lixeira vazia" desc="Nenhum ticket excluído nos últimos 30 dias." />
      ) : (
        <div className="card" style={{ padding: 0, overflow: 'hidden' }}>
          <table className="table">
            <thead>
              <tr>
                <th>Ticket</th>
                <th>Status</th>
                <th>Excluído por</th>
                <th>Excluído em</th>
                <th>Expira em</th>
                <th>Ações</th>
              </tr>
            </thead>
            <tbody>
              {items.map(t => (
                <tr key={t.id}>
                  <td>
                    <div style={{ fontWeight: 600, color: 'var(--accent)', fontSize: 12 }}>{t.id}</div>
                    <div style={{ fontSize: 13, marginTop: 2 }}>{t.title}</div>
                  </td>
                  <td><Badge status={t.status} /></td>
                  <td style={{ fontSize: 13 }}>{t.deletedByName || '—'}</td>
                  <td style={{ fontSize: 12, color: 'var(--text2)' }}>{t.deletedAt ? formatDateTime(t.deletedAt) : '—'}</td>
                  <td>
                    <span style={{
                      fontWeight: 600,
                      fontSize: 12,
                      color: t.daysUntilPurge <= 3 ? 'var(--danger)' : t.daysUntilPurge <= 7 ? '#f59e0b' : 'var(--text2)',
                    }}>
                      {t.daysUntilPurge != null ? `${t.daysUntilPurge} dia(s)` : '—'}
                    </span>
                  </td>
                  <td>
                    <div style={{ display: 'flex', gap: 6 }}>
                      <button
                        className="btn btn-secondary btn-sm"
                        onClick={() => restore(t.id)}
                      >
                        ↩ Restaurar
                      </button>
                      <button
                        className="btn btn-danger btn-sm"
                        onClick={() => purge(t.id, t.title)}
                      >
                        🗑 Excluir
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  )
}
