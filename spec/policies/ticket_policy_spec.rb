require "rails_helper"

RSpec.describe TicketPolicy do
  let(:organization) { create(:organization) }
  let(:admin)        { create(:user, :admin,   organization: organization) }
  let(:analyst)      { create(:user, :analyst, organization: organization) }
  let(:requester)    { create(:user,            organization: organization) }
  let(:other_user)   { create(:user,            organization: organization) }
  let(:ticket)       { create(:ticket, organization: organization, requester: requester, assignee: analyst) }

  subject(:policy)   { described_class }

  # O Scope agora escopa pela empresa EFETIVA da requisição (Current.organization).
  # Em specs unitários precisamos estabelecer esse contexto explicitamente.
  before { Current.organization = organization }
  after  { Current.reset }

  permissions :index?, :create? do
    it "permite qualquer usuario autenticado" do
      expect(policy).to permit(requester, ticket)
      expect(policy).to permit(analyst,   ticket)
      expect(policy).to permit(admin,     ticket)
    end
  end

  permissions :show? do
    it "permite ao dono do ticket" do
      expect(policy).to permit(requester, ticket)
    end

    it "permite ao admin e analyst" do
      expect(policy).to permit(admin,   ticket)
      expect(policy).to permit(analyst, ticket)
    end

    it "nega a usuario sem relacao com o ticket" do
      expect(policy).not_to permit(other_user, ticket)
    end
  end

  # update? e change_status?: admin + analista responsável pelo ticket
  permissions :update?, :change_status? do
    it "permite ao admin e ao analyst responsavel" do
      expect(policy).to permit(admin,   ticket)
      expect(policy).to permit(analyst, ticket)
    end

    it "nega a usuario comum" do
      expect(policy).not_to permit(requester, ticket)
    end
  end

  # triage? e assign?: somente admin e manager (analista NÃO tria nem atribui)
  permissions :triage?, :assign? do
    it "permite apenas a admin e manager" do
      expect(policy).to permit(admin, ticket)
    end

    it "nega ao analyst e usuario comum" do
      expect(policy).not_to permit(analyst,   ticket)
      expect(policy).not_to permit(requester, ticket)
    end
  end

  permissions :destroy? do
    it "permite apenas ao admin" do
      expect(policy).to permit(admin, ticket)
    end

    it "nega ao analyst e usuario comum" do
      expect(policy).not_to permit(analyst,   ticket)
      expect(policy).not_to permit(requester, ticket)
    end
  end

  describe "Scope" do
    let!(:own_ticket)        { create(:ticket, organization: organization, requester: requester) }
    let!(:assigned_ticket)   { create(:ticket, organization: organization, requester: requester, assignee: analyst) }
    let!(:unassigned_ticket) { create(:ticket, organization: organization, requester: other_user) }

    it "admin ve todos os tickets da organizacao" do
      scope = described_class::Scope.new(admin, Ticket.all).resolve
      expect(scope).to include(own_ticket, assigned_ticket, unassigned_ticket)
    end

    it "analyst ve tickets atribuidos a ele (principal ou co-responsavel)" do
      scope = described_class::Scope.new(analyst, Ticket.all).resolve
      expect(scope).to include(assigned_ticket)
      expect(scope).not_to include(unassigned_ticket)
    end

    it "usuario comum ve apenas seus proprios tickets" do
      scope = described_class::Scope.new(requester, Ticket.all).resolve
      expect(scope).to include(own_ticket, assigned_ticket)
      expect(scope).not_to include(unassigned_ticket)
    end
  end
end
