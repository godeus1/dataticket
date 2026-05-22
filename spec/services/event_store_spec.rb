require "rails_helper"

RSpec.describe EventStore do
  let(:organization) { create(:organization) }
  let(:actor)        { create(:user, organization: organization) }
  let(:ticket)       { create(:ticket, organization: organization, requester: actor) }

  describe ".publish" do
    it "cria um Event imutável" do
      expect {
        EventStore.publish(
          event_type:   "ticket.created",
          aggregate:    ticket,
          payload:      { title: ticket.title },
          actor:        actor,
          organization: organization
        )
      }.to change(Event, :count).by(1)
    end

    it "define aggregate_type e aggregate_id corretamente" do
      EventStore.publish(event_type: "ticket.created", aggregate: ticket, organization: organization)
      event = Event.last
      expect(event.aggregate_type).to eq("Ticket")
      expect(event.aggregate_id).to eq(ticket.id.to_s)
    end

    it "incrementa version a cada evento no mesmo aggregate" do
      EventStore.publish(event_type: "ticket.created",      aggregate: ticket, organization: organization)
      EventStore.publish(event_type: "ticket.status_changed", aggregate: ticket, organization: organization)

      versions = Event.where(aggregate_type: "Ticket", aggregate_id: ticket.id).pluck(:version)
      expect(versions).to eq([ 1, 2 ])
    end

    it "não levanta exceção quando organization está ausente (retorna nil)" do
      aggregate_without_org = double("NilOrg", class: double(name: "Widget"), id: 99,
                                               respond_to?: false)
      expect {
        result = EventStore.publish(event_type: "widget.test", aggregate: aggregate_without_org)
        expect(result).to be_nil
      }.not_to raise_error
    end

    it "proíbe atualizar Event (imutabilidade)" do
      event = EventStore.publish(event_type: "ticket.created", aggregate: ticket, organization: organization)
      expect { event.update!(event_type: "hacked") }.to raise_error(ActiveRecord::ReadOnlyRecord)
    end
  end
end
