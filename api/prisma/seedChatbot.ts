import { PrismaClient, BotPersonality } from "@prisma/client";

const prisma = new PrismaClient();

interface R {
  category: string;
  personality: BotPersonality;
  priority: number;
  keywords: string[];
  responses: string[];
}

const RULES: R[] = [
  {
    category: "saudacao",
    personality: "ALL",
    priority: 10,
    keywords: ["oi", "ola", "olá", "eai", "e ai", "salve", "hey", "opa", "fala", "oie", "oii", "bom dia", "boa tarde", "boa noite"],
    responses: [
      "Oi! Tudo bem? 😊",
      "Olá! Que bom falar com você 💛",
      "Oi {name}! Como você está?",
      "E aí, tudo bem? 😄",
    ],
  },
  {
    category: "como_vai",
    personality: "ALL",
    priority: 9,
    keywords: ["tudo bem", "como vai", "como voce esta", "como está", "blz", "beleza", "tudo certo", "de boa"],
    responses: [
      "Tudo ótimo, graças a Deus! E você? 🙏",
      "Bem demais! Acabei de voltar da igreja 😇 E você?",
      "Tudo tranquilo por aqui! Como foi seu dia?",
    ],
  },
  {
    category: "elogio",
    personality: "SHY",
    priority: 8,
    keywords: ["linda", "lindo", "bonita", "bonito", "gata", "gato", "maravilhosa", "perfeita", "perfeito", "gracinha", "fofa", "fofo"],
    responses: [
      "Ai que vergonha 🙈 obrigada!",
      "Para com isso, fiquei toda sem graça 😳",
      "Aii obrigada, você também hein 💛",
    ],
  },
  {
    category: "elogio",
    personality: "FUNNY",
    priority: 8,
    keywords: ["linda", "lindo", "bonita", "bonito", "gata", "gato", "maravilhosa", "perfeita", "perfeito", "gracinha", "fofa", "fofo"],
    responses: [
      "Eu sei né, modéstia à parte 😂 brincadeira! Obrigada 💛",
      "Tá tentando me conquistar? Porque tá funcionando 😏",
      "Cuidado com esses elogios que eu acredito hein 😄",
    ],
  },
  {
    category: "elogio",
    personality: "EXTROVERT",
    priority: 8,
    keywords: ["linda", "lindo", "bonita", "bonito", "gata", "gato", "maravilhosa", "perfeita", "perfeito", "gracinha", "fofa", "fofo"],
    responses: [
      "Aww que fofo! Você também é um charme 😍",
      "Obrigada lindo! Já gostei de você 😄💛",
      "Que gentil! Me conta mais sobre você 😊",
    ],
  },
  {
    category: "elogio",
    personality: "ALL",
    priority: 7,
    keywords: ["linda", "lindo", "bonita", "bonito", "gata", "gato", "maravilhosa", "perfeita", "perfeito"],
    responses: ["Obrigada! Que gentil da sua parte 💛", "Aww, obrigada! 😊"],
  },
  {
    category: "idade",
    personality: "ALL",
    priority: 7,
    keywords: ["quantos anos", "sua idade", "que idade", "quantos vc tem", "quantos voce tem"],
    responses: ["Tenho {age} anos 😊 e você?", "{age} aninhos haha e você, quantos tem?"],
  },
  {
    category: "cidade",
    personality: "ALL",
    priority: 7,
    keywords: ["onde voce mora", "onde mora", "que cidade", "mora onde", "de onde voce", "de onde e"],
    responses: ["Eu moro em {city} 😊 e você?", "Sou de {city}! E você, é de onde?"],
  },
  {
    category: "fe",
    personality: "ALL",
    priority: 8,
    keywords: ["igreja", "congrega", "denominacao", "crente", "evangelico", "evangélico", "catolico", "católico", "jesus", "deus", "fe", "fé", "louvor", "biblia", "bíblia", "oração", "oracao"],
    responses: [
      "Amo falar de fé! Deus é muito bom mesmo 🙏 Você congrega onde?",
      "Que lindo! A fé é a base de tudo pra mim 💛 E pra você?",
      "Glória a Deus! Adoro um bom louvor 🎶 Qual seu louvor favorito?",
    ],
  },
  {
    category: "intencao",
    personality: "ALL",
    priority: 6,
    keywords: ["namorar", "namoro", "relacionamento", "casar", "casamento", "serio", "sério", "compromisso"],
    responses: [
      "Busco algo sério, com propósito e com Deus no centro 💍🙏",
      "Quero um relacionamento de verdade, sabe? Nada de brincadeira 💛",
      "Tô aqui buscando alguém pra caminhar junto na fé 😊",
    ],
  },
  {
    category: "interesses",
    personality: "ALL",
    priority: 5,
    keywords: ["hobby", "gosta de", "o que voce faz", "trabalha com", "faz o que", "tempo livre"],
    responses: [
      "Amo louvor, viajar e um bom café ☕ E você, do que gosta?",
      "Gosto de servir na igreja e ler. E você, o que curte fazer?",
    ],
  },
  {
    category: "despedida",
    personality: "ALL",
    priority: 6,
    keywords: ["tchau", "ate mais", "até mais", "ate logo", "até logo", "falou", "preciso ir", "vou indo", "boa noite pra voce"],
    responses: [
      "Tchau! Que Deus te abençoe 🙏💛",
      "Foi ótimo falar com você! Até logo 😊",
      "Vai com Deus! Falamos mais tarde 💛",
    ],
  },
];

async function main() {
  const count = await prisma.chatbotRule.count();
  if (count > 0) {
    console.log(`Já existem ${count} regras — nada a fazer.`);
    return;
  }
  for (const r of RULES) {
    await prisma.chatbotRule.create({ data: r });
  }
  console.log(`✅ ${RULES.length} regras de chatbot cadastradas.`);
}

main()
  .catch((e) => console.error(e))
  .finally(() => prisma.$disconnect());
