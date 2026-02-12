#!/bin/bash

# Устанавливаем путь скрипта
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Переходим в корень проекта
cd "$SCRIPT_DIR/../" || exit 1

# Параметры подключения
REMOTE_HOST="root@77.222.52.134"
REMOTE_PATH="/root/meet"

# Директория с Docker-конфигурацией
INFRA_DIR="infra/docker"

# Имя образа
IMAGE_NAME="meet-frontend:latest"
IMAGE_TAR="meet-frontend.tar"

set -e

echo "=== Сборка Docker-образа (linux/amd64) ==="
cd "$INFRA_DIR" || exit 1
docker build --platform linux/amd64 -t "$IMAGE_NAME" -f services/web/Dockerfile ../..
if [ $? -eq 0 ]; then
  echo "✓ Образ $IMAGE_NAME успешно собран"
else
  echo "✗ Ошибка при сборке образа"
  exit 1
fi

echo ""
echo "=== Сохранение образа в tar-файл ==="
docker save "$IMAGE_NAME" -o "$IMAGE_TAR"
if [ $? -eq 0 ]; then
  echo "✓ Образ сохранён в $IMAGE_TAR"
else
  echo "✗ Ошибка при сохранении образа"
  exit 1
fi

cd "$SCRIPT_DIR/../" || exit 1

echo ""
echo "=== Создание временной директории для деплоя ==="
DEPLOY_DIR=$(mktemp -d)
cp "$INFRA_DIR/$IMAGE_TAR" "$DEPLOY_DIR/"
cp "$INFRA_DIR/docker-compose.prod.yml" "$DEPLOY_DIR/"
cp -r "$INFRA_DIR/configs" "$DEPLOY_DIR/"

# Копируем .env.production если существует
if [ -f "$INFRA_DIR/.env.production" ]; then
  cp "$INFRA_DIR/.env.production" "$DEPLOY_DIR/"
fi

echo ""
echo "=== Отправка файлов на сервер $REMOTE_HOST:$REMOTE_PATH ==="
ssh "$REMOTE_HOST" "mkdir -p $REMOTE_PATH"
scp -r "$DEPLOY_DIR"/* "$REMOTE_HOST:$REMOTE_PATH/"
rm -rf "$DEPLOY_DIR"

# Удаляем локальный tar после отправки
rm -f "$INFRA_DIR/$IMAGE_TAR"

if [ $? -eq 0 ]; then
  echo "✓ Файлы успешно отправлены"
else
  echo "✗ Ошибка при отправке файлов"
  exit 1
fi

echo ""
echo "=== Загрузка образа и запуск контейнеров на сервере ==="
ssh "$REMOTE_HOST" "cd $REMOTE_PATH && \
  docker load -i $IMAGE_TAR && \
  rm -f $IMAGE_TAR && \
  cp docker-compose.prod.yml docker-compose.yml && \
  ([ -f .env.production ] && cp .env.production .env || true) && \
  docker compose up -d"

if [ $? -eq 0 ]; then
  echo ""
  echo "✓ Деплой успешно завершён!"
else
  echo "✗ Ошибка при загрузке образа или запуске контейнеров"
  exit 1
fi
