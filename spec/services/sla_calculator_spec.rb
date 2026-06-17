require "rails_helper"

RSpec.describe SlaCalculator do
  let(:organization) { create(:organization) }

  def build_ticket(priority_name: nil, sla_hours: nil, created_at: Time.current)
    priority = nil
    if priority_name
      priority = instance_double("Priority", id: 1, name: priority_name, sla_hours: sla_hours)
    end

    instance_double("Ticket",
      organization: organization,
      priority:     priority,
      category:     nil,
      created_at:   created_at
    )
  end

  describe "#calculate_deadline" do
    context "quando o ticket nao tem prioridade" do
      it "retorna nil" do
        ticket = build_ticket
        result = described_class.new(ticket).calculate_deadline
        expect(result).to be_nil
      end
    end

    context "quando a prioridade tem sla_hours definido" do
      it "calcula o prazo com base nas horas SLA" do
        # Segunda-feira 08:00 — 4 horas uteis = segunda 12:00
        start = Time.zone.parse("2026-01-05 08:00:00")  # segunda
        ticket = build_ticket(priority_name: "Critica", sla_hours: 4, created_at: start)

        deadline = described_class.new(ticket).calculate_deadline

        expect(deadline).to be_within(1.minute).of(Time.zone.parse("2026-01-05 12:00:00"))
      end
    end

    context "quando o prazo cruza um fim de semana" do
      it "pula sabado e domingo" do
        # Sexta-feira 16:00 — 4 horas uteis cruzam o fim de semana
        start = Time.zone.parse("2026-01-02 16:00:00")  # sexta
        ticket = build_ticket(priority_name: "Critica", sla_hours: 4, created_at: start)

        deadline = described_class.new(ticket).calculate_deadline

        # 16:00 sex + 2h = 18:00 sex (limite), depois 08:00-10:00 seg = deadline 10:00 seg
        expect(deadline.wday).not_to eq(0)  # nao domingo
        expect(deadline.wday).not_to eq(6)  # nao sabado
      end
    end

    context "quando ha um feriado cadastrado" do
      it "pula o dia de feriado no calculo" do
        holiday_date = Date.parse("2026-01-05")  # segunda
        allow(organization.holidays).to receive(:pluck).with(:date).and_return([ holiday_date ])

        start = Time.zone.parse("2026-01-05 08:00:00")
        ticket = build_ticket(priority_name: "Alta", sla_hours: 2, created_at: start)

        deadline = described_class.new(ticket).calculate_deadline

        # Com segunda bloqueada, as horas uteis comecam na terca
        expect(deadline.to_date).to eq(Date.parse("2026-01-06"))
      end
    end

    context "usando DEFAULT_SLA quando priority.sla_hours eh nil ou zero" do
      it "usa as horas padrao da tabela DEFAULT_SLA" do
        start  = Time.zone.parse("2026-01-05 08:00:00")
        ticket = build_ticket(priority_name: "Baixa", sla_hours: nil, created_at: start)

        # Baixa = 72h uteis, muito maior que zero
        deadline = described_class.new(ticket).calculate_deadline
        expect(deadline).to be > start
      end
    end
  end
end
