require "rails_helper"

RSpec.describe CustomFieldValueService do
  let(:organization) { create(:organization) }
  let(:ticket)       { create(:ticket, organization: organization, requester: create(:user, organization: organization)) }
  let(:text_field)   { create(:custom_field, organization: organization, name: "Versão", field_type: "text") }
  let(:number_field) { create(:custom_field, organization: organization, name: "Impacto", field_type: "number") }

  describe "#save!" do
    context "com array de valores" do
      it "cria TicketFieldValues para cada campo" do
        values = [
          { "custom_field_id" => text_field.id, "value" => "3.2.1" },
          { "custom_field_id" => number_field.id, "value" => "5" }
        ]
        service = described_class.new(ticket, values)
        expect { service.save! }.to change { TicketFieldValue.count }.by(2)
      end
    end

    context "com campo obrigatório não preenchido" do
      let!(:required_field) { create(:custom_field, :required, organization: organization, name: "Número do contrato") }

      it "levanta ValidationError" do
        service = described_class.new(ticket, [])
        expect { service.save! }.to raise_error(CustomFieldValueService::ValidationError, /Número do contrato/)
      end
    end

    context "com valor de dropdown inválido" do
      let(:dropdown) { create(:custom_field, :dropdown, organization: organization) }

      it "levanta ArgumentError" do
        values = [ { "custom_field_id" => dropdown.id, "value" => "Opção Inválida" } ]
        service = described_class.new(ticket, values)
        expect { service.save! }.to raise_error(ArgumentError)
      end
    end

    context "atualiza valor existente (upsert)" do
      it "não duplica o registro" do
        values = [ { "custom_field_id" => text_field.id, "value" => "v1" } ]
        described_class.new(ticket, values).save!

        updated = [ { "custom_field_id" => text_field.id, "value" => "v2" } ]
        described_class.new(ticket, updated).save!

        expect(TicketFieldValue.where(ticket: ticket, custom_field: text_field).count).to eq(1)
        expect(TicketFieldValue.find_by(ticket: ticket, custom_field: text_field).value).to eq("v2")
      end
    end
  end
end
