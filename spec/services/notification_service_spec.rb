require "rails_helper"

RSpec.describe NotificationService do
  let(:organization) { create(:organization) }
  let(:requester)    { create(:user, organization: organization) }
  let(:assignee)     { create(:user, :analyst, organization: organization) }
  let(:ticket) do
    create(:ticket, organization: organization, requester: requester, assignee: assignee,
                    status: "Não iniciado")
  end
  let(:service) { described_class.new(ticket) }

  describe "#notify_assignee" do
    it "cria uma notificacao de assign para o assignee" do
      expect { service.notify_assignee(assignee) }
        .to change { assignee.notifications.count }.by(1)

      notif = assignee.notifications.last
      expect(notif.kind).to eq("assign")
      expect(notif.ticket).to eq(ticket)
    end

    it "nao cria notificacao quando assignee eh nil" do
      expect { service.notify_assignee(nil) }.not_to change { Notification.count }
    end
  end

  describe "#notify_status_change" do
    let(:actor) { requester }

    it "notifica todos os usuarios relevantes exceto o actor" do
      expect { service.notify_status_change(actor, "Não iniciado", "Em andamento") }
        .to change { assignee.notifications.count }.by(1)

      notif = assignee.notifications.last
      expect(notif.kind).to eq("status")
    end

    it "nao notifica o actor" do
      service.notify_status_change(assignee, "Não iniciado", "Em andamento")
      expect(assignee.notifications.where(kind: "status").count).to eq(0)
    end
  end

  describe "#notify_new_comment" do
    let(:commenter) { create(:user, :analyst, organization: organization) }

    it "notifica requester e assignee exceto o comentador" do
      service.notify_new_comment(commenter)

      [requester, assignee].each do |user|
        expect(user.notifications.where(kind: "comment").count).to eq(1)
      end
    end
  end
end
