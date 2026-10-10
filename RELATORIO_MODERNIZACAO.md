# Relatório de auditoria e modernização — Namoro Cristão

**Data:** 30/09/2026  
**Escopo:** aplicativo Flutter, painel administrativo React/Vite, API Express/TypeScript, Prisma/PostgreSQL e infraestrutura local de produção.  
**Estado:** implementação local concluída e revisada; **nenhum deploy, commit ou push foi executado**.

## 1. Resumo executivo

A arquitetura foi auditada e modernizada nas três camadas. O fluxo ativo do aplicativo agora usa a API REST própria e Socket.IO; o painel foi tornado responsivo, acessível e resiliente; o backend recebeu validação de conta, autorização administrativa, segurança de segredos e uma infraestrutura completa para perfis virtuais com DeepSeek/OpenAI, personalidade individual e memória persistente.

Os bloqueadores semânticos encontrados durante a revisão — sessão terminal presa no splash, origem inválida do Socket.IO, perda de token FCM, modelo incompatível com provider, broadcast duplicável, reset concorrente de memória, saldo de Super Likes e logout tardio — foram corrigidos. A revisão final focada nesses fluxos retornou **APPROVED/PASS**.

O app não vende mais nada: a loja e o paywall foram substituídos por **recompensas por anúncio premiado** (ver 3.8), configuráveis no painel. Essa parte passou por quatro rodadas de revisão semântica (as três primeiras com correções; a quarta APPROVED, sem P0, P1 ou P2), e os ajustes feitos depois dela estão listados na seção 6.

O código não deve ser promovido automaticamente à produção: ainda são necessárias configuração de ambiente, aplicação controlada das migrations, backup do banco, configuração dos blocos do Google Ad Manager (incluindo o SSV) e decisões externas sobre armazenamento privado e conformidade de dados de IA.

## 2. Arquitetura atual

- **Aplicativo:** Flutter, API REST autenticada por JWT, Socket.IO para tempo real, Firebase Cloud Messaging para push, Hive para estado local e Google Mobile Ads.
- **Painel:** React + TypeScript + Vite, servido por Nginx, com rotas lazy-loaded e cliente HTTP com refresh single-flight.
- **Backend:** Express + TypeScript + Socket.IO + Prisma.
- **Banco:** PostgreSQL.
- **Produção prevista:** Docker Compose atrás de Traefik/Dokploy.

## 3. Principais melhorias implementadas

### 3.1 Bots e IA

- DeepSeek como provider padrão e OpenAI como alternativa.
- Endpoints oficiais fixos; URL arbitrária de provider não é aceita.
- Chaves por ambiente com precedência sobre o banco.
- Chaves salvas pelo painel cifradas com AES-256-GCM.
- Chave persistida vinculada ao provider para impedir envio ao fornecedor errado.
- Modelo individual também vinculado ao provider; override incompatível é ignorado/rejeitado com segurança.
- Configuração individual por perfil virtual:
  - personalidade;
  - prompt exclusivo;
  - modelo/provider;
  - temperatura;
  - ativação da IA;
  - ativação da memória.
- Regras determinísticas e fallback continuam disponíveis quando a IA está desativada ou falha.
- Identidade obrigatória: o prompt de sistema proíbe o bot de fingir ser humano.
- Aplicativo identifica esses perfis como **“Perfil virtual • IA”** em descoberta, detalhes, listas, match e chat.

### 3.2 Memória persistente

- Nova tabela `bot_conversation_memories`, uma memória acumulada por match.
- Contexto recente combinado com resumo durável e fatos conhecidos.
- Atualização incremental sem descartar automaticamente contexto antigo útil.
- Dados financeiros, documentos, senhas e tokens são proibidos no prompt de sumarização.
- `botMemoryEpoch` impede uma sumarização em voo de recriar memória depois de um reset administrativo.
- Painel permite visualizar contagem e limpar as memórias de um bot.

### 3.3 Broadcasts de bots

