import { PrismaClient, Gender } from "@prisma/client";
import argon2 from "argon2";

const prisma = new PrismaClient();

interface SeedProfile {
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
  portrait: string; // índice da foto no randomuser
  portraitGender: "men" | "women";
  portraitIndex: number;
}

const CHRISTIAN_INTERESTS = [
  "Louvor & Adoração",
  "Estudo bíblico",
  "Missões",
  "Música",
  "Esportes",
  "Viagens",
  "Leitura",
  "Culinária",
  "Voluntariado",
  "Família",
  "Cinema",
  "Café",
];

function birthdayForAge(age: number): Date {
  const d = new Date();
  d.setFullYear(d.getFullYear() - age);
  d.setMonth(2, 15);
  d.setHours(0, 0, 0, 0);
  return d;
}

function mediaFor(p: SeedProfile): { profile: string; media: string[] } {
  const portrait = `https://randomuser.me/api/portraits/${p.portraitGender}/${p.portraitIndex}.jpg`;
  const slug = p.fullName.toLowerCase().replace(/[^a-z]/g, "");
  // 3 imagens: retrato (rosto) + 2 lifestyle (picsum por seed, consistentes).
  const media = [
    portrait,
    `https://picsum.photos/seed/${slug}a/600/800`,
    `https://picsum.photos/seed/${slug}b/600/800`,
  ];
  return { profile: portrait, media };
}

const PROFILES: SeedProfile[] = [
  {
    email: "ana.beatriz@teste.com",
    fullName: "Ana Beatriz",
    gender: "FEMALE",
    age: 25,
    city: "São Paulo",
    lat: -23.55,
    lng: -46.63,
    denomination: "Batista",
    churchFrequency: "Toda semana",
    intention: "Namoro sério",
    about: "Amo louvor e servir na igreja. Buscando alguém que ame a Deus de verdade.",
    interests: ["Louvor & Adoração", "Missões", "Leitura"],
    portrait: "",
    portraitGender: "women",
    portraitIndex: 1,
  },
  {
    email: "juliana.costa@teste.com",
    fullName: "Juliana Costa",
    gender: "FEMALE",
    age: 28,
    city: "Campinas",
    lat: -22.9,
    lng: -47.06,
    denomination: "Presbiteriana",
    churchFrequency: "Toda semana",
    intention: "Casamento",
    about: "Professora, apaixonada por teologia e por um bom café.",
    interests: ["Estudo bíblico", "Café", "Família"],
    portrait: "",
    portraitGender: "women",
    portraitIndex: 2,
  },
  {
    email: "mariana.lima@teste.com",
    fullName: "Mariana Lima",
    gender: "FEMALE",
    age: 23,
    city: "São Paulo",
    lat: -23.56,
    lng: -46.65,
    denomination: "Assembleia de Deus",
    churchFrequency: "Mais de uma vez por semana",
    intention: "Namoro sério",
    about: "Cantora no ministério de louvor. Família e fé em primeiro lugar.",
    interests: ["Louvor & Adoração", "Música", "Viagens"],
    portrait: "",
    portraitGender: "women",
    portraitIndex: 3,
  },
  {
    email: "carolina.souza@teste.com",
    fullName: "Carolina Souza",
    gender: "FEMALE",
    age: 30,
    city: "Rio de Janeiro",
    lat: -22.9,
    lng: -43.2,
    denomination: "Católica",
    churchFrequency: "Às vezes",
    intention: "Amizade",
    about: "Nutricionista, amo praia, esportes e boas conversas.",
    interests: ["Esportes", "Culinária", "Viagens"],
    portrait: "",
    portraitGender: "women",
    portraitIndex: 4,
  },
  {
    email: "leticia.martins@teste.com",
    fullName: "Letícia Martins",
    gender: "FEMALE",
    age: 26,
    city: "Belo Horizonte",
    lat: -19.92,
    lng: -43.94,
    denomination: "Batista",
    churchFrequency: "Toda semana",
    intention: "Namoro sério",
    about: "Voluntária em projetos sociais. Sonho em servir em missões.",
    interests: ["Missões", "Voluntariado", "Leitura"],
    portrait: "",
    portraitGender: "women",
    portraitIndex: 5,
  },
  {
    email: "fernanda.alves@teste.com",
    fullName: "Fernanda Alves",
    gender: "FEMALE",
    age: 32,
    city: "Curitiba",
    lat: -25.43,
    lng: -49.27,
    denomination: "Luterana",
    churchFrequency: "Toda semana",
    intention: "Casamento",
    about: "Arquiteta. Gosto de cinema, viagens e gratidão diária.",
    interests: ["Cinema", "Viagens", "Família"],
    portrait: "",
    portraitGender: "women",
    portraitIndex: 6,
  },
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
    about: "Engenheiro e baterista na igreja. Quero construir um lar com Deus no centro.",
    interests: ["Louvor & Adoração", "Esportes", "Música"],
    portrait: "",
    portraitGender: "men",
    portraitIndex: 11,
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
    about: "Médico. Apaixonado por estudo da Palavra e por trilhas.",
    interests: ["Estudo bíblico", "Esportes", "Viagens"],
    portrait: "",
    portraitGender: "men",
    portraitIndex: 12,
  },
  {
    email: "rafael.oliveira@teste.com",
    fullName: "Rafael Oliveira",
    gender: "MALE",
    age: 31,
    city: "Rio de Janeiro",
    lat: -22.91,
    lng: -43.18,
    denomination: "Assembleia de Deus",
    churchFrequency: "Mais de uma vez por semana",
    intention: "Namoro sério",
    about: "Empreendedor e líder de jovens. Amo café e boa música.",
    interests: ["Louvor & Adoração", "Café", "Família"],
    portrait: "",
    portraitGender: "men",
    portraitIndex: 13,
  },
  {
    email: "tiago.rocha@teste.com",
    fullName: "Tiago Rocha",
    gender: "MALE",
    age: 24,
    city: "Belo Horizonte",
    lat: -19.93,
    lng: -43.93,
    denomination: "Batista",
    churchFrequency: "Toda semana",
    intention: "Namoro sério",
    about: "Estudante de teologia. Gosto de leitura, missões e futebol.",
    interests: ["Missões", "Leitura", "Esportes"],
    portrait: "",
    portraitGender: "men",
    portraitIndex: 14,
  },
];

async function main() {
  const passwordHash = await argon2.hash("123456");

  for (const p of PROFILES) {
    const { profile: profilePicture, media } = mediaFor(p);

    const user = await prisma.user.upsert({
      where: { email: p.email },
      create: { email: p.email, passwordHash, provider: "EMAIL", emailVerified: true },
      update: { passwordHash },
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
        mediaFiles: media,
        profilePicture,
        latitude: p.lat,
        longitude: p.lng,
        addressText: p.city,
        isOnline: Math.random() > 0.5,
        lastActiveAt: new Date(),
      },
      update: {
        mediaFiles: media,
        profilePicture,
        interests: p.interests,
        city: p.city,
        latitude: p.lat,
        longitude: p.lng,
      },
    });

    console.log(`✓ ${p.fullName} (${p.email})`);
  }

  console.log(`\n${PROFILES.length} perfis semeados. Senha de todos: 123456`);
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
