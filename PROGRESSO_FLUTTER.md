# PROGRESSO — Namoro Cristão (Flutter + VPS)

> Documento vivo da **nova fase** do projeto. O app agora é **Flutter** (template
> "mio amore" adaptado), e **não usaremos Firebase** — todo o backend roda na **VPS própria**.
> O `PROGRESSO.md` antigo é da versão React Native (descontinuada).
> Última atualização: 16/06/2026

---

## Decisões travadas (nova fase)

| Tema | Decisão |
|------|---------|
| App | **Flutter** (Dart) — base no template "mio amore" (`aplicativo/`) |
| Backend | **VPS própria** — **sem Firebase** (nada de Firestore/Auth/Storage/Functions) |
| Painel admin | Flutter Web (`painel/`) — também apontará para a API da VPS |
| Login | **Google** + **E-mail** |
| Login REMOVIDO | **Telefone/SMS** (não usar) |
| Login adiado | **Facebook** (ainda não — talvez depois) |
| Cores | **Dourado #D4AF37** (claro) / **#E1C04A** (escuro) + **Navy #111D40** (apoio) |
| Tema | Namoro cristão (dourado = "cor da Bíblia") |
| Idioma | Português (Brasil) |

---

## ⚠️ Pontos de atenção (decidir antes de codar)

1. **Push notifications sem Firebase:** no Android, o envio de push quase sempre passa
   pelo **FCM** (serviço do Google), mesmo com backend próprio; no iOS, pelo **APNs**.
   "Sair do Firebase 100%" não elimina o FCM/APNs para *entrega* de push.
   - **Opção A (recomendada):** manter **só o FCM para push** (gratuito, não exige Firestore),
     e todo o resto (dados, auth, storage) na VPS.
     => continuamos usando `firebase_messaging` apenas para receber o token e as mensagens.
   - **Opção B:** push via WebSocket quando o app está aberto + e-mail para o resto
     (sem push em background). Mais simples, porém sem notificação com o app fechado.
   - **Decisão do usuário:** _(pendente)_

2. **Chat em tempo real:** Firestore fazia isso "de graça" com streams. Na VPS usaremos
   **WebSocket (Socket.io)** — já tínhamos isso pronto no backend Node anterior.

3. **Reaproveitar o backend Node anterior:** a versão React Native tinha um backend
   **Node + TypeScript + Express + Prisma + PostgreSQL + Socket.io** já completo
   (auth e-mail/código/senha/Google, perfil com campos cristãos, descoberta/match, chat,
   monetização, moderação, push, LGPD). **Esse backend serve quase 1:1 para a VPS.**
   Plano: ressuscitá-lo/portá-lo como a API da VPS e ligar o app Flutter nele.

---

## Mapa: Firebase (hoje) → VPS (destino)

| Recurso no app hoje | Pacote Flutter | Destino na VPS |
|--------------------|----------------|----------------|
| Autenticação | `firebase_auth`, `google_sign_in` | API `/auth` (JWT) + Google ID token validado no servidor |
| Banco de dados | `cloud_firestore` | API REST + **PostgreSQL** |
| Tempo real (chat/presença) | streams do Firestore | **WebSocket (Socket.io)** |
| Mídia/fotos | `firebase_storage` | Upload na API → **S3/MinIO** (ou disco da VPS) |
| Push | `firebase_messaging` | FCM só para entrega (Opção A) + disparo pela API |
| Cloud Functions | `cloud_functions/` | Lógica movida para a API da VPS |

### Coleções Firestore em uso (a virar tabelas/endpoints)
`userProfile`, `userInteraction`, `matches` (+ subcoleção `chat`), `verificationForms`,
`feeds`, `deviceTokens`, `notifications`, `blockedUsers`, `reports`, `bannedUsers`,
`accountDeleteRequest`, `appSettings`.

---

## Modelo de usuário — campos a ACRESCENTAR (tema cristão)

Hoje (`lib/models/user_profile_model.dart`): `fullName, gender, about, myPurpose,
interests[], mediaFiles[], birthDay, isVerified, isOnline`, + usernames de redes sociais.

Faltam (do app cristão anterior):
- **denominação** (ex.: Católica, Batista, Assembleia, Presbiteriana, etc.)
- **frequência à igreja** (ex.: toda semana, às vezes, raramente)
- **intenção** (namoro sério, amizade, casamento)
- **cidade** (para exibir no card)
- interesses com sabor cristão (louvor, estudo bíblico, missões, etc.)

> `myPurpose` já existe e pode virar a "intenção".

---

## Estrutura atual das pastas

```
NAMOROCRISTAO/
├── aplicativo/        → app Flutter (mioamoreapp) — Firebase hoje, VPS depois
│   └── lib/{config,helpers,models,providers,views}
├── painel/            → admin Flutter Web (mioamoreadmin) — Firebase hoje, VPS depois
├── cloud_functions/   → Firebase Functions (push) — a migrar para a API da VPS
└── mio amore - developer documentation (1).docx → doc oficial do template
```

### Onde mexer para rebrand (cores/nome) no app
- `lib/config/config.dart` → `appName`, `primaryColor` (hoje rosa `#EC1E79`)
- `lib/helpers/constants.dart` → `primaryColor`, gradiente, logo
- `lib/main.dart` → tema (primarySwatch, AppBar)
- `assets/images/` (logo, splash), `flutter_native_splash` no `pubspec.yaml`

---

## Plano de migração (rascunho — fases)

- [ ] **Fase 0 — Rebrand visual:** trocar cores para dourado/navy, nome, logo, splash.
- [ ] **Fase 1 — API da VPS:** portar o backend Node/Prisma anterior; subir PostgreSQL.
- [ ] **Fase 2 — Auth:** Google + e-mail no app, falando com a API (remover phone/SMS).
- [ ] **Fase 3 — Camada de dados:** trocar providers de Firestore por HTTP (REST) na VPS.
- [ ] **Fase 4 — Chat/tempo real:** WebSocket no lugar dos streams do Firestore.
- [ ] **Fase 5 — Mídia:** upload de fotos para S3/MinIO via API.
- [ ] **Fase 6 — Push:** decidir Opção A/B e ligar.
- [ ] **Fase 7 — Campos cristãos:** modelo + telas de perfil/onboarding + filtros.
- [ ] **Fase 8 — Painel admin:** apontar para a API da VPS.

---

## Decisões confirmadas pelo usuário (16/06/2026)
- **Push:** Opção A — manter **só o FCM para entrega** (resto tudo na VPS).
- **E-mail:** os **dois** — login por **senha** E por **código (OTP)**.
- **Backend:** **API nova** (não reaproveitar a anterior). **Docker já instalado e aberto.**
- **Ordem:** começar pelo **app (rebranding)** primeiro; backend depois.
- Usuário quer rodar via **Android Studio + celular físico** p/ ver em tempo (quase) real.

## Estado do Flutter (diagnóstico 16/06/2026)
- Flutter **3.29.2** (em `C:\dev\flutter`), Dart 3.7.2. `flutter pub get` OK.
- `flutter analyze`: **código saudável** — só 2 erros, ambos por falta do
  `lib/firebase_options.dart` (arquivo do Firebase, que não existe e **não queremos**),
  + 1 aviso de `print`.
- **Estratégia de boot durante a migração:** o app sobe **sem Firebase** (flag
  `kBackendReady = false` no `main.dart`) e vai direto para a tela de **Login** — assim dá
  pra ver o rebrand no celular sem precisar de backend. Quando a API da VPS estiver pronta,
  religamos auth/dados apontando para ela (e o FCM para push).

## Rebrand — Fase 0 (em andamento)
- `config.dart`: `appName` = "Namoro Cristão"; `primaryColor` = **#D4AF37**;
  `isPhoneAuthAvailable=false`, `isFacebookAuthAvailable=false`, `isGoogleAuthAvailable=true`.
- Logo/splash ainda são os do template "mio amore" (rosa) — trocar quando houver arte nova.
- Login por e-mail (senha+OTP) entra na **Fase 2** junto com a API.

## ✅ Build rodando no celular físico + rebrand inicial — 16/06/2026

App **compilando e rodando no Galaxy S23 (Android 16) via WiFi** (depuração sem fio).
Bundle id definido: **com.winup.namoro**.

### Conexão do dispositivo (WiFi / wireless debugging)
- adb em `%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe`.
- Parear: `adb pair <IP>:<portaPareamento> <codigo>` → depois aparece via mDNS.
- Device id no Flutter: `adb-RXCW304QK5L-pKAT8Z._adb-tls-connect._tcp`.
- Rodar: `flutter run -d <deviceId> --debug`.

### Correções de build do Android (template "mio amore" era antigo)
Migrado para **Gradle 8.7 + AGP 8.3 + Kotlin 1.9.22** (Java 21 do Android Studio exige isso).
Arquivos: `android/settings.gradle` (pluginManagement+plugins), `android/build.gradle`,
`android/app/build.gradle` (namespace `com.winup.namoro`, compileSdk 35, minSdk 23),
`gradle-wrapper.properties` (8.7), `gradle.properties` (jvmargs 4G).
Patches no `android/build.gradle` (subprojects.afterEvaluate) p/ plugins antigos:
- **namespace-patch**: injeta `namespace` em plugins sem ele (ex.: `record`) — exigência do AGP 8.
- **remove `-Werror`**: plugins como `video_player_android` quebravam no JDK 21 pelo aviso
  "source value 8 is obsolete" (registrado no afterEvaluate + doFirst p/ rodar por último).
- Removido `package="your_app_bundle_id"` dos manifests `debug/` e `profile/` (conflitava
  com o namespace).
- AdMob `APPLICATION_ID` trocado p/ o id de teste do Google (placeholder crashava no startup).

### Rebrand (Fase 0) aplicado
- `config.dart`: nome "Namoro Cristão", `primaryColor` #D4AF37, só Google ligado
  (telefone/Facebook desativados), flag `kBackendReady=false`.
- `main.dart`: app sobe **sem Firebase**; tela de **splash interna** feita em código —
  fundo navy #111D40 + ícone/coração branco + "Namoro Cristão" (logo branca por código).
- Splash **nativo** (flutter_native_splash) trocado de imagem rosa p/ **cor navy sólida**.
- `login_page.dart`: logo rosa substituída por cabeçalho (ícone dourado + nome navy +
  "Conexões com propósito e fé"); adicionado botão **Entrar com e-mail** (placeholder até a
  API); textos de termos traduzidos p/ PT-BR. Google e e-mail mostram aviso "chega na
  próxima fase" enquanto `kBackendReady=false`.

### Observações
- Logo/ícone do app (launcher) e arte de marca ainda são placeholders — falta arte definitiva.
- Logs de WebView ("Missing scheme in uri") aparecem por causa do fluxo antigo de termos/versão
  — inofensivo por enquanto.

**Próximo:** continuar rebrand/telas internas e iniciar a **API nova na VPS** (Docker) —
auth Google + e-mail (senha+OTP), depois migrar a camada de dados (Firestore → REST/WebSocket).

## 🧠 Estudo do painel admin Flutter (referência) + decisão TS — 16/06/2026

O `painel/` (Flutter "mioamoreadmin", fluent_ui + Firebase) foi estudado e **será
substituído por um painel em TypeScript** (React + Vite). Mantido por ora só como
referência funcional (não apagar ainda).

Funcionalidades do admin (a replicar no painel TS):
- Auth: registro do 1º **super-admin** + login. Admin tem `permissions[]`
  (Verification, Report, Account Delete) e `isSuperAdmin`.
- **Dashboard**: total de usuários (M/F), verificados, interações (like/dislike/superlike),
  matches, dispositivos logados, denúncias, banidos, verificações pendentes, exclusões.
- **Usuários** (lista+detalhe), **Verificações** (aprovar/rejeitar com selfie),
  **Denúncias** + **Banir**, **Pedidos de exclusão de conta**, **Admins**,
  **Configurações** (appSettings: `isChattingEnabledBeforeMatch`; trocar email/nome/senha).

## 🏗️ Arquitetura definida (TypeScript ponta a ponta)
- **API** (`api/`): Node + TS + **Express + Prisma + PostgreSQL + Socket.io** + JWT + Zod.
  Central — consumida pelo **app Flutter** e pelo **painel**. Push via FCM (Opção A).
- **Painel admin** (`painel/` será TS depois): **React + Vite + TS**, tempo real (Socket.io).
- **Postgres/Redis** via Docker.
- Auth: app = Google + e-mail (senha+OTP); painel = e-mail/senha (admins).

**Em construção:** esqueleto da API em `api/`.

## ✅ API — fundação + módulo de Autenticação completo — 16/06/2026

API criada em `api/` (**Node + TS + Express + Prisma + PostgreSQL + Socket.io + JWT + Zod**),
**rodando e testada de ponta a ponta**. Doc detalhada em `api/README.md`.

### Infra
- Docker (`api/docker-compose.yml`): **Postgres** em `localhost:5433` (user/senha/db =
  namoro/namoro/namoro_cristao) + **Redis** em `localhost:6380`. Portas alteradas p/ não
  conflitar com serviços locais.
- `.env` configurado; segredos JWT de dev (trocar em produção).
- Migrations aplicadas: `init` (todas as tabelas) + `auth_email_codes` (tabela de OTP).
- `npm run dev` (tsx watch) sobe em `http://localhost:3333`. `npm run lint` = `tsc --noEmit` (limpo).

### Modelo de dados (Prisma) — tabelas
`users`, `profiles` (campos cristãos: denomination, churchFrequency, intention, city,
interests[], mediaFiles[], localização, redes sociais, isVerified, isOnline),
`admins` (permissions[] + isSuperAdmin), `interactions` (LIKE/DISLIKE/SUPERLIKE),
`matches`, `messages` (TEXT/IMAGE/AUDIO/GIFT), `verification_forms`, `reports`, `blocks`,
`banned_users`, `account_delete_requests`, `device_tokens`, `notifications`, `feeds`,
`app_settings`, `email_codes` (OTP).

### Autenticação implementada (JWT access 15m + refresh 30d)
**App** (`/api/auth`): `register`, `login` (senha), `request-code` + `login-code` (OTP por
e-mail), `google` (valida ID token via google-auth-library), `refresh`, `me`.
- Login por código também **cadastra** se o e-mail ainda não existe.
- Google: cria usuário ou **vincula** googleId a conta de e-mail existente.
- Respostas trazem `hasProfile` (decide onboarding no app).
- Conta banida (`banned_users`) é bloqueada no login.

**Painel** (`/api/admin/auth`): `needs-setup`, `register-super` (1º super-admin, bloqueia se
já houver admin), `login`, `refresh`, `me`. Admin nasce com todas as permissões.

Bibliotecas: `lib/jwt.ts` (sign/verify), `lib/password.ts` (argon2), `lib/email.ts`
(loga código no dev), `services/otp.service.ts` (código de 6 dígitos, hash argon2,
expira em 10min, uso único), `services/google.service.ts`. Middlewares
`requireUser`/`requireAdmin`.

### Testado (todos OK)
- Admin: needs-setup → register-super → 2º registro bloqueado (403) → login → me.
- App: register → login(senha) → me → request-code (código no log) → login-code →
  refresh; código inválido rejeitado (400).

### Credenciais de teste criadas (banco dev)
- **Admin**: `admin@namoro.com` / `admin12345` (super-admin).
- **App**: `maria@teste.com` / `123456` (senha); `joao@teste.com` (criado via código OTP).

