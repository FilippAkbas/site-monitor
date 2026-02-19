# Site Monitor

Мониторинг 17 сайтов через GitHub Actions каждые 10 минут.
Уведомления в Telegram только при падении и восстановлении.

## Настройка

1. Settings → Secrets → Actions → New repository secret:
   - `TG_TOKEN` — Telegram Bot Token
   - `TG_CHAT`  — Telegram Chat ID

2. Actions → Enable workflows

## Добавить сайт

Открой `monitor.sh`, добавь домен в массив `SITES`.
