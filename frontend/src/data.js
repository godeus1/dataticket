// ── i18n ──────────────────────────────────────────────────────────────────
export const PT = {
  dashboard:'Painel', tickets:'Tickets', calendar:'Calendário', kb:'Base de Conhecimento',
  reports:'Relatórios', settings:'Configurações', profile:'Meu Perfil', logout:'Sair',
  newTicket:'Novo Ticket', login:'Entrar', email:'E-mail', password:'Senha',
  title:'Título', description:'Descrição', category:'Categoria', priority:'Prioridade',
  status:'Status', assignee:'Responsável', deadline:'Prazo', requester:'Solicitante',
  save:'Salvar', cancel:'Cancelar', edit:'Editar', delete:'Excluir', create:'Criar',
  search:'Buscar', filter:'Filtrar', export:'Exportar', name:'Nome', users:'Usuários',
  queues:'Filas', priorities:'Prioridades', categories:'Categorias', holidays:'Feriados',
  profiles:'Perfis', auditLog:'Log de Auditoria', systemConfig:'Config. Sistema',
  open:'Aberto', inProgress:'Em andamento', resolved:'Resolvido', closed:'Fechado',
  triage:'Triado, aguardando atendimento', waiting:'Aguardando terceiros', reopened:'Reaberto', notStarted:'Não iniciado',
  low:'Baixa', medium:'Média', high:'Alta', critical:'Crítica',
  comment:'Comentar', public:'Público', internal:'Interno', send:'Enviar',
  notifications:'Notificações', markAllRead:'Marcar todas como lidas',
  day:'Dia', week:'Semana', month:'Mês', year:'Ano',
  total:'Total', hours:'Horas', effort:'Esforço', available:'Disponível',
  admin:'Administrador', analyst:'Analista', user:'Usuário', manager:'Gestor', msp_admin:'Super Admin',
  welcome:'Bem-vindo ao', forgotPassword:'Esqueci minha senha',
  triageBtn:'Triar Ticket', closeTicket:'Fechar Ticket', reopenTicket:'Reabrir Ticket',
  assignTo:'Atribuir a', history:'Histórico', attachments:'Anexos',
  knowledge:'Conhecimento', articles:'Artigos', keywords:'Palavras-chave',
  active:'Ativo', inactive:'Inativo', sla:'SLA', color:'Cor',
  firstName:'Nome', lastName:'Sobrenome', role:'Perfil',
  connectM365:'Conectar Microsoft 365', connectGoogle:'Conectar Google',
  changePassword:'Alterar Senha', myProfile:'Meu Perfil',
  companyName:'Nome da empresa', timezone:'Fuso horário', dateFormat:'Formato de data',
  emailSender:'E-mail remetente', enableEmails:'Ativar e-mails',
  slaExpired:'SLA Vencido', noData:'Sem dados', loading:'Carregando...',
  effortHours:'Horas de esforço', start:'Iniciar', pause:'Pausar', resume:'Retomar',
  timer:'Cronômetro', sessions:'Sessões', back:'Voltar',
};

export const EN = {
  dashboard:'Dashboard', tickets:'Tickets', calendar:'Calendar', kb:'Knowledge Base',
  reports:'Reports', settings:'Settings', profile:'My Profile', logout:'Logout',
  newTicket:'New Ticket', login:'Sign In', email:'Email', password:'Password',
  title:'Title', description:'Description', category:'Category', priority:'Priority',
  status:'Status', assignee:'Assignee', deadline:'Deadline', requester:'Requester',
  save:'Save', cancel:'Cancel', edit:'Edit', delete:'Delete', create:'Create',
  search:'Search', filter:'Filter', export:'Export', name:'Name', users:'Users',
  queues:'Queues', priorities:'Priorities', categories:'Categories', holidays:'Holidays',
  profiles:'Profiles', auditLog:'Audit Log', systemConfig:'System Config',
  open:'Open', inProgress:'In Progress', resolved:'Resolved', closed:'Closed',
  triage:'In Triage', waiting:'Waiting 3rd Party', reopened:'Reopened', notStarted:'Not Started',
  low:'Low', medium:'Medium', high:'High', critical:'Critical',
  comment:'Comment', public:'Public', internal:'Internal', send:'Send',
  notifications:'Notifications', markAllRead:'Mark all as read',
  day:'Day', week:'Week', month:'Month', year:'Year',
  total:'Total', hours:'Hours', effort:'Effort', available:'Available',
  admin:'Administrator', analyst:'Analyst', user:'User', manager:'Manager', msp_admin:'Super Admin',
  welcome:'Welcome to', forgotPassword:'Forgot password',
  triageBtn:'Triage Ticket', closeTicket:'Close Ticket', reopenTicket:'Reopen Ticket',
  assignTo:'Assign to', history:'History', attachments:'Attachments',
  knowledge:'Knowledge', articles:'Articles', keywords:'Keywords',
  active:'Active', inactive:'Inactive', sla:'SLA', color:'Color',
  firstName:'First Name', lastName:'Last Name', role:'Role',
  connectM365:'Connect Microsoft 365', connectGoogle:'Connect Google',
  changePassword:'Change Password', myProfile:'My Profile',
  companyName:'Company Name', timezone:'Timezone', dateFormat:'Date Format',
  emailSender:'Sender Email', enableEmails:'Enable Emails',
  slaExpired:'SLA Expired', noData:'No data', loading:'Loading...',
  effortHours:'Effort Hours', start:'Start', pause:'Pause', resume:'Resume',
  timer:'Timer', sessions:'Sessions', back:'Back',
};

