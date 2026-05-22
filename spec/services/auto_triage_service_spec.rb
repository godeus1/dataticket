require "rails_helper"

RSpec.describe AutoTriageService do
  let(:organization) { create(:organization) }
  let(:priority)     { create(:priority, organization: organization) }
  let(:category)     { create(:category, organization: organization) }
  let(:ticket) do
    create(:ticket,
           organization: organization,
           title: "Servidor fora do ar",
           description: "O servidor de produção parou de responder")
  end

  describe "#apply" do
    context "when a matching rule exists" do
      let!(:rule) do
        TriageRule.create!(
          organization: organization,
          name:         "Regra servidor",
          keyword:      "servidor",
          priority:     priority,
          category:     category,
          position:     0,
          active:       true
        )
      end

      it "applies category and priority from the rule" do
        service = described_class.new(ticket)
        matched = service.apply

        expect(matched).to eq(rule)
        expect(ticket.reload.category_id).to eq(category.id)
        expect(ticket.reload.priority_id).to eq(priority.id)
      end
    end

    context "when no rule matches" do
      it "returns nil and leaves ticket unchanged" do
        TriageRule.create!(
          organization: organization,
          name: "Regra irrelevante",
          keyword: "xyzxyz123",
          position: 0,
          active: true
        )
        service = described_class.new(ticket)
        expect(service.apply).to be_nil
        expect(ticket.reload.category_id).to be_nil
      end
    end

    context "when rule is inactive" do
      let!(:inactive_rule) do
        TriageRule.create!(
          organization: organization,
          name:     "Regra inativa",
          keyword:  "servidor",
          priority: priority,
          position: 0,
          active:   false
        )
      end

      it "ignores inactive rules" do
        service = described_class.new(ticket)
        expect(service.apply).to be_nil
      end
    end

    context "with multiple rules ordered by position" do
      let!(:rule_low)  { TriageRule.create!(organization: organization, name: "Low",  keyword: "servidor", position: 10, active: true) }
      let!(:rule_high) { TriageRule.create!(organization: organization, name: "High", keyword: "servidor", priority: priority, position: 1, active: true) }

      it "applies the rule with the lowest position first" do
        service = described_class.new(ticket)
        matched = service.apply
        expect(matched).to eq(rule_high)
      end
    end
  end
end
