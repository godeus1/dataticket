class Article < ApplicationRecord
  belongs_to :organization
  belongs_to :author, class_name: "User", foreign_key: :author_id
  belongs_to :category, optional: true

  has_many :article_attachments, dependent: :destroy

  validates :title, presence: true

  scope :published, -> { where(published: true) }
  scope :recent,    -> { order(created_at: :desc) }

  def keyword_list
    keywords.to_s.split(",").map(&:strip)
  end
end
