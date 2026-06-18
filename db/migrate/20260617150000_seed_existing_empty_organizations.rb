class SeedExistingEmptyOrganizations < ActiveRecord::Migration[8.1]
  # Seeda empresas existentes que estão sem prioridades (ex: Datatry, criada vazia
  # no Sprint 1) com prioridades padrão + categoria geral, para ficarem utilizáveis.
  # O OrganizationSeeder é idempotente, então empresas já configuradas são ignoradas.
  def up
    Organization.find_each { |org| OrganizationSeeder.new(org).call }
  end

  def down
    # Não remove dados seedados (podem já estar em uso). Ajuste manual se necessário.
  end
end
