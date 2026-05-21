class DataMigrationService
  Result = Struct.new(:success?, :counts, :errors, keyword_init: true)

  STATUS_MAP = {
    "Em triagem"     => "Triado, aguardando atendimento",
    "In progress"    => "Em andamento",
    "In Progress"    => "Em andamento",
    "Waiting"        => "Aguardando terceiros",
    "Resolved"       => "Resolvido",
    "Closed"         => "Fechado",
    "Reopened"       => "Reaberto"
  }.freeze

  def initialize(json_backup_path)
    @path   = json_backup_path
    @errors = []
    @counts = Hash.new(0)

    # Lookup maps: legacy_id → AR object
    @user_map     = {}
    @category_map = {}
    @priority_map = {}
    @queue_map    = {}
  end

  def call
    data = JSON.parse(File.read(@path))
    org  = Organization.first_or_create!(name: "Salvabras", slug: "salvabras")

    ActiveRecord::Base.transaction do
      migrate_users(data["users"],         org)
      migrate_categories(data["categories"], org)
      migrate_priorities(data["priorities"], org)
      migrate_queues(data["queues"],         org)
      migrate_tickets(data["tickets"],       org)
      migrate_articles(data["articles"],     org)

      raise ActiveRecord::Rollback if @errors.any?
    end

    if @errors.any?
      Result.new(success?: false, counts: @counts, errors: @errors)
    else
      Rails.logger.info("[DataMigration] Concluída: #{@counts.map { |k, v| "#{k}=#{v}" }.join(', ')}")
      Result.new(success?: true, counts: @counts, errors: [])
    end
  rescue JSON::ParserError => e
    Result.new(success?: false, counts: @counts, errors: ["JSON inválido: #{e.message}"])
  rescue StandardError => e
    Result.new(success?: false, counts: @counts, errors: ["Erro inesperado: #{e.message}"])
  end

  private

  # ── Users ──────────────────────────────────────────────────────────────────

  def migrate_users(users, org)
    return unless users.is_a?(Array)

    users.each do |u|
      legacy_id = u["id"].to_s
      email     = u["email"].to_s.downcase.strip
      next if email.blank?

      user = org.users.find_or_initialize_by(email: email)
      user.assign_attributes(
        first_name:  u["firstName"] || u["first_name"] || email.split("@").first,
        last_name:   u["lastName"]  || u["last_name"]  || "Migrado",
        role:        map_role(u["role"]),
        active:      u.fetch("active", true),
        legacy_id:   legacy_id
      )
      user.password = SecureRandom.hex(16) if user.new_record?

      if user.save
        @user_map[legacy_id] = user
        @counts[:users] += 1
      else
        @errors << "Usuário #{email}: #{user.errors.full_messages.join(', ')}"
      end
    end
  end

  # ── Categories ─────────────────────────────────────────────────────────────

  def migrate_categories(categories, org)
    return unless categories.is_a?(Array)

    categories.each do |c|
      legacy_id = c["id"].to_s
      cat = org.categories.find_or_create_by!(name: c["name"].to_s.strip) do |r|
        r.color  = c["color"] || "#2383e2"
        r.active = c.fetch("active", true)
      end
      @category_map[legacy_id] = cat
      @counts[:categories] += 1
    rescue ActiveRecord::RecordInvalid => e
      @errors << "Categoria #{c['name']}: #{e.message}"
    end
  end

  # ── Priorities ─────────────────────────────────────────────────────────────

  def migrate_priorities(priorities, org)
    return unless priorities.is_a?(Array)

    priorities.each do |p|
      legacy_id = p["id"].to_s
      pri = org.priorities.find_or_create_by!(name: p["name"].to_s.strip) do |r|
        r.color     = p["color"]    || "#6b7280"
        r.sla_hours = p["slaHours"] || p["sla_hours"] || 48
        r.position  = p["position"] || 0
        r.active    = p.fetch("active", true)
      end
      @priority_map[legacy_id] = pri
      @counts[:priorities] += 1
    rescue ActiveRecord::RecordInvalid => e
      @errors << "Prioridade #{p['name']}: #{e.message}"
    end
  end

  # ── Queues ─────────────────────────────────────────────────────────────────

  def migrate_queues(queues, org)
    return unless queues.is_a?(Array)

    queues.each do |q|
      legacy_id = q["id"].to_s
      queue = org.queues.find_or_create_by!(name: q["name"].to_s.strip) do |r|
        r.active = q.fetch("active", true)
      end
      @queue_map[legacy_id] = queue
      @counts[:queues] += 1
    rescue ActiveRecord::RecordInvalid => e
      @errors << "Fila #{q['name']}: #{e.message}"
    end
  end

  # ── Tickets ────────────────────────────────────────────────────────────────

  def migrate_tickets(tickets, org)
    return unless tickets.is_a?(Array)

    tickets.each do |tk|
      requester = resolve_user(tk["requesterId"] || tk["requester_id"], org)
      assignee  = resolve_user(tk["assigneeId"]  || tk["assignee_id"],  org)

      ticket = org.tickets.new(
        title:            tk["title"].to_s.truncate(255),
        description:      tk["description"],
        status:           normalize_status(tk["status"]),
        requester:        requester,
        assignee:         assignee,
        category:         @category_map[tk["categoryId"].to_s],
        priority:         @priority_map[tk["priorityId"].to_s],
        queue:            @queue_map[tk["queueId"].to_s],
        effort_estimated: tk["effortEstimated"] || tk["effort_estimated"] || 0,
        deadline:         parse_time(tk["deadline"]),
        resolved_at:      parse_time(tk["resolvedAt"] || tk["resolved_at"]),
        triaged:          tk.fetch("triaged", false),
        created_at:       parse_time(tk["createdAt"] || tk["created_at"]) || Time.current
      )

      if ticket.save
        migrate_comments(tk["comments"], ticket)
        @counts[:tickets] += 1
      else
        @errors << "Ticket '#{tk['title']}': #{ticket.errors.full_messages.join(', ')}"
      end
    end
  end

  def migrate_comments(comments, ticket)
    return unless comments.is_a?(Array)

    comments.each do |c|
      author = resolve_user(c["userId"] || c["user_id"], ticket.organization)
      next unless author

      ticket.comments.create!(
        body:       c["text"] || c["body"],
        kind:       c["type"] || c["kind"] || "public",
        user:       author,
        created_at: parse_time(c["date"] || c["created_at"]) || Time.current
      )
      @counts[:comments] += 1
    rescue ActiveRecord::RecordInvalid => e
      @errors << "Comentário no ticket #{ticket.id}: #{e.message}"
    end
  end

  # ── Articles ───────────────────────────────────────────────────────────────

  def migrate_articles(articles, org)
    return unless articles.is_a?(Array)

    articles.each do |a|
      author = resolve_user(a["authorId"] || a["author_id"], org) || org.users.first

      org.articles.create!(
        title:      a["title"].to_s.truncate(255),
        content:    a["content"],
        keywords:   a["keywords"],
        published:  a.fetch("published", false),
        author_id:  author&.id,
        created_at: parse_time(a["createdAt"] || a["created_at"]) || Time.current
      )
      @counts[:articles] += 1
    rescue ActiveRecord::RecordInvalid => e
      @errors << "Artigo '#{a['title']}': #{e.message}"
    end
  end

  # ── Helpers ────────────────────────────────────────────────────────────────

  def resolve_user(legacy_id, org)
    return nil if legacy_id.blank?

    @user_map[legacy_id.to_s] ||
      org.users.find_by(legacy_id: legacy_id.to_s)
  end

  def normalize_status(raw)
    return "Não iniciado" if raw.blank?

    STATUS_MAP[raw] ||
      Ticket::STATUSES.find { |s| s.downcase == raw.to_s.downcase } ||
      "Não iniciado"
  end

  def map_role(raw)
    case raw.to_s.downcase
    when "admin", "administrator"    then "admin"
    when "analyst", "agent", "staff" then "analyst"
    else "user"
    end
  end

  def parse_time(value)
    return nil if value.blank?

    Time.zone.parse(value.to_s)
  rescue ArgumentError, TypeError
    nil
  end
end
