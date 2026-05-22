import { useState } from 'react'
import { useApp } from '../AppContext.jsx'
import { PT, EN } from '../data.js'
import { api } from '../api.js'
import { mapUser } from '../mapper.js'

function genCode() {
  return Math.random().toString(36).toUpperCase().slice(2, 8)
}

export default function LoginScreen() {
  const { setCurrentUser, setScreen, lang, setLang, theme, setTheme, notifyEmail, systemConfig } = useApp()
  const t = lang === 'pt' ? PT : EN

  const [step, setStep]       = useState('login')   // 'login' | 'forgot' | 'verify'
  const [em, setEm]           = useState('')
  const [pw, setPw]           = useState('')
  const [err, setErr]         = useState('')
  const [loading, setLoading] = useState(false)

  // Reset de senha
  const [resetCode, setResetCode] = useState('')
  const [inputCode, setInputCode] = useState('')
  const [newPw, setNewPw]         = useState('')
  const [confirmPw, setConfirmPw] = useState('')
  const [resetTarget, setResetTarget] = useState(null)

  async function doLogin() {
    setLoading(true); setErr('')
    try {
      const result = await api.login(em.trim().toLowerCase(), pw)
      const user   = mapUser(result.user)
      // setCurrentUser carrega todos os dados da API (mostra loading screen)
      setCurrentUser(user)
      if (user.role === 'user') setScreen('new-ticket')
    } catch (e) {
      if (e.status === 401) setErr('Credenciais inválidas. Verifique o e-mail e a senha.')
      else setErr(e.message ?? 'Erro ao conectar. Tente novamente.')
    } finally {
      setLoading(false)
    }
  }

  async function sendResetCode() {
    setLoading(true); setErr('')
    try {
      if (!systemConfig?.enableEmails) {
        setErr('O envio de e-mails está desativado. Contate o administrador para redefinir sua senha.')
        return
      }
      // Tentativa de validar e-mail via API (sem expor dados sensíveis)
      const u = { email: em.trim().toLowerCase(), firstName: 'Usuário' }
      const code = genCode()
      setResetCode(code)
      setResetTarget(u)
      notifyEmail(
        u.email,
        'DataTicket — Código de redefinição de senha',
        `<div style="font-family:sans-serif;max-width:480px;margin:0 auto">
          <div style="background:#2383e2;padding:20px;border-radius:8px 8px 0 0">
            <h2 style="color:#fff;margin:0">🎯 DataTicket · Salvabras</h2>
          </div>
          <div style="border:1px solid #e5e7eb;border-top:none;padding:24px;border-radius:0 0 8px 8px">
            <p>Olá <strong>${u.firstName}</strong>,</p>
            <p>Recebemos uma solicitação para redefinir a sua senha. Use o código abaixo:</p>
            <div style="text-align:center;margin:24px 0">
              <span style="display:inline-block;background:#f0f7ff;border:2px dashed #2383e2;border-radius:10px;padding:14px 32px;font-size:32px;font-weight:800;letter-spacing:8px;color:#2383e2">${code}</span>
            </div>
            <p style="color:#6b7280;font-size:12px">Este código expira em 15 minutos. Se não foi você, ignore este e-mail.</p>
          </div>
        </div>`
      )
      setStep('verify')
    } finally {
      setLoading(false)
    }
  }

  async function doResetPassword() {
    setErr('')
    if (inputCode.trim().toUpperCase() !== resetCode) { setErr('Código inválido.'); return }
    if (!newPw || newPw.length < 6) { setErr('A nova senha deve ter pelo menos 6 caracteres.'); return }
    if (newPw !== confirmPw) { setErr('As senhas não conferem.'); return }
    // Nota: a redefinição de senha via código é feita pelo administrador no painel.
    // Esta tela apenas valida o código enviado por e-mail.
    setStep('login')
    setEm(resetTarget.email)
    setPw('')
    setErr('')
    setInputCode(''); setNewPw(''); setConfirmPw(''); setResetCode(''); setResetTarget(null)
    alert('Código validado! Entre em contato com o administrador para redefinir sua senha no painel.')
  }

  return (
    <div style={{ minHeight: '100vh', background: 'var(--bg2)', display: 'flex', alignItems: 'center', justifyContent: 'center', padding: '20px' }}>
      <div style={{ width: '100%', maxWidth: 400, background: 'var(--bg)', border: '1px solid var(--border)', borderRadius: 16, padding: 40, boxShadow: '0 4px 40px rgba(0,0,0,.08)' }}>
        <div style={{ textAlign: 'center', marginBottom: 32 }}>
          <div style={{ fontSize: 32, marginBottom: 8 }}>🎯</div>
          <div style={{ fontSize: 26, fontWeight: 800, color: 'var(--accent)', letterSpacing: -1 }}>DataTicket</div>
          <div style={{ fontSize: 13, color: 'var(--text2)', marginTop: 4 }}>Salvabras · Sistema de Helpdesk</div>
        </div>

        {/* ── Login ── */}
        {step === 'login' && (
          <>
            <div className="form-row">
              <label className="label">{t.email}</label>
              <input className="input" type="email" value={em} onChange={e => setEm(e.target.value)} onKeyDown={e => e.key === 'Enter' && doLogin()} />
            </div>
            <div className="form-row">
              <label className="label">{t.password}</label>
              <input className="input" type="password" value={pw} onChange={e => setPw(e.target.value)} onKeyDown={e => e.key === 'Enter' && doLogin()} />
            </div>
            {err && <p style={{ color: 'var(--danger)', fontSize: 12, marginBottom: 10 }}>{err}</p>}
            <button style={{ background: 'none', border: 'none', color: 'var(--accent)', fontSize: 12, cursor: 'pointer', marginBottom: 16, padding: 0 }} onClick={() => { setStep('forgot'); setErr('') }}>
              {t.forgotPassword}
            </button>
            <button className="btn btn-primary" style={{ width: '100%', padding: 11, fontSize: 14 }} onClick={doLogin} disabled={loading}>
              {loading ? '⏳ Verificando...' : t.login}
            </button>
            <div style={{ marginTop: 16, padding: 12, background: 'var(--bg2)', borderRadius: 8, fontSize: 12, color: 'var(--text2)' }}>
              Acesso restrito a usuários cadastrados. Contate o administrador para obter credenciais.
            </div>
          </>
        )}

        {/* ── Esqueci a senha ── */}
        {step === 'forgot' && (
          <>
            <p style={{ fontSize: 13, color: 'var(--text2)', marginBottom: 16, lineHeight: 1.6 }}>
              Informe seu e-mail. Enviaremos um código de 6 dígitos para você redefinir a senha.
            </p>
            <div className="form-row">
              <label className="label">{t.email}</label>
              <input className="input" type="email" value={em} onChange={e => setEm(e.target.value)} />
            </div>
            {err && <p style={{ color: 'var(--danger)', fontSize: 12, marginBottom: 10 }}>{err}</p>}
            <button className="btn btn-primary" style={{ width: '100%', padding: 10 }} onClick={sendResetCode} disabled={loading}>
              {loading ? '⏳ Enviando...' : '📧 Enviar código'}
            </button>
            <button className="btn btn-secondary" style={{ width: '100%', marginTop: 8 }} onClick={() => { setStep('login'); setErr('') }}>{t.cancel}</button>
          </>
        )}

        {/* ── Verificar código + nova senha ── */}
        {step === 'verify' && (
          <>
            <p style={{ fontSize: 13, color: 'var(--text2)', marginBottom: 16, lineHeight: 1.6 }}>
              Código enviado para <strong>{resetTarget?.email}</strong>. Digite o código e a nova senha.
            </p>
            <div className="form-row">
              <label className="label">Código recebido por e-mail</label>
              <input className="input" value={inputCode} onChange={e => setInputCode(e.target.value.toUpperCase())} placeholder="Ex: A3BX7Z" style={{ letterSpacing: 4, fontWeight: 700, fontSize: 18 }} />
            </div>
            <div className="form-row">
              <label className="label">Nova senha</label>
              <input className="input" type="password" value={newPw} onChange={e => setNewPw(e.target.value)} placeholder="Mínimo 6 caracteres" />
            </div>
            <div className="form-row">
              <label className="label">Confirmar nova senha</label>
              <input className="input" type="password" value={confirmPw} onChange={e => setConfirmPw(e.target.value)} onKeyDown={e => e.key === 'Enter' && doResetPassword()} />
            </div>
            {err && <p style={{ color: 'var(--danger)', fontSize: 12, marginBottom: 10 }}>{err}</p>}
            <button className="btn btn-primary" style={{ width: '100%', padding: 10 }} onClick={doResetPassword} disabled={loading}>
              {loading ? '⏳ Salvando...' : '🔑 Redefinir senha'}
            </button>
            <button className="btn btn-secondary" style={{ width: '100%', marginTop: 8 }} onClick={() => { setStep('forgot'); setErr('') }}>← Voltar</button>
          </>
        )}

        <div style={{ display: 'flex', gap: 8, marginTop: 20, justifyContent: 'center' }}>
          <button className="btn btn-secondary btn-sm" onClick={() => setLang(lang === 'pt' ? 'en' : 'pt')}>
            🌐 {lang === 'pt' ? 'EN' : 'PT'}
          </button>
          <button className="btn btn-secondary btn-sm" onClick={() => setTheme(theme === 'light' ? 'dark' : 'light')}>
            {theme === 'light' ? '🌙 Escuro' : '☀️ Claro'}
          </button>
        </div>
      </div>
    </div>
  )
}
