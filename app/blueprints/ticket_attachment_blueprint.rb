class TicketAttachmentBlueprint < Blueprinter::Base
  identifier :id
  fields :filename, :content_type, :byte_size, :storage_key, :created_at
end
