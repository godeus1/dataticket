class SlaDigestJob < ApplicationJob
  queue_as :default

  # Pluck apenas IDs para não serializar objetos AR completos em cada deliver_later.
  # O mailer recarrega os dados necessários no momento da execução, com dados frescos.
  def perform
    today = Date.current

    Organization.find_each do |org|
      next unless org.email_type_enabled?("sla_digest")

      expired_ids    = org.tickets.open.overdue.pluck(:id)
      expiring_ids   = org.tickets.open
                          .where(deadline: today.beginning_of_day..today.end_of_day)
                          .pluck(:id)

      next if expired_ids.empty? && expiring_ids.empty?

      org.users.staff.active.find_each do |user|
        SlaDigestMailer.daily(user.id, org.id, expired_ids, expiring_ids).deliver_later
      end
    end
  end
end
