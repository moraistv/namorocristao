import { prisma } from "../src/config/prisma";

const VERSES = [
  { reference: "1 Coríntios 13:4-5", text: "O amor é paciente, o amor é bondoso. Não inveja, não se vangloria, não se orgulha. Não maltrata, não procura seus interesses, não se ira facilmente, não guarda rancor." },
  { reference: "Provérbios 3:5-6", text: "Confie no Senhor de todo o seu coração e não se apoie em seu próprio entendimento; reconheça o Senhor em todos os seus caminhos, e ele endireitará as suas veredas." },
  { reference: "Eclesiastes 4:9-10", text: "É melhor ter companhia do que estar sozinho, porque maior é a recompensa do trabalho de duas pessoas. Se um cair, o amigo pode ajudá-lo a levantar-se." },
  { reference: "Cântico dos Cânticos 3:4", text: "Encontrei aquele a quem o meu coração ama. Eu o segurei e não o deixei ir." },
  { reference: "Jeremias 29:11", text: "Porque sou eu que conheço os planos que tenho para vocês, planos de fazê-los prosperar e não de lhes causar dano, planos de dar-lhes esperança e um futuro." },
  { reference: "Colossenses 3:14", text: "Acima de tudo, porém, revistam-se do amor, que é o elo perfeito." },
  { reference: "Salmos 37:4", text: "Deleite-se no Senhor, e ele atenderá aos desejos do seu coração." },
  { reference: "Provérbios 18:22", text: "Aquele que encontra uma esposa encontra algo excelente; recebeu uma bênção do Senhor." },
  { reference: "1 João 4:19", text: "Nós amamos porque ele nos amou primeiro." },
  { reference: "Rute 1:16", text: "Aonde você for, irei eu; onde você ficar, ficarei eu. O seu povo será o meu povo, e o seu Deus será o meu Deus." },
  { reference: "Filipenses 4:13", text: "Tudo posso naquele que me fortalece." },
  { reference: "Romanos 12:10", text: "Dediquem-se uns aos outros com amor fraternal. Prefiram dar honra aos outros mais do que a si próprios." },
];

async function main() {
  const count = await prisma.dailyVerse.count();
  if (count > 0) {
    console.log(`Já existem ${count} versos cadastrados — nada a fazer.`);
    return;
  }
  let i = 0;
  for (const v of VERSES) {
    await prisma.dailyVerse.create({
      data: { reference: v.reference, text: v.text, active: true, sortOrder: i++ },
    });
  }
  console.log(`✅ ${VERSES.length} versículos cadastrados.`);
}

main().finally(() => prisma.$disconnect());
