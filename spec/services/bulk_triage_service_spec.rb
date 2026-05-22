require "rails_helper"

RSpec.describe BulkTriageService do
  let(:organization) { create(:organization) }
  let(:actor)        { create(:user, :admin, organization: organization) }
  let(:priority)     { create(:priority, organization: organization) }

  let!(:ticket1) { create(:ticket, organization: organization, requester: actor) }
  let!(:ticket2) { create(:ticket, organization: organization, requester: actor) }
  let!(:resolved) do
    create(:ticket, :resolved, organization: organization, requester: actor)
  end

  describe "#call" do
    subject(:result) do
      described_class.new(
        [ticket1.id, ticket2.id, resolved.id],
        { priority_id: priority.id },
        actor
      ).call
    end

    it "retorna successo quando todos os elegíveis sao triados" do
      expect(result.success?).to be true
    end

    it "lista os tickets triados" do
      expect(result.triaged).to include(ticket1.id, ticket2.id)
    end

    it "lista os tickets pulados (status incompatível)" do
      expect(result.skipped).to include(resolved.id)
    end

    it "nao retorna erros para tickets validos" do
      expect(result.errors).to be_empty
    end

    context "quando um ticket_id nao existe" do
      subject(:result) do
        described_class.new(["TK-9999"], {}, actor).call
      end

      it "registra o erro e retorna failure" do
        expect(result.success?).to be false
        expect(result.errors.first).to include("TK-9999")
      end
    end
  end
end