### Pendências/notas
- Google login exige `GOOGLE_CLIENT_IDS` no `.env` (senão 503) — ligar quando tiver os IDs.
- Refresh é **stateless** (sem revogação/blacklist ainda) — logout é client-side por ora.
- Socket.io já inicializado (sem handlers de chat ainda).

**Próximo:** módulos de **perfil/onboarding**, **descoberta/match**, **chat (Socket.io)**,
moderação, verificação, notificações (FCM), e endpoints de leitura do **painel** (dashboard,
usuários). Depois, ligar o **app Flutter** (`kBackendReady=true`) e iniciar o **painel React**.

## ✅ App Flutter ligado à API (login por e-mail) — 16/06/2026

Login por e-mail do app **conectado à API real** (sem Firebase). Como o resto do app ainda
é Firebase, após logar mostramos uma tela de sucesso (prova de integração no device).

- `lib/config/api_config.dart`: `baseUrl = http://192.168.3.253:3333/api` (IP do PC na LAN;
  trocar pela VPS depois).
- `lib/services/token_storage.dart`: guarda access/refresh/email no **Hive**.
- `lib/services/auth_api.dart`: `register`, `login`, `requestCode`, `loginWithCode` (http).
- `lib/views/auth/email_auth_page.dart`: tela de e-mail (entrar/criar conta), tela de
  **código OTP** e **LoggedInPage** (sucesso, navy + dourado, com botão Sair).
- `login_page.dart`: botão "Entrar com e-mail" agora abre o fluxo real.
- `main.dart`: auto-login — se há sessão salva (`TokenStorage.isLoggedIn`), splash vai direto
  pra `LoggedInPage`.
- **Firewall**: regra inbound TCP 3333 criada ("Namoro API 3333").

### Como testar no celular (com a API rodando — `cd api; npm run dev`)
- Abrir app → "Entrar com e-mail".
- **Senha**: `maria@teste.com` / `123456` (ou "Criar conta" com e-mail novo).
- **Código**: digitar e-mail → "Entrar com código" → o código de 6 dígitos aparece no
  **console da API** (em dev) → digitar na tela → entra.
- Sucesso → tela "Login realizado!". "Sair" limpa a sessão.

**Próximo:** continuar a API — perfil/onboarding, descoberta/match, chat (Socket.io),
moderação, verificação, notificações — e depois migrar a camada de dados do app + painel React.

## ✅ API — Perfil + Descoberta/Match + Chat — 16/06/2026

Mais três módulos prontos e **testados de ponta a ponta** (todos com `tsc` limpo).

### Perfil / Onboarding (`/api/me`, requer usuário)
- `GET /me/profile` — perfil atual (ou null).
- `PUT /me/profile` — cria/atualiza (upsert). Valida **idade ≥ 18**. Campos: fullName,
  gender, birthday, about, intention, denomination, churchFrequency, city, interests[],
  mediaFiles[], profilePicture, redes sociais.
- `PUT /me/location` — lat/long/addressText.
- `POST /me/online` — presença (isOnline + lastActiveAt).

### Descoberta / Match (`/api`, requer usuário)
- `GET /discovery?minAge&maxAge&maxDistanceKm` — candidatos, excluindo já avaliados,
  bloqueados (2 sentidos), banidos e o próprio. Retorna card com **idade, cidade,
  distância (Haversine), matchPercent** (55 base + interesses×8 + mesma denominação +14 +
  mesma frequência +8, clamp 40–99). Ordenado por compatibilidade. `needsProfile=true` se
  o usuário ainda não tem perfil.
- `POST /swipe` — `{ toUserId, type: LIKE|DISLIKE|SUPERLIKE }`. Cria interação; se houver
  reciprocidade (LIKE/SUPERLIKE), cria **Match** e emite `match:new` via Socket.io aos dois.
- `GET /matches` — matches ativos com dados do outro + última mensagem + não-lidas.

### Chat (`/api/matches/:matchId/messages` + Socket.io)
- REST: `GET` histórico (paginado por `before`/`limit`), `POST` enviar, `POST /read` marcar lido.
- **Socket.io** (`src/sockets/index.ts`): autentica no handshake (JWT access, type user),
  sala pessoal `user:<id>` e sala por match `match:<id>`. Eventos:
  `match:join` (entra + marca lido), `match:leave`, `message:send` (persiste e entrega em
  tempo real ao match e ao destinatário), `message:read`, `typing`. Match novo dispara
  `match:new` na sala pessoal.
- Regras: só membros do match ativo; bloqueio em qualquer sentido impede a conversa.

### Teste executado (OK)
alice2 e bob2 → perfis → discovery (alice vê bob, matchPercent calculado) → swipe LIKE
recíproco → **match criado** → alice manda "Oi Bob, graça e paz!" → bob lê histórico (1 msg)
→ marca como lido (`marked:1`).

### Rotas montadas em `routes/index.ts`
`/auth` (app), `/admin/auth` (painel), `/me` (perfil), `/` (discovery/swipe/matches),
`/matches` (chat). Health em `/api/health`.

## ✅ API — Moderação + Verificação + Dispositivos + Painel (admin) — 16/06/2026

Mais quatro módulos prontos e **testados** (`tsc` limpo). Com isso a API já cobre o núcleo
do app e dá suporte total ao painel admin.

### Moderação (app, `/api`, requer usuário)
- `POST /reports` `{ reportedId, reason }` — denúncia (não pode denunciar a si).
- `GET /blocks` / `POST /blocks` `{ blockedId }` / `DELETE /blocks/:blockedId` — bloqueio;
  bloquear **encerra o match** entre os dois.
- `POST /me/delete-request` / `DELETE /me/delete-request` — pedido de exclusão (LGPD) + cancelar.

### Verificação (app, `/api/me/verification`)
- `POST /` `{ selfieUrl }` — envia selfie p/ verificação (status PENDING).
- `GET /` — status da última verificação.

### Dispositivos / Notificações (app, `/api`)
- `POST /devices` `{ token, platform }` / `DELETE /devices` — token FCM (push, Opção A).
- `GET /notifications` / `POST /notifications/:id/read`.

### Painel admin (`/api/admin`, requer admin; permissões por ação)
- `GET /dashboard` — contadores: usuários (total/M/F/verificados), interações
  (likes/dislikes/superlikes), matches, dispositivos, denúncias, banidos, verificações
  pendentes, pedidos de exclusão.
- `GET /users?search=&take=&skip=` / `GET /users/:userId` (detalhe + stats).
- `POST /users/:userId/ban` `{ reason }` / `DELETE /users/:userId/ban` — banir/desbanir
  (permissão REPORT); banir encerra matches e marca `isBanned`.
- `GET /reports?status=` / `POST /reports/:id` `{ status }` (permissão REPORT).
- `GET /verifications?status=` / `POST /verifications/:id/review` `{ approve }`
  (permissão VERIFICATION); aprovar marca o perfil como `isVerified`.
- `GET /account-delete-requests` / `POST /account-delete-requests/:userId/process`
  (permissão ACCOUNT_DELETE) — **anonimiza** a conta (LGPD): apaga perfil/tokens, encerra
  matches, zera e-mail/senha/googleId, marca `deletedAt` e a solicitação como DONE.
- `GET /settings` / `PUT /settings` `{ isChattingEnabledBeforeMatch }`.
- `GET /admins` / `POST /admins` `{ name, email, password, permissions[] }` /
  `DELETE /admins/:id` — **só super-admin**; não remove super-admin.

Helpers: `lib/adminPermission.ts` (`assertPermission`, `assertSuperAdmin`).

### Testado (OK)
- Admin: dashboard, settings get/put, users list (idade calculada), detalhe + stats.
- App: verificação submit/status, device register, report, notifications.
- Ciclo admin: listar verificação PENDING → aprovar → **perfil vira verificado**.

### Estado da API (resumo)
Módulos prontos: **auth (app+admin), perfil/onboarding, descoberta/match, chat
(REST+Socket.io), moderação, verificação, dispositivos/notificações, painel admin**.
Faltam (próximos): envio real de **push FCM** (precisa server key), **feeds**, premium/IAP,
exportação LGPD, e revogação de refresh token.

**Próximo:** iniciar o **painel admin em React + Vite + TS** consumindo esses endpoints
(login admin → dashboard → usuários → denúncias → verificações → settings), com tempo real.

## ✅ Painel admin em React + Vite + TS (`painel-web/`) — 16/06/2026

Painel web criado **do zero em TypeScript** (substitui o `painel/` Flutter, que fica só de
referência e pode ser apagado). **Build OK** (vite) e **dev server no ar** em
`http://localhost:5173`.

### Stack e estrutura
- React 18 + Vite 5 + React Router 6, sem libs de UI (CSS próprio, tema dourado/navy).
```
painel-web/
├── index.html, vite.config.ts, tsconfig.json, package.json
└── src/
    ├── theme.css        cores (gold #D4AF37 / navy #111D40), botões, tabela, cards, badges
    ├── api.ts           cliente fetch + tokens (localStorage) + refresh automático no 401
    ├── auth.tsx         AuthProvider/useAuth (needs-setup, login, registerSuper, me, logout)
    ├── main.tsx, App.tsx (rotas protegidas; sem admin → Login)
    ├── components/Layout.tsx  (sidebar navy + navegação + sair)
    └── pages/  Login, Dashboard, Users, Reports, Verifications, Settings
```

### Telas prontas
- **Login**: detecta 1º acesso (`/admin/auth/needs-setup`) → mostra criação do super-admin;
  senão, login normal. Guarda tokens e renova sozinho.
- **Dashboard**: cards com todos os contadores de `/admin/dashboard`.
- **Usuários**: busca, lista (nome, e-mail, sexo, idade, cidade, status), **banir/desbanir**.
- **Denúncias**: lista + marcar Revisado/Descartar.
- **Verificações**: grid de selfies pendentes + **Aprovar/Rejeitar**.
- **Configurações**: toggle "conversa antes do match" (`/admin/settings`).

### Como acessar
1. API rodando (`cd api; npm run dev`) e Postgres no Docker.
2. Painel: `cd painel-web; npm run dev` → abrir `http://localhost:5173`.
3. Login: **admin@namoro.com** / **admin12345** (super-admin já criado).
- CORS liberado p/ `http://localhost:5173` no `.env` da API.

### Pendências do painel (próximas)
Detalhe do usuário (modal/página), pedidos de exclusão (processar), gestão de admins
(criar/remover — super-admin), tempo real via Socket.io (atualizar dashboard/denúncias ao
vivo), paginação na lista de usuários.

## 📌 Estado geral do projeto (16/06/2026)
- **App Flutter**: rebrand (dourado/navy) + login por e-mail/senha/código ligado à API real,
  rodando no celular. Resto das telas ainda Firebase (a migrar).
- **API** (`api/`): auth (app+admin), perfil, descoberta/match, chat (REST+Socket.io),
  moderação, verificação, dispositivos, painel admin — tudo testado.
- **Painel** (`painel-web/`): login, dashboard, usuários, denúncias, verificações, settings.
- **Infra**: Postgres+Redis (Docker), firewall 3333 liberado.

**Próximos grandes passos:** (a) migrar as telas internas do app (descoberta/chat/perfil) do
Firebase para a API; (b) push FCM real; (c) completar o painel; (d) deploy na VPS.

## ✨ Painel admin — redesign profissional (ícones + gráficos + telas completas) — 16/06/2026

A pedido (estava simples demais), o painel foi repaginado:
- **Ícones SVG** via `lucide-react` (sidebar, cards, botões).
- **Gráficos** via `recharts` na Dashboard:
  - Área: **novos cadastros (14 dias)** — novo endpoint `GET /admin/stats/signups?days=`.
  - Pizza/donut: **distribuição por gênero**.
  - Barras: **interações** (likes/super/dislikes).
- **Stat cards** com círculo de ícone colorido (usuários, verificados, matches, interações,
  denúncias, banidos, verif. pendentes, exclusões).
- **Sidebar** com gradiente navy, avatar do admin, item "Admins" só para super-admin.
- Tema refinado (`theme.css`): sombras, hover, badges, tabela com header, inputs com foco.

### Telas que faltavam (agora completas — paridade com o painel Flutter)
- **Banidos**: lista filtrada (`/admin/users?banned=true`) + desbanir.
- **Exclusões de conta**: lista de pedidos + **processar** (anonimização LGPD, com confirmação).
- **Admins** (super-admin): tabela + formulário de **criar admin** com permissões (checkbox)
  + remover. (`/admin/admins`).

### API: ajustes de suporte
- `GET /admin/users?banned=true` — filtro de banidos.
- `GET /admin/stats/signups?days=14` — série de cadastros por dia (para o gráfico).

Build do painel OK (recharts + lucide). Acessar em `http://localhost:5173`
(login admin@namoro.com / admin12345) — **dar refresh** que o Vite recarrega.

## ✅ App: núcleo completo ligado à API (descobrir, match, chat em tempo real) — 16/06/2026

O app agora, **após o login, entra no app de verdade** (não mais a tela de aviso) — todas as
telas novas falam com a **nossa API** (Postgres/VPS), com **chat em tempo real (Socket.io)**,
mesmo padrão visual dourado/navy. `flutter analyze` limpo; rodando no Galaxy S23.

### Perfis de teste semeados (10) — `USUARIOS_TESTE.txt` na raiz
`prisma/seed.ts` (rodar: `npm run db:seed`). 10 perfis cristãos variados (6 mulheres, 4 homens),
idades 23–32, cidades BR, denominações/frequência/intenção/interesses, **3 imagens cada**
(rosto via randomuser.me + 2 lifestyle via picsum) e localização (lat/lng) p/ distância.
Senha de todos: **123456**. Também: admin@namoro.com/admin12345 (painel).

