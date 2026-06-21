/**
 * Script de simulação para testes (idempotente).
 *
 * - Garante o usuário-alvo (padrão: maria@teste.com) com perfil e fotos.
 * - Garante um elenco de perfis com FOTOS DE ROSTO reais (randomuser + pravatar).
 * - Faz vários perfis CURTIREM / SUPER CURTIREM o alvo (aparece em "Curtidas").
 * - Cria MATCHES + CONVERSAS com mensagens não lidas (aparece em "Matches").
 *
 * Uso: npx tsx prisma/simulate.ts [emailDoAlvo]
 */
import { PrismaClient, Gender, InteractionType, MessageType } from "@prisma/client";
import argon2 from "argon2";

const prisma = new PrismaClient();

const TARGET_EMAIL = process.argv[2] || "maria@teste.com";

/** Gera 3 fotos de ROSTO reais e estáveis para um perfil. */
function faces(g: "men" | "women", ruIdx: number, pv1: number, pv2: number): string[] {
  return [
    `https://randomuser.me/api/portraits/${g}/${ruIdx}.jpg`,
    `https://i.pravatar.cc/600?img=${pv1}`,
    `https://i.pravatar.cc/600?img=${pv2}`,
  ];
}

function birthdayForAge(age: number): Date {
  const d = new Date();
  d.setFullYear(d.getFullYear() - age);
  d.setMonth(2, 15);
  d.setHours(0, 0, 0, 0);
  return d;
}

interface P {
  email: string;
  fullName: string;
  gender: Gender;
  age: number;
  city: string;
  lat: number;
  lng: number;
  denomination: string;
  churchFrequency: string;
  intention: string;
  about: string;
  interests: string[];
  photos: string[];
}

// Elenco masculino (curtidores naturais para uma usuária) + alguns extras.
const PEOPLE: P[] = [
  {
    email: "lucas.pereira@teste.com",
    fullName: "Lucas Pereira",
    gender: "MALE",
    age: 27,
    city: "São Paulo",
    lat: -23.54,
    lng: -46.64,
    denomination: "Batista",
    churchFrequency: "Toda semana",
    intention: "Namoro sério",
    about: "Engenheiro e baterista na igreja. Quero um lar com Deus no centro.",
    interests: ["Louvor & Adoração", "Esportes", "Música"],
    photos: faces("men", 11, 11, 12),
  },
  {
    email: "gabriel.santos@teste.com",
    fullName: "Gabriel Santos",
    gender: "MALE",
    age: 29,
    city: "Campinas",
    lat: -22.91,
    lng: -47.07,
    denomination: "Presbiteriana",
    churchFrequency: "Toda semana",
    intention: "Casamento",
    about: "Médico. Apaixonado pela Palavra e por trilhas.",
    interests: ["Estudo bíblico", "Esportes", "Viagens"],
    photos: faces("men", 12, 13, 14),
  },
  {
    email: "rafael.oliveira@teste.com",
    fullName: "Rafael Oliveira",
    gender: "MALE",
    age: 31,
    city: "São Paulo",
    lat: -23.55,
    lng: -46.63,
    denomination: "Assembleia de Deus",
    churchFrequency: "Mais de uma vez por semana",
    intention: "Namoro sério",
    about: "Empreendedor e líder de jovens. Amo café e boa música.",
    interests: ["Louvor & Adoração", "Café", "Família"],
    photos: faces("men", 13, 15, 33),
  },
  {
    email: "tiago.rocha@teste.com",
    fullName: "Tiago Rocha",
    gender: "MALE",
    age: 24,
    city: "São Paulo",
    lat: -23.56,
    lng: -46.65,
    denomination: "Batista",
    churchFrequency: "Toda semana",
    intention: "Namoro sério",
    about: "Estudante de teologia. Leitura, missões e futebol.",
    interests: ["Missões", "Leitura", "Esportes"],
    photos: faces("men", 14, 50, 51),
  },
  {
    email: "matheus.almeida@teste.com",
    fullName: "Matheus Almeida",
    gender: "MALE",
    age: 28,
    city: "São Paulo",
    lat: -23.53,
    lng: -46.62,
    denomination: "Quadrangular",
    churchFrequency: "Toda semana",
    intention: "Casamento",
    about: "Designer. Sirvo na mídia da igreja. Café e violão sempre.",
    interests: ["Música", "Café", "Louvor & Adoração"],
    photos: faces("men", 32, 52, 53),
  },
  {
    email: "pedro.henrique@teste.com",
    fullName: "Pedro Henrique",
    gender: "MALE",
    age: 26,
    city: "Guarulhos",
    lat: -23.46,
    lng: -46.53,
    denomination: "Presbiteriana",
    churchFrequency: "Toda semana",
    intention: "Namoro sério",
    about: "Professor de história. Amo um bom debate e missões urbanas.",
    interests: ["Estudo bíblico", "Leitura", "Voluntariado"],
    photos: faces("men", 41, 54, 55),
  },
  {
    email: "joao.vitor@teste.com",
    fullName: "João Vítor",
    gender: "MALE",
    age: 30,
    city: "Osasco",
    lat: -23.53,
    lng: -46.79,
    denomination: "Batista",
    churchFrequency: "Mais de uma vez por semana",
    intention: "Casamento",
    about: "Fisioterapeuta. Corro maratonas e amo adorar.",
    interests: ["Esportes", "Louvor & Adoração", "Viagens"],
    photos: faces("men", 45, 56, 57),
  },
  {
    email: "andre.luiz@teste.com",
    fullName: "André Luiz",
    gender: "MALE",
    age: 33,
    city: "São Paulo",
    lat: -23.55,
    lng: -46.64,
    denomination: "Metodista",
    churchFrequency: "Toda semana",
    intention: "Namoro sério",
    about: "Advogado e voluntário. Família e fé acima de tudo.",
    interests: ["Família", "Voluntariado", "Leitura"],
    photos: faces("men", 60, 58, 59),
  },
];

