# Build stage
FROM node:20-alpine AS builder
WORKDIR /app

RUN apk add --no-cache openssl

COPY package*.json ./
RUN npm ci

# Copy Prisma schema early for better layer caching:
# prisma generate is re-run only when the schema changes, not on every code change.
COPY prisma ./prisma
RUN ./node_modules/.bin/prisma generate

COPY . .
RUN npm run build

# Production stage
FROM node:20-alpine AS production
WORKDIR /app

RUN apk add --no-cache openssl && chown node:node /app

USER node

ENV NODE_ENV=production

COPY --chown=node:node package*.json ./
RUN npm ci --omit=dev

COPY --from=builder --chown=node:node /app/build ./build
COPY --from=builder --chown=node:node /app/node_modules/.prisma ./node_modules/.prisma
COPY --from=builder --chown=node:node /app/node_modules/@prisma ./node_modules/@prisma
# Copy prisma CLI from builder so CMD doesn't fall back to npx (which downloads
# a fresh copy with broken OpenSSL detection, picking the wrong engine binary)
COPY --from=builder --chown=node:node /app/node_modules/prisma ./node_modules/prisma
COPY --from=builder --chown=node:node /app/node_modules/.bin/prisma ./node_modules/.bin/prisma
COPY --chown=node:node prisma ./prisma
COPY --chown=node:node server.js ./server.js
COPY --from=builder --chown=node:node /app/public ./public

EXPOSE 3005

HEALTHCHECK --interval=30s --timeout=5s --start-period=40s --retries=3 \
    CMD ["node", "-e", "require('http').get('http://localhost:3005/', (r) => process.exit(r.statusCode >= 500 ? 1 : 0)).on('error', () => process.exit(1))"]

CMD ["sh", "-c", "./node_modules/.bin/prisma migrate deploy && npm run start"]
