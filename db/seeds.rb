puts "🌱 Iniciando seeds..."

# ── Organização ────────────────────────────────────────────────────────────────
org = Organization.find_or_create_by!(slug: "salvabras") do |o|
  o.name           = "Salvabras"
  o.timezone       = "America/Sao_Paulo"
  o.date_format    = "DD/MM/YYYY"
  o.emails_enabled = false
  o.smtp_host      = "smtp.office365.com"
  o.smtp_port      = 587
  o.smtp_user      = "mobile@salvabras.com.br"
end
puts "  ✅ Organização: #{org.name}"

# ── Admin ──────────────────────────────────────────────────────────────────────
# SEED_ADMIN_PASSWORD obrigatória — sem fallback inseguro.
# Execute: SEED_ADMIN_PASSWORD=MinhaS3nh@Forte rails db:seed
admin_password = ENV.fetch("SEED_ADMIN_PASSWORD") do
  abort <<~MSG

    ❌  SEED_ADMIN_PASSWORD não definida.

    Por segurança, não existe senha padrão de fallback.
    Defina a variável antes de executar as seeds:

      SEED_ADMIN_PASSWORD='MinhaS3nh@Forte' rails db:seed

    Em produção (Railway):
      railway variables set SEED_ADMIN_PASSWORD='MinhaS3nh@Forte'
  MSG
end

admin = User.find_or_initialize_by(email: "erick.oliveira@salvabras.com.br", organization: org)
unless admin.persisted?
  admin.assign_attributes(
    first_name:           "Erick",
    last_name:            "Oliveira",
    password:             admin_password,
    role:                 "admin",
    active:               true,
    available_hours:      8,
    max_hours_per_ticket: 4,
    avatar_initials:      "EO",
    avatar_color:         "#2383e2"
  )
  admin.save!
  puts "  ✅ Admin criado: #{admin.email}"
else
  puts "  ℹ️  Admin já existe: #{admin.email}"
end

# ── Analista de demonstração ───────────────────────────────────────────────────
analyst = User.find_or_initialize_by(email: "analista@salvabras.com.br", organization: org)
unless analyst.persisted?
  analyst.assign_attributes(
    first_name:           "Ana",
    last_name:            "Lima",
    password:             admin_password,
    role:                 "analyst",
    active:               true,
    available_hours:      8,
    max_hours_per_ticket: 4,
    avatar_initials:      "AL",
    avatar_color:         "#7c3aed"
  )
  analyst.save!
  puts "  ✅ Analista criado: #{analyst.email}"
else
  puts "  ℹ️  Analista já existe: #{analyst.email}"
end

# ── Usuário solicitante de demonstração ───────────────────────────────────────
requester = User.find_or_initialize_by(email: "solicitante@salvabras.com.br", organization: org)
unless requester.persisted?
  requester.assign_attributes(
    first_name:           "Carlos",
    last_name:            "Mendes",
    password:             admin_password,
    role:                 "user",
    active:               true,
    available_hours:      0,
    max_hours_per_ticket: 0,
    avatar_initials:      "CM",
    avatar_color:         "#059669"
  )
  requester.save!
  puts "  ✅ Solicitante criado: #{requester.email}"
else
  puts "  ℹ️  Solicitante já existe: #{requester.email}"
end

# ── Categorias ─────────────────────────────────────────────────────────────────
categories_data = [
  { name: "Infraestrutura", color: "#2383e2" },
  { name: "Software",       color: "#7c3aed" },
  { name: "Rede",           color: "#059669" },
  { name: "Acesso",         color: "#d97706" },
  { name: "Hardware",       color: "#e53e3e" }
]
categories_data.each do |attrs|
  cat = org.categories.find_or_create_by!(name: attrs[:name]) { |c| c.color = attrs[:color] }
  puts "  ✅ Categoria: #{cat.name}"
end

# Atalhos para uso posterior
infra_cat = org.categories.find_by!(name: "Infraestrutura")
sw_cat    = org.categories.find_by!(name: "Software")
rede_cat  = org.categories.find_by!(name: "Rede")
acesso_cat = org.categories.find_by!(name: "Acesso")

# ── Prioridades ────────────────────────────────────────────────────────────────
priorities_data = [
  { name: "Crítica",  color: "#e53e3e", sla_hours: 4,   sla_days: 0.17, position: 0 },
  { name: "Alta",     color: "#f97316", sla_hours: 8,   sla_days: 0.33, position: 1 },
  { name: "Média",    color: "#eab308", sla_hours: 24,  sla_days: 1.0,  position: 2 },
  { name: "Baixa",    color: "#22c55e", sla_hours: 72,  sla_days: 3.0,  position: 3 },
  { name: "Mínima",   color: "#6b7280", sla_hours: 168, sla_days: 7.0,  position: 4 }
]
priorities_data.each do |attrs|
  pri = org.priorities.find_or_create_by!(name: attrs[:name]) do |p|
    p.color     = attrs[:color]
    p.sla_hours = attrs[:sla_hours]
    p.sla_days  = attrs[:sla_days]
    p.position  = attrs[:position]
  end
  puts "  ✅ Prioridade: #{pri.name}"
