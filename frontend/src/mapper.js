// ── Data mappers — converte respostas da Rails API para o formato camelCase do frontend ──

export function mapUser(u) {
  if (!u) return null
  return {
    id:                u.id,
    email:             u.email,
    firstName:         u.first_name        ?? u.firstName  ?? '',
    lastName:          u.last_name         ?? u.lastName   ?? '',
    role:              u.role              ?? 'user',
    active:            u.active            ?? true,
    avatar:            u.avatar_initials   ?? u.avatar     ?? ((u.first_name?.[0] ?? '') + (u.last_name?.[0] ?? '')).toUpperCase(),
    color:             u.avatar_color      ?? u.color      ?? '#2383e2',
    availableHours:    u.available_hours   ?? u.availableHours    ?? 8,
    maxHoursPerTicket: u.max_hours_per_ticket ?? u.maxHoursPerTicket ?? 4,
    organizationId:    u.organization_id   ?? u.organizationId,
  }
}

export function mapComment(c) {
  if (!c) return null
  return {
    id:     c.id,
    text:   c.body ?? c.text ?? '',
    type:   c.kind ?? c.type ?? 'public',
    userId: c.user?.id ?? c.user_id ?? c.userId ?? null,
    date:   c.created_at ?? c.date ?? new Date().toISOString(),
  }
}

export function mapAttachment(a) {
  if (!a) return null
  return {
    id:   a.id,
    name: a.filename ?? a.name ?? '',
    url:  a.url      ?? null,
    size: a.file_size ?? a.size ?? 0,
    type: a.content_type ?? a.type ?? '',
  }
}

export function mapTicket(t) {
  if (!t) return null
  return {
    id:              t.id,
    title:           t.title       ?? '',
    description:     t.description ?? '',
    status:          t.status      ?? 'Não iniciado',
    ticketType:      t.ticket_type ?? t.ticketType ?? 'incidente',
    requesterId:     t.requester?.id ?? t.requester_id ?? t.requesterId ?? null,
    assigneeId:      t.assignee?.id  ?? t.assignee_id  ?? t.assigneeId  ?? null,
    priorityId:      t.priority_id  ?? t.priorityId  ?? null,
    categoryId:      t.category_id  ?? t.categoryId  ?? null,
    queueId:         t.queue_id     ?? t.queueId     ?? null,
    deadline:        t.deadline     ?? null,
    createdAt:       t.created_at   ?? t.createdAt   ?? new Date().toISOString(),
    updatedAt:       t.updated_at   ?? t.updatedAt   ?? new Date().toISOString(),
    resolvedAt:      t.resolved_at  ?? t.resolvedAt  ?? null,
    effortEstimated: parseFloat(t.effort_estimated ?? t.effortEstimated ?? 0),
    effortUsed:      parseFloat(t.effort_used      ?? t.effortUsed      ?? 0),
    triaged:         t.triaged   ?? false,
    escalated:       t.escalated ?? false,
    slaExpired:      t.sla_expired ?? t.slaExpired ?? false,
    tags:            (t.tags         ?? []).map(tag  => ({ id: tag.id, name: tag.name, color: tag.color })),
    comments:        (t.comments     ?? []).map(mapComment),
    attachments:     (t.attachments  ?? []).map(mapAttachment),
    history:         (t.history      ?? []),
    scheduledDays:   [],
  }
}

export function mapPriority(p) {
  if (!p) return null
  return {
    id:       p.id,
    name:     p.name,
    color:    p.color    ?? '#6b7280',
    slaHours: p.sla_hours ?? p.slaHours ?? 24,
    slaDays:  p.sla_days  ?? p.slaDays  ?? 1,
    position: p.position  ?? 0,
    active:   p.active    ?? true,
  }
}

export function mapCategory(c) {
  if (!c) return null
  return {
    id:     c.id,
    name:   c.name,
    color:  c.color  ?? '#2383e2',
    active: c.active ?? true,
  }
}

export function mapQueue(q) {
  if (!q) return null
  return {
    id:           q.id,
    name:         q.name,
    description:  q.description  ?? '',
    active:       q.active        ?? true,
    categoryName: q.category_name ?? q.categoryName ?? '',
    members:      (q.users ?? []).map(u => u.id),
  }
}

export function mapHoliday(h) {
  if (!h) return null
  return {
    id:        h.id,
    name:      h.name,
    date:      typeof h.date === 'string' ? h.date : new Date(h.date).toISOString().slice(0, 10),
    kind:      h.kind      ?? 'Nacional',
    recurring: h.recurring ?? false,
  }
}

export function mapArticle(a) {
  if (!a) return null
  return {
    id:        a.id,
    title:     a.title    ?? '',
    name:      a.title    ?? '',   // alias usado em alguns lugares
    body:      a.body     ?? '',
    keywords:  a.keywords ?? '',
    published: a.published ?? false,
    active:    a.published ?? false,
    authorId:  a.author?.id ?? a.author_id ?? a.authorId ?? null,
  }
}

export function mapNotification(n) {
  if (!n) return null
  return {
    id:       n.id,
    title:    n.title    ?? '',
    desc:     n.body     ?? n.desc ?? '',
    type:     n.kind     ?? n.type ?? 'info',
    read:     n.read     ?? false,
    date:     n.created_at ?? n.date ?? new Date().toISOString(),
    ticketId: n.ticket_id  ?? n.ticketId ?? null,
  }
}

export function mapAuditLog(l) {
  if (!l) return null
  return {
    id:       l.id,
    action:   l.action,
    entity:   l.entity,
    entityId: l.entity_id ?? l.entityId,
    userId:   l.user_id   ?? l.userId,
    date:     l.created_at ?? l.date ?? new Date().toISOString(),
    changes:  l.changes_data ?? l.changes ?? {},
  }
}

export function mapOrganization(o) {
  if (!o) return null
  return {
    id:                 o.id,
    companyName:        o.name             ?? '',
    emailSender:        o.smtp_user        ?? o.smtpUser        ?? '',
    enableEmails:       o.emails_enabled   ?? o.emailsEnabled   ?? false,
    timezone:           o.timezone         ?? 'America/Sao_Paulo',
    dateFormat:         o.date_format      ?? o.dateFormat      ?? 'DD/MM/YYYY',
    smtpHost:           o.smtp_host        ?? o.smtpHost        ?? '',
    smtpPort:           o.smtp_port        ?? o.smtpPort        ?? 587,
    smtpPassSet:        o.smtp_pass_set    ?? false,
    slug:               o.slug             ?? '',
    attachmentsEnabled: o.attachments_enabled ?? false,
  }
}
