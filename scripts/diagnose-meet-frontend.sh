#!/bin/bash

# Диагностика meet-frontend и проверка проксирования трафика
# Запуск: ./diagnose-meet-frontend.sh [--remote]
#   --remote  — выполнить диагностику на удалённом сервере через SSH

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REMOTE_HOST="root@77.222.52.134"
REMOTE_PATH="/root/meet"
FRONTEND_URL="https://meet.limpopo113.ru"
RTC_URL="https://rtc.meet.limpopo113.ru"

# Ожидаемый порт приложения (Next.js в Dockerfile)
EXPECTED_APP_PORT=3000

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

ok() { echo -e "${GREEN}✓${NC} $1"; }
fail() { echo -e "${RED}✗${NC} $1"; }
warn() { echo -e "${YELLOW}⚠${NC} $1"; }
info() { echo -e "  $1"; }

run_checks() {
  echo "=== Диагностика meet-frontend ==="
  echo ""

  # 1. Проверка контейнера
  echo "--- Контейнер ---"
  if docker ps -a --format '{{.Names}}' | grep -q '^meet-frontend$'; then
    ok "Контейнер meet-frontend существует"
    STATUS=$(docker inspect meet-frontend --format '{{.State.Status}}')
    if [ "$STATUS" = "running" ]; then
      ok "Статус: $STATUS"
    else
      fail "Статус: $STATUS (ожидается running)"
    fi
  else
    fail "Контейнер meet-frontend не найден"
    return 1
  fi
  echo ""

  # 2. Проверка порта в Traefik vs фактический порт приложения
  echo "--- Конфигурация портов ---"
  TRAEFIK_PORT=$(docker inspect meet-frontend --format '{{index .Config.Labels "traefik.http.services.meet-frontend.loadbalancer.server.port"}}')
  if [ -n "$TRAEFIK_PORT" ]; then
    info "Traefik loadbalancer.server.port: $TRAEFIK_PORT"
    if [ "$TRAEFIK_PORT" != "$EXPECTED_APP_PORT" ]; then
      warn "Несоответствие: приложение слушает порт $EXPECTED_APP_PORT, Traefik ожидает $TRAEFIK_PORT"
      info "Исправьте в docker-compose.prod.yml: loadbalancer.server.port=$EXPECTED_APP_PORT"
    else
      ok "Порт Traefik совпадает с портом приложения ($EXPECTED_APP_PORT)"
    fi
  fi
  echo ""

  # 3. Проверка доступности изнутри (Node.js в контейнере)
  echo "--- Внутренняя доступность (приложение в контейнере) ---"
  if docker exec meet-frontend node -e "
    const http = require('http');
    const req = http.get('http://localhost:3000', (res) => process.exit(res.statusCode < 400 ? 0 : 1));
    req.on('error', () => process.exit(1));
    req.setTimeout(3000, () => { req.destroy(); process.exit(1); });
  " 2>/dev/null; then
    ok "Приложение отвечает на localhost:3000"
  else
    fail "Приложение не отвечает на localhost:3000"
  fi
  echo ""

  # 4. Проверка сети и Traefik
  echo "--- Сеть ---"
  if docker network inspect app_network &>/dev/null; then
    ok "Сеть app_network существует"
    if docker network inspect app_network --format '{{range .Containers}}{{.Name}} {{end}}' | grep -q meet-frontend; then
      ok "meet-frontend подключён к app_network"
    else
      warn "meet-frontend не в app_network (Traefik не сможет проксировать)"
    fi
  else
    fail "Сеть app_network не найдена"
  fi
  echo ""

  # 5. Внешняя проверка (через curl к публичному URL)
  echo "--- Внешняя доступность (проксирование) ---"
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -k --connect-timeout 5 "$FRONTEND_URL" 2>/dev/null || echo "000")
  if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "301" ] || [ "$HTTP_CODE" = "302" ]; then
    ok "Запрос к $FRONTEND_URL вернул HTTP $HTTP_CODE"
  elif [ "$HTTP_CODE" = "502" ] || [ "$HTTP_CODE" = "503" ]; then
    fail "Запрос к $FRONTEND_URL вернул HTTP $HTTP_CODE (Bad Gateway/Service Unavailable)"
    info "Возможная причина: Traefik ожидает порт $TRAEFIK_PORT, а приложение слушает $EXPECTED_APP_PORT"
  elif [ "$HTTP_CODE" = "000" ]; then
    warn "Не удалось подключиться к $FRONTEND_URL (таймаут/DNS/сеть)"
  else
    warn "Запрос к $FRONTEND_URL вернул HTTP $HTTP_CODE"
  fi
  echo ""

  # 6. LiveKit (опционально)
  echo "--- RTC (LiveKit) ---"
  RTC_CODE=$(curl -s -o /dev/null -w "%{http_code}" -k --connect-timeout 5 "$RTC_URL" 2>/dev/null || echo "000")
  if [ "$RTC_CODE" != "000" ]; then
    info "Запрос к $RTC_URL вернул HTTP $RTC_CODE"
  else
    warn "Не удалось подключиться к $RTC_URL"
  fi
  echo ""

  echo "=== Диагностика завершена ==="
}

if [ "$1" = "--remote" ]; then
  echo "Выполнение диагностики на удалённом сервере $REMOTE_HOST..."
  echo ""
  ssh "$REMOTE_HOST" "bash -s" < "$SCRIPT_DIR/diagnose-meet-frontend.sh"
else
  run_checks
fi