- Chave de idempotência vinculada ao hash canônico de bot, audiência, conteúdo e limite.
- Reutilização da mesma chave com payload diferente retorna conflito 409.
- Estados persistentes: `PENDING`, `PROCESSING`, `COMPLETED` e `FAILED`.
- Lease global e lease por destinatário.
- Snapshot persistente de destinatários.
- Ledger `bot_broadcast_recipients` com unicidade por broadcast/usuário.
- Mensagem e estado `SENT` são confirmados na mesma transação.
- Uma tentativa interrompida pode ser retomada com a mesma chave sem reenviar destinatários concluídos.
- Contadores representam mensagens persistidas; não simulam entrega push.
- Painel preserva a tentativa no `localStorage`, inclusive após reload, e exige confirmação para abandonar uma tentativa não terminal.

### 3.4 Segurança e autorização do backend

- Tokens de usuário e admin são diferenciados.
- Conta de usuário é revalidada em cada request e no handshake Socket.IO.
- Banimento, suspensão, exclusão e remoção de admin invalidam acesso existente.
- Gestão de IA, bots, presentes, anúncios, recompensas, configurações e broadcasts restrita a super-admin. As guardas dos roteadores de presentes/anúncios/versos e de recompensas são **por caminho**: uma guarda sem path interceptava toda requisição `/admin/*` e bloqueava o analytics do bot para admins comuns.
- Analytics de bot permanece disponível ao admin autenticado sem expor credenciais.
- CORS aceita somente origens HTTP/HTTPS exatas; wildcard, path, query e fragment são rejeitados.
- `trust proxy` usa quantidade de hops configurável.
- OTP usa gerador criptograficamente seguro e consumo compare-and-set.
- Login Google exige `email_verified=true`.
- Payloads Socket.IO são validados e `typing` exige participação em match ativo.
- Resposta atrasada do bot revalida match e bloqueios antes de persistir.

### 3.5 Descoberta, swipes e monetização interna

- Queries de idade/distância são validadas.
- Alvo do swipe precisa existir, estar ativo, ter perfil e não estar bloqueado/banido/suspenso.
- Super Like usa transação serializável e compare-and-set.
- Saldo diário e saldo bônus de Super Likes foram separados.
- A interação registra se consumiu diária, bônus ou possui proveniência legada desconhecida.
- Rewind devolve exatamente ao pool correto; registros legados voltam como bônus.
- Match recém-criado pode ser desfeito ignorando apenas a mensagem `SYSTEM`.
- Pagamentos removidos: não existem mais `/me/purchase`, `/me/premium`, CRUD de produtos nem valor do crédito em R$. `GET /me/stats` devolve só VIP, limites e saldos. O endpoint antigo que permitia a qualquer usuário autenticado se conceder VIP/créditos (`/me/purchase`, `/me/premium` em modo de desenvolvimento) deixou de existir. VIP continua existindo, mas só é concedido pelo painel.
- Ativar Boost é atômico: uma porta condicional abre a janela (só um pedido simultâneo passa) e o decremento é condicionado ao saldo; sem saldo a janela é revertida. Não gasta outro Boost enquanto um estiver ativo.
- Envio de presente debita os créditos de forma condicionada ao saldo, então envios simultâneos nunca deixam o saldo negativo (créditos agora só vêm de recompensas).
- O "dia" dos limites diários (Super Like diário e recompensas) vira à meia-noite de Brasília (UTC-3), independentemente do fuso do container (UTC).

### 3.6 Aplicativo Flutter

- Origem Socket.IO derivada com `Uri`; remover `/api` não corrompe mais `https://api...`.
- URLs relativas de mídia são normalizadas por helper compartilhado.
- Refresh single-flight vinculado à geração e ao refresh token da sessão.
- Timeout, rede, 429 e 5xx não apagam credenciais.
- 401 terminal, conta banida, suspensa ou indisponível encerram apenas a sessão capturada.
- Coordenador global trata expiração em splash, onboarding, chat e demais rotas.
- Splash diferencia ausência de sessão, perfil incompleto, erro terminal e indisponibilidade transitória.
- Logout usa snapshot atômico; rotina antiga não pode apagar login novo.
- Push possui listeners de foreground, abertura e rotação de token.
- Remoção FCM pendente é persistida; invalidação local termina antes da troca de conta e o DELETE remoto pode ser retomado.
- Presença possui heartbeat e tratamento explícito de lifecycle.
- Tap com `matchId` tenta abrir a conversa correta.
- Typing fabricado foi removido; o estado vem do socket e bots exibem indicação explícita de IA.
- Swipes só avançam visualmente após confirmação; erros preservam o card.
- Super Like do detalhe usa o mesmo gate de quota/recado.
- Loja e paywall foram removidos; os atalhos (cartões do perfil, Super Likes esgotados, notificação) levam à tela **Recompensas**. Recursos exclusivos VIP mostram apenas um aviso, sem caminho de compra.
- Controllers, timers e subscriptions auditados receberam descarte/guards de `mounted`.

