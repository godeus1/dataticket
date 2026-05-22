# frozen_string_literal: true
# Endpoint publico (sem autenticacao) para receber a avaliacao CSAT.
# O token de URL garante que apenas o solicitante correto possa avaliar.

module Api
  module V1
    class CsatController < ActionController::API
      rescue_from ActiveRecord::RecordNotFound do
        render json: { error: "Link de avaliacao invalido ou expirado" }, status: :not_found
      end

      def submit
        ticket = Ticket.find_by!(csat_token: params[:token])

        return render json: { error: "Este ticket ja foi avaliado" }, status: :unprocessable_entity if ticket.csat_score.present?

        score   = params[:score].to_i
        comment = params[:comment].to_s.strip

        unless (1..5).include?(score)
          return render json: { error: "Nota invalida. Use um valor entre 1 e 5." }, status: :unprocessable_entity
        end

        ticket.update!(csat_score: score, csat_comment: comment.presence)

        render json: {
          message: "Avaliacao registrada com sucesso. Obrigado pelo feedback!",
          score:   score
        }
      end
    end
  end
end
