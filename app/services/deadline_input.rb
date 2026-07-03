# Normaliza o valor de "prazo" informado manualmente (triagem ou edição pelo
# admin). Um input só-data ("YYYY-MM-DD") deve virar o FIM daquele dia no fuso
# de Brasília — senão vira meia-noite UTC e aparece como o dia anterior / SLA
# vencido. Valores com hora explícita passam direto.
module DeadlineInput
  TZ = "America/Sao_Paulo".freeze

  def self.normalize(value)
    return value if value.blank?

    s = value.to_s.strip
    if s.match?(/\A\d{4}-\d{2}-\d{2}\z/)
      ActiveSupport::TimeZone[TZ].parse(s).end_of_day
    else
      value
    end
  rescue ArgumentError
    value
  end
end
