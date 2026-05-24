class SlaDigestJob < ApplicationJob
  queue_as :default

  def perform
    Organization.find_each do |org|
      expired        = org.tickets.open.overdue.includes(:priority)
      expiring_today = org.tickets.open
                          .where(deadline: Time.current.beginning_of_day..Time.current.end_of_day)
                          .includes(:priority)

      next if expired.empty? && expiring_today.empty?

      org.users.staff.active.find_each do |user|
        SlaDigestMailer.daily(user, expired, expiring_today).deliver_now
      end
    end
  end
end
