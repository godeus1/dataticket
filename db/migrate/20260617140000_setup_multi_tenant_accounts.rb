class SetupMultiTenantAccounts < ActiveRecord::Migration[8.1]
  # Sprint 1 — estrutura multi-empresa (abordagem SEGURA, sem renomear tickets):
  #   1. Salvabras passa a usar prefixo SAL; a numeração reinicia em SAL-00001.
  #      Os tickets EXISTENTES (TK-XXXX) NÃO são tocados — continuam válidos.
  #   2. Cria a conta-plataforma e vincula as empresas órfãs (Salvabras).
  #   3. Cria a empresa Datatry (prefixo DAT).
  #   4. Promove o super-admin a msp_admin (vê e troca entre todas as empresas).
  #
  # Idempotente: find_or_create_by + guards. Pode rodar mais de uma vez sem efeito.
  def up
    # 1. Salvabras: troca prefixo TK → SAL e reinicia o contador (próximo = SAL-00001).
    #    Não renomeia tickets antigos (decisão deliberada para não mexer na PK).
    salvabras = Organization.find_by(ticket_prefix: "TK")
    if salvabras
      salvabras.update_columns(ticket_prefix: "SAL")
      execute("UPDATE ticket_counters SET counter = 0 WHERE organization_id = #{salvabras.id}")
    end

    # 2. Conta-plataforma + vínculo das empresas órfãs
    account = Account.find_or_create_by!(slug: "datatry") do |a|
      a.name   = "Datatry"
      a.plan   = "standard"
      a.active = true
    end
    Organization.where(account_id: nil).update_all(account_id: account.id)

    # 3. Empresa Datatry (prefixo DAT)
    Organization.find_or_create_by!(slug: "datatry") do |o|
      o.name          = "Datatry"
      o.account_id    = account.id
      o.ticket_prefix = "DAT"
      o.timezone      = "America/Sao_Paulo"
      o.date_format   = "DD/MM/YYYY"
    end

    # 4. Promove o super-admin a msp_admin (update_columns: sem callbacks; o papel é
    #    lido do banco a cada request, então não exige novo login).
    super_admin = User.find_by(email: "e.oliveira@datatry.com.br")
    if super_admin
      super_admin.update_columns(role: "msp_admin")
    else
      say "AVISO: usuário e.oliveira@datatry.com.br não encontrado — msp_admin não promovido", true
    end
  end

  def down
    User.where(email: "e.oliveira@datatry.com.br").update_all(role: "admin")
    Organization.where(slug: "datatry").destroy_all
    Organization.where(ticket_prefix: "SAL").update_all(ticket_prefix: "TK")
    # Conta e vínculos mantidos; ajuste manual se um rollback completo for necessário.
  end
end
