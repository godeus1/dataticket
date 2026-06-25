class TicketComment < ApplicationRecord
  belongs_to :ticket, foreign_key: :ticket_id
  # Autor opcional: comentários vindos de resposta de e-mail de remetente
  # desconhecido não têm usuário do DataTicket vinculado.
  belongs_to :user, optional: true

  validates :body, presence: true
  validates :kind, inclusion: { in: %w[public internal] }
  validate  :has_author

  scope :public_only,   -> { where(kind: "public") }
  scope :internal_only, -> { where(kind: "internal") }

  # Nome exibível do autor (usuário vinculado ou nome guardado no comentário).
  def display_author
    return user.full_name if user
    [ author_name.presence || "Desconhecido", author_email.presence ].compact.join(" ")
  end

  private

  def has_author
    return if user_id.present? || author_email.present? || author_name.present?

    errors.add(:base, "Comentário precisa de um autor (usuário ou e-mail)")
  end
end