// ── Permissions ──────────────────────────────────────────────────────────
// msp_admin (super admin) é admin-equivalente em toda empresa.
export const isAdmin = (role) => role === 'admin' || role === 'msp_admin'

export const PERM = {
  // msp_admin: super admin multi-empresa — mesmos poderes do admin + troca de empresa
  msp_admin:{ createTicket:true,  editTicket:true,  deleteTicket:true,  reassign:true,  closeTicket:true,  reopenTicket:true,  comment:true, internalComment:true,  calendar:true,  allTickets:true,  reports:true,  settings:true,  triage:true,  logEffort:true,  trash:true  },
  // admin: tudo + exclusão + configurações de sistema
  admin:    { createTicket:true,  editTicket:true,  deleteTicket:true,  reassign:true,  closeTicket:true,  reopenTicket:true,  comment:true, internalComment:true,  calendar:true,  allTickets:true,  reports:true,  settings:true,  triage:true,  logEffort:true,  trash:true  },
  // manager: visão total, tria, muda status, sem config de admin
  manager:  { createTicket:true,  editTicket:true,  deleteTicket:false, reassign:true,  closeTicket:true,  reopenTicket:true,  comment:true, internalComment:true,  calendar:true,  allTickets:true,  reports:true,  settings:false, triage:true,  logEffort:true,  trash:false },
  // analyst: apenas tickets atribuídos, pode comentar e registrar esforço
  analyst:  { createTicket:true,  editTicket:false, deleteTicket:false, reassign:false, closeTicket:true,  reopenTicket:false, comment:true, internalComment:true,  calendar:true,  allTickets:false, reports:true,  settings:false, triage:false, logEffort:true,  trash:false },
  // user: apenas seus próprios tickets
  user:     { createTicket:true,  editTicket:false, deleteTicket:false, reassign:false, closeTicket:false, reopenTicket:false, comment:true, internalComment:false, calendar:false, allTickets:false, reports:false, settings:false, triage:false, logEffort:false, trash:false },
};

// ── Status ───────────────────────────────────────────────────────────────
export const STATUS_LIST = ['Não iniciado','Triado, aguardando atendimento','Em andamento','Aguardando terceiros','Resolvido','Fechado','Reaberto'];
export const STATUS_ALIAS = { 'Em triagem': 'Triado, aguardando atendimento' }; // migração

export const STATUS_COLORS = {
  'Não iniciado':                    { bg:'#f3f4f6', text:'#6b7280' },
  'Triado, aguardando atendimento':  { bg:'#eff6ff', text:'#3b82f6' },
  'Em triagem':                      { bg:'#eff6ff', text:'#3b82f6' }, // alias legado
  'Em andamento':       { bg:'#ecfdf5', text:'#059669' },
  'Aguardando terceiros':{ bg:'#fffbeb', text:'#d97706' },
  'Resolvido':          { bg:'#f0fdf4', text:'#15803d' },
  'Fechado':            { bg:'#f9fafb', text:'#374151' },
  'Reaberto':           { bg:'#fef2f2', text:'#dc2626' },
};

export const ALLOWED_TRANSITIONS = {
  'Não iniciado':                   ['Triado, aguardando atendimento'],
  'Triado, aguardando atendimento': ['Em andamento'],
  'Em triagem':                     ['Em andamento'], // alias legado
  'Em andamento':        ['Aguardando terceiros','Resolvido'],
  'Aguardando terceiros':['Em andamento','Resolvido'],
  'Resolvido':           ['Fechado'],
  'Fechado':             [],
  'Reaberto':            ['Em andamento', 'Fechado'],
};

// ── Helpers ──────────────────────────────────────────────────────────────
const now = new Date();
const d = (days) => { const x = new Date(now); x.setDate(x.getDate() - days); return x.toISOString(); };
const df = (days) => { const x = new Date(now); x.setDate(x.getDate() + days); return x.toISOString(); };

