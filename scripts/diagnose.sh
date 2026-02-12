#!/bin/bash

# Диагностика проекта на сервере через SSH
# Запускается локально, подключается к серверу

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/../" || exit 1

# Параметры подключения (как в deploy.sh)
REMOTE_HOST="${REMOTE_HOST:-root@77.222.52.134}"
REMOTE_PATH="${REMOTE_PATH:-/root/meet}"

echo "=== Статус контейнеров проекта на $REMOTE_HOST ==="
echo ""
ssh "$REMOTE_HOST" "cd $REMOTE_PATH && (docker compose ps 2>/dev/null || docker-compose ps 2>/dev/null)"
echo ""

echo "=== Нагрузка контейнеров (CPU, память, сеть, диск) ==="
echo ""
ssh "$REMOTE_HOST" "cd $REMOTE_PATH && CONTAINERS=\$(docker compose ps -q 2>/dev/null || docker-compose ps -q 2>/dev/null); [ -n \"\$CONTAINERS\" ] && docker stats --no-stream --format 'table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}' \$CONTAINERS || docker stats --no-stream --format 'table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}' \$(docker ps -q --filter 'name=meet-')"
echo ""

echo "=== Использование диска Docker ==="
ssh "$REMOTE_HOST" "docker system df"
