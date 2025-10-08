# Stage 1: Dependencies
FROM node:18-alpine AS deps
WORKDIR /app
COPY package*.json ./
COPY prisma ./prisma
RUN npm ci --silent

# Stage 2: Builder
FROM node:18-alpine AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
ENV NEXT_TELEMETRY_DISABLED=1 \
  NODE_ENV=production
RUN apk add --no-cache openssl \
  && npx prisma generate \
  && npm run build

# Stage 3: Runner
FROM node:18-alpine AS runner
WORKDIR /app
ENV NEXT_TELEMETRY_DISABLED=1 \
  NODE_ENV=production \
  PORT=3000
RUN apk add --no-cache curl dumb-init openssl
RUN addgroup --system --gid 1001 nodejs \
  && adduser --system --uid 1001 nextjs
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./ 
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static
# COPY --from=builder --chown=nextjs:nodejs /app/public ./public
COPY --from=builder --chown=nextjs:nodejs /app/node_modules/.prisma ./node_modules/.prisma
USER nextjs
EXPOSE 3000
CMD ["dumb-init", "node", "server.js"]

# Stage 4: Migrator
FROM node:18-alpine AS migrator
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY package*.json ./
COPY prisma ./prisma
RUN apk add --no-cache openssl \
  && npx prisma generate
