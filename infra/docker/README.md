# LiveKit Meet — Docker

Инфраструктура для запуска LiveKit Meet в Docker. Self-hosted, без Cloud, без аналитики и записи.

## Требования

- Docker
- Docker Compose

## Dev (локальная разработка)

```bash
cd infra/docker
docker compose up
```

- **Фронт**: http://localhost
- **LiveKit**: ws://localhost:7880

### Порты

| Порт | Назначение |
|------|------------|
| 80 | nginx → web (фронт) |
| 7880 | LiveKit WebSocket (сигнализация) |
| 7881 | LiveKit ICE over TCP |
| 50000–50100/udp | LiveKit WebRTC media |

## Prod

```bash
cd infra/docker
docker compose -f docker-compose.prod.yml up -d
```

Требуется сеть `app_network` и Traefik.

### Образы

- **meet-frontend:latest** — предсобранный образ фронта
- **livekit/livekit-server:latest** — официальный образ LiveKit

### Сборка meet-frontend

```bash
cd infra/docker
docker compose build web
```

Образ будет помечен как `meet-frontend:latest`.

Или из корня проекта:

```bash
docker build -f infra/docker/services/web/Dockerfile -t meet-frontend:latest .
```

Примечание: если фоновые изображения в `public/background-images/` — Git LFS указатели, сборка автоматически подтянет их с Unsplash.

### Сеть app_network

Перед запуском prod создайте сеть:

```bash
docker network create app_network
```

## Env

Скопируйте `.env.example` в `.env` и настройте:

```env
LIVEKIT_URL=ws://localhost:7880
```

Для prod в `meet-frontend` передаётся `LIVEKIT_URL=wss://rtc.meet.limpopo113.ru` (или ваш поддомен).

Ключи для JWT — в `configs/livekit/livekit.yaml` (секция `keys`). Для dev: `devkey: secret`. Приложение получает их через env (LIVEKIT_API_KEY, LIVEKIT_API_SECRET) — значения должны совпадать с livekit.yaml. В prod добавьте эти переменные в окружение meet-frontend, если используете стандартный LiveKit Meet.

## Конфиги

- **configs/livekit/livekit.yaml** — конфиг LiveKit-сервера
- **configs/nginx/default.conf** — nginx для фронта (dev)

## Prod-настройка

1. **Домен**: замените `meet.limpopo113.ru` и `rtc.meet.limpopo113.ru` на свои в `docker-compose.prod.yml`
2. **Traefik**: entrypoints `websecure`, certresolver `letsencrypt`
3. **livekit.yaml**: для prod установите `use_external_ip: true` или `node_ip` с публичным IP сервера. Без этого ICE-кандидаты могут быть некорректными.
4. **DNS**: добавьте A-записи для `meet.*` и `rtc.*` на IP сервера

## Архитектура

**Dev**: Browser → nginx:80 → web:3000 | Browser → livekit:7880

**Prod**: Browser → Traefik → meet-frontend:80 | Browser → Traefik → meet-livekit:7880 (wss) | Browser → meet-livekit:7881,50000–50100 (WebRTC media)
