# DataTicket — Sistema de Helpdesk

Monorepo com frontend React e backend Rails API.

```
dataticket/
├── app/          ← Rails 8 API (deploy: Railway)
├── config/
├── db/
├── frontend/     ← React 18 + Vite (deploy: Vercel)
│   ├── src/
│   └── package.json
├── Gemfile
└── railway.toml
```

## Rodando localmente

**Backend (Rails API) — porta 3001:**
```bash
bundle install
rails db:migrate
rails s -p 3001
```

**Frontend (React) — porta 3000:**
```bash
cd frontend
npm install
npm run dev
```

Acesse: http://localhost:3000  
O Vite faz proxy de `/api` → `localhost:3001` automaticamente.

## Deploy

| Serviço | Plataforma | Config |
|---------|-----------|--------|
| Backend | Railway | raiz do repo, `railway.toml` |
| Frontend | Vercel | pasta `frontend/`, env `VITE_API_URL` |

## Variáveis de ambiente

**Vercel (frontend):**
```
VITE_API_URL=https://web-production-03f8b.up.railway.app/api/v1
```

**Railway (backend):**
```
RAILS_MASTER_KEY=...
DATABASE_URL=...
ALLOWED_ORIGINS=https://seu-projeto.vercel.app
```

---
Desenvolvido por **DataTry Tecnologia e Negócios**