### Camada de serviços (Flutter)
- `config/api_config.dart` — baseUrl (IP do PC; trocar p/ VPS).
- `services/token_storage.dart` — access/refresh/email/**userId** no Hive (+ `updateTokens`).
- `services/auth_api.dart` — register/login/requestCode/loginCode (salva userId).
- `services/app_api.dart` — cliente autenticado (perfil, discovery, swipe, matches, chat)
  com **refresh automático no 401**.
- `services/chat_socket.dart` — Socket.io (connect com JWT, join/leave match, message:send,
  message:read, typing, match:new).

### Telas novas (`lib/views/app/`)
- `app_theme.dart` — cores + listas (denominações, frequência, intenções, interesses, emojis).
- `onboarding_page.dart` — completa o perfil (nome, gênero, nascimento, cidade, denominação,
  frequência, intenção, interesses até 5, sobre) → `PUT /me/profile`.
- `main_shell.dart` — navegação inferior (Descobrir / Matches / Perfil), estilo dourado/navy.
- `discover_page.dart` — **swipe cards** (swipe_cards) com galeria de fotos (tap p/ trocar),
  nome/idade, cidade+distância, **% match**, selo verificado, tags denominação/intenção;
  botões X / super (estrela) / curtir; **dialog "Deu Match!"** com "Conversar".
- `matches_page.dart` — lista de matches (avatar, online, última msg, não-lidas) → chat.
- `chat_page.dart` — **chat em tempo real** (histórico REST + Socket.io: enviar, receber,
  marcar lido ao abrir, indicador "digitando"); bolhas douradas (minhas) / brancas.
- `profile_page.dart` — meu perfil (foto, infos cristãs, interesses) + sair.

### Roteamento
- Login (senha/código) → `goAfterAuth`: tem perfil → `MainShell`; sem perfil → `OnboardingPage`.
- Auto-login (`main.dart`): se logado, busca `/me/profile` e decide MainShell/Onboarding;
  token inválido → volta ao Login.

### Como testar o fluxo completo no celular
1. App → "Entrar com e-mail" → login como um **perfil semeado** (ex.: `ana.beatriz@teste.com`
   / 123456) → já tem perfil → cai em **Descobrir** vendo os outros 9.
2. Curtir alguém. Para dar match: logar no outro perfil e curtir de volta (ou usar 2 contas).
3. Match → abre o **chat em tempo real** (testável com 2 dispositivos/contas).
4. Conta nova (sem perfil) cai no **Onboarding** primeiro.

### Comunicação em tempo real (app ↔ API ↔ painel)
- App: REST (perfil/discovery/swipe/matches) + Socket.io (chat).
- Match novo dispara `match:new` aos dois usuários; mensagens entregues na hora via socket.
- Painel lê os mesmos dados (dashboard reflete usuários/matches/interações reais).

**Próximos:** editar perfil + upload de fotos (S3/MinIO), push FCM real, filtros de descoberta,
tempo real no painel (Socket.io), e deploy na VPS (trocar baseUrl + HTTPS).

## ✨ Onboarding repaginado — wizard em 6 etapas + localização real — 16/06/2026

A tela gigante de "completar perfil" virou um **wizard em etapas** (uma coisa por tela),
com barra de progresso e botões Voltar/Continuar. Tudo em PT-BR.

### Etapas
1. **Nome e sobrenome** (campos separados).
2. **Gênero** (chips em português: Masculino/Feminino/Outro — enviado como MALE/FEMALE/OTHER)
   + **Nascimento**: campo **digitável** com máscara `DD/MM/AAAA` **e** calendário
   (`showDatePicker`) — ambos em **português** (app agora com `flutter_localizations`,
   locale pt_BR no `MaterialApp`). Valida 18+.
3. **Localização**: **País → Estado → Cidade**, com **busca** (bottom sheet pesquisável):
   - País: lista real via **restcountries** (nome em PT + **bandeira emoji**), Brasil no topo.
   - Brasil: Estado e Cidade reais via **IBGE**; ainda há **"Buscar por CEP" (ViaCEP)** que
     preenche estado+cidade automaticamente.
   - Outros países: estado/cidade em texto livre.
4. **Fé**: denominação + frequência + intenção (chips).
5. **Interesses**: até 5 (chips).
6. **Sobre você**: bio opcional → **Concluir** salva via `PUT /me/profile`.

### Arquivos
- `services/location_api.dart` — restcountries (países+bandeira), IBGE (estados/cidades),
  ViaCEP (CEP), com fallback se a rede falhar.
- `views/app/widgets/searchable_sheet.dart` — bottom sheet com busca reutilizável.
- `views/app/onboarding_page.dart` — reescrito como `PageView` de 6 etapas + validação por etapa.
- `main.dart` — `localizationsDelegates` + `supportedLocales` pt_BR/en (calendário/datas PT).

Endereço salvo: `city` + `addressText` ("Cidade - UF - País"). `flutter analyze` limpo;
rodando no celular.

> Obs.: bandeiras de **estados** em SVG ficaram de fora por ora (hospedagem/where); países
> usam bandeira emoji (nativa, sem rede). Dá pra evoluir para SVG depois se quiser.

## ✨ Onboarding: foto obrigatória + sem CEP, e Perfil redesenhado — 16/06/2026

### Mudanças no onboarding (wizard agora 7 etapas)
- **Removido** o campo "Buscar por CEP" (e o método `_lookupCep` no app — `LocationApi.lookupCep`
  segue existindo mas sem uso).
- **Nova etapa "Suas fotos" (obrigatória)** logo após o nome: o usuário adiciona de **1 a 6 fotos**
  (anti-fake — precisa de pelo menos 1 pra avançar). Grid com adicionar/remover; 1ª foto = "Principal".
- Ordem das etapas: 1) Nome+Sobrenome, 2) **Fotos**, 3) Gênero+Nascimento, 4) Localização
  (País→Estado→Cidade), 5) Fé, 6) Interesses, 7) Sobre.
- No salvar: envia `mediaFiles` (URLs das fotos) e `profilePicture` (1ª foto).

### Upload de fotos (API) — sem S3 ainda (dev)
- `api/src/config/paths.ts` → `UPLOADS_DIR` (pasta `api/uploads/`).
- `app.ts`: serve estático em **`/uploads`** + limite JSON 12MB + `crossOriginResourcePolicy:false`.
- Novo endpoint **`POST /api/me/photos`** `{ image: base64, ext }` → salva no disco e retorna
  **URL absoluta** (`http://<host>:3333/uploads/<arquivo>`). Valida tipo (jpg/png/webp) e tamanho (8MB).
- App: `image_picker` (maxWidth/Quality 75 → comprime) → base64 → `AppApi.uploadPhoto` → URL.
- `tsconfig.json`: `include` ajustado p/ só `src/**` (o `seed.ts` roda via tsx).

### Perfil redesenhado (`profile_page.dart`)
- **Carrossel de fotos** (PageView 460px) com indicadores no topo, gradiente navy e nome/idade/
  selo verificado/cidade sobre a foto.
- **Sheet branco arredondado** sobreposto com:
  - **Pills** de denominação / frequência / intenção (ícone dourado + borda).
  - Seção **"Sobre mim"** em card.
  - **Interesses** em chips dourados (com emoji).
  - Botão **Sair** (outline) + botão sair flutuante no topo.
- Visual no padrão dourado/navy. `flutter analyze` limpo.

### Estado atual (resumo rápido)
- **App**: login (e-mail/senha/código) → onboarding em 7 etapas (foto obrigatória) → app
  (Descobrir swipe / Matches / Chat tempo real / Perfil) — tudo na **nossa API**.
- **API**: auth, perfil (+upload fotos), descoberta/match, chat (REST+Socket.io), moderação,
  verificação, dispositivos, painel admin (dashboard+gráficos), upload de fotos. `tsc` limpo.
- **Painel** (`painel-web`): React+Vite, ícones+gráficos, todas as telas.
- **Perfis teste**: 10 (ver `USUARIOS_TESTE.txt`), senha 123456.
- **Servidores**: API (`api`, porta 3333, Docker Postgres 5433) + Painel (`painel-web`, 5173)
  + app no Galaxy S23 via WiFi. Firewall 3333 liberado.

### Próximos
Editar perfil (prefill), bandeiras SVG de estados, push FCM real, filtros de descoberta,
tempo real no painel, deploy na VPS (HTTPS + trocar baseUrl/CORS).

## 🗺️ ROADMAP — Grande pacote de melhorias (pedido 16/06/2026)

Objetivo: deixar o app mais completo/premium. Itens (ordem de implementação):

1. **Aba "Curtidas"** (novo item no menu inferior):
   - Mostra **quem deu match** com você (cards com foto) e **quem te curtiu** (likes recebidos
     pendentes).
   - **Gating por assinatura**: sem plano → foto e nome **borrados (blur)**; ao tocar → abre
     opção de **assinar/pagar plano**. Com plano ativo → sem blur, vê tudo.
   - Backend: `GET /likes` (matches + likedYou + isPremium). Dev: endpoint p/ ativar premium e testar.

2. **Descobrir — correções/UX**:
   - **Trocar de foto** quando o perfil tem mais de 1 imagem (hoje não passa) → corrigir
     navegação por toque (e/ou usar swiper com builder).
   - **Tocar no card → abrir perfil completo** da pessoa, **mantendo os botões** (X / super / curtir)
     embaixo e um **botão Voltar no topo**; **esconder só o menu inferior** (Descobrir/Matches…).
   - **Feedback ao arrastar**: arrastar p/ **curtir** → overlay esverdeado/**dourado** com blur
     ("que bom"); arrastar p/ **X** → overlay **escuro/azulado** com blur ("descartando").
     (precisa de swiper com offset de arraste → `flutter_card_swiper`).

3. **Perfil — upload de fotos**: hoje o perfil só mostra; permitir **adicionar/remover fotos**
   no próprio perfil (reusar `POST /me/photos` + `PUT /me/profile`).

4. **Fotos privadas / trancadas**:
   - Permitir **trancar** uma foto (privada) — outros só veem após **solicitar acesso** e o dono
     **liberar**.
   - Ao solicitar → **notificar no chat** com **botões Aprovar / Negar**.
   - Backend: `Profile.lockedPhotos[]` + modelo `PhotoAccessRequest` (requester, owner, status) +
     endpoints request/approve/deny; mensagem especial no chat (novo tipo/ábordagem).

Status: começando por (1) e (2). (4) é a mais complexa (schema + chat) — entra logo após.

## 🎨 SPEC DE DESIGN (refs W3Tinder/Tinder enviadas) — adaptar p/ nossas cores (dourado/navy)

> O usuário enviou prints de referência (template "W3Tinder", rosa). **Manter nossas cores**
> (dourado #D4AF37 + navy #111D40), só seguir o LAYOUT/UX das telas. Mais prints virão.

### 1) Descobrir (cards) — PRIORIDADE
- Card **grande, full-bleed** (ocupa quase a tela toda), cantos arredondados, foto cobrindo tudo.
- **Não** mostrar pilha de cards atrás de forma estranha (no máximo um leve atrás).
- Nome + idade grande embaixo à esquerda + subtítulo (ex.: cidade/profissão) menor.
- Botão **super like (estrela)** flutuante no canto **inferior direito** do card.
- **Feedback ao arrastar**: arrastar p/ direita = **curtir** → overlay/borda VERDE com ✓ (check);
  arrastar p/ esquerda = **não curtir** → ❌ em círculo VERMELHO (no nosso caso: curtir =
  verde/dourado, não = vermelho/escuro). Cantos do card "tombam" levemente ao arrastar.
- **Topo**: logo à esquerda; à direita ícones de **filtros** (sliders) e **grade** (grid/lista).
- Trocar foto tocando nas laterais; **tocar no card/nome → abre o perfil** (sem o ícone "ⓘ").
- Mostrar **status online** (bolinha verde + "online"/"recentemente ativo") perto do nome.
- Reposicionar o **% match** (hoje está ruim) — discreto perto do nome.

### 2) Perfil (meu) — ref print 1
- Avatar **circular central** com **anel de progresso** + pílula "**X% completo**".
- Nome + idade + subtítulo (profissão/intenção).
- Topo: **engrenagem (config)** à esquerda, **lápis (editar)** à direita. (Remover o "Sair" solto.)
- Linha de cards: **Super Likes / Boosts / Assinatura (Premium)** com "+".
- Bloco promo "**Seja Premium**" com botão.
- **Editar perfil** de verdade (campos), além de gerenciar fotos.

### 3) Matches / Chat — ref print 4
- Barra "**Buscar matches**" no topo.
- **"Novos matches"**: lista horizontal de avatares; o **1º é um círculo "N Curtidas"**
  (quem te curtiu, leva à aba Curtidas).
- **"Mensagens"**: lista com avatar, **bolinha verde de online**, nome, última mensagem,
  **horário** ("2m atrás") e **check de lido**.

### 4) Adicionar fotos — ref print 5
- Título "**Adicione fotos recentes**" + "Envie 2 para começar. Adicione 4+ para destacar".
- **Grade 3x2** de caixas tracejadas com botão **+** (gradiente) em cada; foto preenchida tem **✕**.
- Botão **Avançar/Salvar** (gradiente dourado).

### 5) Curtidas / Top Picks — ref print 6
- Abas no topo: "**N Curtidas**" | "**Top Picks**".
- Seção "**Recentemente ativos**": cards 2 colunas (foto, nome+idade, "• Recentemente ativo"
  verde, botão estrela).
- Seção "**Interesses em comum**": cards com **tag** do interesse compartilhado.
- (Já temos a base "Curtidas" com blur premium — evoluir p/ esse layout.)

### 6) Filtros (já em construção) — distância, idade, sexo, denominação, interesses
- Backend `/discovery` já aceita: minAge, maxAge, maxDistanceKm, gender, denominations, interests.
- App: tela de Filtros (RangeSlider idade, slider distância + "qualquer", chips sexo/denominação/
  interesses). Falta ligar no Descobrir.

### Pendências já iniciadas (turno anterior) a concluir
- Descobrir: usar filtros, card maior, sem pilha, sem "ⓘ", tap→perfil, % match reposicionado,
  bolinha online.
- Perfil: remover "Sair" do topo, adicionar **Editar perfil**.
- Painel admin: card "**Online agora**" + indicador online na lista (backend já retorna isOnline).
- **Fotos privadas/trancadas** + solicitar acesso + aprovar/negar no chat (ainda pendente).

## ✅ Implementado: "É um Match!" instantâneo + filtros + discover/perfil/painel — 16/06/2026

### Tela "É um Match!" (instantânea) — ref print enviado
- `match_celebration.dart`: overlay full-screen branco com **corações flutuantes** animados,
  título "**É um Match!**", "Você e X se curtiram", **2 avatares** (meu + dele) com coração
  dourado no meio, botão **Conversar** (dourado) + **Pular**.
- Aparece **na hora**:
  - quando EU dou o like que fecha o match (resposta do swipe traz `withUser`);
  - quando a OUTRA pessoa me curte → **Socket.io** `match:new` (backend só emite pro lado
    passivo; payload agora traz `name` + `photo`). MainShell tem **socket global** ouvindo isso.
- Minha foto guardada em `TokenStorage.myPhoto` (salva no MainShell ao abrir).

### Filtros (ligados) — ref pedido
- `filters_page.dart` (sexo, faixa de idade, distância + "qualquer", denominações, interesses).
- Descobrir: ícone **filtros** no topo → abre a tela → recarrega com a query
  (`/discovery?minAge&maxAge&maxDistanceKm&gender&denominations&interests`). Backend respeita.

### Descobrir — melhorias
- **Só 1 card visível** (sem pilha estranha embaixo), card **maior** (menos padding).
- **% match** virou pílula dourada discreta ao lado do nome (removido o badge do topo).
- **Status online** (bolinha verde + "online"/"online recentemente") perto do nome.
- Removido o ícone **ⓘ**; agora **tocar no centro/nome → abre o perfil**, laterais trocam foto.
- Mantido feedback colorido ao arrastar (verde curtir / escuro não / navy super).

### Perfil — melhorias
- Removido o **Sair do topo** (fica só no rodapé).
- Novo botão **Editar perfil** → `edit_profile_page.dart` (nome, cidade, sobre, denominação,
  frequência, intenção, interesses) salvando via `PUT /me/profile` (mantém fotos/gênero/data).

### Painel admin
- Dashboard: card **"Online agora"** (`stats.users.online`).
- Lista de usuários: badge **● online**. Backend retorna `isOnline`/`lastActiveAt` + filtro
  `?online=true`.

### Backend
- `/discovery`: filtros gender/denominations/interests + card com `isOnline`/`lastActiveAt`.
- `swipe`: resposta com `withUser` (nome/foto) e `match:new` só pro passivo (nome/foto).
- `/me/online` (presença) + `/me/premium` (dev) já existiam; `setOnline` chamado no MainShell.

### Ainda pendente (próximos)
Fotos privadas/trancadas + solicitar/aprovar no chat; layouts finos dos prints (perfil com
anel de progresso, "Novos matches" + círculo de curtidas no topo do chat, grade de adicionar
fotos, aba Top Picks/Recentemente ativos).

## ✅ Chat/Matches estilo Tinder + Fotos privadas (solicitar/aprovar no chat) — 17/06/2026

### Matches/Mensagens (ref print 4)
- Barra **"Buscar matches"** + título.
- **"Novos matches"** em linha horizontal: 1º item é o **círculo dourado "N Curtidas"**
  (abre a aba Curtidas); demais = matches **sem conversa ainda** (avatar + 1º nome + bolinha online).
- **"Conversas"**: lista com avatar + **bolinha verde online** + nome + última mensagem +
  **horário** ("2m/1h/3d") + badge de não-lidas / check de lido.

### Fotos privadas / trancadas (pedido recorrente — feito)
**Backend** (migration `private_photos`):
- `Profile.lockedPhotos[]`; `MessageType.PHOTO_REQUEST`; modelo `PhotoAccessRequest`
  (requester/owner/status PENDING/APPROVED/DENIED).
- Descoberta: cards mostram **só fotos públicas** (locked excluídas) + `hasLockedPhotos`/`lockedCount`.
- Endpoints (`/api`): `POST /photo-access/request {ownerId}` (exige match → cria pedido +
  **mensagem PHOTO_REQUEST no chat** via socket), `POST /photo-access/:id/decide {approve}`
  (dono aprova/nega → manda aviso no chat), `GET /photo-access/can-see/:ownerId`,
  `GET /users/:ownerId/locked-photos` (só se APPROVED).
- `PUT /me/profile` aceita `lockedPhotos`.

**App**:
- **Gerenciar fotos**: cada foto tem **cadeado** (trancar/destrancar = privada). Salva
  `mediaFiles` + `lockedPhotos`.
- **Chat**: botão no topo **pedir fotos privadas** (vira "pendente"); quando o dono recebe, a
  mensagem **PHOTO_REQUEST** mostra **Aprovar/Negar**; após aprovar, o solicitante vê o ícone
  **cadeado aberto** → abre **galeria das fotos privadas**.
- `ChatPage` agora recebe `otherUserId` (matches/curtidas/match novo passam).

`flutter analyze` e `tsc` limpos.

### Ainda pendente (fila)
Curtidas/Top Picks (abas + recentemente ativos + interesses em comum); perfil com anel de
progresso (ref print 1); grade de adicionar fotos estilo print 5; push FCM real; deploy VPS.

## 🐞 Fix: tocar no nome/foto no Descobrir não abria o perfil — 17/06/2026
- **Causa**: a área do nome (Positioned na base do card) ficava por cima das zonas laterais
  de troca de foto; tocar no nome trocava a foto em vez de abrir o perfil.
- **Correção**: o bloco de nome/cidade/tags virou um `GestureDetector(opaque)` → `onOpenProfile`.
  Agora: **tocar no nome → abre perfil**; **centro da foto → abre perfil**; **laterais → trocam foto**.
- `flutter analyze` limpo.

---

## 💾 CHECKPOINT — pausa do dia (17/06/2026)

### Como retomar o ambiente (tudo local)
1. **Docker Postgres** (persiste sozinho): `docker ps` deve mostrar `namoro_pg`. Se não:
   `cd api ; docker compose up -d`.
2. **API**: `cd api ; npm run dev` → http://localhost:3333 (health em `/api/health`).
3. **Painel**: `cd painel-web ; npm run dev` → http://localhost:5173 (admin@namoro.com / admin12345).
4. **App no celular** (WiFi): celular com Depuração sem fio ligada (mesmo WiFi) →
   `adb pair <ip:portaPareamento> <codigo>` → `adb connect <ip:portaConexão>` →
   `flutter run -d <id> --debug` (de dentro de `aplicativo/`). adb em
   `%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe`.
   - O IP do PC é **192.168.3.253**; `ApiConfig.baseUrl` aponta pra ele (trocar p/ VPS no deploy).

### Estado FUNCIONAL hoje
- **App**: login (e-mail senha/código) → onboarding 7 etapas (foto obrigatória, país/estado/
  cidade reais) → **Descobrir** (card grande, 1 por vez, filtros reais, online, %match, tocar
  abre perfil, arraste com feedback colorido) → **Curtidas** (blur premium) → **Matches/Chat**
  (novos matches + círculo curtidas + conversas, chat tempo real Socket.io) → **Perfil**
  (carrossel, editar perfil, gerenciar fotos com **cadeado/privadas**). **Match instantâneo**
  (tela "É um Match!" mesmo quando te curtem). **Fotos privadas**: pedir/aprovar/negar no chat.
- **API**: auth, perfil(+upload fotos+premium+online), descoberta(filtros), match, chat
  (REST+socket), moderação, verificação, devices, fotos privadas, painel (dashboard+gráficos+
  online). `tsc` limpo. Migrations: init, auth_email_codes, private_photos.
- **Painel**: login, dashboard (gráficos + online), usuários (online/banir), denúncias,
  verificações, banidos, exclusões, admins, configurações.

### Credenciais de teste — `USUARIOS_TESTE.txt`
10 perfis (senha 123456) + admin@namoro.com/admin12345.

### FILA (próximos passos quando voltar)
1. **Curtidas/Top Picks**: abas "N Curtidas" | "Top Picks" + "Recentemente ativos" +
   "Interesses em comum" (ref print 6).
2. **Perfil (meu)** estilo ref print 1: avatar central com **anel de progresso** + "% completo",
   engrenagem/lápis no topo, cards Super Likes/Boosts/Premium, promo.
3. **Grade de adicionar fotos** estilo print 5 (3x2 tracejado).
4. **Push FCM real** (Opção A — token já é registrado; falta projeto FCM + envio no backend).
5. **Pagamento real** do Premium (hoje é botão dev que ativa).
6. **Deploy na VPS**: subir API+Postgres (Docker), HTTPS, trocar `ApiConfig.baseUrl` e CORS,
   storage de fotos (S3/MinIO em vez de disco local).
7. Bandeiras SVG de estados; revogação de refresh token; tempo real no painel.

### Observações técnicas
- Fotos enviadas ficam em `api/uploads/` (disco) e são servidas em `/uploads` — **trocar por
  S3/MinIO no deploy** (URLs absolutas hoje usam o IP local).
- Cleartext HTTP liberado só em debug; produção exige HTTPS.
- `kBackendReady=false` no app (sobe sem Firebase). Firebase só será usado p/ FCM (push) depois.


---

## 👑 Plano VIP + Super Like com limite + Configurações + Perfil melhorado — 17/06/2026

### Resumo
Sessão focada em "resolver tudo": confirmado que o **app builda e roda** (APK debug gerado
com sucesso — o patch de `-Werror` no `android/build.gradle` resolveu o erro do
`video_player_android`; o "não roda no celular" era ausência de device conectado, não erro
de build). Adicionados Super Like com limite real, plano VIP completo e telas que faltavam.

### Backend (API) — feito
- **Schema** (migration `premium_superlikes`): `User` ganhou `premiumPlan`, `premiumUntil`,
  `superLikesUsedToday`, `superLikesResetAt`, `boostsRemaining`.
- **`lib/premium.ts`** (novo): limites (FREE=1, PREMIUM=5 super likes/dia), planos
  (monthly/quarterly/yearly com dias+preço de exibição), `isPremiumActive` (valida por data),
  `ensureDailyReset` (zera contador a cada dia), `superLikesLeft`, `premiumStats`.
- **`POST /me/premium`**: agora aceita `{plan}` (ativa VIP com validade) ou `{active:false}`
  (cancela) ou `{active:true}` (dev infinito). Retorna `premiumStats`.
- **`GET /me/stats`** (novo): estado premium + super likes restantes + lista de planos.
- **`swipe` SUPERLIKE**: respeita limite diário; se estourar, retorna **403 + code
  `SUPERLIKE_LIMIT`** (o app abre o paywall). Premium incrementa contador até 5/dia.
- `/likes` agora usa `isPremiumActive` (considera validade).
- `tsc` limpo. Endpoints testados via curl: `/me/stats` (free → superLikesLeft:1),
  assinar `monthly` → `isPremium:true`, `premiumUntil` +30d, `superLikesPerDay:5`. ✅

### App (Flutter) — feito
- **`premium_page.dart`** (nova): paywall VIP em tela cheia (navy/dourado), coroa, lista de
  6 benefícios, 3 cards de plano (1/3/12 meses, "MAIS POPULAR" no trimestral), botão Assinar
  → `subscribePlan`. Mostra card "Você é VIP 👑" + validade quando já assinante.
- **`settings_page.dart`** (nova): card VIP, e-mail, switch de notificações, privacidade/termos,
  **Sair da conta** e **Excluir conta** (chama `/me/delete-request` e desloga).
- **Descobrir**: botão Super Like agora mostra **badge com saldo** ("∞" se VIP); ao tocar sem
  saldo → abre o VIP; se o backend recusar (403) também abre. Coroa VIP no topo.
- **Perfil**: engrenagem (⚙️) + coroa no topo direito; **barra de "Perfil completo %"**
  (7 critérios); **card VIP** clicável. Sair continua no rodapé.
- **app_api.dart**: `subscribePlan(plan)`, `getStats()`, `requestAccountDeletion()`.
- `flutter analyze` limpo (só resta 1 info de `print` em código velho do template).

### Limites definidos
- Super Likes/dia: **grátis = 1**, **VIP = 5**. Reset diário automático.
- Planos: Mensal R$ 39,90 · Trimestral R$ 89,90 (R$ 29,97/mês) · Anual R$ 239,90 (R$ 19,99/mês).

### Ainda na fila (próximos)
- Pagamento real (hoje a assinatura ativa direto, sem gateway).
- Curtidas: abas Top Picks / Recentemente ativos / Interesses em comum.
- Grade de adicionar fotos 3x2 tracejada (print 5).
- Push FCM real; deploy VPS (HTTPS, S3/MinIO, trocar baseUrl/CORS).


---

## 🔴 Tempo real no chat + badges + simulação de testes — 17/06/2026 (tarde)

### App rodando no celular (modo dev / hot)
- App instalado e rodando no SM S911B via WiFi (`192.168.3.212`). API em `192.168.3.253:3333`.
- **Dúvida do usuário respondida**: NÃO precisa recompilar APK toda vez — `flutter run` mantém
  sessão e o hot reload atualiza em segundos. Só recompila do zero em mudança nativa.
- ⚠️ Causa de "não conecta na API": a API tinha caído. Religada, escuta em `0.0.0.0:3333`.

### Matches/Chat em tempo real + badges
- **MainShell**: socket global agora escuta `message:new`/`messages:read`/`match:new` e dispara
  um `ValueNotifier` (_tick) → a lista de Matches recarrega **sozinha** (sem puxar pra baixo).
- **Badge no menu** (item Matches): bola **laranja** (#FF6B35) com o nº de **conversas** não lidas
  (não o total de mensagens — 10 msgs no mesmo chat = 1 conversa).
- **Tela Matches**: removido o campo de busca. Na conversa:
  - Recebidas não lidas → **bolinha laranja com a qtd de mensagens** daquela conversa.
  - Enviadas por mim → ✓ (enviada, cinza) / ✓✓ (lida, **laranja**).
- **Chat**: bolhas agora têm **horário** + ✓/✓✓ (✓✓ laranja quando lida); leitura atualiza em
  tempo real via `messages:read`. Envio de mensagens funcionando (socket).
- **Loja de Presentes** (botão 🎁 no chat): abre sheet "em breve" com prévia (🌹🧸💍☕🍫✨).
  Planejado: comprar **moedas** e enviar presentes; upload e preço no **painel admin**. (FUTURO)

### Top Picks
- Backend `GET /top-picks` (melhores por compatibilidade). App: aba **Top Picks** na tela de
  Curtidas (grid com % match; abre o perfil com botões curtir/super/x).

### Simulação de testes (NOVO) — `api/prisma/simulate.ts` + rotas `/dev`
- `npx tsx prisma/simulate.ts maria@teste.com`: garante o alvo + elenco com **fotos de rosto
  reais** (randomuser + pravatar), corrige fotos antigas (picsum) de todos os perfis, cria
  **6 curtidas/super likes** chegando + **2 matches com conversas** (mensagens não lidas).
- Rotas dev (só fora de produção, públicas):
  - `POST /api/dev/live-match/:email` → reciproca uma curtida pendente, cria match e **emite
    `match:new` em tempo real** (popup "É um Match!" na hora).
  - `POST /api/dev/live-message/:email { count? }` → envia N mensagens de matches existentes em
    tempo real (testa badge/contador).
- Mais 8 perfis masculinos com fotos adicionados ao elenco de teste.

### Pendências/futuro
- Loja de presentes com moedas (compra de moedas, catálogo no admin, envio no chat).
- Pagamento real (VIP + moedas). Push FCM. Deploy VPS.


---

## 🎙️ Áudio no chat + fotos + super like prioridade + curtidas 6 cards — 17/06/2026 (noite)

### Chat — envio confiável + mídia
- **Bug corrigido**: enviar mensagem "não fazia nada". O envio dependia só do socket; agora
  envia por **REST** (`POST /matches/:id/messages`) que **persiste + emite em tempo real** pros
  dois lados, com UI otimista e dedupe por id. ✓✓ de leitura também emite em tempo real.
- **Fotos no chat**: botões separados de **galeria** e **câmera** (movidos pra barra de baixo,
  perto do envio). Bolha de imagem com toque pra **zoom** (InteractiveViewer).
- **Áudio (voz)**: gravação estilo WhatsApp com `social_media_recorder` (segure o microfone,
  arraste pra cancelar) — aparece quando o campo está vazio; com texto, vira botão enviar.
  Player com **onda/entonação** via `voice_message_package` (VoiceMessageView/VoiceController).
  Upload do .m4a no `/me/photos` (passou a aceitar áudio: m4a/aac/mp3/wav/ogg). Duração embutida
  no content como `url#segundos`.
- **Topo do chat**: tocar no **nome** → abre o perfil (`GET /users/:id/profile`); tocar na
  **foto** → zoom. Ações de fotos privadas movidas pra menu ⋮ (tirou o ícone "álbum" do topo).
- Bolhas minhas com **degradê dourado** (premium).

### Super Like com prioridade (gamificação)
- **Descobrir**: quem te deu **super like** aparece no **topo** (boosted); os demais são
  **embaralhados** (dificulta achar → mais tempo no app). Like normal não tem prioridade.
- **Curtidas**: super likes vêm **primeiro** na lista "Quem te curtiu".

### Curtidas (tela)
- Grade agora **3 colunas** → mostra **6 cards sem scroll**.
- Cards mostram **cidade/distância** (km) e usam **só o 1º nome** (nome grande não empurra mais
  a cidade). Selo de estrela nos super likes. Backend `/likes` passou a devolver `city`/`distanceKm`.

### Chat — "stories" de curtidas
- No topo do Chat, em vez de 1 círculo "N Curtidas", agora mostra **uma bolinha por pessoa que
  curtiu** (até 7), estilo **stories** (anel dourado; anel navy+dourado p/ super like). Se não
  for premium, a foto fica **borrada com cadeado**. "Ver todas" abre a aba Curtidas.

### Menu
- "Matches" → **"Chat"**; círculo Curtidas troca de aba (não abre tela presa).

### Próximos (fila do usuário, em ordem)
1. **Push/notificações** (FCM) — nova curtida, nova mensagem, e push manual.
2. **Localização**: pedir GPS, calcular distância real entre as pessoas e exibir "X km" em
   destaque no topo do Descobrir.
3. (Depois) Loja de presentes com moedas; pagamento real; deploy VPS.


---

## 🛠️ Fixes chat + distância por cidade + perfil melhorado — 17/06/2026 (noite 2)

### Bugs corrigidos
- **Teclado fechava ao digitar a 1ª letra**: ao esconder os botões de mídia, o TextField mudava
  de posição na Row e perdia o foco. Resolvido com **ValueKey estável** + FocusNode no campo.
- **Preview da conversa mostrava URL** de foto/áudio → agora "📷 Foto", "🎤 Mensagem de voz".
- **Gravador de áudio com listras preto/amarelo** (overflow) → colocado em `Expanded` (sem estouro).
- **Carrossel de fotos no perfil não arrastava** → adicionadas **zonas de toque** (lados) +
  swipe; navega tocando ou arrastando.

### Distância por cidade (sem depender de GPS do outro)
- `lib/geo.ts`: tabela `CITY_COORDS` + `resolveCoords` + `distanceBetween` → calcula distância
  pela **cidade** quando não há lat/lng. Usado em descoberta, `/likes` e `/users/:id/profile`.

### Descobrir
- **Online agora fica na MESMA linha** da cidade/distância (menos linhas).
- **Badge de distância em vidro** (glassmorphism, ref. SVG do usuário) no topo do card: "📍 X Km".

### Perfil (ProfileDetailView) melhorado
- Mostra **online** (bolinha verde + "online/online recentemente") junto da cidade/distância.
- **Distância** exibida; **% de compatibilidade** agora também aparece num chip perto do "Sobre"
  (continua no topo também). Navegação de fotos por toque + swipe.

### Próximos (fila)
- Notificações (push FCM precisa do google-services.json; internas já dá pra fazer).
- Loja de presentes com moedas; pagamento real; deploy VPS.


---

## 💬 Barra do chat redesenhada + Perfil estilo "W3Tinder" — 17/06/2026 (noite 3)

### Barra de mensagem do chat (ref. print do usuário)
- Pill único e limpo: **emoji (esq)** + "Sua mensagem" + **câmera** + **presente** (no lugar do clipe).
- **Câmera** agora abre menu: **Tirar foto** ou **Escolher da galeria** (2 em 1).
- **Emoji rápido**: sheet com ~50 emojis (inclui 🙏✝️❤️) que inserem no campo.
- Botão **enviar dourado** (arredondado) fora; com campo vazio vira **gravador de áudio**.

### Perfil próprio refeito (ref. print W3Tinder, cores nossas)
- **Avatar central** com **anel de progresso dourado** + pill **"X% Completo"**.
- Topo: **engrenagem (config)** à esquerda, **lápis (editar)** à direita.
- Nome + idade + **badge VIP** (dourado, do lado do nome quando assinante).
- **3 cards rápidos**: Super Likes (saldo), **Assinar Plus** (some quando VIP), **Boosts** (saldo) —
  cada um com "+" pra comprar (abre a tela VIP). Inscrições removido.
- **Banner "Seja VIP"** abaixo (some quando já é VIP).
- Abaixo: **detalhes do perfil** (denominação, frequência, intenção, cidade, Sobre, interesses) +
  Gerenciar fotos + Sair.
- Mantida a tela VIP (premium_page) e o "Você é VIP".

### Localização (GPS)
- `LocationService` (geolocator): pede permissão ao entrar, pega o GPS e atualiza `/me/location`
  pra refinar a distância. Fallback por cidade continua quando sem GPS.


---

## 🎨 Design System + consistência + Bloquear/Denunciar — 17/06/2026 (noite 4)

### Chat — menu de 3 pontos
- Trocado "Ver perfil"/"Pedir fotos" por **Bloquear** e **Denunciar** (ícones).
- **Bloquear**: dialog estilizado (avisos + Cancelar/Sim, bloquear) → `POST /blocks` → fecha o chat.
- **Denunciar**: sheet com lista de motivos (Assédio, Conteúdo inapropriado, Catfishing, etc.)
  → `POST /reports`. "Ver fotos privadas" só aparece se acesso APROVADO.

### Barra do chat (correção de aproveitamento)
- Microfone virou **botão fixo** (sem buracão à direita); expande pra barra cheia só ao gravar
  (via callbacks startRecording/stopRecording). Câmera + presente juntos no fim do pill.

### DESIGN SYSTEM (novo) — `app_theme.dart`
Centralizado pra acabar com a inconsistência (antes: ~14 cinzas, 11 raios diferentes):
- **Tokens**: cores (gold/navy/bg/surface), texto em 3 níveis (textPrimary/Secondary/Muted),
  `border`, `fieldBg`; raios `rSm/rMd/rLg/rPill`; `softShadow`; `primaryButton`/`secondaryButton`.
- **Componentes reutilizáveis**: `AppTabHeader` (cabeçalho único das abas), `SectionTitle`,
  `AppCard`, `AppChoiceChip` (chip dourado/branco com animação).
- **Aplicado**: cabeçalho unificado (título 24 + ícone) em **Descobrir, Curtidas e Chat**
  (antes cada um tinha tamanho/estilo diferente). Chips de **Filtros** e **Editar perfil**
  agora usam o `AppChoiceChip` (eram duplicados).
- `flutter analyze` limpo.

### Próximo (sugestões de polish ainda pendentes)
- Migrar cards/pills das telas restantes para `AppCard`/tokens (perfil, settings).
- Skeletons no lugar do spinner; estados vazios com ilustração.
- Hero na foto do perfil; transições de página suaves.


## Painel Admin — Modal de detalhes do usuário (controle/segurança)
- Clicar numa linha em **Usuários** abre modal grande (Tabler `modal-xl`) com tudo do usuário.
- Backend `GET /admin/users/:userId` (admin.controller `userDetail`) agrega: perfil completo, financeiro (premium/plano/gasto estimado), métricas (likes dados/recebidos, super likes, matches, mensagens, fotos, fotos privadas, denúncias recebidas/feitas, bloqueios), conta (idade, notificações, feed, verificações), segurança (último IP, dispositivos, logs de acesso) e galeria de fotos.
- Novo modelo Prisma `AccessLog` (userId, ip, userAgent, action) + migration `20260618164215_access_logs`. Registro via `lib/accessLog.ts` (`recordAccess`) nos pontos de auth do app (register/login/login_code/google). `app.set("trust proxy", true)`.
- MAC address: indisponível (não exposto por navegador/SO) — modal informa isso. Gasto é estimado pelo plano (não há histórico de pagamentos no schema).
- Arquivos: `painel-web/src/components/UserDetailModal.tsx`, `painel-web/src/pages/Users.tsx`, `api/src/modules/admin/admin.controller.ts`, `api/src/lib/accessLog.ts`, `api/src/modules/auth/user.auth.controller.ts`.


## Painel Admin — Página completa do usuário (substitui o modal)
- Rota `/usuarios/:userId` (`painel-web/src/pages/UserDetail.tsx`). Clicar na linha ou no botão "Informações" navega pra página. Modal removido.
- Tabela de Usuários: botões **Informações**, **Suspender/Reativar**, **Banir/Desbanir** + sexo traduzido (Masculino/Feminino/Outro) + selo "Suspenso".
- Página tem painel de **Ações administrativas**: Banir, Suspender (prompt dias), Verificar/Remover verificação, **Dar VIP** (dropdown controlado: mensal/trimestral/anual), Remover VIP, **+ Super Likes**, **+ Boosts**.
- Backend (admin.controller + rotas): `suspendUser`/`unsuspendUser` (campo `User.suspendedUntil`, migration `user_suspension`, login bloqueia suspensos via `ensureNotBanned`), `grantPremium`/`revokePremium` (usa `PREMIUM_PLANS`), `addCredits` (boosts incrementa; super likes reduz `superLikesUsedToday`), `setVerified`.


## Painel Admin — Diálogos/Toasts personalizados + Página de detalhe da denúncia
- `components/ui.tsx`: `Dialog` (confirmação/input, navy+dourado) e `Toast` (sucesso/erro). Substituíram alert/confirm/prompt nativos em Usuários e na página do usuário.
- `components/UserLocationMap.tsx`: mapa BR com estado do usuário em dourado + pin (lat/long). `userDetail` retorna `location` + `reportsReceived` (lista).
- Página `/denuncias/:id` (`pages/ReportDetail.tsx`): investigação completa. Backend `GET /admin/reports/:id` (`reportDetail`) reúne resumo do autor e do denunciado (cards clicáveis → /usuarios/:id), relação entre eles (match/bloqueios/interações), histórico (nº denúncias contra o denunciado e feitas pelo autor + alerta de abuso), e outras denúncias contra o denunciado. Ações: marcar revisada/descartar/reabrir + suspender/banir o denunciado (diálogos). Tabela Reports agora clicável (botão Investigar).


## Painel Admin — Banidos, Exclusões, Admins e Configurações repaginados
- **Banidos**: avatar + nome, linhas clicáveis → /usuarios/:id, desbanir com diálogo+toast.
- **Exclusões (LGPD)**: backend `listDeleteRequests` agora enriquece com nome/foto/e-mail/cidade/VIP do usuário. Página com aviso LGPD, avatar, linha clicável, processar com diálogo de confirmação irreversível + toast.
- **Admins**: avatar (dourado pro super-admin + coroa), permissões com rótulos PT em badges, data "desde", criar com checkboxes descritivos + toast, remover com diálogo.
- **Configurações**: switch "conversa antes do match" em card descritivo, salvar no header com toast, card "Sobre".


## Painel Admin — Monetização (Planos, Presentes, Anúncios) + Config remota
- Migration `monetization`: modelos `Product` (kind PREMIUM/CREDITS/SUPERLIKES/BOOSTS, title, priceCents, amount, durationDays, googleProductId, active, sortOrder), `Gift` (name, imageUrl, costCredits, active), `AdSettings` (singleton: enabled + banner/interstitial/rewarded enabled + ad unit IDs Android + interstitialEverySecs), `MonetizationSettings` (singleton: creditPriceCents, currency).
- Módulo `api/src/modules/monetization` (controller+routes). Admin (requireAdmin, montado em /api/admin): CRUD `/products`, `/gifts` (+ `/gifts/upload` base64 gif/png/svg→disco), `/monetization` (valor do crédito), `/ads`. Público (montado em /api/config, app lê em tempo real): `GET /config/store` (produtos+presentes+creditPriceCents ativos) e `GET /config/ads` (retorna só IDs ativos conforme flags).
- Painel: menu ganhou **Planos** e **Anúncios**.
  - `pages/Plans.tsx` (/planos): cards de atalho (Presentes, Anúncios, Valor de 1 crédito), produtos por categoria (tabela: título, qtd/dias, preço R$, SKU Google, ativo toggle, editar/excluir) + form criar/editar. Compras reais via Google Play in-app billing (admin define SKU).
  - `pages/Gifts.tsx` (/planos/presentes): upload de imagem (GIF/PNG/SVG) via base64, nome, custo em créditos, grade de presentes (toggle/excluir) + valor do crédito.
  - `pages/Ads.tsx` (/anuncios): AdMob remoto — liga/desliga geral + por tipo, ad unit IDs Android, frequência do intersticial. App ID fica fixo no Flutter (exigência do SDK).
- TODO Flutter (futuro): ler `/config/store` e `/config/ads`, integrar in_app_purchase (Google Play) e google_mobile_ads (só App ID no AndroidManifest).


## Painel Admin — Anúncios completo (AdMob) + Planos profissional
- Migration `ads_full_options`: `AdSettings` expandido — testMode + testDeviceIds; formatos appOpen/banner/interstitial/rewarded/rewardedInterstitial/native (toggle + ad unit ID Android cada); bannerPosition (top/bottom); appOpenOnResume + appOpenEverySecs; intersticial: everySecs, everyClicks, onOpenChat, onOpenProfile, onSwipe; caps maxAdsPerSession/maxAdsPerDay. Público `/config/ads` retorna tudo estruturado (units, banner, appOpen, interstitial, caps) só com ativos.
- `pages/Ads.tsx`: status geral + modo teste + device IDs, tabela de formatos com toggle e ad unit ID, cards App Open / Banner / Limites globais, e gatilhos do intersticial.
- `pages/Plans.tsx` repaginado: cada categoria (VIP/Créditos/SuperLikes/Boosts) com botão "Adicionar" que abre **modal** dedicado (sem form jogado), produtos em cards (preço destacado, SKU, toggle ativo, editar/excluir). Modal ProductModal valida e cria/edita.


## Envio de Presentes (créditos) — ponta a ponta
- Schema: `User.credits Int` (migration `user_credits`). `premiumStats` e `/me/stats` agora expõem `credits`.
- Backend chat: `chat.service.sendGift` (valida membership + presente ativo + saldo; debita créditos em transação; cria mensagem `GIFT` com content JSON {giftId,name,imageUrl,cost}); controller `sendGift` emite socket pros dois; rota `POST /matches/:matchId/gifts {giftId}` (retorna {message, credits}). Erro 402 = créditos insuficientes.
- Admin: `addCredits` agora também aceita `credits`; UserDetail mostra saldo e tem botão "+ Créditos".
- Flutter (`app_api.dart`): `getStore()`, `getGifts()`, `sendGift(matchId, giftId)`.
- Flutter (`chat_page.dart`): `_openGiftShop` real — carrega presentes de `/config/store` + saldo de `/me/stats`, grade 3 col com imagem/nome/custo, mostra saldo, confirma e envia (debita local). `_giftBubble` renderiza a mensagem GIFT (card dourado com imagem+nome). SVG cai em ícone (sem flutter_svg). `flutter analyze` limpo.
- adb wireless agora em 192.168.3.212:33879 (porta muda a cada reconexão).


## Chat — presença online + presentes (refino)
- SVG renderiza no app via `flutter_svg` (`SvgPicture.network` no `_giftImage`).
- Cabeçalho do chat mostra presença: ponto verde + "Online", ou "visto há X min/horas", e após 24h "visto em DD/MM às HH:MM". Helper `presenceText(isOnline, lastActiveAt)` em app_theme.dart. Chat busca status via `getUserCard` no init + timer 30s (cancelado no dispose).
- Lista de conversas: mensagem GIFT agora mostra ícone `assets/icons/ic_gift.svg` (recolorido como foto/mic) + "Presente" em vez do JSON cru. Novo asset ic_gift.svg (fill currentColor).
- Painel Presentes: imagem em caixa quadrada fixa (104x104, object-fit contain) pra padronizar tamanho entre SVG/PNG. Bug imagem cortada resolvido (era maxWidth/maxHeight; agora contain).


---

## 📝 Sessão 18–19/06/2026 — Painel monetização, presentes no app, login, splash e correções

> Resumo detalhado de tudo feito nesta leva. Ambiente: Postgres (Docker `namoro_pg`), API
> (`api/ npm run dev`, porta 3333), painel (`painel-web/ npm run dev`, porta 5173), app via
> `flutter run -d 192.168.3.212:<porta> --debug` (a porta do adb wireless muda a cada
> reconexão — usadas na sessão: 44929 → 33879 → 38727 → 33403). PC: 192.168.3.253.
> adb em `%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe` (no PowerShell usar
> `& "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" connect <ip:porta>`).

### Painel — visual Tabler + cor dourada + Montserrat
- Painel migrado para **@tabler/core** (CSS oficial) com **menu na lateral** (navbar-vertical).
- `theme.css`: `--tblr-primary` dourado `#d4af37` (texto navy nos botões); azul antigo do
  Tabler (`#066fd1`) sobrescrito por **navy `#111d40`** (variáveis `--tblr-blue/azure` +
  classes `.text-blue/.bg-blue/.bg-blue-lt`). Sidebar e topo **navy**, item ativo em faixa
  dourada. Fonte global trocada de Inter → **Montserrat** (Google Fonts no `index.html`).
- Bug do **badge das Denúncias** (número "1" jogado no canto): o Tabler posiciona o badge
  absoluto; resolvido forçando no `theme.css` `.navbar-vertical .nav-link .nav-link-title .badge`
  como `position: static !important` + `margin-left: 6px` (cola no texto).
- Header de cima removido (criava faixa vazia + linha): o **admin logado** (avatar dourado,
  nome, cargo, botão Sair) foi pro **rodapé do menu lateral** (`mt-auto`).
- Login do painel (`pages/Login.tsx`) refeito no padrão Tabler (card, `form-control`,
  `input-icon` com ícones de e-mail/senha/usuário, botão dourado, fundo navy).
- Todas as telas internas migradas pro padrão Tabler (tabelas `table-vcenter`, badges,
  cabeçalhos `page-pretitle`+`page-title`): Usuários, Denúncias, Verificações, Banidos,
  Exclusões, Admins, Configurações. Backup do painel antigo: `painel-web-backup-20260618-1106.zip`.
- Dashboard com dados reais + **mapa do Brasil** (`react-simple-maps`, `public/br-states.json`)
  com estados coloridos por nº de usuários (gradiente navy) e lista de cidades.

### Painel — página completa do usuário + ações + segurança (IP)
- Rota `/usuarios/:userId` (`pages/UserDetail.tsx`) — substituiu o modal. Clicar na linha
  ou em "Informações" abre a página. Tabela de Usuários com botões **Informações /
  Suspender / Banir** e sexo traduzido (Masculino/Feminino/Outro).
- Backend `GET /admin/users/:userId` agrega tudo: perfil, financeiro (premium/plano/gasto
  estimado), métricas (likes dados/recebidos, super likes, matches, mensagens, fotos,
  fotos privadas, denúncias, bloqueios), conta (idade, notificações, feed, verificações),
  **segurança (último IP, dispositivos, logs de acesso)**, localização e galeria de fotos.
- **Logs de acesso (IP):** novo modelo Prisma `AccessLog` (migration `access_logs`) +
  `lib/accessLog.ts` (`recordAccess`) gravando IP/user-agent no register/login/login_code/
  google (`app.set("trust proxy", true)`). **MAC não é capturável** (navegador/SO não expõem).
- Ações administrativas (controller + rotas): suspender/reativar (`User.suspendedUntil`,
  migration `user_suspension`; login bloqueia suspensos), banir/desbanir, dar/remover **VIP**
  (`grantPremium`/`revokePremium`), **+ créditos / + super likes / + boosts** (`addCredits`),
  verificar/remover verificação (`setVerified`).
- Página de **detalhe da denúncia** `/denuncias/:id` (`pages/ReportDetail.tsx`): backend
  `GET /admin/reports/:id` (`reportDetail`) reúne autor e denunciado (cards clicáveis →
  perfil), relação entre eles (match/bloqueios/interações), histórico de denúncias +
  alerta de abuso, e ações (revisar/descartar/reabrir + suspender/banir o denunciado).

### Painel — diálogos/toasts personalizados (sem alertas do navegador)
- `components/ui.tsx`: `Dialog` (confirmação/entrada, navy + dourado) e `Toast`
  (sucesso/erro no canto). Substituíram todos os `alert/confirm/prompt` nativos em
  Usuários, UserDetail, ReportDetail, Banidos, Exclusões, Admins, Plans, Gifts.
- `components/UserLocationMap.tsx`: mapa do BR com o estado do usuário em dourado + pin
  (lat/long). Card de localização + lista de denúncias recebidas no UserDetail.

### Painel — Monetização (Planos, Créditos, Presentes, Anúncios) — remoto via API
- Migration `monetization`: `Product` (kind PREMIUM/CREDITS/SUPERLIKES/BOOSTS, title,
  priceCents, amount, durationDays, googleProductId/SKU, active, sortOrder), `Gift`
  (name, imageUrl, costCredits, active), `AdSettings` (singleton), `MonetizationSettings`
  (singleton: creditPriceCents, currency). Migration `user_credits` add `User.credits`.
- Módulo `api/src/modules/monetization` (controller+routes). **Admin** (`/api/admin`):
  CRUD `/products`, `/gifts` (+ `/gifts/upload` base64 gif/png/svg→disco, retorna caminho
  **relativo** `/uploads/...`), `/monetization` (valor do crédito), `/ads`. **Público**
  (`/api/config`, app lê em tempo real): `GET /config/store` (produtos+presentes+
  creditPriceCents ativos) e `GET /config/ads` (estruturado, só formatos ativos).
- `pages/Plans.tsx` (`/planos`): categorias (VIP/Créditos/SuperLikes/Boosts), cada uma com
  botão "Adicionar" que abre **modal** (ProductModal) — produtos em cards (preço, SKU,
  toggle ativo, editar/excluir). Atalhos pra Presentes, Anúncios e valor do crédito.
- `pages/Gifts.tsx` (`/planos/presentes`): **GiftModal** (criar/editar) com upload de
  imagem (GIF/PNG/SVG/JPG/WebP), nome, custo em créditos, ordem, ativo; grade de presentes
  com imagem em caixa quadrada fixa (104×104, object-fit contain) + conversão pra R$.
- `pages/Ads.tsx` (`/anuncios`) — **AdMob completo** (migration `ads_full_options`):
  liga/desliga geral + modo teste + device IDs; formatos **App Open, Banner, Intersticial,
  Rewarded, Rewarded Interstitial, Native** (toggle + ad unit ID Android cada); banner
  position; App Open onResume/everySecs; gatilhos do intersticial (everySecs, everyClicks,
  onOpenChat, onOpenProfile, onSwipe); caps por sessão/dia. App ID fica fixo no Flutter.

### App — Envio de presentes (créditos) ponta a ponta
- Backend chat: `chat.service.sendGift` (valida membership + presente ativo + saldo;
  debita créditos em transação; cria mensagem `GIFT` com content JSON
  {giftId,name,imageUrl,cost}); rota `POST /matches/:matchId/gifts` (emite socket pros
  dois; retorna {message, credits}; erro 402 = créditos insuficientes). `premiumStats` e
  `/me/stats` expõem `credits`.
- Flutter `app_api.dart`: `getStore()`, `getGifts()`, `sendGift(matchId, giftId)`.
- Flutter `chat_page.dart`: `_openGiftShop` real (loja em grade com saldo, custo e imagem),
  envio com confirmação e débito local; `_giftBubble` renderiza o presente (card dourado +
  imagem + nome). **SVG** renderiza via `flutter_svg` (`SvgPicture.network`).
- **Bug imagem do presente só aparecia ícone:** o upload salvava URL com `localhost:3333`
  (host de quem subiu), inacessível pelo celular. Corrigido: backend salva caminho relativo
  `/uploads/...` e o app resolve qualquer `/uploads/` (até as antigas com localhost) pro IP
  real via `_mediaUrl` (origin de `ApiConfig.baseUrl`).

### App — chat: presença online + lista de conversas
- Cabeçalho do chat mostra presença: ponto verde + "Online", ou "visto há X min/horas", e
  após 24h "visto em DD/MM às HH:MM" (helper `presenceText` em `app_theme.dart`). Busca via
  `getUserCard` no init + timer 30s (cancelado no dispose).
- Lista de conversas (`matches_page.dart`): mensagem **GIFT** mostra ícone
  `assets/icons/ic_gift.svg` (recolorido como foto/mic) + "Presente"; **"digitando..."** em
  tempo real e prefixo **"Você:"** quando a última mensagem foi minha.
- **Digitando em tempo real na lista:** servidor (`sockets/index.ts`) passou a emitir o
  evento `typing` para a **sala pessoal do outro usuário** (com cache de participantes do
  match), não só para a sala do match — assim a lista recebe mesmo sem o chat aberto. O
  chat só emite typing quando o estado muda (evita spam). `main_shell` mantém um
  `ValueNotifier<Set<String>>` de matchIds digitando (auto-expira em 6s) e passa à MatchesPage.

### App — tela "Ativar Localização"
- `views/app/enable_location_page.dart` (padrão navy + dourado): título, descrição,
  ilustração (círculos radar + pino + Icons.public), botão "Permitir Localização" e "Agora
  não". Mostrada pelo `main_shell` **após login** se a permissão ainda não foi concedida
  (`LocationService.hasPermission()`), em vez de pedir a permissão direto.

### App — perfil (meu e público)
- **Interesses com ícones**: `kInterestIcon` (mapa interesse→IconData) + `interestIcon()` em
  `app_theme.dart`; chips de interesse mostram **ícone + texto** no meu perfil
  (`profile_page.dart`) e no público (`profile_detail_view.dart`).
- Meu perfil: infos (denominação/igreja/intenção/cidade) agrupadas num card **"Informações"**.
- Perfil público aberto pelo **chat** (`withActions:false`): **% de match escondida** (badge
  do topo e caixa de compatibilidade só aparecem na descoberta).
- **Swipe das fotos** no perfil: as zonas de toque cobriam tudo e travavam o arraste; agora
  só as laterais (~25% cada) tocam pra trocar e o **centro fica livre pro swipe**.

### App — menu inferior mais compacto
- `main_shell.dart`: padding vertical reduzido (8→4/5), ícone 26→24, espaçamentos menores e
  `SafeArea(minimum bottom:2)` — barra mais baixa, sem espaço gigante.

### App — tela de login: ilustração "órbita de pessoas"
- `views/auth/people_orbit.dart` (`PeopleOrbit`): ilustração estilo radar com **cores nossas**
  (dourado/navy) — órbita **tracejada** (CustomPainter), círculos concêntricos, avatar
  central com anel, **avatares ao redor com o centro exatamente sobre a linha tracejada**
  (raio = `size/2 - 1`, igual ao traço), pino de localização e balão de conversa decorativos.
  Avatares usam fotos da randomuser (ilustração). Colocado no topo do `login_page.dart` no
  lugar do ícone de coração.

### App — splash: fim da "splash dupla" + correção do travamento
- Causa da sensação de 2 splashes: a splash nativa (navy via `flutter_native_splash`) +
  a splash do Flutter (navy+coração+texto) com **delay artificial de 2s**.
- Removido o `Future.delayed(2s)` do `_decideRoute` e a config `flutter_native_splash` do
  pubspec (a janela nativa de launch é navy e blenda; o ícone do sistema no Android 12+ é
  inevitável).
- **Bug: app travou na splash** após remover o delay — log mostrou
  `Failed assertion: '!navigator._debugLocked'`: o `Navigator.pushReplacement` era chamado
  **durante o build do 1º frame** (Navigator travado). Corrigido movendo a decisão de rota
  pra **após o primeiro frame** com `WidgetsBinding.instance.addPostFrameCallback` no
  `initState` da `SplashScreen` (sem delay, sem travar).

### App — remoção do Facebook (causa de lentidão no startup)
- Diagnóstico **com evidência nos logs** (não achismo): no boot apareciam erros repetidos
  `com.facebook.GraphResponse ... Invalid application ID / Object with ID 'appID'`. O SDK
  nativo do Facebook se **auto-inicializava** lendo o `facebook_app_id = "appID"` (placeholder)
  do `strings.xml`/`AndroidManifest` e disparava chamadas à Graph API que falhavam no cold start.
- **Removido o Facebook por completo** (não será usado): tirado do `AndroidManifest.xml`
  (queries do provider, meta-data ApplicationId/ClientToken, FacebookActivity/CustomTabActivity),
  do `strings.xml` (só ficou `app_name`), do `pubspec.yaml` (`flutter_facebook_auth`,
  `flutter pub get` removeu 10 pacotes), e do Dart (`auth_providers.dart`: import +
  `signInWithFacebook` + `FacebookAuth.instance.logOut()`; `login_page.dart`: botão Facebook).
  Mantido o campo `facebookUsername` do perfil (é link de rede social, do template — não é o SDK).

### Pendências/próximos
- Integrar **AdMob** no Flutter lendo `/config/ads` (só App ID fixo no AndroidManifest) e
  **in_app_purchase** (Google Play) lendo `/config/store` para compras reais (hoje "gasto" é
  estimado pelo plano; créditos são concedidos pelo admin).
- Verificações no painel no mesmo padrão das outras telas (ver selfie grande, comparar fotos).
- Empacotar a fonte localmente (google_fonts baixa em runtime) e testar build **release**
  para medir velocidade real.
- Deploy na VPS (trocar `ApiConfig.baseUrl` + `API_BASE` do painel para HTTPS).


---

## 🚀 Sessão 19/06/2026 — Pacotão de features (Tinder/Badoo-like) — backend + app + painel

> Implementado em lote, sem testar no celular (usuário testa numa compilação só no final).
> Validado: `flutter analyze` limpo (só 1 aviso `print` pré-existente), API `tsc --noEmit` limpo,
> painel `tsc --noEmit` limpo. Migration `features_boost_rewind_prompts_verse`.

### Schema (migration features_boost_rewind_prompts_verse)
- `Profile`: `boostUntil DateTime?`, `incognito Boolean`, `prompts Json?` (perguntas de fé [{q,a}]).
- `Interaction`: `note String?` (recado do super like).
- `AppSettings`: `boostDurationMin`, `superLikeMessageEnabled`, `rewindPremiumOnly`,
  `incognitoPremiumOnly`, `dailyVerseEnabled`, `freeDailyLikes`.
- `DailyVerse` (reference, text, active, sortOrder) — verso do dia gerenciável.

### Backend (API)
- **Boost/Turbo**: `POST /me/boost` (consome boostsRemaining, seta `boostUntil = now+boostDurationMin`). Descoberta ordena: super likers → boost ativo → resto.
- **Rewind**: `POST /swipe/undo` (`undoLastSwipe`) — apaga última interação e desfaz match sem mensagens. Gating `rewindPremiumOnly` (403 PREMIUM_ONLY).
- **Super Like com recado**: `swipe` aceita `note`; aparece em `/likes` (likedYou[].note).
- **Filtros premium**: descoberta aceita `intention` e `churchFrequency` (além de denominações/interesses).
- **Modo incógnito**: `POST /me/incognito {enabled}` (gating `incognitoPremiumOnly`); descoberta exclui `incognito:true`.
- **Perguntas de fé (prompts)**: salvas no `PUT /me/profile` (validator aceita `prompts[]`).
- **Verso do dia**: `GET /config/verse` (rotaciona por dia; lista padrão embutida se vazio) + CRUD admin `/admin/verses`.
- **Compra/resgate**: `POST /me/purchase {productId}` concede PREMIUM/CREDITS/SUPERLIKES/BOOSTS (verificação Google Play real = pendente).
- **Settings admin** expandido com as flags acima.

### App (Flutter)
- `app_api.dart`: `swipe(note)`, `undoSwipe`, `activateBoost`, `setIncognito`, `purchase`, `getDailyVerse`.
- **Descobrir** (`discover_page.dart`): card do **verso do dia** no topo; botões **Rewind** (↺) e **Boost** (⚡) na barra de ações; **Super Like com recado** (diálogo com mensagem opcional); match abre após a animação (sem travada).
- **Filtros** (`filters_page.dart`): seções **Intenção** e **Frequência à igreja** (marcadas ⭐ VIP) — seleção única.
- **Loja** nova (`store_page.dart`): lê `/config/store`, lista produtos por categoria, compra via `/me/purchase` (mostra saldo de créditos). Aberta pelos cards de Super Likes/Boosts no perfil.
- **Configurações** (`settings_page.dart`): toggle **Modo incógnito** (cai no VIP se gated).

### Painel (React)
- **Configurações** repaginada: flags de chat/descoberta + recursos premium (super like recado, rewind/incógnito só VIP, duração do boost) + verso do dia + curtidas grátis/dia.
- Nova página **Versos** (`/versos`, item no menu): CRUD do verso do dia.

### Pendências (precisam de credenciais externas, fora do código)
- **Google Play Billing real**: hoje `/me/purchase` concede direto; falta verificar o token de compra com a Google (precisa Play Console + produtos publicados).
- **Push FCM real**: notificações persistem + socket; envio FCM em background precisa da server key/credenciais do Firebase.
- **Editor de perguntas de fé (prompts)** no onboarding/editar perfil (backend já aceita; falta a UI de edição) e exibição no perfil público.


---

# 📊 ESTADO COMPLETO DO PROJETO (snapshot 19/06/2026)

Documento-resumo de TUDO que está pronto e TUDO que falta. Para detalhes de cada item, ver as seções datadas acima.

## 0. Como rodar (ambiente de dev)
- **Postgres (Docker)**: `namoro_pg` em `localhost:5433` (user/senha/db = namoro/namoro/namoro_cristao). Redis em `localhost:6380`.
- **API**: `cd api ; npm run dev` → `http://localhost:3333` (tsx watch, recarrega sozinho). `npm run lint` = `tsc --noEmit`.
- **Painel**: `cd painel-web ; npm run dev` → `http://localhost:5173`. Login: `admin@namoro.com` / `admin12345`.
- **App**: `cd aplicativo ; flutter run -d 192.168.3.212:<porta> --debug` (adb wireless; a porta muda a cada reconexão). PC = `192.168.3.253`. adb: `& "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" connect <ip:porta>`.
- Ao mexer no schema Prisma: parar a API antes de `npx prisma migrate dev` (lock no Windows).
- Usuário de teste app: `maria@teste.com` / `123456` (e perfis semeados, senha `123456`). Teste vivo: `1@1.com`.

## 1. Arquitetura
- **App** Flutter (`aplicativo/`, package `mioamoreapp`, bundle `com.winup.namoro`) — SEM Firebase (`kBackendReady=false`), tudo na nossa API.
- **API** Node + TS + Express + Prisma + PostgreSQL + Socket.io + JWT + Zod (`api/`).
- **Painel** React + Vite + TS + **@tabler/core** (`painel-web/`).
- Cores: dourado `#D4AF37` + navy `#111D40`. Idioma PT-BR.

## 2. ✅ PRONTO — API (módulos e endpoints)
- **Auth app** (`/api/auth`): register, login (senha), request-code + login-code (OTP e-mail), google (ID token), refresh, me. Registra IP/dispositivo (`AccessLog`) no login. Bloqueia banidos e **suspensos**.
- **Auth painel** (`/api/admin/auth`): needs-setup, register-super, login, refresh, me.
- **Perfil** (`/api/me`): get/upsert profile (campos cristãos + prompts), location, online, photos (base64), premium, **boost**, **incognito**, **purchase**, stats.
- **Descoberta/Match** (`/api`): discovery (filtros idade/distância/gênero/denominação/interesses/**intenção**/**frequência**; ordena super likers → **boost** → resto; exclui **incógnito**), swipe (+nota super like), **swipe/undo (Rewind)**, matches, likes (quem te curtiu + nota), top-picks, users/:id/profile.
- **Chat** (`/api/matches/:id` + Socket.io): histórico, enviar, marcar lido, **enviar presente** (`/gifts`, debita créditos). Socket: message:new, messages:read, **typing** (entregue na sala pessoal → funciona na lista), match:new.
- **Moderação**: reports, blocks, delete-request (LGPD).
- **Verificação**: enviar selfie, status.
- **Dispositivos/Notificações**: device tokens (FCM), notifications list/read.
- **Painel admin** (`/api/admin`): dashboard, stats/signups, stats/locations, users (lista/detalhe COMPLETO com IP/logs/stats/financeiro), ban/suspend, **VIP/créditos/superlikes/boosts**, verify, reports (+detalhe/investigação), verifications, account-delete, settings (+flags), admins, **products/gifts/ads/verses (monetização)**.
- **Config pública** (`/api/config`, app lê em tempo real): store (produtos+presentes+valor do crédito), ads (AdMob), verse (verso do dia).
- **Dev/simulação** (`/api/dev`, só dev): live-match, live-likes, live-message.