### 3.7 Painel administrativo

- Sessão multiaba e refresh single-flight.
- Falhas transitórias no bootstrap preservam tokens e oferecem retry.
- Rotas e menus respeitam super-admin/permissões.
- Lazy loading por página e error boundary para falha de chunk/render.
- Drawer móvel com foco inicial, trap de foco, Escape, backdrop e breakpoint consistente.
- Modais acessíveis, confirmações assíncronas e toasts anunciados.
- Dashboard distingue zero real de dado indisponível e usa consulta agregada escalável no backend.
- Usuários com paginação real e ações ocultas sem permissão.
- Bots, regras e analytics tipados, validados e com estados de loading/erro/retry.
- Nginx com headers de segurança, shell sem cache e assets com hash imutáveis.

### 3.8 Recompensas por anúncio premiado (substituem a loja paga)

- **O que o usuário ganha:** Super Likes extras, Boosts ou créditos para presentes. Cada oferta (`ad_rewards`) define quantidade por anúncio, limite por dia, espera entre anúncios, texto, ordem e ativação. O painel tem a página **Recompensas** (menu Negócio & conteúdo) para criar, editar, ativar e excluir ofertas, ver os números e ajustar o teto diário por usuário.
- **Fluxo:** o app carrega um anúncio premiado do **Google Ad Manager**, reserva o resgate (`POST /me/rewards/:id/claims`), exibe o anúncio com `userId` e `customData=claimId` para o SSV e confirma (`POST /me/rewards/claims/:id/complete`). Um novo início expira o resgate anterior do mesmo usuário; só resgates concedidos contam para os limites.
- **Concessão idempotente:** a troca `PENDING→GRANTED` e o crédito do saldo ocorrem na mesma transação; confirmação do app, callback SSV, repetições e corridas não creditam em dobro. `transaction_id` do SSV é único.
- **SSV (verificação do Google):** `GET /api/ads/ssv` (público) valida a assinatura ECDSA/SHA-256 contra as chaves do Google (cache de 6h, renovação em rotação). Como o Google assina callbacks de qualquer conta, o painel guarda o **`ad_unit` esperado**. Um callback só é considerado se a assinatura for válida, trouxer o `custom_data` de um resgate nosso e, quando traz `user_id`, ele for o dono desse resgate; com o `ad_unit` esperado preenchido (obrigatório para exigir o SSV), callbacks de outro bloco são ignorados (não concedem e não viram "último callback"). Só vira "último callback aceito" o que pertence a um resgate nosso e não é resgate vencido nem `transaction_id` repetido; ele (data e `ad_unit`) aparece no painel, com botão "Usar o último" que pede confirmação de que o `ad_unit` é do bloco do admin. Uma URL assinada repetida de um resgate cujo prazo (10 min) já passou não conta como último callback. Callbacks recusados deixam linha no log (no máximo 5 por minuto) e a última recusa (motivo e `ad_unit`) aparece no painel; ela é guardada só em memória, zera ao reiniciar a API e também quando o bloco Premiado ou o `ad_unit` esperado mudam. Com `Exigir confirmação do Google` ligado, só o callback concede; desligado (padrão), o app confirma e o servidor aplica limites e uma espera mínima de 5s. A URL aparece no painel, com botão de copiar.
- **Ligar a exigência do SSV é protegido pelo servidor** (`409 SSV_NOT_READY` com a lista do que falta): ao ligar, exige Modo teste desligado, anúncios e formato Premiado ligados, ID do bloco salvo e ao menos um callback aceito. Sempre exige `ad_unit` esperado preenchido e, ao ligar ou ao trocá-lo com a exigência já ligada, igual ao `ad_unit` do último callback aceito (evita erro de digitação que faria todo resgate ficar pendente). Com a exigência ligada, `PUT /admin/ads` recusa trocar ou limpar o ID do bloco Premiado (`409 SSV_UNIT_LOCKED`), e a página Anúncios mostra o campo bloqueado. Com a exigência desligada, trocar o ID do bloco Premiado zera o último callback e o `ad_unit` esperado, para a prova ser refeita com o bloco novo (senão seria possível religar a exigência com um `ad_unit` que o bloco novo nunca envia). Esse reset não é à prova de tudo: um callback de resgate iniciado antes da troca e que chegue depois dela pode repor o "último callback" com o `ad_unit` do bloco antigo enquanto o esperado está vazio. Por isso o diálogo de "Usar o último" mostra a hora do callback (que deve ser a do teste do próprio admin) e a exigência só deve ser ligada depois de um teste feito com o bloco novo; fechar isso por completo pediria guardar o instante da troca em uma coluna nova. `PUT /admin/ads` e `PUT /admin/reward-settings` leem, decidem e gravam numa transação com a linha de `ad_settings` travada (`SELECT ... FOR UPDATE`), então não correm um sobre o outro. Com o Modo teste ligado a exigência fica suspensa (o bloco de demonstração nunca chama a URL).
- **Concorrência:** o início de resgate e o registro de swipes usam transação Serializable. Colisões (`P2034`) são repetidas com espera aleatória (de 25 a 75 ms multiplicados pelo número da tentativa; 5 tentativas no resgate, 4 no swipe). Na revisão semântica, em PostgreSQL descartável, isso eliminou os `409` até 20 pedidos simultâneos; a 40 simultâneos ainda sobraram falhas (até cerca de 10% nos swipes mútuos e, nos inícios de resgate, até cerca de 23% quando o planner escolhe o índice `(status, createdAt)` com a tabela quase toda `GRANTED`). O esgotamento devolve `409 REWARD_CONFLICT`/`SWIPE_CONFLICT`, deixa um aviso no log e o app pode tentar de novo; cada colisão tratada ainda aparece como erro `P2034` no log do Prisma (ruído esperado). Se o tráfego chegar a esse nível, o caminho é serializar por usuário (lock consultivo), mas não é uma troca simples: só é seguro se a concessão (`PENDING→GRANTED`) tomar o mesmo lock, ou se o início reavaliar os limites depois de expirar o resgate anterior. Sem isso, uma concessão concorrente passa entre a leitura dos limites e a criação do novo resgate e o usuário ganha um resgate acima do limite diário; hoje o Serializable fecha essa janela.
- **Blocos e modo teste:** o bloco do anúncio premiado continua na página **Anúncios**. Com **Modo teste** ligado o app usa o bloco de demonstração do Ad Manager (`/21775744923/example/rewarded`); desligado, só usa o ID salvo. O servidor aplica a mesma regra do app: sem Modo teste e sem ID salvo, as recompensas ficam indisponíveis. Os aparelhos de teste do painel agora são aplicados ao SDK.
- **Teto diário:** é **por usuário** e soma todas as recompensas (não existe teto somado de todos os usuários).
- **Exclusão de ofertas:** só ofertas sem resgates podem ser excluídas (FK `RESTRICT`); as demais são desativadas. Isso preserva o histórico e a base dos limites diários.
- **Boost utilizável:** a ativação de Boost não tinha tela no app. Foi adicionada (cartão de Boosts no perfil e na tela Recompensas).
- **Dados legados:** `products`, `monetization_settings` e os enums de produto permanecem no banco apenas como histórico (nenhuma migration destrutiva).

