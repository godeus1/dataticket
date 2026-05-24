# frozen_string_literal: true
# app/services/attachment_compressor.rb
#
# Comprime imagens antes do armazenamento.
# Requer: gem "image_processing" (já no Gemfile) + ImageMagick no sistema.
#
# Tipos não-imagem são retornados como StringIO sem modificação.
require "mini_magick"

class AttachmentCompressor
  MAX_DIMENSION = 1920
  JPEG_QUALITY  = 75
  IMAGE_TYPES   = %w[image/jpeg image/jpg image/png image/webp].freeze
  # GIF preserva animações — não convertemos

  Result = Struct.new(:io, :content_type, :filename, keyword_init: true)

  # Recebe um IO (ou String binária), content_type e filename originais.
  # Retorna Result com io comprimido (StringIO), content_type e filename finais.
  def self.compress(io, content_type:, filename:)
    return Result.new(io: wrap(io), content_type: content_type, filename: filename) \
      unless IMAGE_TYPES.include?(content_type.to_s.downcase.split(";").first.strip)

    data = io.respond_to?(:read) ? io.read : io.to_s
    image = MiniMagick::Image.read(data)

    # Redimensiona se exceder o limite máximo
    if image.width > MAX_DIMENSION || image.height > MAX_DIMENSION
      image.resize "#{MAX_DIMENSION}x#{MAX_DIMENSION}>"
    end

    image.quality JPEG_QUALITY.to_s
    image.format "jpg"

    new_filename = File.basename(filename.to_s, ".*") + ".jpg"
    Result.new(
      io:           StringIO.new(image.to_blob),
      content_type: "image/jpeg",
      filename:     new_filename
    )
  rescue => e
    Rails.logger.warn("[compressor] #{e.class}: #{e.message} — usando original sem compressão")
    io.respond_to?(:rewind) ? io.rewind : nil
    Result.new(io: wrap(io), content_type: content_type, filename: filename)
  end

  def self.wrap(io)
    case io
    when StringIO then io
    when String   then StringIO.new(io)
    else
      data = io.respond_to?(:read) ? io.read : io.to_s
      StringIO.new(data)
    end
  end
  private_class_method :wrap
end