### Modelos Prisma (tabelas)
users, profiles (+boostUntil/incognito/prompts), admins, interactions (+note), matches, messages, verification_forms, reports, blocks, banned_users, account_delete_requests, device_tokens, notifications, feeds, app_settings (+flags), email_codes, photo_access_requests, **access_logs**, **products**, **gifts**, **ad_settings**, **monetization_settings**, **daily_verses**. User: +credits, +suspendedUntil.

## 3. ✅ PRONTO — Painel admin (telas)
Login (Tabler dourado), Dashboard (dados reais + mapa do Brasil), Usuários (lista + página de detalhe com ações: banir/suspender/VIP/créditos/verificar + IP/logs/financeiro), Denúncias (lista + investigação completa), Verificações, Banidos, Exclusões (LGPD), Admins, **Planos** (produtos por categoria + modal), **Presentes** (upload GIF/PNG/SVG + valor do crédito), **Anúncios** (AdMob completo remoto), **Versos** (verso do dia), **Configurações** (flags de recursos). Diálogos/toasts próprios (sem alert do navegador). Menu lateral navy + dourado.

## 4. ✅ PRONTO — App (telas e recursos)
- **Splash**: nativa navy + ícone (a do Flutter é invisível; navega após 1º frame).
- **Login**: ilustração "órbita de pessoas" (PeopleOrbit), Google + e-mail, "Criar conta", versão. Sem Facebook (removido).
- **Auth e-mail**: entrar/criar (senha) + código OTP.
- **Onboarding**: wizard 6 etapas (nome, gênero/nascimento, localização país/estado/cidade + CEP, fé, interesses, sobre).
- **Ativar Localização**: tela própria (navy+dourado) + termos/política.
- **Descobrir**: swipe cards, galeria, % match, selo verificado; **verso do dia**, **Rewind**, **Boost**, **Super Like com recado**; filtros (idade/distância/gênero/denominação/interesses + **intenção/frequência VIP**).
- **Chat (aba)**: Matches recentes (redondos, ocultam se vazio) + Conversas (linha divisória recuada; "digitando..." em tempo real; "Você:" prefixo; preview com ícone p/ foto/áudio/presente).
- **Chat (conversa)**: tempo real, presença (online/visto há...), ✓/✓✓, foto/galeria/câmera, **áudio**, **presentes** (loja com saldo, render do presente, SVG), bloquear/denunciar.
- **Curtidas**: quem te curtiu (blur p/ não-VIP), super likes em destaque.
- **Perfil**: avatar com anel de progresso, cards (Super Likes/Plus/Boosts → **Loja**), VIP badge, infos em card, interesses com ícones, gerenciar fotos.
- **Loja**: compra de créditos/super likes/boosts/VIP (lê /config/store, concede via /me/purchase).
- **VIP/Premium**: paywall com planos.
- **Configurações**: VIP, notificações, **modo incógnito**, privacidade, sair, excluir conta (LGPD).