## 4. Migrations de banco

Arquivos:

- `api/prisma/migrations/20260623010000_ai_bot_memory/migration.sql`
- `api/prisma/migrations/20260624010000_ad_rewards/migration.sql`

A migration `ai_bot_memory` adiciona, entre outros:

- provider/modelo/temperatura/memória por bot;
- `botMemoryEpoch`;
- `bonusSuperLikes`;
- proveniência anulável de Super Like legado;
- provider associado à chave de IA;
- origem e latência dos logs de chatbot;
- memória de conversa;
- status, hash e leases de broadcast;
- ledger de destinatários;
- índices de suporte.

A migration `ad_rewards` cria os enums `RewardKind`/`RewardClaimStatus`, as tabelas `ad_rewards` e `ad_reward_claims` (FK do usuário com `CASCADE` e da oferta com `RESTRICT`, índices por usuário/status, oferta e status/data), cinco colunas em `ad_settings` (`rewardsRequireSsv`, `rewardsMaxPerDay`, `rewardsSsvAdUnit`, `rewardsSsvLastAt`, `rewardsSsvLastAdUnit`) e semeia três ofertas iniciais (Super Likes, Boost e créditos), editáveis no painel.

**As migrations foram aplicadas apenas a um PostgreSQL 16 descartável, local (as 17 em sequência, sem erro e sem drift em relação ao `schema.prisma`). Nenhum banco real foi alterado.** Antes da aplicação em produção:

