require "csv"

module Api
  module V1
    class ReportsController < ApplicationController
      def index
        authorize :report, :index?
        data = cached_report_data
        render json: data
      end

      # GET /api/v1/reports/export?format=csv&period=30
      # GET /api/v1/reports/export?format=pdf&period=30
      def export
        authorize :report, :index?
        @report_data = cached_report_data
        fmt = params[:format].to_s.downcase

        case fmt
        when "csv"
          send_data build_csv, filename: "relatorio-#{Date.today}.csv",
                               type: "text/csv; charset=utf-8",
                               disposition: "attachment"
        when "pdf"
          send_data build_pdf, filename: "relatorio-#{Date.today}.pdf",
                               type: "application/pdf",
                               disposition: "attachment"
        else
          render json: { error: "Formato inválido. Use 'csv' ou 'pdf'." }, status: :unprocessable_entity
        end
      end

      private

      def report_params
        params.permit(:period, :from, :to, :assignee_id, :category_id, :priority_id, :format)
      end

      # Cache de 5 min por combinação de org + parâmetros do relatório.
      # Elimina re-execução das 11 queries a cada refresh de tela.
      # TTL curto (5 min) preserva a percepção de dados em tempo real.
      def cached_report_data
        key = "report/#{@organization.id}/#{report_params.to_h.sort.to_json}"
        Rails.cache.fetch(key, expires_in: 5.minutes) do
          ReportService.new(@organization, report_params).call
        end
      end

      # ── CSV ──────────────────────────────────────────────────────────────────
      def build_csv
        CSV.generate(headers: true, encoding: "UTF-8") do |csv|
          csv << [ "Relatório DataTicket", Date.today.strftime("%d/%m/%Y") ]
          csv << []

          # Volume summary
          csv << [ "Total de Tickets", @report_data[:total_tickets] ]
          csv << [ "Abertos",          @report_data[:open_tickets] ]
          csv << [ "Resolvidos",        @report_data[:resolved_tickets] ]
          csv << [ "SLA Estourado",     @report_data[:overdue_tickets] ]
          csv << [ "Escalados",         @report_data[:escalated_count] ]
          csv << []

          # CSAT
          if (csat = @report_data[:csat_summary])
            csv << [ "CSAT Médio", csat[:avg] ]
            csv << [ "Total de Avaliações", csat[:total] ]
            (csat[:distribution] || {}).each do |score, count|
              csv << [ "Nota #{score}", count ]
            end
            csv << []
          end

          # Volume by day
          csv << [ "Data", "Tickets Criados" ]
          (@report_data[:volume_by_day] || []).each do |row|
            csv << [ row[:date], row[:count] ]
          end
          csv << []

          # By status
          csv << [ "Status", "Quantidade" ]
          (@report_data[:by_status] || {}).each do |status, count|
            csv << [ status, count ]
          end
          csv << []

          # By ticket type
          csv << [ "Tipo", "Quantidade" ]
          (@report_data[:by_ticket_type] || {}).each do |type, count|
            csv << [ type, count ]
          end
        end
      end

      # ── PDF (Prawn) ───────────────────────────────────────────────────────────
      def build_pdf
        require "prawn"
        require "prawn/table"

        Prawn::Document.new(page_size: "A4", margin: 40) do |pdf|
          pdf.font_families.update("DejaVu" => {
            normal: "#{Prawn::DATADIR}/fonts/DejaVuSans.ttf",
            bold:   "#{Prawn::DATADIR}/fonts/DejaVuSans-Bold.ttf"
          }) rescue nil

          pdf.text "Relatório DataTicket", size: 18, style: :bold
          pdf.text "Gerado em #{Date.today.strftime('%d/%m/%Y')}", size: 10, color: "666666"
          pdf.move_down 12

          # Summary table
          summary_data = [
            [ "Métrica", "Valor" ],
            [ "Total de Tickets",  @report_data[:total_tickets].to_s ],
            [ "Abertos",           @report_data[:open_tickets].to_s ],
            [ "Resolvidos",        @report_data[:resolved_tickets].to_s ],
            [ "SLA Estourado",     @report_data[:overdue_tickets].to_s ],
            [ "Escalados",         @report_data[:escalated_count].to_s ]
          ]
          pdf.table(summary_data, header: true, width: pdf.bounds.width,
                    cell_style: { size: 10, padding: [ 4, 8 ] })
          pdf.move_down 12

          # CSAT
          if (csat = @report_data[:csat_summary]) && csat[:total].to_i > 0
            pdf.text "CSAT", size: 14, style: :bold
            pdf.move_down 4
            pdf.text "Nota média: #{csat[:avg]&.round(2) || '-'} | Avaliações: #{csat[:total]}"
            pdf.move_down 10
          end

          # Volume by day
          volume = @report_data[:volume_by_day] || []
          if volume.any?
            pdf.text "Volume por Dia", size: 14, style: :bold
            pdf.move_down 4
            rows = [ [ "Data", "Tickets" ] ] + volume.map { |r| [ r[:date].to_s, r[:count].to_s ] }
            pdf.table(rows, header: true, width: pdf.bounds.width,
                      cell_style: { size: 9, padding: [ 3, 6 ] })
          end
        end.render
      end
    end
  end
end
