@echo off
cd /d "C:\Users\ErickOliveira\Downloads\dataticket\dataticket-api"

set DB_HOST=127.0.0.1
set DB_PORT=5432
set DB_USER=postgres
set DB_PASSWORD=@Erick123
set DEVISE_JWT_SECRET_KEY=10fa7847c186f6acbf0da717b32109ef5dabdecae9570ebfcb335eaced1933a0bab8e942675ea9cc72e5585b9b4daef741eeb8e2bdd8424d82c97b84ace080a6
set RAILS_ENV=development
set SEED_ADMIN_PASSWORD=@Salva123
set ALLOWED_ORIGINS=http://localhost:5173,http://localhost:4173,http://localhost:3001

bundle exec rails server -p 3001 -b 127.0.0.1
