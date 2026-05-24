import { useState, useEffect } from 'react'

const BASE = import.meta.env.VITE_API_URL ?? '/api/v1'

export default function CsatPage() {
  const token = window.location.pathname.split('/csat/')[1]?.split('?')[0]
  const preScore = new URLSearchParams(window.location.search).get('score')

  const [score, setScore] = useState(preScore ? Number(preScore) : null)
  const [comment, setComment] = useState('')
  const [status, setStatus] = useState('idle') // idle | submitting | done | error
  const [errorMsg, setErrorMsg] = useState('')

  useEffect(() => {
    if (preScore && score) handleSubmit(score)
  }, []) // eslint-disable-line react-hooks/exhaustive-deps

  async function handleSubmit(selectedScore) {
    if (status === 'submitting' || status === 'done') return
    setStatus('submitting')
    try {
      const res = await fetch(`${BASE}/csat/${token}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ score: selectedScore ?? score, comment }),
      })
      const data = await res.json()
      if (!res.ok) {
        setErrorMsg(data?.error ?? 'Erro ao enviar avaliação.')
        setStatus('error')
      } else {
        setStatus('done')
      }
    } catch {
      setErrorMsg('Não foi possível conectar ao servidor. Tente novamente.')
      setStatus('error')
    }
  }

  const scoreLabels = ['', 'Muito insatisfeito', 'Insatisfeito', 'Neutro', 'Satisfeito', 'Muito satisfeito']
  const scoreColors = ['', '#dc2626', '#f97316', '#d97706', '#65a30d', '#16a34a']

  return (
    <div style={{ minHeight: '100vh', background: '#f3f4f6', display: 'flex', alignItems: 'center', justifyContent: 'center', padding: '24px 16px', fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif' }}>
      <div style={{ background: '#fff', borderRadius: 12, boxShadow: '0 4px 24px rgba(0,0,0,.08)', maxWidth: 480, width: '100%', overflow: 'hidden' }}>
        {/* Header */}
        <div style={{ background: '#1e40af', padding: '24px 32px' }}>
          <div style={{ color: '#fff', fontSize: 20, fontWeight: 700 }}>DataTicket</div>
          <div style={{ color: '#bfdbfe', fontSize: 13, marginTop: 4 }}>Pesquisa de satisfação</div>
        </div>

        <div style={{ padding: '32px' }}>
          {status === 'done' ? (
            <div style={{ textAlign: 'center', padding: '16px 0' }}>
              <div style={{ fontSize: 48, marginBottom: 16 }}>🎉</div>
              <div style={{ fontSize: 18, fontWeight: 700, color: '#111827', marginBottom: 8 }}>Obrigado pelo feedback!</div>
              <div style={{ fontSize: 14, color: '#6b7280' }}>Sua avaliação foi registrada e nos ajuda a melhorar o atendimento.</div>
            </div>
          ) : status === 'error' ? (
            <div style={{ textAlign: 'center', padding: '16px 0' }}>
              <div style={{ fontSize: 48, marginBottom: 16 }}>⚠️</div>
              <div style={{ fontSize: 16, fontWeight: 600, color: '#dc2626', marginBottom: 8 }}>{errorMsg}</div>
              <button onClick={() => setStatus('idle')} style={{ marginTop: 8, padding: '8px 20px', background: '#1e40af', color: '#fff', border: 'none', borderRadius: 6, cursor: 'pointer', fontSize: 14 }}>
                Tentar novamente
              </button>
            </div>
          ) : (
            <>
              <div style={{ fontSize: 16, fontWeight: 600, color: '#111827', marginBottom: 8 }}>Como foi nosso atendimento?</div>
              <div style={{ fontSize: 14, color: '#6b7280', marginBottom: 24 }}>Selecione uma nota de 1 a 5:</div>

              {/* Score buttons */}
              <div style={{ display: 'flex', gap: 10, justifyContent: 'center', marginBottom: 24 }}>
                {[1, 2, 3, 4, 5].map(n => (
                  <button
                    key={n}
                    onClick={() => setScore(n)}
                    style={{
                      width: 52, height: 52, borderRadius: '50%', border: score === n ? '3px solid #1e40af' : '2px solid #e5e7eb',
                      background: score === n ? scoreColors[n] : '#f9fafb',
                      color: score === n ? '#fff' : '#374151',
                      fontSize: 18, fontWeight: 700, cursor: 'pointer',
                      transition: 'all .15s',
                    }}
                  >
                    {n}
                  </button>
                ))}
              </div>
              {score && (
                <div style={{ textAlign: 'center', fontSize: 13, color: scoreColors[score], fontWeight: 600, marginBottom: 20 }}>
                  {scoreLabels[score]}
                </div>
              )}

              {/* Comment */}
              <textarea
                placeholder="Comentário opcional..."
                value={comment}
                onChange={e => setComment(e.target.value)}
                rows={3}
                style={{ width: '100%', padding: '10px 12px', border: '1px solid #e5e7eb', borderRadius: 8, fontSize: 14, color: '#374151', resize: 'vertical', boxSizing: 'border-box', outline: 'none' }}
              />

              <button
                onClick={() => handleSubmit()}
                disabled={!score || status === 'submitting'}
                style={{
                  marginTop: 16, width: '100%', padding: '12px', background: score ? '#1e40af' : '#93c5fd',
                  color: '#fff', border: 'none', borderRadius: 8, fontSize: 15, fontWeight: 600,
                  cursor: score ? 'pointer' : 'not-allowed', transition: 'background .15s',
                }}
              >
                {status === 'submitting' ? 'Enviando...' : 'Enviar avaliação'}
              </button>
            </>
          )}
        </div>

        <div style={{ padding: '14px 32px', background: '#f9fafb', borderTop: '1px solid #e5e7eb', fontSize: 11, color: '#9ca3af', textAlign: 'center' }}>
          © {new Date().getFullYear()} DataTicket — Mensagem automática
        </div>
      </div>
    </div>
  )
}
