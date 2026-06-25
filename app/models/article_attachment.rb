class ArticleAttachment < ApplicationRecord
  belongs_to :article
  belongs_to :user

  validates :filename, presence: true
end
