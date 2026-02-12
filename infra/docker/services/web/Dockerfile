FROM node:20-alpine AS base

RUN corepack enable && corepack prepare pnpm@10.18.2 --activate

FROM base AS deps
WORKDIR /app
COPY apps/web/package.json apps/web/pnpm-lock.yaml* ./
RUN pnpm install --frozen-lockfile

FROM base AS builder
RUN apk add --no-cache curl
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY apps/web ./
COPY --from=deps /app/package.json ./
COPY --from=deps /app/pnpm-lock.yaml* ./
RUN mkdir -p public/background-images && \
  ( [ "$(wc -c < public/background-images/ali-kazal-tbw_KQE3Cbg-unsplash.jpg 2>/dev/null || echo 0)" -lt 1000 ] && \
    curl -sL "https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=800" -o public/background-images/ali-kazal-tbw_KQE3Cbg-unsplash.jpg || true ) && \
  ( [ "$(wc -c < public/background-images/samantha-gades-BlIhVfXbi9s-unsplash.jpg 2>/dev/null || echo 0)" -lt 1000 ] && \
    curl -sL "https://images.unsplash.com/photo-1497366216548-37526070297c?w=800" -o public/background-images/samantha-gades-BlIhVfXbi9s-unsplash.jpg || true )
RUN pnpm build

FROM base AS runner
WORKDIR /app
ENV NODE_ENV=production
ENV PORT=3000
ENV HOSTNAME="0.0.0.0"

RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

COPY --from=builder /app/public ./public
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

USER nextjs
EXPOSE 3000

CMD ["node", "server.js"]
