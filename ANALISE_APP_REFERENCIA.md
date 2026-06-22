# 📊 ANÁLISE DO APP DE REFERÊNCIA ("Encontros" / mypair.app antigo)

> Documento de análise das telas enviadas pelo dono do projeto, mostrando como
> o produto era ANTES (versão mais completa). Objetivo: mapear **tudo** que existe
> nessa referência para agregar/replicar no **Namoro Cristão**.
> Cada item traz: **o que é**, **como aparenta funcionar** e **status no nosso app**.
> Data da análise: 21/06/2026.

---

## ⚠️ DECISÃO DO DONO (21/06/2026)
> **Papel "Gerente" foi DESCARTADO.** O próprio **Admin** gerencia os Modelos
> diretamente (sem camada de manager). **Manter tudo** de **Bots, Regras de Bot,
> Analytics do Bot e Bots com IA** — é prioridade. Hotmart/Gerente saem do escopo.

---

## 🎭 1. PAPÉIS DE USUÁRIO (3 níveis de acesso)

A referência tem **três papéis distintos**, com login único e "ACESSO DEMO" na tela
de entrada (botões: **Admin**, **Gerente**, **Usuário**):

| Papel | O que faz |
|-------|-----------|
| **Admin** | Controla tudo: bots, anúncios, vendas, gerentes, push, configurações. |
| **Gerente** (Manager) | Cria e gerencia **Modelos** (perfis isca), faz **Disparo de Modelos**, vê assinantes, integra Hotmart. |
| **Usuário** | Usa o app normal (swipe, chat, missões). |

- **Status no nosso app:** temos só **Admin** (painel) e **Usuário** (app). **FALTA o papel "Gerente"** e toda a camada de **Modelos**.

---

## 🤖 2. BOTS / CHATBOT (o coração da monetização da referência)

### 2.1 Regras do Bot (chatbot por palavra-chave) — `/admin/chatbot-rules`
Tela "Regras do Chatbot — Palavras-chave e respostas automáticas dos robôs (**25 regras**)".

Cada **regra** tem:
- **Categoria** (ex.: `saudacao`, `elogio`).
- **Personalidade**: `Todas`, `Tímida`, `Engraçada`, `Extrovertida` (a mesma categoria tem variações por personalidade do bot).
- **Prioridade** (0–10) — qual regra ganha quando várias batem.
- **Palavras-chave** (separadas por vírgula). Ex. saudação: `oi, ola, olá, eai, e ai, salve, hey, opa, fala, bom dia, boa tarde, boa noite, oie, oii, olii`.
- **Respostas** (uma por linha; o bot **sorteia** uma). Ex.: "Oi! Tudo bem? 😊", "Olá! Como você está?", "E aí, tudo bom? 💜".
- **Variáveis dinâmicas** nas respostas: `{name}`, `{age}`, `{city}` (personaliza com dados do usuário real).
- **Toggle "Regra ativa"** por regra.
- Busca por palavra-chave/categoria/resposta + filtro por categoria + botão "**+ Nova Regra**".

Exemplos de categorias vistas:
- `saudacao` (Todas, prioridade 10).
- `elogio` em 3 personalidades (Tímida / Engraçada / Extrovertida), prioridade 9 — keywords: `linda, gata, bonita, gostosa, maravilhosa, perfeita, princesa, deusa, musa, gatinha`. Respostas combinam com a personalidade (a tímida fica encabulada, a engraçada brinca, a extrovertida puxa papo).

### 2.2 Analytics do Bot — `/admin/chatbot-analytics`
"Categorias acionadas e mensagens sem match". Cards:
- **Total de Interações** (ex.: 3)
- **Categorias Únicas** (ex.: 1)
- **Fallbacks** (mensagens que o bot não soube responder, ex.: 2)
- **Taxa de Match** (% de mensagens que bateram numa regra, ex.: 33,3%)
- Gráfico **Top Categorias** (barras) + **Distribuição por Categoria** (pizza).
- Tabela **"Mensagens sem Match (Fallbacks)"** com colunas: Mensagem, Idioma, Data → serve pra descobrir o que cadastrar de nova regra.

### 2.3 Bots futuros com IA (pedido explícito do dono)
> "cadastrar bots futuros para conversar com pessoa via IA"

Ou seja, além das regras fixas por palavra-chave, querem **bots que conversam via IA**
(LLM) de forma natural, mantendo o usuário engajado (e empurrando pra assinar/comprar).
A ideia: o "Modelo" (perfil isca) responde sozinho — primeiro por regras, depois por IA.