// Mantém a maria (alvo) com perfil bonito caso ainda não exista.
const TARGET: P = {
  email: TARGET_EMAIL,
  fullName: "Maria",
  gender: "FEMALE",
  age: 26,
  city: "São Paulo",
  lat: -23.55,
  lng: -46.63,
  denomination: "Batista",
  churchFrequency: "Toda semana",
  intention: "Namoro sério",
  about: "Amo a Deus, louvor e boas conversas. Buscando algo sério. 🙏",
  interests: ["Louvor & Adoração", "Estudo bíblico", "Viagens"],
  photos: faces("women", 65, 45, 46),
};

async function upsertPerson(p: P): Promise<string> {
  const passwordHash = await argon2.hash("123456");
  const user = await prisma.user.upsert({
    where: { email: p.email },
    create: { email: p.email, passwordHash, provider: "EMAIL", emailVerified: true },
    update: {},
  });
  await prisma.profile.upsert({
    where: { userId: user.id },
    create: {
      userId: user.id,
      fullName: p.fullName,
      gender: p.gender,
      birthday: birthdayForAge(p.age),
      about: p.about,
      intention: p.intention,
      denomination: p.denomination,
      churchFrequency: p.churchFrequency,
      city: p.city,
      interests: p.interests,
      mediaFiles: p.photos,
      profilePicture: p.photos[0],
      latitude: p.lat,
      longitude: p.lng,
      addressText: p.city,
      isOnline: Math.random() > 0.4,
      lastActiveAt: new Date(),
    },
    update: {
      mediaFiles: p.photos,
      profilePicture: p.photos[0],
      interests: p.interests,
      isOnline: Math.random() > 0.4,
      lastActiveAt: new Date(),
    },
  });
  return user.id;
}

async function like(fromId: string, toId: string, type: InteractionType) {
  await prisma.interaction.upsert({
    where: { fromUserId_toUserId: { fromUserId: fromId, toUserId: toId } },
    create: { fromUserId: fromId, toUserId: toId, type },
    update: { type },
  });
}

async function ensureMatch(aId: string, bId: string) {
  const [userAId, userBId] = aId < bId ? [aId, bId] : [bId, aId];
  return prisma.match.upsert({
    where: { userAId_userBId: { userAId, userBId } },
    create: { userAId, userBId, isActive: true },
    update: { isActive: true },
  });
}

