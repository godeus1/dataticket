import { useEffect } from 'react'
import { STATUS_COLORS, formatDate } from './data.js'

export function Avatar({ user, size = 30 }) {
  return (
    <div
      className="avatar"
      style={{
        width: size, height: size,
        background: (user?.color || '#6b7280') + '22',
        color: user?.color || '#6b7280',
        fontSize: Math.max(9, size * 0.35),
      }}
    >
      {user?.avatar || '?'}
    </div>
  )
}

export function Badge({ status }) {
  const c = STATUS_COLORS[status] || { bg: '#f3f4f6', text: '#6b7280' }
  return <span className="badge" style={{ background: c.bg, color: c.text }}>{status}</span>
}

export function PriBadge({ priority }) {
  if (!priority) return <span className="chip" style={{ background: '#f3f4f6', color: '#6b7280' }}>—</span>
  return (
    <span className="chip" style={{ background: priority.color + '22', color: priority.color }}>
      {priority.name}
    </span>
  )
}

export function CatChip({ category }) {
  if (!category) return <span className="chip" style={{ background: '#f3f4f6', color: '#6b7280' }}>—</span>
  return (
    <span className="chip" style={{ background: category.color + '22', color: category.color }}>
      {category.name}
    </span>
  )
}

export function Toast({ msg, onClose }) {
  useEffect(() => {
    const t = setTimeout(onClose, 3000)
    return () => clearTimeout(t)
  }, [onClose])
  return <div className="toast">📧 {msg}</div>
}

export function EmptyState({ icon = '📭', title = 'Sem dados', desc = '' }) {
  return (
    <div className="empty-state">
      <div className="empty-icon">{icon}</div>
      <h3>{title}</h3>
      {desc && <p>{desc}</p>}
    </div>
  )
}

export function ModalOverlay({ onClose, children }) {
  return (
    <div className="modal-overlay" onMouseDown={e => e.target === e.currentTarget && onClose?.()}>
      {children}
    </div>
  )
}

export function SectionHeader({ title, action }) {
  return (
    <div className="page-header">
      <h2 className="page-title">{title}</h2>
      {action}
    </div>
  )
}
