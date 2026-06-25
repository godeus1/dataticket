class ArticleBlueprint < Blueprinter::Base
  identifier :id

  fields :title, :body, :keywords, :published, :category_id, :created_at, :updated_at

  association :author, blueprint: UserBlueprint, view: :summary
  association :article_attachments, blueprint: ArticleAttachmentBlueprint, name: :attachments
end
