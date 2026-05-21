# Railway / Heroku process definitions
# ─────────────────────────────────────
# web   : Puma HTTP server (inclui Solid Queue Supervisor via SOLID_QUEUE_IN_PUMA=true)
# worker: Processo separado de background jobs — use quando escalar horizontalmente
# release: Executa migrações antes de cada deploy (reconhecido pelo Railway)

web:     bundle exec thrust ./bin/rails server -b 0.0.0.0 -p $PORT
worker:  bundle exec rails solid_queue:start
release: bundle exec rails db:migrate