async function msg(
  matchId: string,
  senderId: string,
  content: string,
  read: boolean,
  minutesAgo: number
) {
  await prisma.message.create({
    data: {
      matchId,
      senderId,
      type: MessageType.TEXT,
      content,
      readAt: read ? new Date() : null,
      createdAt: new Date(Date.now() - minutesAgo * 60000),
    },
  });
}

async function main() {
  console.log(`\n🎬 Simulando interações para: ${TARGET_EMAIL}\n`);

  // 1) Fotos + perfis (elenco + alvo).
  const targetId = await upsertPerson(TARGET);
  console.log(`✓ Alvo garantido: ${TARGET.fullName} (${TARGET_EMAIL})`);

  const ids: Record<string, string> = {};
  for (const p of PEOPLE) {
    ids[p.email] = await upsertPerson(p);
    console.log(`✓ ${p.fullName} — fotos de rosto OK`);
  }

  // 2) Curtidas e super likes CHEGANDO para o alvo (aparecem em "Curtidas").
  //    Estes NÃO viram match (o alvo ainda não curtiu de volta).
  const likers: Array<[string, InteractionType]> = [
    ["lucas.pereira@teste.com", "SUPERLIKE"],
    ["gabriel.santos@teste.com", "LIKE"],
    ["matheus.almeida@teste.com", "SUPERLIKE"],
    ["pedro.henrique@teste.com", "LIKE"],
    ["joao.vitor@teste.com", "LIKE"],
    ["andre.luiz@teste.com", "SUPERLIKE"],
  ];
  for (const [email, type] of likers) {
    await like(ids[email], targetId, type);
  }
  console.log(`\n💛 ${likers.length} curtidas/super likes chegaram para o alvo.`);

  // 2b) Garante uma boa leva de "quem te curtiu" com quem NÃO está em match.
  await ensureIncomingLikes(targetId, 8);

  // 3) MATCHES + CONVERSAS (reciprocidade) com mensagens não lidas.
  const matchEmails = ["rafael.oliveira@teste.com", "tiago.rocha@teste.com"];
  for (const email of matchEmails) {
    const otherId = ids[email];
    await like(targetId, otherId, "LIKE");
    await like(otherId, targetId, "LIKE");
    const m = await ensureMatch(targetId, otherId);
    // Limpa mensagens antigas dessa conversa (idempotência).
    await prisma.message.deleteMany({ where: { matchId: m.id } });
    const name = PEOPLE.find((p) => p.email === email)!.fullName.split(" ")[0];
    await msg(m.id, otherId, `Oi! Tudo bem? Vi que curtimos os mesmos louvores 🙌`, true, 60);
    await msg(m.id, targetId, `Oi ${name}! Tudo ótimo, e com você?`, true, 55);
    await msg(m.id, otherId, `Indo bem! Qual igreja você congrega?`, false, 8);
    await msg(m.id, otherId, `Bora tomar um café qualquer dia desses? ☕`, false, 3);
    console.log(`💬 Match + conversa com ${name} (2 mensagens não lidas).`);
  }

  // 4) Conserta fotos antigas (picsum/landscape) de QUALQUER perfil por rostos.
  const legacy = await prisma.profile.findMany();
  let fixed = 0;
  for (const prof of legacy) {
    const hasBad =
      prof.mediaFiles.length === 0 ||
      prof.mediaFiles.some((u) => u.includes("picsum")) ||
      !prof.profilePicture ||
      (prof.profilePicture?.includes("picsum") ?? false);
    if (!hasBad) continue;
    const g = prof.gender === "MALE" ? "men" : "women";
    const base = (Math.abs(hashCode(prof.id)) % 80) + 5;
    const photos = faces(
      g,
      base % 90,
      (base % 60) + 1,
      ((base + 7) % 60) + 1
    );
    await prisma.profile.update({
      where: { id: prof.id },
      data: { mediaFiles: photos, profilePicture: photos[0] },
    });
    fixed++;
  }
  if (fixed > 0) console.log(`\n🖼️  Fotos corrigidas em ${fixed} perfis antigos.`);

  console.log(`\n✅ Simulação concluída! Abra o app na maria e veja:`);
  console.log(`   • Curtidas: ${likers.length} pessoas (com super likes).`);
  console.log(`   • Matches: ${matchEmails.length} conversas com mensagens novas.`);
}