- **Status no nosso app:** **NÃO temos NADA disso.** É um módulo grande e central da estratégia. Precisa: modelo de dados de regras, motor de matching de palavra-chave com prioridade/personalidade, analytics, e (fase 2) integração com IA (OpenAI/Gemini) por trás dos Modelos.

---

## 🧑‍🎤 3. MODELOS (perfis isca gerenciados) — painel do GERENTE

Tela "Modelos — Crie perfis de modelos e compartilhe links para atrair usuários".
- Cartão de modelo: foto, **Nome** (Ana Clara), **gênero** (F), **idade** (22), **bio** ("Amo louvar e caminhar na praia"), contador de **matches** (0 matches), botão **"Copiar Link"** (ex.: `/models/ana-clara-5502`), editar e excluir. Botão "**+ Nova Modelo**".
- **Editar Modelo**: Nome, Idade, Gênero, Bio, **Fotos (máx. 5)**.
- **"Copiar Link"** → link público de captação: a pessoa que abre cai num funil/cadastro já "conversando" com aquela modelo (estratégia de aquisição via tráfego pago/links).

### 3.1 Disparo de Modelos — `/manager/disparo` e `/admin/...`
Item de menu "**Disparo Modelos**" no Gerente e no Admin. Provável função: **disparar
mensagens em massa** pelas modelos (broadcast) para usuários — reengajamento/venda.

- **Status no nosso app:** **NÃO temos.** Temos perfis de teste (seed), mas não um sistema gerenciável de Modelos com link de captação, contador de matches e disparo.

---

## 🎮 4. GAMIFICAÇÃO / MISSÕES (aba "Missões" no app)

Tela com cabeçalho **"Nível 1"** (ícone de fogo), saldo de **moedas (🪙 0)** e **gemas (💎 0)**,
barra de **XP (0/100)** e "Próxima recompensa no Nível 2: 🏅 **Selo Iniciante**".
Abas: **Missões** e **Ranking**.

Missões observadas (com recompensa e progresso):
| Missão | Objetivo | Recompensa |
|--------|----------|-----------|
| Missão Social | Envie 5 mensagens hoje | 100 🪙 |
| Missão Explorador | Assista 20 vídeos | 1 🎁 |
| Missão Explorador | Veja 20 perfis no feed | 1 ⚡ (super like) |
| Missão Sorte Grande | Consiga 2 matches | 1 🎁 / 200 🪙 |
| Primeiro Like | Dê seu primeiro like do dia | 25 🪙 |
| Fogo no Chat | Tenha 3 conversas ativas | 150 🪙 |

Conceitos:
- **Níveis + XP** (progressão), **moedas** e **gemas** (2 moedas virtuais), **selos/badges** por nível.
- **Ranking** (competição entre usuários — engajamento).
- Recompensas das missões **dão super likes / presentes / moedas** → isso explica o
  "aqui que tem poucos super" (os super likes saem como **recompensa de missão**, não só comprados).

- **Status no nosso app:** temos super likes/boosts/créditos e loja, mas **NÃO temos níveis, XP, missões, gemas, selos nem ranking.** Falta o sistema de gamificação completo.

---

## 💝 5. ENVIAR PRESENTE DURANTE O SWIPE (no card de descoberta)

No card de descoberta (Beatriz Lima, 25), os botões de ação são **quatro**:
- ✖️ (passar/dislike)
- 🎁 (**enviar presente** — direto no card, antes mesmo do match!)
- ❤️ (curtir — botão central grande)
- ⚡ (super like / boost)

Ou seja: dá pra **mandar presente pra pessoa enquanto curte/descobre**, não só dentro do chat.
Isso é um gatilho de venda forte (gasta crédito/gema pra se destacar antes do match).

- **Status no nosso app:** nosso card de descoberta tem só passar / curtir / super like / (rewind, boost). **FALTA o botão de presente no card** (hoje presente só existe dentro do chat).

---

## 🧭 6. ONBOARDING (cadastro em 5 etapas)

Wizard com barra de progresso (ex.: "2 de 5 — 40%"):
1. (etapa 1 — provavelmente nome/foto)
2. **"Qual é o seu gênero?"** → Homem, Mulher, Não-binário, Outro.
3. **"Quem você quer conhecer?"** → Homens, Mulheres, Todos.
4. **"O que você está buscando?"** → Relacionamento, Algo casual, Amizades, Não sei ainda.
5. (etapa 5 — provavelmente localização/finalizar)

- **Status no nosso app:** temos onboarding (6 etapas), gênero, intenção e localização. Cobertura parecida. **Diferença:** a referência separa "quem quer conhecer" (preferência de gênero do match) como passo próprio — vale conferir se temos esse filtro de preferência.

