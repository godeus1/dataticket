class TicketsChannel < ApplicationCable::Channel
  def subscribed
    stream_for current_user.organization
  end

  def unsubscribed
    stop_all_streams
  end
end