end

# Atalhos
critica_pri = org.priorities.find_by!(name: "Crítica")
alta_pri    = org.priorities.find_by!(name: "Alta")
media_pri   = org.priorities.find_by!(name: "Média")
baixa_pri   = org.priorities.find_by!(name: "Baixa")

# ── Filas de atendimento ───────────────────────────────────────────────────────
fila_infra = TicketQueue.find_or_create_by!(name: "Fila Infraestrutura", organization: org) do |q|
  q.category = infra_cat
  q.active   = true
end
puts "  ✅ Fila: #{fila_infra.name}"

fila_sw = TicketQueue.find_or_create_by!(name: "Fila Software", organization: org) do |q|
  q.category = sw_cat
  q.active   = true
end
puts "  ✅ Fila: #{fila_sw.name}"

# Membros das filas
[fila_infra, fila_sw].each do |fila|
  QueueMembership.find_or_create_by!(queue_id: fila.id, user: admin)
end
QueueMembership.find_or_create_by!(queue_id: fila_infra.id, user: analyst)
QueueMembership.find_or_create_by!(queue_id: fila_sw.id,    user: analyst)
puts "  ✅ Membros das filas configurados"

# ── Políticas de SLA ──────────────────────────────────────────────────────────
sla_policies_data = [
  { priority: critica_pri, category: nil,       response_hours: 1, resolve_hours: 4  },
  { priority: alta_pri,    category: nil,       response_hours: 2, resolve_hours: 8  },
  { priority: media_pri,   category: nil,       response_hours: 4, resolve_hours: 24 },
  { priority: baixa_pri,   category: nil,       response_hours: 8, resolve_hours: 72 },
  { priority: nil,         category: infra_cat, response_hours: 2, resolve_hours: 8  }
]
sla_policies_data.each do |attrs|
  policy = SlaPolicy.find_or_create_by!(
    organization: org,
    priority:     attrs[:priority],
    category:     attrs[:category]
  ) do |p|
    p.response_hours = attrs[:response_hours]
    p.resolve_hours  = attrs[:resolve_hours]
    p.active         = true
  end
  label = [
    attrs[:priority]&.name,
    attrs[:category]&.name
  ].compact.join(" + ")
  puts "  ✅ SLA Policy: #{label} → resolve em #{policy.resolve_hours}h"
end

# ── Feriados ───────────────────────────────────────────────────────────────────
holidays_data = [
  { name: "Ano Novo",               date: "2026-01-01", kind: "Nacional"   },
  { name: "Carnaval",               date: "2026-02-17", kind: "Nacional"   },
  { name: "Tiradentes",             date: "2026-04-21", kind: "Nacional"   },
  { name: "Dia do Trabalho",        date: "2026-05-01", kind: "Nacional"   },
  { name: "Corpus Christi",         date: "2026-06-04", kind: "Nacional"   },
  { name: "Independência do Brasil",date: "2026-09-07", kind: "Nacional"   },
  { name: "Nossa Sra. Aparecida",   date: "2026-10-12", kind: "Nacional"   },
  { name: "Finados",                date: "2026-11-02", kind: "Nacional"   },
  { name: "Proclamação da República",date:"2026-11-15", kind: "Nacional"   },
  { name: "Natal",                  date: "2026-12-25", kind: "Nacional"   }
]
holidays_data.each do |attrs|
  h = org.holidays.find_or_create_by!(name: attrs[:name]) do |hol|
    hol.date = attrs[:date]
    hol.kind = attrs[:kind]
  end
  puts "  ✅ Feriado: #{h.name} (#{h.date})"
end

# ── Tickets de demonstração ───────────────────────────────────────────────────
# Definidos ANTES das regras de triagem para que o auto-triage não
# sobrescreva os estados pré-definidos dos tickets de demonstração.

Current.user = admin

