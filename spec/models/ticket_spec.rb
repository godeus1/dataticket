require "rails_helper"

RSpec.describe Ticket, type: :model do
  let(:org)       { create(:organization) }
  let(:requester) { create(:user, organization: org) }

  describe "validations" do
    it { is_expected.to validate_presence_of(:title) }
    it { is_expected.to validate_length_of(:title).is_at_most(255) }
    it { is_expected.to validate_inclusion_of(:status).in_array(Ticket::STATUSES) }
  end

  describe "associations" do
    it { is_expected.to belong_to(:organization) }
    it { is_expected.to belong_to(:requester).class_name("User") }
    it { is_expected.to belong_to(:assignee).class_name("User").optional }
    it { is_expected.to have_many(:comments).class_name("TicketComment") }
    it { is_expected.to have_many(:histories).class_name("TicketHistory") }
  end

  describe "#generate_ticket_id" do
    it "assigns a PREFIX-NNNN id on create" do
      ticket = org.tickets.create!(title: "Teste", requester: requester)
      expect(ticket.id).to match(/\A#{Regexp.escape(org.ticket_prefix)}-\d{4,}\z/)
    end

    it "increments the sequence per organization" do
      t1 = org.tickets.create!(title: "Primeiro", requester: requester)
      t2 = org.tickets.create!(title: "Segundo",  requester: requester)
      n1 = t1.id.split("-").last.to_i
      n2 = t2.id.split("-").last.to_i
      expect(n2).to eq(n1 + 1)
    end
  end

  describe "#can_transition_to?" do
    it "allows valid transitions" do
      ticket = build(:ticket, status: "Não iniciado") rescue Ticket.new(status: "Não iniciado")
      expect(ticket.can_transition_to?("Em andamento")).to be true
    end

    it "rejects invalid transitions" do
      ticket = Ticket.new(status: "Não iniciado")
      expect(ticket.can_transition_to?("Resolvido")).to be false
    end
  end

  describe "#sla_expired?" do
    it "returns true when deadline passed and not resolved" do
      ticket = Ticket.new(status: "Em andamento", deadline: 1.hour.ago)
      expect(ticket.sla_expired?).to be true
    end

    it "returns false when resolved" do
      ticket = Ticket.new(status: "Resolvido", deadline: 1.hour.ago)
      expect(ticket.sla_expired?).to be false
    end
  end
end
