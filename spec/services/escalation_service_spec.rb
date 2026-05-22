require "rails_helper"

RSpec.describe EscalationService do
  let(:organization) { create(:organization) }
  let(:admin)        { create(:user, :admin,   organization: organization) }
  let(:assignee)     { create(:user, :analyst, organization: organization) }
  let(:requester)    { create(:user,            organization: organization) }

  let(:ticket) do
    create(:ticket,
      organization: organization,
      requester:    requester,
      assignee:     assignee,
      status:       "Em andamento",
      deadline:     2.hours.ago,
      created_at:   5.hours.ago
    )
  end

  before { admin } # garante que admin existe na org

  describe "#escalate" do
    subject(:service) { described_class.new(ticket) }

    it "marca o ticket como escalado" do
      service.escalate
      expect(ticket.reload.escalated).to be true
      expect(ticket.escalated_at).to be_present
    end

    it "cria um TicketHistory com campo escalation" do
      expect { service.escalate }
        .to change { ticket.histories.where(field: "escalation").count }.by(1)
    end

    it "notifica o assignee e os admins" do
      service.escalate
      expect(assignee.notifications.where(kind: "status").count).to eq(1)
      expect(admin.notifications.where(kind: "status").count).to eq(1)
    end

    it "nao re-escala um ticket ja escalado" do
      ticket.update!(escalated: true)
      expect(Ticket).not_to receive(:open)
      # EscalationJob filtra por escalated: false antes de chamar o service
    end
  end
end