1. criar backup verificável do PostgreSQL;
2. testar `prisma migrate deploy` em uma cópia/staging;
3. validar backfills e contagens;
4. só então permitir que o container de produção execute a migration.

## 5. Configuração obrigatória de produção

O arquivo `.env.production.example` foi atualizado. Variáveis críticas:

| Variável | Obrigatoriedade/uso |
|---|---|
| `DATABASE_URL` ou `POSTGRES_*` | Banco PostgreSQL |
| `JWT_ACCESS_SECRET` | Obrigatória, forte e exclusiva |
| `JWT_REFRESH_SECRET` | Obrigatória, forte e diferente da anterior |
| `CORS_ORIGINS` | Obrigatória; origem exata do painel |
| `TRUST_PROXY_HOPS` | `1` no cenário Traefik/Dokploy atual |
| `VITE_API_BASE` | URL pública da API com `/api` |
| `AI_SECRET_ENCRYPTION_KEY` | Obrigatória em produção, mínimo 32 caracteres, diferente dos JWTs |
| `DEEPSEEK_API_KEY` | Recomendada para o provider padrão |
| `OPENAI_API_KEY` | Opcional, para usar OpenAI |
| `AI_REQUEST_TIMEOUT_MS` | 1000–120000; exemplo: `15000` |
| `FIREBASE_SERVICE_ACCOUNT_B64` | Recomendada para push HTTP v1 |
| `GOOGLE_CLIENT_IDS` | Necessária se login Google estiver ativo |

Não preencher segredos em arquivos versionados; usar o ambiente seguro do Dokploy.

## 6. Validações executadas

| Validação | Resultado |
|---|---|
| `npx prisma validate` | PASS |
| `npm run prisma:generate` | PASS |
| `npm run build` em `api/` | PASS |
| `npx tsc --noEmit --pretty false` no painel | PASS |
| `npm run build` em `painel-web/` | PASS |
| `dart format` nos Dart alterados | PASS, sem alterações pendentes |
| `flutter analyze --no-pub` após as correções finais | PASS — `No issues found` |
| `prisma migrate deploy` das 17 migrations em PostgreSQL 16 descartável | PASS |
| `prisma migrate diff` (banco migrado × `schema.prisma`) | PASS — sem diferenças |
| Integração das recompensas em PostgreSQL descartável (limites, espera, teto, SSV, idempotência, concessões e inícios concorrentes, expiração, Boost atômico) | PASS (scripts temporários, removidos depois) |
| Rotas HTTP novas/removidas, permissões e validações (usuário, admin comum e super-admin; analytics do bot aberto ao admin comum) | PASS (scripts temporários, removidos) |
| Callbacks SSV assinados com par de chaves local contra a rota real (válido, `ad_unit` de outro bloco, `user_id` divergente, repetição, adulterado) e leitura das chaves reais do Google | PASS |
| Ordem das checagens do callback (resgate inexistente, `custom_data` inválido, outro usuário e outro `ad_unit` não viram "último callback"), validações de `PUT /admin/reward-settings` (digitação errada, campo vazio, troca com a exigência ligada, Modo teste, bloco ausente), trava `SSV_UNIT_LOCKED` em `PUT /admin/ads`, 10 inícios de resgate simultâneos e 12 swipes mútuos simultâneos | PASS — 49 verificações em PostgreSQL descartável (script temporário, removido); 10/10 inícios concluídos e 1 match por par |
| Achados da 3ª revisão: trocar o bloco Premiado zera a prova do SSV (esperado, último callback e `ad_unit`) e religar com o esperado antigo é recusado; corpo de `PUT /admin/ads` sem o ID não gera `409` falso; recusas de callback registradas e expostas ao painel; SSV que chega depois da confirmação do app vira "último callback", mas resgate vencido e `transaction_id` repetido não; 120 pares simultâneos de `PUT /admin/ads` × `PUT /admin/reward-settings` sem estado impossível (trava de linha); 10 inícios de resgate e 12 swipes mútuos simultâneos | PASS — 39 verificações em PostgreSQL descartável (script temporário, removido); 73 pares com Anúncios antes e 47 com Recompensas antes |
| Ajustes pós-4ª revisão: URL assinada repetida de resgate vencido não avança o último callback (dentro do prazo ainda avança, sem crédito em dobro); SSV tardio depois da confirmação do app vira último callback; a recusa em memória é limpa ao mudar o `ad_unit` esperado ou o bloco Premiado e mantida ao salvar sem mudá-los | PASS — 15 verificações em PostgreSQL descartável (script temporário, removido) |
| `npx tsc --noEmit` na API e no painel e `vite build` do painel depois dos ajustes pós-4ª revisão | PASS |
| Boost e envio de presente sob concorrência (um sucesso, saldo nunca negativo) | PASS |
| `git diff --check` | PASS; somente avisos informativos LF→CRLF |
| Revisão semântica final dos bloqueadores de sessão, Socket.IO, FCM, IA e Super Likes (anterior às recompensas) | APPROVED/PASS |
| Revisão semântica das recompensas por anúncio premiado (4 rodadas) | 1ª, 2ª e 3ª: NEEDS_CHANGES, com os achados corrigidos (a 3ª teve 1 P2, só no modo SSV, e 9 P3). 4ª: **APPROVED**, sem P0, P1 ou P2 e com 9 P3. Depois da 4ª foram aplicados, **sem nova rodada**, os P3 de repetição de URL assinada, recusa em memória, painel (foco do teclado, "Atualizar", campo travado) e relatório; o P3 do callback em voo do bloco antigo ficou como limitação documentada (3.8) |
| `flutter build apk --debug --no-pub` | PASS em checkpoint anterior; duas repetições após a última guarda de logout foram interrompidas externamente com `^C` |

