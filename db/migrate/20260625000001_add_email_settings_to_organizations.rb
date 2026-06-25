class AddEmailSettingsToOrganizations < ActiveRecord::Migration[8.1]
  # Toggles ON/OFF por TIPO de e-mail, por empresa (ex: redefinição de senha ON
  # numa empresa e OFF em outra). Hash { "password_reset" => true, ... }.
  # Ausência da chave = ligado (default ON).
  def change
    add_column :organizations, :email_settings, :jsonb, default: {}, null: false
  end
end
