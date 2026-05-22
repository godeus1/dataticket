require "rails_helper"

RSpec.describe CustomField, type: :model do
  let(:org) { create(:organization) }

  describe "validações" do
    it "é válido com atributos mínimos" do
      cf = build(:custom_field, organization: org)
      expect(cf).to be_valid
    end

    it "rejeita field_type inválido" do
      cf = build(:custom_field, organization: org, field_type: "arquivo")
      expect(cf).not_to be_valid
    end

    it "rejeita dropdown sem options" do
      cf = build(:custom_field, :dropdown, organization: org, options: [])
      expect(cf).not_to be_valid
      expect(cf.errors[:options]).to be_present
    end
  end

  describe "#cast_value" do
    let(:text_field)   { build(:custom_field, organization: org, field_type: "text") }
    let(:number_field) { build(:custom_field, organization: org, field_type: "number") }
    let(:date_field)   { build(:custom_field, organization: org, field_type: "date") }
    let(:dropdown_field) { build(:custom_field, :dropdown, organization: org) }

    it "retorna string para text" do
      expect(text_field.cast_value("hello")).to eq("hello")
    end

    it "retorna Float para number" do
      expect(number_field.cast_value("42")).to eq(42.0)
    end

    it "retorna Date para date" do
      expect(date_field.cast_value("2025-01-15")).to eq(Date.parse("2025-01-15"))
    end

    it "aceita opção válida de dropdown" do
      expect(dropdown_field.cast_value("Opção A")).to eq("Opção A")
    end

    it "rejeita opção inválida de dropdown" do
      expect { dropdown_field.cast_value("Inválida") }.to raise_error(ArgumentError)
    end

    it "lança ArgumentError para number inválido" do
      expect { number_field.cast_value("abc") }.to raise_error(ArgumentError)
    end
  end
end