Não há suíte first-party de testes automatizados nem scripts de teste na API/painel. A ausência foi mantida porque a tarefa não autorizou criar testes.

## 7. Limitações e pendências antes de produção

1. **Anúncio premiado e SSV:** o SSV segue a documentação do Google e foi exercitado com callbacks assinados por uma chave local e com a leitura das chaves reais do Google, mas **não com um callback real do Ad Manager** (conta ainda não configurada). Por isso `Exigir confirmação do Google` nasce desligado e o servidor só deixa ligá-lo depois de aceitar um callback (assinado pelo Google, de qualquer conta, ligado a um resgate nosso) e com o `ad_unit` esperado igual ao dele. Enquanto estiver desligado (padrão), o app confirma o resgate e o servidor limita por oferta, por dia e por espera. Isso contém fraude, mas só o SSV impede resgates sem ver o anúncio. O formato do `ad_unit` no Ad Manager só é conhecido com um callback real; o painel mostra o recebido para o admin confirmar. Enquanto o `ad_unit` esperado estiver vazio, quem tem conta no app e uma conta própria de anúncios consegue gerar um callback assinado para o próprio resgate (ou repetir, dentro dos 10 minutos de vida do resgate, uma URL assinada que tenha visto, por exemplo em log de proxy) e aparecer como "último callback"; por isso o painel pede a confirmação do `ad_unit` e da hora ao usar o último e orienta a salvar o esperado assim que ele for conferido. Salvar o esperado passa a ignorar blocos de outras contas mesmo com a exigência desligada, mas não impede a repetição de uma URL legítima dentro desse prazo (sem crédito em dobro, por causa do `transaction_id`). Não confirmado sem um teste real: se o Ad Manager envia o SSV para anúncios de teste e para aparelhos cadastrados em "IDs de dispositivos de teste" (Anúncios); no primeiro teste, se nenhum callback chegar, assista com o aparelho fora dessa lista. Com o SSV exigido, iniciar outro anúncio antes do callback do anterior expira o anterior (o app espera até ~20s, então é raro), e um callback depois do prazo de 10 minutos é ignorado.
2. **Fotos privadas:** URLs são removidas de DTOs públicos, mas `/uploads` ainda é storage estático. Privacidade forte exige bucket privado e URLs assinadas curtas ou endpoint autenticado.
3. **Tokens locais:** JWTs permanecem no Hive comum; produção móvel deve migrar para Keychain/Keystore.
4. **Fila de resposta da IA:** serialização por match ainda é em memória do processo. Operação multi-réplica exige fila/lock distribuído.
5. **Retomada de broadcast:** é durável, mas request-driven; não existe worker autônomo para retomar lease expirado.
6. **LGPD/IA:** perfil, fé, histórico e memória podem ser enviados ao provider configurado. Revisar consentimento, base legal, retenção e contrato com o fornecedor.
7. **Exclusão de conta:** revisar retenção/anonimização de mensagens, logs, memórias e arquivos físicos segundo política jurídica definida.
8. **Autenticação e abuso:** ainda é recomendável adicionar rate limiting para login/OTP (e, de forma geral, para endpoints autenticados como o início de resgates, que grava uma linha por pedido; linhas não concedidas com mais de 7 dias são apagadas), além de persistência/revogação server-side de refresh tokens.
9. **Configuração mobile:** termos, privacidade e IDs definitivos do Ad Manager (App ID no `AndroidManifest`, hoje o de teste do Google, e os blocos no painel) precisam ser preenchidos antes da publicação. Banner e intersticial ainda usam as classes do AdMob; só o anúncio premiado já usa Ad Manager.
10. **Validação live:** FCM, Socket.IO, DeepSeek e Ad Manager precisam de smoke test em staging com serviços reais (a migration já foi exercitada em PostgreSQL descartável).
11. **iOS:** não foi compilado nesta máquina Windows.
12. **APK final:** repetir `flutter build apk --debug --no-pub` em terminal estável, pois a execução final foi cancelada externamente.
13. **Código legado de compras:** o pacote `purchases_flutter` e a permissão `com.android.vending.BILLING` continuam no app porque código fora do fluxo de compra ainda importa o RevenueCat: `views/custom/subscription_builder.dart`, `providers/auth_providers.dart` e os providers de `providers/subscriptions/` (ofertas, assinatura e inicialização). Remover junto com esses arquivos.
14. **"Ver quem te curtiu":** continua exclusivo VIP, travado só no app (a API ainda devolve a lista). Para virar recompensa por anúncio, a trava precisa ir para o servidor primeiro.
15. **Versões antigas do app:** não há versão mínima nem aviso de atualização. Quem ainda roda a versão com loja/VIP abre essas telas vazias (as rotas de compra deixaram de existir) e não vê as recompensas até atualizar.
16. **Erros de infraestrutura como 500 e diagnóstico por processo:** estouro de timeout de transação (`P2028`) e de espera por conexão do pool (`P2024`) sobem como 500 genérico (o `errorHandler` é global); as duas transações novas do painel (Anúncios e Recompensas) usam o timeout padrão de 5 s. A última recusa de callback do SSV fica em memória por processo, então zera ao reiniciar e, com mais de uma réplica da API, mostra só a da réplica que atendeu (soma-se ao item 4).

