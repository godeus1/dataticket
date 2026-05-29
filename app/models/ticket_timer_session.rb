class TicketTimerSession < ApplicationRecord
  belongs_to :ticket
  belongs_to :user

  validates :started_at,    presence: true
  validates :stopped_at,    presence: true, if: -> { completed? || cancelled? }
  validates :duration_mins, presence: true,
                            numericality: { greater_than_or_equal_to: 0 },
                            if: :completed?
  validates :status, inclusion: { in: %w[running completed cancelled] }

  scope :chronological, -> { order(:started_at) }
  scope :running,       -> { where(status: "running") }
  scope :completed,     -> { where(status: "completed") }

  def running?   = status == "running"
  def completed? = status == "completed"
  def cancelled? = status == "cancelled"

  # Stops a running session and computes duration.
  def stop!(stopped_time = Time.current)
    duration = ((stopped_time - started_at) / 60.0).round(2)
    update!(stopped_at: stopped_time, duration_mins: duration, status: "completed")
  end

  # Marks a running session as cancelled without computing duration.
  def cancel!
    update!(stopped_at: Time.current, duration_mins: 0.0, status: "cancelled")
  end
end
