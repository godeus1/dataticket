namespace :swagger do
  desc "Valida se as rotas da API v1 estão documentadas em swagger/v1/swagger.yaml"
  task validate: :environment do
    require "yaml"

    spec_path = Rails.root.join("swagger/v1/swagger.yaml")

    unless spec_path.exist?
      abort "❌  Arquivo não encontrado: #{spec_path}"
    end

    spec             = YAML.load_file(spec_path, permitted_classes: [Symbol])
    documented_paths = spec.fetch("paths", {}).keys

    # ── Normaliza path do OpenAPI → regex para comparação ─────────────────────
    # Ex: "/api/v1/tickets/{id}" → /\A\/api\/v1\/tickets\/[^\/]+\z/
    def documented_pattern(path)
      Regexp.new("\\A" + path.gsub(/\{[^}]+\}/, "[^/]+") + "\\z")
    end

    patterns = documented_paths.map { |p| documented_pattern(p) }

    # ── Coleta rotas da API v1 do Rails router ─────────────────────────────────
    api_routes = Rails.application.routes.routes
      .select { |r| r.path.spec.to_s.start_with?("/api/v1") }
      .map do |r|
        r.path.spec.to_s
         .gsub(/\(\.format\)\z/, "")           # remove (.:format)
         .gsub(/:(\w+)/, "{\1}")               # :id → {id}
      end
      .uniq
      .sort

    # ── Identifica rotas não documentadas ─────────────────────────────────────
    missing = api_routes.reject do |route|
      patterns.any? { |pat| pat.match?(route) }
    end

    # ── Identifica paths documentados que não existem nas rotas ───────────────
    extra = documented_paths.reject do |doc_path|
      api_routes.any? { |r| documented_pattern(doc_path).match?(r) }
    end

    # ── Relatório ──────────────────────────────────────────────────────────────
    puts "\n#{"=" * 60}"
    puts "  Swagger Validation Report"
    puts "=" * 60
    puts "  Arquivo:    #{spec_path.relative_path_from(Rails.root)}"
    puts "  Rotas API:  #{api_routes.size}"
    puts "  Paths doc:  #{documented_paths.size}"
    puts "=" * 60

    if missing.any?
      puts "\n⚠️  Rotas sem documentação (#{missing.size}):"
      missing.each { |r| puts "   - #{r}" }
    else
      puts "\n✅ Todas as #{api_routes.size} rotas da API v1 estão documentadas."
    end

    if extra.any?
      puts "\nℹ️  Paths documentados sem rota Rails correspondente (#{extra.size}):"
      extra.each { |p| puts "   - #{p}" }
    end

    puts "\n"

    if missing.any?
      exit 1
    end
  end

  desc "Lista todos os paths documentados no swagger.yaml"
  task paths: :environment do
    require "yaml"
    spec = YAML.load_file(Rails.root.join("swagger/v1/swagger.yaml"), permitted_classes: [Symbol])
    spec.fetch("paths", {}).each_key { |path| puts path }
  end
end