## 5. ⏳ PENDÊNCIAS (o que falta) — detalhado

### A. Monetização real (Google Play Billing) — ALTA prioridade
- Hoje `POST /me/purchase` **concede o produto direto** (testável), mas NÃO valida a compra com a Google.
- Falta: integrar pacote `in_app_purchase` no Flutter; criar os produtos no **Google Play Console** (mesmos SKUs do painel); no backend, **verificar o purchase token** com a Google Play Developer API antes de conceder; tratar reembolso/cancelamento/assinatura recorrente.
- Pré-requisito externo: conta Play Console + app publicado (ao menos em teste interno) + app assinado (release).

### B. Push de notificações (FCM) — ALTA prioridade
- Hoje: notificações ficam só em socket/registro; **não há push em background**.
- Falta: server key/credenciais do **Firebase (FCM)**; serviço no backend que envia push em novo match/mensagem/curtida usando os `device_tokens`; no app, pedir permissão de notificação e tratar o token. (Decisão já tomada: "Opção A" — só FCM para entrega.)
- Pré-requisito externo: projeto Firebase + arquivo de credenciais.

### C. Perguntas de fé (prompts) — MÉDIA
- Backend já salva `profile.prompts`. Falta: **UI de edição** no onboarding/editar perfil (escolher pergunta + responder) e **exibir** no perfil público (`profile_detail_view`) e no card de descoberta.

