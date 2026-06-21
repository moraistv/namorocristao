# ---------- build ----------
FROM node:20-bookworm AS build
WORKDIR /app

# Instala dependências (inclui devDeps p/ compilar TS e gerar Prisma Client)
COPY package*.json ./
RUN npm ci

# Código + schema
COPY tsconfig.json ./
COPY prisma ./prisma
COPY src ./src

# Prisma Client + build TypeScript
RUN npx prisma generate
RUN npm run build

# ---------- runtime ----------
FROM node:20-bookworm-slim AS runtime
WORKDIR /app
ENV NODE_ENV=production

# openssl é necessário ao Prisma em runtime
RUN apt-get update && apt-get install -y --no-install-recommends openssl \
    && rm -rf /var/lib/apt/lists/*

# Copia node_modules (com prisma CLI + client gerado), build e schema
COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/dist ./dist
COPY --from=build /app/prisma ./prisma
COPY package*.json ./

# Pasta de uploads (montada como volume no compose)
RUN mkdir -p /app/uploads

EXPOSE 3333

# Aplica migrações pendentes e sobe a API
CMD ["sh", "-c", "npx prisma migrate deploy && node dist/server.js"]