export function formatDate(iso, fmt = 'DD/MM/AAAA') {
  if (!iso) return '-';
  const dt = new Date(iso);
  if (isNaN(dt)) return '-';
  const dd = String(dt.getDate()).padStart(2,'0');
  const mm = String(dt.getMonth()+1).padStart(2,'0');
  const yyyy = dt.getFullYear();
  const hh = String(dt.getHours()).padStart(2,'0');
  const mi = String(dt.getMinutes()).padStart(2,'0');
  const base = fmt === 'MM/DD/AAAA' ? `${mm}/${dd}/${yyyy}` : `${dd}/${mm}/${yyyy}`;
  return base;
}

export function formatDateTime(iso) {
  if (!iso) return '-';
  const dt = new Date(iso);
  if (isNaN(dt)) return '-';
  return dt.toLocaleString('pt-BR');
}

export function isExpired(deadline) {
  if (!deadline) return false;
  return new Date(deadline) < new Date();
}

// ── SLA / Business-day helpers ────────────────────────────────────────────
// Total hours an analyst can work on tickets per day (system-wide cap)
const DAILY_CAP = 6;

function _midnight(date) {
  const d = new Date(date);
  d.setHours(0, 0, 0, 0);
  return d;
}

function _ds(date) {
  const d = _midnight(date);
  return `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`;
}

// Mon–Fri, skipping registered holidays
export function isBusinessDay(date, holidays = []) {
  const day = new Date(date).getDay();
  if (day === 0 || day === 6) return false;
  const mid = _midnight(date).getTime();
  return !holidays.some(h => _midnight(h.date).getTime() === mid);
}

function _addBusinessDays(from, n, holidays) {
  let d = _midnight(from);
  let added = 0;
  while (added < n) {
    d = new Date(d);
    d.setDate(d.getDate() + 1);
    if (isBusinessDay(d, holidays)) added++;
  }
  return d;
}

function _nextBizDay(from, holidays) {
  let d = _midnight(from);
  while (!isBusinessDay(d, holidays)) {
    d = new Date(d);
    d.setDate(d.getDate() + 1);
  }
  return d;
}

// Earliest business day the ticket should be worked on (never in the past)
function _slaStart(createdAt, slaHours, holidays) {
  const slaDays = Math.ceil(slaHours / 8);
  let target = _addBusinessDays(createdAt, slaDays, holidays);
  const today = _midnight(new Date());
  if (target < today) target = _nextBizDay(today, holidays);
  return target;
}

// Hours already scheduled for an assignee on a given date (from scheduledDays arrays)
function _load(assigneeId, ds, tickets) {
  return tickets
    .filter(tk =>
      tk.assigneeId === assigneeId &&
      !['Fechado', 'Resolvido'].includes(tk.status)
    )
    .reduce((sum, tk) => {
      const e = (tk.scheduledDays || []).find(sd => sd.date === ds);
      return sum + (e ? e.hours : 0);
    }, 0);
}

/**
 * Rebuilds scheduledDays and deadline for every active triaged ticket.
 *
 * Rules:
 *  - Daily cap per analyst = DAILY_CAP (6 h)
 *  - Per-ticket daily limit = user.maxHoursPerTicket
 *  - Higher-priority tickets are scheduled first; lower-priority tickets
 *    fill whatever capacity remains (automatic "bump" effect)
 *  - Tickets with no effortEstimated get a plain SLA deadline, no scheduledDays
 */
