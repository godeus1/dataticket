require "rails_helper"

RSpec.describe Organization, "#email_type_enabled?" do
  let(:org) { create(:organization, emails_enabled: true) }

  it "todos os tipos vêm ligados por padrão" do
    Organization::EMAIL_TYPES.each do |type|
      expect(org.email_type_enabled?(type)).to be(true), "esperava #{type} ligado"
    end
  end

  it "toggle OFF desativa o tipo específico (e só ele)" do
    org.update!(email_settings: { "password_reset" => false })
    expect(org.email_type_enabled?("password_reset")).to be false
    expect(org.email_type_enabled?("welcome")).to be true
  end

  it "tipos NÃO-críticos respeitam o master emails_enabled" do
    org.update!(emails_enabled: false)
    expect(org.email_type_enabled?("ticket_created")).to be false
    expect(org.email_type_enabled?("status_changed")).to be false
  end

  it "tipos CRÍTICOS (password_reset/welcome) ignoram o master, mas respeitam o toggle" do
    org.update!(emails_enabled: false)
    expect(org.email_type_enabled?("password_reset")).to be true

    org.update!(email_settings: { "password_reset" => false })
    expect(org.email_type_enabled?("password_reset")).to be false
  end
end
