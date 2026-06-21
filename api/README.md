# Namoro Cristão — API

Backend em **Node + TypeScript + Express + Prisma + PostgreSQL + Socket.io**.
Atende o **app (Flutter)** e o **painel admin (React/TS)**.

## Como rodar (dev)

```sh
# 1) Subir Postgres + Redis (Docker)
docker compose up -d

# 2) Instalar deps
npm install

# 3) Variáveis de ambiente
copy .env.example .env   # (Windows)  — ajuste se necessário

# 4) Criar/atualizar tabelas
npx prisma migrate dev

# 5) Subir a API (hot reload)
npm run dev
# http://localhost:3333/api/health
```

- Postgres: `localhost:5433` (user `namoro` / senha `namoro` / db `namoro_cristao`).
- Em dev, os **códigos OTP de e-mail são impressos no console** (sem SMTP real).
- Login com Google só funciona após definir `GOOGLE_CLIENT_IDS` no `.env`
  (sem isso, `/api/auth/google` responde 503).

## Estrutura

```
api/
├── docker-compose.yml         postgres (5433) + redis (6380)
├── prisma/schema.prisma       modelo de dados completo
├── src/
│   ├── config/                env (Zod) + prisma client
│   ├── lib/                    jwt, password (argon2), email, errors
│   ├── middlewares/            auth (requireUser/requireAdmin), errorHandler
│   ├── services/               otp.service, google.service
│   ├── modules/auth/           controllers + rotas (app e admin)
│   ├── routes/index.ts         monta as rotas + /health
│   ├── app.ts                  express (helmet, cors, json)
│   └── server.ts               http + socket.io
```

## Autenticação

JWT com par **access** (15m) + **refresh** (30d). Enviar o access no header:
`Authorization: Bearer <token>`. O payload tem `{ sub, type }` onde `type` é
`user` (app) ou `admin` (painel).

### Endpoints do APP — base `/api/auth`
| Método | Rota | Body | Descrição |
|--------|------|------|-----------|
| POST | `/register` | `{ email, password }` | Cadastro por e-mail/senha |
| POST | `/login` | `{ email, password }` | Login por senha |
| POST | `/request-code` | `{ email }` | Envia código OTP (login sem senha) |
| POST | `/login-code` | `{ email, code }` | Login/cadastro por código |
| POST | `/google` | `{ idToken }` | Login com Google (valida ID token) |
| POST | `/refresh` | `{ refreshToken }` | Renova os tokens |
| GET | `/me` | — (Bearer) | Dados do usuário + perfil |

Respostas de login retornam: `{ user, accessToken, refreshToken, hasProfile }`.
`hasProfile=false` → o app manda o usuário para o onboarding.

### Endpoints do PAINEL — base `/api/admin/auth`
| Método | Rota | Body | Descrição |
|--------|------|------|-----------|
| GET | `/needs-setup` | — | `true` se ainda não há nenhum admin |
| POST | `/register-super` | `{ name, email, password }` | Cria o 1º super-admin (só se não houver admin) |
| POST | `/login` | `{ email, password }` | Login do admin |
| POST | `/refresh` | `{ refreshToken }` | Renova os tokens |
| GET | `/me` | — (Bearer) | Dados do admin |

## Próximos módulos (a implementar)
Perfil/onboarding, descoberta/match, chat (Socket.io), moderação (denúncia/bloqueio/ban),
verificação, notificações (FCM), feeds, app settings, e os endpoints de leitura do painel
(dashboard, usuários, etc.).