## 8. Checklist recomendado de release

- [ ] Revisar e aceitar o diff local.
- [ ] Guardar também todos os arquivos novos ainda não rastreados.
- [ ] Configurar todas as variáveis obrigatórias no Dokploy.
- [ ] Fazer backup e restore-test do PostgreSQL.
- [ ] Aplicar migration em staging e validar os backfills.
- [ ] Testar login, refresh, ban/suspensão e logout concorrente.
- [ ] Testar socket/reconnect, typing e abertura de push por `matchId`.
- [ ] Testar DeepSeek com dois bots, prompts/modelos distintos e reset de memória.
- [ ] Interromper e retomar um broadcast usando a mesma chave.
- [ ] Confirmar que perfis virtuais são identificados em todos os fluxos.
- [ ] Validar painel em 320, 375, 768 e 1024 px, além de teclado/axe.
- [ ] Repetir build APK final e, em macOS, build iOS sem assinatura.
- [ ] Criar os blocos no Ad Manager, salvar os IDs em Anúncios, desligar o Modo teste e testar uma recompensa de ponta a ponta.
- [ ] Configurar a URL do SSV no bloco Premiado, validar o callback e só então ligar `Exigir confirmação do Google`.
- [ ] Migrar fotos privadas para storage protegido.
- [ ] Só então autorizar deploy, commit e push.