---

## 🖥️ 7. PAINEL ADMIN — itens de menu da referência

Menu lateral do Admin (roxo):
- **Dashboard**
- **Gerentes** (gestão dos managers) — ⚠️ não temos
- **Vendas** (relatório de vendas) — ⚠️ não temos tela dedicada
- **Chat & Bloqueio** (moderação de chats + bloqueios)
- **Push Ativos** (push notifications ativas/agendadas)
- **Notificações** (envio manual) — ✅ temos
- **Regras do Bot** — ⚠️ não temos
- **Analytics Bot** — ⚠️ não temos
- **Anúncios** — ✅ temos
- **Disparo Modelos** — ⚠️ não temos
- **Presentes** — ✅ temos
- **Assinatura App** (gestão de planos/assinaturas) — ✅ temos (Planos)
- **Webhook Logs** (logs de webhooks — ex.: Hotmart/pagamento) — ⚠️ não temos
- **Configurações** — ✅ temos

Menu lateral do **Gerente**:
- Dashboard, **Assinantes**, **Modelos**, **Disparo Modelos**, Anúncios, **Hotmart**, Configurações.

---

## 💳 8. INTEGRAÇÃO DE PAGAMENTO (Hotmart)

Item "**Hotmart**" no painel do Gerente + "**Webhook Logs**" no Admin. Indica que a
monetização web (assinaturas/produtos) passa pela **Hotmart** com **webhooks**
(confirmação de pagamento → libera VIP). Diferente do nosso atual (Google Play Billing no app).

- **Status no nosso app:** temos planos/loja e (no app) Google Play Billing como plano. **FALTA** integração Hotmart + recebimento de webhooks (importante pra venda via web/link de modelo).

---

## 🎨 9. IDENTIDADE VISUAL DA REFERÊNCIA

- Tema **roxo/rosa (gradiente)**, logo coração, nome "**Encontros**".
- **Atenção:** o NOSSO app é **dourado #D4AF37 + navy #111D40**, nome **Namoro Cristão**, nicho **cristão**. Ou seja, **mantemos nossa identidade** — aproveitamos as **funcionalidades**, não o visual roxo.

---

## ✅ 10. RESUMO — O QUE FALTA NO NAMORO CRISTÃO (backlog priorizado)

### 🔴 Prioridade ALTA (núcleo de engajamento/venda da referência)
1. **Modelos (perfis isca)** gerenciados pelo **Admin** (sem papel Gerente) + link público de captação (`/models/slug`).
2. **Bots / Regras de Chatbot** (palavra-chave → resposta, com personalidade, prioridade, variáveis `{name}{age}{city}`) + **Analytics do Bot** (fallbacks, taxa de match).
3. **Bots com IA** (fase 2): Modelos respondendo via LLM (OpenAI/Gemini).
4. **Gamificação**: níveis, XP, moedas, gemas, **missões** (com recompensas em super like/presente/moeda) e **ranking**.
5. **Presente no card de descoberta** (botão 🎁 antes do match).

### 🟡 Prioridade MÉDIA
6. **Disparo de Modelos** (broadcast de mensagens pelas modelos — agora acionado pelo Admin).
7. **Vendas** (relatório financeiro) no painel.
8. **Push Ativos** (agendamento/gestão de push).

### ❌ Fora de escopo (decisão do dono)
- Papel **Gerente** (Admin faz tudo).
- **Hotmart + Webhook Logs** (mantém Google Play Billing no app).

### 🟢 Já temos (equivalente)
- Notificações manuais, Anúncios (AdMob completo), Presentes (no chat), Planos/Assinatura, Configurações, moderação (denúncias/banidos), verso do dia, super like/boost/rewind, modo incógnito, tempo real.

---

## 📝 NOTAS / DÚVIDAS PARA O DONO
- O **"link da modelo"** leva a um cadastro já vinculado àquela modelo (a pessoa começa "conversando" com ela)? Confirmar o funil exato.
- Os **bots com IA** devem usar qual provedor (OpenAI? Gemini?) e qual orçamento por mensagem?
- **Gemas vs Moedas**: qual a diferença de uso (gema = premium/comprada, moeda = ganha em missão)? Confirmar regras de economia.
- **Hotmart**: vamos manter Google Play no app E Hotmart no web, ou só um?
- Missões: lista fixa ou cadastrável pelo admin (provável que admin cadastre)?

---

> Próximo passo sugerido: transformar o backlog ALTA em specs e implementar por módulo,
> mantendo nossa identidade (dourado/navy, nicho cristão) e o tempo real que já temos.
