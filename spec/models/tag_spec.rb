require "rails_helper"

RSpec.describe Tag, type: :model do
  let(:org) { create(:organization) }

  it "normaliza o nome para minúsculas" do
    tag = Tag.create!(organization: org, name: "Urgente", color: "#ff0000")
    expect(tag.name).to eq("urgente")
  end

  it "não permite nome duplicado na mesma organização" do
    Tag.create!(organization: org, name: "bug", color: "#ff0000")
    dup = Tag.new(organization: org, name: "bug", color: "#00ff00")
    expect(dup).not_to be_valid
    expect(dup.errors[:name]).to be_present
  end

  it "permite mesmo nome em organizações diferentes" do
    org2 = create(:organization)
    Tag.create!(organization: org,  name: "bug", color: "#ff0000")
    tag2 = Tag.new(organization: org2, name: "bug", color: "#ff0000")
    expect(tag2).to be_valid
  end

  it "rejeita cor inválida" do
    tag = Tag.new(organization: org, name: "t1", color: "red")
    expect(tag).not_to be_valid
    expect(tag.errors[:color]).to be_present
  end
end
