class ArticleBlueprint < Blueprinter::Base
  identifier :id

  fields :title, :body, :keywords, :published, :created_at, :updated_at

  association :author, blueprint: UserBlueprint, view: :summary
end