export function fullReschedule(allTickets, users, holidays, priorities) {
  const result = [...allTickets];

  // ── Tickets with no effort: just set a plain SLA deadline ────────────────
  for (const tk of allTickets) {
    if (['Fechado', 'Resolvido'].includes(tk.status)) continue;
    if (!tk.triaged || tk.effortEstimated > 0) continue;
    if (!tk.priorityId) continue;
    const pri = priorities.find(p => p.id === tk.priorityId);
    const d = new Date(_slaStart(tk.createdAt, pri?.slaHours || 48, holidays));
    d.setHours(18, 0, 0, 0);
    const idx = result.findIndex(t => t.id === tk.id);
    if (idx >= 0) result[idx] = { ...result[idx], deadline: d.toISOString(), scheduledDays: [] };
  }

  // ── Tickets with effort: build multi-day schedule per assignee ───────────
  const byAssignee = {};
  for (const tk of allTickets) {
    if (
      !tk.assigneeId || !tk.triaged ||
      !tk.effortEstimated || tk.effortEstimated <= 0 ||
      ['Fechado', 'Resolvido'].includes(tk.status)
    ) continue;
    if (!byAssignee[tk.assigneeId]) byAssignee[tk.assigneeId] = [];
    byAssignee[tk.assigneeId].push(tk);
  }

  for (const [aidStr, tkList] of Object.entries(byAssignee)) {
    const assigneeId = Number(aidStr);
    const user = users.find(u => u.id === assigneeId);
    const maxPerTicket = user?.maxHoursPerTicket || 3;

    // Higher priority first, then oldest ticket first (fair tie-breaking)
    const sorted = [...tkList].sort((a, b) => {
      const pa = a.priorityId || 0, pb = b.priorityId || 0;
      if (pb !== pa) return pb - pa;
      return new Date(a.createdAt) - new Date(b.createdAt);
    });

    const loadMap = {};  // dateStr → hours used so far in this scheduling pass

    for (const tk of sorted) {
      const pri = priorities.find(p => p.id === tk.priorityId);
      let current = _slaStart(tk.createdAt, pri?.slaHours || 48, holidays);
      let remaining = tk.effortEstimated;
      const scheduledDays = [];
      let safety = 0;

      while (remaining > 0 && safety < 120) {
        safety++;
        if (!isBusinessDay(current, holidays)) {
          current = new Date(current); current.setDate(current.getDate() + 1);
          continue;
        }
        const ds = _ds(current);
        const used = loadMap[ds] || 0;
        const cap = DAILY_CAP - used;
        if (cap > 0) {
          const h = Math.min(maxPerTicket, cap, remaining);
          scheduledDays.push({ date: ds, hours: h });
          loadMap[ds] = used + h;
          remaining -= h;
        }
        current = new Date(current); current.setDate(current.getDate() + 1);
      }

      const lastDay = scheduledDays[scheduledDays.length - 1];
      const deadline = lastDay
        ? new Date(lastDay.date + 'T18:00:00').toISOString()
        : tk.deadline;

      const idx = result.findIndex(t => t.id === tk.id);
      if (idx >= 0) result[idx] = { ...result[idx], scheduledDays, deadline };
    }
  }

  return result;
}

// Simple SLA deadline (no capacity checks) — used when effort is unknown
export function calcSlaDeadline(createdAt, slaHours, holidays = []) {
  const d = new Date(_slaStart(createdAt, slaHours, holidays));
  d.setHours(18, 0, 0, 0);
  return d.toISOString();
}

// ── Mock data ─────────────────────────────────────────────────────────────
// SHA-256 de '@Salva123'
export const MOCK_USERS = [
  { id:1, firstName:'Erick', lastName:'Oliveira', email:'erick.oliveira@salvabras.com.br', passwordHash:'461fea3401682bc430dc1bffa8a2d7b532d5a45af3d2b4229768eb331f51ae91', role:'admin', active:true, avatar:'EO', availableHours:8, maxHoursPerTicket:4, color:'#2383e2' },
];

export const MOCK_CATEGORIES = [
  { id:1, name:'TI',             color:'#3b82f6', active:true },
  { id:2, name:'RH',             color:'#8b5cf6', active:true },
  { id:3, name:'Financeiro',     color:'#10b981', active:true },
  { id:4, name:'Comercial',      color:'#f59e0b', active:true },
  { id:5, name:'Infraestrutura', color:'#ef4444', active:true },
];

export const MOCK_PRIORITIES = [
  { id:1, name:'Baixa',   slaHours:72, slaDays:3,    color:'#38a169', active:true },
  { id:2, name:'Média',   slaHours:48, slaDays:2,    color:'#3b82f6', active:true },
  { id:3, name:'Alta',    slaHours:24, slaDays:1,    color:'#f59e0b', active:true },
  { id:4, name:'Crítica', slaHours:8,  slaDays:0.33, color:'#e53e3e', active:true },
];

export const MOCK_QUEUES = [
  { id:1, name:'Suporte TI',    categoryId:1, members:[2,3], active:true },
  { id:2, name:'Atendimento RH',categoryId:2, members:[2],   active:true },
  { id:3, name:'Financeiro',    categoryId:3, members:[3],   active:true },
];

export const MOCK_HOLIDAYS = [
  { id:1, name:'Ano Novo',      date:'2025-01-01', type:'Nacional' },
  { id:2, name:'Carnaval',      date:'2025-03-04', type:'Nacional' },
  { id:3, name:'Tiradentes',    date:'2025-04-21', type:'Nacional' },
  { id:4, name:'Dia do Trabalho',date:'2025-05-01',type:'Nacional' },
  { id:5, name:'Independência', date:'2025-09-07', type:'Nacional' },
];

export const MOCK_TICKETS = [];

export const MOCK_ARTICLES = [];

export const MOCK_NOTIFICATIONS = [];

export const INITIAL_AUDIT = [
  { action:'Sistema iniciado', entity:'DataTicket', userId:1, date:new Date().toISOString(), newVal:'v1.0.0' },
];

export const INITIAL_SYSTEM_CONFIG = {
  companyName: 'Salvabras',
  emailSender: 'tecnologia@salvabras.com.br',
  smtpHost: 'smtp.office365.com',
  smtpPort: 587,
  timezone: 'America/Sao_Paulo',
  dateFormat: 'DD/MM/AAAA',
  enableEmails: true,
};
