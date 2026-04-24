# Build stage
FROM node:20-alpine AS builder
WORKDIR /app

RUN apk add --no-cache openssl

COPY package*.json ./
RUN npm ci

COPY . .
RUN ./node_modules/.bin/prisma generate
RUN npm run build

# Production stage
FROM node:20-alpine AS production
WORKDIR /app

RUN apk add --no-cache openssl

ENV NODE_ENV=production

COPY package*.json ./
RUN npm ci --omit=dev

COPY --from=builder /app/build ./build
COPY --from=builder /app/node_modules/.prisma ./node_modules/.prisma
COPY --from=builder /app/node_modules/@prisma ./node_modules/@prisma
# Copy prisma CLI from builder so CMD doesn't fall back to npx (which downloads
# a fresh copy with broken OpenSSL detection, picking the wrong engine binary)
COPY --from=builder /app/node_modules/prisma ./node_modules/prisma
COPY --from=builder /app/node_modules/.bin/prisma ./node_modules/.bin/prisma
COPY prisma ./prisma
COPY server.js ./server.js
RUN mkdir -p ./public
COPY --from=builder /app/public ./public

EXPOSE 3000

CMD ["sh", "-c", "./node_modules/.bin/prisma migrate deploy && npm run start"]