demo_tickets = [
  {
    title:       "Servidor de arquivos \\\\fs01 inacessível",
    description: "O servidor de arquivos \\fs01 está inacessível desde as 09:00. " \
                 "Impacta toda a equipe financeira (≈30 usuários). " \
                 "Tentei reiniciar o serviço via RDP sem sucesso.",
    status:      "Em andamento",
    ticket_type: "incidente",
    category:    infra_cat,
    priority:    critica_pri,
    queue:       fila_infra,
    assignee:    analyst,
    deadline:    2.hours.ago   # SLA vencido — demonstra relatório de breach
  },
  {
    title:       "Erro 500 ao gerar relatório de vendas no ERP",
    description: "Ao acessar Módulo Financeiro → Relatórios → Vendas Mensais, " \
                 "o sistema exibe 'Internal Server Error'. " \
                 "Ocorre desde a atualização da versão 3.4.1 (ontem às 18:00). " \
                 "Log de erro anexado.",
    status:      "Não iniciado",
    ticket_type: "incidente",
    category:    sw_cat,
    priority:    alta_pri,
    queue:       fila_sw,
    assignee:    nil,
    deadline:    6.hours.from_now
  },
  {
    title:       "Solicitação de acesso VPN para novo colaborador",
    description: "Novo colaborador Pedro Alves (pedro.alves@salvabras.com.br) iniciará " \
                 "em 01/06/2026 em regime home-office. " \
                 "Necessita de acesso VPN e criação de conta no AD.",
    status:      "Triado, aguardando atendimento",
    ticket_type: "requisição",
    category:    acesso_cat,
    priority:    media_pri,
    queue:       fila_infra,
    assignee:    analyst,
    deadline:    2.days.from_now
  },
  {
    title:       "Notebook com tela piscando intermitentemente",
    description: "O notebook do usuário Carlos Mendes (patrimônio #NB-0042) " \
                 "apresenta tela piscando desde ontem. " \
                 "Problema ocorre tanto com carregador quanto na bateria.",
    status:      "Resolvido",
    ticket_type: "problema",
    category:    org.categories.find_by(name: "Hardware"),
    priority:    baixa_pri,
    queue:       fila_infra,
    assignee:    analyst,
    deadline:    nil
  }
]

demo_tickets.each do |attrs|
  next if org.tickets.exists?(title: attrs[:title])

  ticket = org.tickets.new(
    title:       attrs[:title],
    description: attrs[:description],
    status:      attrs[:status],
    ticket_type: attrs[:ticket_type],
    requester:   requester,
    assignee:    attrs[:assignee],
    category:    attrs[:category],
    priority:    attrs[:priority],
    queue_id:    attrs[:queue]&.id,
    deadline:    attrs[:deadline]
  )
  ticket.save!
  puts "  ✅ Ticket: #{ticket.id} — #{ticket.title[0..60]}"
end

# ── Regras de triagem ─────────────────────────────────────────────────────────
# Criadas APÓS os tickets de demonstração para não afetar o estado pré-definido
triage_rules_data = [
  {
    name:     "Incidente VPN / Acesso Remoto",
    keyword:  "vpn",
    priority: critica_pri,
    category: rede_cat,
    queue:    fila_infra,
    position: 0
  },
  {
    name:     "Erro em Sistema / Software",
    keyword:  "erro",
    priority: alta_pri,
    category: sw_cat,
    queue:    fila_sw,
    position: 1
  },
  {
    name:     "Senha / Acesso Bloqueado",
    keyword:  "senha",
    priority: alta_pri,
    category: acesso_cat,
    queue:    fila_infra,
    position: 2
  },
  {
    name:     "Servidor / Infraestrutura",
    keyword:  "servidor",
    priority: alta_pri,
    category: infra_cat,
    queue:    fila_infra,
    position: 3
  }
]
triage_rules_data.each do |attrs|
  rule = TriageRule.find_or_create_by!(organization: org, keyword: attrs[:keyword]) do |r|
    r.name     = attrs[:name]
    r.priority = attrs[:priority]
    r.category = attrs[:category]
    r.queue    = attrs[:queue]
    r.position = attrs[:position]
    r.active   = true
  end
  puts "  ✅ Regra de triagem: \"#{rule.keyword}\" → #{rule.name}"
end

# ── Tags de demonstração ───────────────────────────────────────────────────────
tags_data = [
  { name: "urgente",   color: "#e53e3e" },
  { name: "cliente",   color: "#3b82f6" },
  { name: "reincidente", color: "#f97316" },
  { name: "pendente-terceiros", color: "#8b5cf6" }
]
tags_data.each do |attrs|
  tag = org.tags.find_or_create_by!(name: attrs[:name]) { |t| t.color = attrs[:color] }
  puts "  ✅ Tag: ##{tag.name}"
end

puts "\n🎉 Seeds concluídos com sucesso!"
puts ""
puts "   Acessos criados:"
puts "   👤 Admin:      erick.oliveira@salvabras.com.br  (role: admin)"
puts "   👤 Analista:   analista@salvabras.com.br        (role: analyst)"
puts "   👤 Solicitante: solicitante@salvabras.com.br    (role: user)"
puts "   🔑 Senha de todos: <conforme SEED_ADMIN_PASSWORD>"
puts ""
puts "   Dados criados:"
puts "   📂 #{org.categories.count} categorias"
puts "   🚦 #{org.priorities.count} prioridades"
puts "   📥 #{TicketQueue.where(organization: org).count} filas de atendimento"
puts "   📋 #{SlaPolicy.where(organization: org).count} políticas de SLA"
puts "   📅 #{org.holidays.count} feriados nacionais (2026)"
puts "   🎫 #{org.tickets.count} tickets de demonstração"
puts "   ⚙️  #{TriageRule.where(organization: org).count} regras de triagem"
puts "   🏷️  #{org.tags.count} tags"
