Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    # Origens fixas: dev local + qualquer preview/produção dataticket*.vercel.app
    base_origins = [
      "http://localhost:3000",
      "http://localhost:5173",
      /\Ahttps:\/\/dataticket[^.]*\.vercel\.app\z/,
    ]

    # ALLOWED_ORIGINS adiciona origens extras (ex: domínio próprio) sem substituir as fixas
    extra = ENV.fetch("ALLOWED_ORIGINS", "").split(",").map(&:strip).reject(&:empty?)

    origins base_origins + extra

    resource "*",
      headers:     :any,
      methods:     %i[get post put patch delete options head],
      credentials: false,
      expose:      [ "Authorization" ]
  end
end