function hashCode(s: string): number {
  let h = 0;
  for (let i = 0; i < s.length; i++) {
    h = (Math.imul(31, h) + s.charCodeAt(i)) | 0;
  }
  return h;
}

/**
 * Garante que pelo menos `want` perfis (que NÃO estão em match com o alvo e que
 * o alvo ainda não avaliou) tenham curtido o alvo → aparecem em "Curtidas".
 */
async function ensureIncomingLikes(targetId: string, want: number) {
  // Quem o alvo já avaliou (não pode aparecer como curtida pendente).
  const out = await prisma.interaction.findMany({
    where: { fromUserId: targetId },
    select: { toUserId: true },
  });
  const ratedByTarget = new Set(out.map((i) => i.toUserId));

  // Com quem o alvo já tem match.
  const matches = await prisma.match.findMany({
    where: { OR: [{ userAId: targetId }, { userBId: targetId }] },
  });
  const matched = new Set<string>();
  matches.forEach((m) =>
    matched.add(m.userAId === targetId ? m.userBId : m.userAId)
  );

  // Candidatos: perfis que não sou eu, não avaliados por mim, não em match.
  const profiles = await prisma.profile.findMany({ take: 60 });
  const candidates = profiles
    .map((p) => p.userId)
    .filter((id) => id !== targetId && !ratedByTarget.has(id) && !matched.has(id));

  let added = 0;
  for (const id of candidates) {
    if (added >= want) break;
    const type: InteractionType = added % 3 === 0 ? "SUPERLIKE" : "LIKE";
    await like(id, targetId, type);
    added++;
  }

  // Se não houver candidatos suficientes, cria novos "admiradores" frescos.
  const admirers: P[] = [
    mkAdmirer("Felipe Andrade", "men", 70, 21, 22, "São Paulo", -23.55, -46.64),
    mkAdmirer("Bruno Carvalho", "men", 68, 23, 24, "Santo André", -23.66, -46.53),
    mkAdmirer("Daniel Moreira", "men", 51, 25, 26, "São Paulo", -23.5, -46.6),
    mkAdmirer("Vinícius Ramos", "men", 52, 27, 28, "Osasco", -23.53, -46.79),
    mkAdmirer("Eduardo Nunes", "men", 53, 29, 30, "Guarulhos", -23.46, -46.53),
    mkAdmirer("Thiago Barros", "men", 54, 31, 32, "Diadema", -23.68, -46.62),
    mkAdmirer("Rodrigo Pinto", "men", 55, 33, 34, "São Paulo", -23.55, -46.63),
    mkAdmirer("Caio Fernandes", "men", 56, 35, 36, "São Bernardo", -23.69, -46.56),
  ];
  let ai = 0;
  while (added < want && ai < admirers.length) {
    const a = admirers[ai++];
    const id = await upsertPerson(a);
    if (id === targetId) continue;
    // Garante que o alvo não avaliou (perfil novo) e curte o alvo.
    const already = await prisma.interaction.findUnique({
      where: { fromUserId_toUserId: { fromUserId: targetId, toUserId: id } },
    });
    if (already) continue;
    const type: InteractionType = added % 3 === 0 ? "SUPERLIKE" : "LIKE";
    await like(id, targetId, type);
    added++;
  }

  console.log(`💌 ${added} curtidas garantidas em "Quem te curtiu".`);
}

let admirerSeq = 1;
function mkAdmirer(
  fullName: string,
  g: "men" | "women",
  ru: number,
  pv1: number,
  pv2: number,
  city: string,
  lat: number,
  lng: number
): P {
  const email = `admirer${admirerSeq++}@teste.com`;
  return {
    email,
    fullName,
    gender: g === "men" ? "MALE" : "FEMALE",
    age: 24 + (admirerSeq % 8),
    city,
    lat,
    lng,
    denomination: ["Batista", "Presbiteriana", "Assembleia de Deus", "Católica"][
      admirerSeq % 4
    ],
    churchFrequency: "Toda semana",
    intention: "Namoro sério",
    about: "Cristão buscando um relacionamento sério com propósito. 🙏",
    interests: ["Louvor & Adoração", "Estudo bíblico", "Família"],
    photos: faces(g, ru % 90, pv1, pv2),
  };
}main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
