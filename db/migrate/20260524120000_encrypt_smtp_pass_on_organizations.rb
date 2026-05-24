class EncryptSmtpPassOnOrganizations < ActiveRecord::Migration[8.1]
  def up
    # text comporta o ciphertext do ActiveRecord Encryption (maior que string(255))
    change_column :organizations, :smtp_pass, :text

    # Lê valores em texto plano existentes e re-salva com criptografia
    ActiveRecord::Encryption.config.support_unencrypted_data = true
    Organization.reset_column_information
    Organization.find_each do |org|
      plaintext = org.smtp_pass
      next if plaintext.blank?
      org.smtp_pass = plaintext
      org.save!(validate: false)
    end
  ensure
    ActiveRecord::Encryption.config.support_unencrypted_data = false
  end

  def down
    change_column :organizations, :smtp_pass, :string
  end
end
