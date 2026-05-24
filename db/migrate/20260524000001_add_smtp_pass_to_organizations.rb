class AddSmtpPassToOrganizations < ActiveRecord::Migration[8.1]
  def change
    add_column :organizations, :smtp_pass, :string
  end
end
