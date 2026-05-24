import { useState } from 'react'
import { useApp } from '../AppContext.jsx'
import { PT, EN } from '../data.js'
import { api } from '../api.js'
import { mapUser } from '../mapper.js'

export default function LoginScreen() {
  const { setCurrentUser, setScreen, lang, setLang, theme, setTheme } = useApp()
  const t = lang === 'pt' ? PT : EN

  const [step, setStep]       = useState('login')   // 'login' | 'forgot' | 'verify'
  const [em, setEm]           = useState('')
  const [pw, setPw]           = useState('')
  const [err, setErr]         = useState('')
  const [loading, setLoading] = useState(false)
  const [resetEmail, setResetEmail] = useState('')

  // Reset de senha
  const [inputCode, setInputCode] = useState('')
  const [newPw, setNewPw]         = useState('')
  const [confirmPw, setConfirmPw] = useState('')

  async function doLogin() {
    setLoading(true); setErr('')
    try {
      const result = await api.login(em.trim().toLowerCase(), pw)
      const user   = mapUser(result.user)
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
    if (!em.trim()) { setErr('Informe seu e-mail.'); return }
    setLoading(true); setErr('')
    try {
      await api.requestPasswordReset(em.trim().toLowerCase())
      setResetEmail(em.trim().toLowerCase())
      setStep('verify')
    } catch (e) {
      setErr(e.message ?? 'Erro ao enviar o código. Tente novamente.')
    } finally {
      setLoading(false)
    }
  }

  async function doResetPassword() {
    setErr('')
    if (!inputCode.trim()) { setErr('Informe o código recebido por e-mail.'); return }
    if (!newPw || newPw.length < 6) { setErr('A nova senha deve ter pelo menos 6 caracteres.'); return }
    if (newPw !== confirmPw) { setErr('As senhas não conferem.'); return }
    setLoading(true)
    try {
      await api.confirmPasswordReset(resetEmail, inputCode.trim().toUpperCase(), newPw)
      setStep('login')
      setEm(resetEmail)
      setPw('')
      setErr('')
      setInputCode(''); setNewPw(''); setConfirmPw(''); setResetEmail('')
    } catch (e) {
      setErr(e.message ?? 'Código inválido ou expirado. Tente novamente.')
    } finally {
      setLoading(false)
    }
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
              <input className="input" type="email" value={em} onChange={e => setEm(e.target.value)} onKeyDown={e => e.key === 'Enter' && doLogin()} autoComplete="username" />
            </div>
            <div className="form-row">
              <label className="label">{t.password}</label>
              <input className="input" type="password" value={pw} onChange={e => setPw(e.target.value)} onKeyDown={e => e.key === 'Enter' && doLogin()} autoComplete="current-password" />
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
              <input className="input" type="email" value={em} onChange={e => setEm(e.target.value)} onKeyDown={e => e.key === 'Enter' && sendResetCode()} autoComplete="email" />
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
              Se o e-mail <strong>{resetEmail}</strong> estiver cadastrado, você receberá um código em instantes.
            </p>
            <div className="form-row">
              <label className="label">Código recebido por e-mail</label>
              <input
                className="input"
                value={inputCode}
                onChange={e => setInputCode(e.target.value.toUpperCase())}
                placeholder="Ex: A3BX7Z"
                maxLength={6}
                style={{ letterSpacing: 4, fontWeight: 700, fontSize: 18, textTransform: 'uppercase' }}
                autoComplete="one-time-code"
              />
            </div>
            <div className="form-row">
              <label className="label">Nova senha</label>
              <input className="input" type="password" value={newPw} onChange={e => setNewPw(e.target.value)} placeholder="Mínimo 6 caracteres" autoComplete="new-password" />
            </div>
            <div className="form-row">
              <label className="label">Confirmar nova senha</label>
              <input className="input" type="password" value={confirmPw} onChange={e => setConfirmPw(e.target.value)} onKeyDown={e => e.key === 'Enter' && doResetPassword()} autoComplete="new-password" />
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