### D. Google login — MÉDIA
- Precisa `GOOGLE_CLIENT_IDS` no `.env` da API e configuração OAuth no app (senão dá 503). Botão já existe.

### E. AdMob no app — MÉDIA
- Painel já controla tudo (`/config/ads`). Falta: integrar `google_mobile_ads` no Flutter lendo `/config/ads` (App Open, banner, intersticial por gatilho/tempo, rewarded), respeitando os limites; só o **App ID** fica fixo no AndroidManifest.

### F. Stories/Momentos (24h) — BAIXA (engajamento)
- Tabela `feeds` existe. Falta: UI de criar/ver stories + expiração 24h.

### G. Verificações no painel no padrão das outras telas — BAIXA
- Ver selfie grande, comparar com fotos do perfil, aprovar/rejeitar com motivo.

### H. Performance / produção — quando for publicar
- Empacotar a fonte (google_fonts baixa em runtime) ou usar fonte do sistema; testar **build release**.
- Upload de fotos hoje é disco local (`/uploads`); em produção migrar para **S3/MinIO**.
- Deploy na **VPS**: trocar `ApiConfig.baseUrl` (app) e `API_BASE` (painel) para a URL pública **HTTPS**; subir Postgres/Redis; variáveis de ambiente/segredos JWT de produção.
- Refresh token é stateless (sem revogação/blacklist) — logout é client-side.

