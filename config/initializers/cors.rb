Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    allowed = ENV.fetch(
      "ALLOWED_ORIGINS",
      "http://localhost:3000,http://localhost:5173," \
      "https://dataticket-api.vercel.app," \
      "https://dataticket-erick-schittini-s-projects.vercel.app," \
      "https://dataticket-git-main-erick-schittini-s-projects.vercel.app"
    ).split(",").map(&:strip)
    origins allowed

    resource "*",
      headers:     :any,
      methods:     %i[get post put patch delete options head],
      credentials: false,
      expose:      [ "Authorization" ]
  end
end
