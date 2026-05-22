class AccountBlueprint < Blueprinter::Base
  identifier :id
  fields :name, :slug, :plan, :active, :created_at

  view :full do
    include_view :default

    field :organizations_count do |account|
      account.organizations.count
    end

    field :organization_names do |account|
      account.organizations.pluck(:name)
    end
  end
end
