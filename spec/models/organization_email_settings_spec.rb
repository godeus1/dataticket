require "rails_helper"

RSpec.describe Organization, "#email_type_enabled?" do
  let(:org) { create(:organization) }

  it "todos os tipos vêm ligados por padrão" do
    Organization::EMAIL_TYPES.each do |type|
      expect(org.email_type_enabled?(type)).to be(true), "esperava #{type} ligado"
    end
  end

  it "toggle OFF desativa um tipo NÃO-crítico específico (e só ele)" do
    org.update!(email_settings: { "ticket_created" => false })
    expect(org.email_type_enabled?("ticket_created")).to be false
    expect(org.email_type_enabled?("status_changed")).to be true
  end

  it "o master emails_enabled NÃO afeta o envio (controle é só por tipo)" do
    org.update!(emails_enabled: false)
    expect(org.email_type_enabled?("ticket_created")).to be true
    expect(org.email_type_enabled?("status_changed")).to be true
  end

  it "tipos CRÍTICOS (password_reset/welcome) SEMPRE enviam, mesmo com toggle OFF" do
    org.update!(emails_enabled: false, email_settings: { "password_reset" => false, "welcome" => false })
    expect(org.email_type_enabled?("password_reset")).to be true
    expect(org.email_type_enabled?("welcome")).to be true
  end
end
