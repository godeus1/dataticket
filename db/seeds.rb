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
admin_password = ENV.fetch("SEED_ADMIN_PASSWORD", "change-me-on-first-login")
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

# ── Categorias ─────────────────────────────────────────────────────────────────
[
  { name: "Infraestrutura", color: "#2383e2" },
  { name: "Software",       color: "#7c3aed" },
  { name: "Rede",           color: "#059669" },
  { name: "Acesso",         color: "#d97706" },
  { name: "Hardware",       color: "#e53e3e" }
].each do |attrs|
  cat = org.categories.find_or_create_by!(name: attrs[:name]) { |c| c.color = attrs[:color] }
  puts "  ✅ Categoria: #{cat.name}"
end

# ── Prioridades ────────────────────────────────────────────────────────────────
[
  { name: "Crítica",  color: "#e53e3e", sla_hours: 4,   sla_days: 0.17, position: 0 },
  { name: "Alta",     color: "#f97316", sla_hours: 8,   sla_days: 0.33, position: 1 },
  { name: "Média",    color: "#eab308", sla_hours: 24,  sla_days: 1.0,  position: 2 },
  { name: "Baixa",    color: "#22c55e", sla_hours: 72,  sla_days: 3.0,  position: 3 },
  { name: "Mínima",   color: "#6b7280", sla_hours: 168, sla_days: 7.0,  position: 4 }
].each do |attrs|
  pri = org.priorities.find_or_create_by!(name: attrs[:name]) do |p|
    p.color     = attrs[:color]
    p.sla_hours = attrs[:sla_hours]
    p.sla_days  = attrs[:sla_days]
    p.position  = attrs[:position]
  end
  puts "  ✅ Prioridade: #{pri.name}"
end

puts "\n🎉 Seeds concluídos!"
puts "   Login: erick.oliveira@salvabras.com.br"
puts "   Senha: #{admin_password}"