### I. Recursos extras sugeridos (não iniciados) — BAIXA
- Modo "quem está online agora" dedicado, daily picks como tela com push, gamificação (ofensiva diária/badges), boost com tela de "você está em destaque" e timer visível, ver quem leu priorizado.

## 6. Bugs conhecidos
- Áudio no chat: histórico antigo de "Cleartext HTTP" — resolver `usesCleartextTraffic`/network_security_config no Android se reaparecer (uploads em http://).
- Aviso `avoid_print` em `lib/views/custom/subscription_builder.dart:129` (pré-existente, inofensivo).


---

## 🔔 Sessão 19/06/2026 (parte 2) — AdMob (teste), Notificações manuais, Push FCM (pronto), Analytics

> Validado: `flutter analyze` limpo (só o aviso `print` pré-existente), API `tsc` limpo, painel `tsc` limpo. Sem teste no celular (usuário compila no final).

### AdMob (IDs de TESTE do Google — pronto pra ver funcionando)
- `config.dart`: `isAdmobAvailable=true`; `AndroidAdUnits` com IDs de teste do Google. App ID de teste já no AndroidManifest.
- `services/ads_service.dart`: lê `/config/ads` (cache) e expõe IDs/flags; fallback nos IDs de teste do Google.
- `views/app/ads/app_banner.dart`: banner (AdMob) — exibido **acima do menu inferior** no `main_shell` (todas as abas).
- `services/interstitial_manager.dart`: pré-carrega e exibe intersticial respeitando `interstitialEverySecs`; disparado ao **abrir conversa** (flag `onOpenChat`).
- `prisma/seedAds.ts`: preencheu o painel (AdSettings) com os IDs de teste + tudo ligado. (rodar: `npx tsx prisma/seedAds.ts`)
- App lê tudo de `/config/ads` → ligar/desligar/trocar no painel reflete no app.
- TODO produção: trocar pelos IDs reais do AdMob; App Open ad ainda não plugado no app (precisa observer de ciclo de vida).

### Notificações manuais (painel → app) + Push FCM pronto
- `lib/push.ts`: `notifyUser`/`notifyUsers` (persiste em `notifications` + emite socket `notification:new` + envia FCM se `FCM_SERVER_KEY` no .env) e `pushOnly` (só FCM, p/ mensagens).
- Backend wiring: **novo match** → `notifyUser` (persistente + push); **nova mensagem** → `pushOnly` (background). Broadcast admin → `notifyUsers`.
- Admin: `POST /admin/notifications/broadcast {title, body, audience: all|premium|free|online|user, userId?}` + `GET /admin/notifications/recent`.
- Painel: nova página **Notificações** (`/notificacoes`, no menu) — compõe e envia por público, lista recentes.
- App: `chat_socket` ganhou `onNotification`; `main_shell` mostra **SnackBar** navy ao receber `notification:new` em tempo real.
- **Push real (background)**: 100% pronto — basta pôr `FCM_SERVER_KEY` no `.env` da API (e config FCM no app). Hoje, sem a key, funciona em tempo real (socket/in-app).

### Google Analytics (Firebase) — pronto/seguro
- Dependência `firebase_analytics` adicionada. `services/analytics_service.dart`: no-op seguro até o Firebase estar configurado (google-services.json + Firebase.initializeApp). `AnalyticsService.init()` no boot.
- Eventos já instrumentados: login/sign_up (email), swipe, match, boost, super_like, purchase (loja). Métodos prontos p/ message_sent, gift_sent, screen.
- "Interligar no painel": o **Dashboard** do painel já mostra métricas reais do nosso banco (cadastros, matches, interações, etc.). Os eventos do Firebase Analytics aparecem no **console do Firebase** (externo) quando ativado.
- TODO produção: criar projeto Firebase, baixar `google-services.json` (app) e aplicar o google-services gradle plugin; chamar `Firebase.initializeApp()` (hoje só roda se `kBackendReady=true`).

### Itens que sigo podendo fazer (próximos)
- App Open ad (anúncio ao retomar o app) com lifecycle observer.
- Tela de **notificações** dentro do app (lista persistente) com sino/badge.
- Esconder anúncios para usuários VIP.
- Editor de perguntas de fé (prompts) no onboarding/editar perfil.
- Google Play Billing real (verificação do recibo) e Google login (CLIENT_IDS).


---

# ✅ ÍNDICE-MESTRE / CONFIRMAÇÃO 100% (19/06/2026 parte 3)

> Tudo abaixo está **implementado e compilando** (app `flutter analyze` limpo exceto 1 aviso `print` pré-existente; API e painel `tsc` limpos). Detalhes nas seções datadas acima.
> **adb wireless: nova porta `192.168.3.212:33753`** (muda a cada reconexão).

## App (Flutter) — telas e arquivos
- `main.dart` — boot sem Firebase (`kBackendReady=false`), AnalyticsService.init, splash navy invisível (navega após 1º frame via addPostFrameCallback).
- `services/`: `app_api.dart` (todos os endpoints), `auth_api.dart`, `token_storage.dart`, `chat_socket.dart` (message/read/typing/match/**notification**), `location_service.dart`, `ads_service.dart`, `interstitial_manager.dart`, `analytics_service.dart`.
- `config/api_config.dart` — baseUrl `http://192.168.3.253:3333/api`.
- `config/config.dart` — `isAdmobAvailable=true`, AndroidAdUnits com IDs de TESTE, Facebook removido.
- Auth: `login_page.dart` (PeopleOrbit + Google + e-mail + criar conta + versão), `email_auth_page.dart` (entrar/criar + OTP + analytics), `people_orbit.dart`.
- `views/app/`: `main_shell.dart` (nav inferior compacta + banner AdMob + socket global + notificações SnackBar + EnableLocation), `discover_page.dart` (swipe, verso do dia, **Rewind/Boost/Super Like com recado**, filtros), `filters_page.dart` (+intenção/frequência VIP), `matches_page.dart` (Matches recentes redondos/ocultam + Conversas com linha recuada + digitando + "Você:" + intersticial ao abrir), `chat_page.dart` (tempo real, presença, áudio, presentes/loja, bloquear/denunciar), `profile_page.dart` (anel, cards→Loja, infos, interesses com ícone), `profile_detail_view.dart` (sem % no chat, swipe fotos), `store_page.dart` (compra de produtos), `premium_page.dart`, `settings_page.dart` (modo incógnito), `enable_location_page.dart` (+termos), `onboarding_page.dart` (wizard 6 etapas), `app_theme.dart` (cores/listas/presença/ícones interesse), `ads/app_banner.dart`.

## API (Node/TS) — módulos e arquivos
- `lib/`: jwt, password, email, errors, geo, age, premium (planos/superlikes/credits), adminPermission, accessLog (IP), **push** (notifyUser/notifyUsers/pushOnly — FCM-ready).
- `modules/auth` (app+painel, registra IP), `modules/profile` (perfil/prompts, location, online, photos, premium, **boost**, **incognito**, **purchase**, stats), `modules/match` (discovery c/ boost/incognito/filtros, swipe+nota, **swipe/undo**, matches, likes+nota, top-picks, userCard), `modules/chat` (REST+Socket, **gifts**), `modules/moderation`, `modules/verification`, `modules/device`, `modules/photoAccess`, `modules/admin` (dashboard, stats, users+detalhe+ações VIP/créditos/suspender/verify, reports+detalhe, verifications, delete, settings+flags, admins, **notifications/broadcast**), `modules/monetization` (products/gifts/ads/verses + config público store/ads/verse), `modules/dev` (live-match/likes/message).
- `sockets/index.ts` — auth handshake, salas user/match, message/read/typing (typing entregue na sala pessoal), match:new, emitToUser.
- Migrations: init, auth_email_codes, private_photos, premium_superlikes, access_logs, user_suspension, monetization, ads_full_options, user_credits, features_boost_rewind_prompts_verse.

## Painel (React/Tabler) — páginas
Login, Dashboard (mapa BR), Usuários (+detalhe/ações), Verificações, Denúncias (+investigação), Banidos, Exclusões, Admins, **Planos**, **Presentes**, **Anúncios** (AdMob completo), **Versos**, **Notificações** (broadcast), **Configurações** (flags). Componentes: Layout (menu navy+dourado), ui (Dialog/Toast), BrazilMap, UserLocationMap.

## Monetização/engajamento prontos
VIP/planos, créditos, super likes, boosts, presentes, **loja in-app** (concede via /me/purchase — falta verificação Google Play real), AdMob (IDs teste), verso do dia, boost, rewind, super like com recado, incógnito, filtros premium, notificações manuais, push FCM (ready), Analytics (ready).

## A FAZER nesta sessão (pedido agora)
1. Cadastrar ~10 versículos bonitos (seed).
2. Match → mensagem automática (sistema) no chat + abrir direto no chat.
3. Notificações: nova mensagem; nova curtida (só VIP vê quem; não-VIP recebe borrado e ao tocar é levado a assinar). Outros tipos conforme necessário.

---

# ✅ CONCLUÍDO — Match auto-mensagem + notificações de curtida/mensagem (19/06/2026 parte 4)

> Tudo abaixo está **implementado e compilando** (app `flutter analyze` limpo; API `tsc` limpo).
> **adb wireless: porta `192.168.3.212:33753`.**

## 1. Versículos (seed)
- `api/prisma/seedVerses.ts` — **12 versículos** cristãos cadastrados (referência + texto), exibidos como "Verso do dia" na descoberta (`/config/verse`). Seed já rodado com sucesso.

## 2. Mensagem automática de match (tipo SYSTEM)
- **Schema**: adicionado valor `SYSTEM` ao enum `MessageType` (migration `message_type_system`).
- **`api/src/modules/match/match.service.ts`** (`swipe`): ao criar um match novo, se ainda **não houver mensagens**, cria uma `Message` tipo `SYSTEM` com o texto
  `"🎉 Vocês deram match! Que tal começar a conversa? 💛"` e emite `message:new` aos **dois** usuários.
- **`api/src/modules/dev/dev.controller.ts`** (`liveMatch`): mesma mensagem SYSTEM ao simular match (testes do painel/dev).
- **`getMatches`**: a "última mensagem" e a contagem de **não lidas** ignoram mensagens `SYSTEM` (`type: { not: "SYSTEM" }`). Resultado: um match novo (só com a mensagem do sistema) continua aparecendo em **"Matches recentes"** (avatar redondo), não em "Conversas".
- **App `chat_page.dart`** (`_bubble`): mensagem `SYSTEM` renderiza como **banner central dourado** (fundo `gold 15%`, borda `gold 40%`, texto navy centralizado) — não é balão de remetente.
- **App `matches_page.dart`** (`_previewWidget`): como o backend nunca devolve SYSTEM como `lastMessage`, o preview nunca mostra o texto do sistema.

## 3. "Quando abrir, ir pro chat"
- A tela de celebração de match (`showMatchCelebration`, disparada por `match:new`) já tem botão **"Conversar"** que abre o `ChatPage` direto.
- Ao abrir, a mensagem SYSTEM já está lá convidando a iniciar a conversa.

## 4. Notificações
### Nova mensagem
- `chat.service.ts sendMessage` → `pushOnly` (FCM em background; ativa com `FCM_SERVER_KEY`).

### Nova curtida / super like (com gating premium)
- `match.service.ts swipe` (sem reciprocidade):
  - `LIKE` → `notifyUser(toUser, "Alguém curtiu você! 💛", "Você recebeu uma nova curtida. Veja quem foi!", { type: "like" })`.
  - `SUPERLIKE` → `notifyUser(toUser, "Você recebeu um Super Like! ⭐", "Alguém te super curtiu. Abra para ver!", { type: "superlike" })`.
  - A notificação é **genérica de propósito** (não revela quem) — o "quem" fica gated.
- **Gating premium** (já existia, agora amarrado ao fluxo de notificação):
  - Aba **Curtidas** (`likes_page.dart`): para não-premium as fotos de quem curtiu são **borradas** (`ImageFilter.blur 16`) e ao tocar abre a `PremiumPage` (`"Veja quem já te curtiu e dê match!"`). Premium vê tudo nítido + badge VIP.
- **SnackBar tappável** (`main_shell.dart onNotification`):
  - `type == "match"` → **não** mostra SnackBar (a celebração `match:new` já cobre, evita duplicar).
  - `type == "like" | "superlike"` → SnackBar navy com ação **"Ver"** (dourada) que leva à **aba Curtidas** (`_index = 1`), onde o não-premium vê borrado e é convidado a assinar.
  - Demais tipos → SnackBar informativa sem ação.

### Plumbing
- `api/src/lib/push.ts` `notifyUser`: o socket `notification:new` agora inclui o campo **`data`** (ex.: `{ matchId }`) além de `id/title/body/type/createdAt`, permitindo navegação contextual no app.
- `chat_socket.dart`: callback `onNotification(Map data)` já repassa o payload completo.

## Pendências externas (não-código)
- `FCM_SERVER_KEY` no `.env` para push real em background.
- `google-services.json` + `Firebase.initializeApp` para Analytics.
- Verificação de recibo Google Play Billing; `GOOGLE_CLIENT_IDS` para login Google.

## Validação desta sessão
- `cd aplicativo ; flutter analyze lib/views/app/chat_page.dart lib/views/app/main_shell.dart lib/views/app/matches_page.dart` → **No issues found**.
- `cd api ; npm run lint` (`tsc --noEmit`) → **limpo**.

---

# ✅ Ajustes — Verso no Perfil + Banner no chat + fix build AdMob/Analytics (19/06/2026 parte 5)

## Fix de build (manifest merger)
- `android/app/src/main/AndroidManifest.xml`: AdMob (`play-services-ads`) e Firebase Analytics (`play-services-measurement`) declaravam a mesma property `android.adservices.AD_SERVICES_CONFIG` com recursos diferentes → build falhava em `processDebugMainManifest`. Resolvido adicionando `xmlns:tools` e um `<property ... tools:replace="android:resource">` apontando para `@xml/gma_ad_services_config`.

## Verso do dia movido p/ o Perfil
- Removido o card de verso do topo da **Descoberta** (`discover_page.dart`) — junto com estado `_verseRef/_verseText` e `_loadVerse()`.
- Adicionado no **Perfil** (`profile_page.dart`): card "Verso do dia" (gradiente dourado, ✝️, texto itálico navy + referência dourada) logo após os cards rápidos. Carrega via `AppApi.getDailyVerse()`.

## Banner de anúncio no meio do chat
- `ads/app_banner.dart`: novo widget **`ChatInlineAd`** (BannerAd `AdSize.mediumRectangle`, card branco com legenda "Publicidade"). Fica `SizedBox.shrink()` até carregar — sem espaço vazio.
- `chat_page.dart`: a `ListView.builder` injeta o `ChatInlineAd` no índice do meio quando há **6+ mensagens** (`itemCount = msgs + 1`).

## Validação
- `flutter analyze` nos 4 arquivos → **No issues found**. App compilado e rodando no celular (porta 33753).

---

# ✅ Ajustes — Verso compacto + anúncios ocultos p/ VIP (19/06/2026 parte 6)

## Verso do dia mais compacto (Perfil)
- `profile_page.dart _verseCard()`: card reduzido — fundo dourado suave 10%, padding menor (12x9), ✝️ 14px, texto 11.5px (máx. 2 linhas, ellipsis), referência 10px. Ocupa bem menos espaço.

## Assinantes VIP NÃO veem anúncios
- `ads_service.dart`: novo `static bool isPremiumUser` + getter `shouldShowAds => enabled && !isPremiumUser`. O `load()` agora busca `AppApi.getStats()` e seta `isPremiumUser` ANTES de configurar os IDs — como banners e intersticial aguardam `load()`, o status já está correto quando checam `shouldShowAds`.
- `ads/app_banner.dart` (`AppBannerAd` e `ChatInlineAd`): trocado `AdsService.enabled` → `AdsService.shouldShowAds`.
- `interstitial_manager.dart` (`preload` e `maybeShow`): idem.
- `premium_page.dart _subscribe()`: ao assinar, seta `AdsService.isPremiumUser = true` para os anúncios sumirem **na hora**.

## Validação
- `flutter analyze` nos 5 arquivos → **No issues found**. App recompilado e rodando (porta 33753).

---

# ✅ Anúncios reativos em tempo real (19/06/2026 parte 7)

> Mudanças de anúncios no painel e assinatura VIP refletem no app **na hora**, sem reabrir.

## Backend
- `sockets/index.ts`: novo `emitToAll(event, payload)` (broadcast p/ todos os sockets conectados).
- `monetization.controller.ts updateAds()`: após salvar, dispara `emitToAll("config:ads", { changed: true })`.

## App (Flutter)
- `ads_service.dart`:
  - `ValueNotifier<int> revision` + `_bump()` — sinaliza widgets de anúncio para reavaliarem.
  - `setPremium(bool)` — marca VIP e notifica (esconde anúncios na hora).
  - `reload()` — `load(force:true)` + `_bump()` (recarrega config remota e reflete).
- `ads/app_banner.dart` (`AppBannerAd` e `ChatInlineAd`): agora ouvem `AdsService.revision`. Em cada mudança descartam o anúncio atual e recriam (ou somem) conforme `shouldShowAds` e os IDs atualizados.
- `chat_socket.dart`: novo callback `onConfigAds` ouvindo o evento `config:ads`.
- `main_shell.dart` (socket global): `onConfigAds: () => AdsService.reload()`.
- `premium_page.dart _subscribe()`: usa `AdsService.setPremium(true)` (reflete imediatamente).

## Fluxos cobertos
- Admin liga/desliga/edita anúncios no painel → `config:ads` → app recarrega config → banners/intersticial somem/aparecem/trocam de ID sem reabrir.
- Usuário assina VIP → anúncios somem na hora.

## Validação
- API `tsc` limpo; `flutter analyze` nos 5 arquivos → **No issues found**. App rodando (porta 33753); API e painel reerguidos.

---

# ✅ App 100% em tempo real (conta, anúncios, loja) (19/06/2026 parte 8)

## Causa do bug relatado
O `ProfilePage` (e Curtidas/Descobrir) só carregava status premium no `initState`. Como as 4 abas ficam num `IndexedStack` (vivas em memória), trocar de aba NÃO re-roda o `initState`. Resultado: ao dar VIP pelo painel ou comprar, o Perfil continuava com botão "Assinar" e sem selo VIP — só atualizava reabrindo o app.

## Barramento global de eventos (novo)
- `aplicativo/lib/services/realtime_bus.dart`: `RealtimeBus` com `ValueNotifier` `account` (mudou conta: VIP/créditos/selo/ban) e `store` (mudou planos/presentes/crédito). Métodos `accountChanged()` / `storeChanged()`.

## Telas reativas (escutam o barramento)
- `profile_page.dart`: escuta `RealtimeBus.account` → recarrega perfil + stats (selo VIP aparece, botão "Assinar"/card "Seja VIP" some na hora).
- `likes_page.dart`: escuta `account` → recarrega (gating premium das fotos).
- `discover_page.dart`: escuta `account` → recarrega stats (super likes/boosts/filtros VIP).
- `store_page.dart`: escuta `store` e `account` → recarrega produtos/créditos.

## Eventos de socket (servidor → app)
- `config:me` (para o usuário específico) emitido em: `grantPremium`, `revokePremium`, `banUser`, `unbanUser`, `suspendUser`, `unsuspendUser`, `addCredits`, `setVerified`.
- `config:store` (broadcast) emitido em: create/update/delete de products e gifts, e `updateMonetization`.
- `config:ads` (broadcast) já existia (updateAds).
- `chat_socket.dart`: callbacks `onConfigMe`, `onConfigStore` (além de `onConfigAds`).

## main_shell — tratamento central
- `onConfigMe(data)`:
  - `isPremium` → `AdsService.setPremium(...)` (esconde/mostra anúncios na hora).
  - `banned: true` / `suspended: true` → **logout forçado** imediato (limpa token, SnackBar e volta ao login).
  - senão → `RealtimeBus.accountChanged()` + `_tick++` (atualiza conversas).
- `onConfigStore()` → `RealtimeBus.storeChanged()`.
- `onConfigAds()` → `AdsService.reload()`.

## Compra in-app reflete na hora
- `premium_page.dart _subscribe()`: `AdsService.setPremium(true)` + `RealtimeBus.accountChanged()`.
- `store_page.dart _buy()`: se `kind == PREMIUM` → `AdsService.setPremium(true)`; sempre `RealtimeBus.accountChanged()`.

## Fluxos cobertos em tempo real (sem reabrir o app)
- Admin dá/remove VIP → selo + remoção do botão Assinar + anúncios somem/voltam.
- Admin dá créditos/super likes/boosts → refletem em Perfil/Descobrir/Loja.
- Admin verifica usuário → selo de verificação aparece.
- Admin bane/suspende → usuário é deslogado na hora.
- Admin edita planos/presentes/valor do crédito → Loja atualiza.
- Admin liga/desliga/edita anúncios → banners/intersticial reagem.
- Compra de VIP/itens no app → tudo reflete imediatamente.

## Validação
- API `tsc` limpo; `flutter analyze` nos 8 arquivos → **No issues found**.
- (App NÃO foi rodado a pedido do usuário; validado só por análise estática.)
