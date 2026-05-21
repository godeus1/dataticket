class DataMigrationService
  Result = Struct.new(:success?, :imported, :errors, keyword_init: true)

  def initialize(organization, data)
    @organization = organization
    @data         = data
    @imported     = 0
    @errors       = []
  end

  def call
    ActiveRecord::Base.transaction do
      Array(@data).each_with_index do |record, idx|
        import_ticket(record, idx)
      end
      raise ActiveRecord::Rollback if @errors.any?
    end

    if @errors.any?
      Result.new(success?: false, imported: 0, errors: @errors)
    else
      Result.new(success?: true, imported: @imported, errors: [])
    end
  end

  private

  def import_ticket(record, idx)
    requester = find_or_create_user(record[:requester_email])
    ticket    = @organization.tickets.new(
      title:       record[:title],
      description: record[:description],
      status:      map_status(record[:status]),
      requester:   requester,
      created_at:  record[:created_at] || Time.current
    )

    if ticket.save
      @imported += 1
    else
      @errors << "Registro #{idx + 1}: #{ticket.errors.full_messages.join(', ')}"
    end
  rescue StandardError => e
    @errors << "Registro #{idx + 1}: #{e.message}"
  end

  def find_or_create_user(email)
    return nil if email.blank?

    @organization.users.find_or_create_by!(email: email.downcase) do |u|
      u.first_name = email.split("@").first
      u.last_name  = "Importado"
      u.role       = "user"
      u.password   = SecureRandom.hex(16)
    end
  end

  def map_status(raw)
    return "Não iniciado" if raw.blank?

    Ticket::STATUSES.find { |s| s.downcase == raw.to_s.downcase } || "Não iniciado"
  end
end
