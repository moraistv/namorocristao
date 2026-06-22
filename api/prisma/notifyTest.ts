/**
 * Dispara notificações de teste (match, curtida, mensagem) via FCM v1 para um
 * usuário (padrão: 1@1.com). Serve para testar o push com o app minimizado.
 *
 * Uso no container: npx tsx prisma/notifyTest.ts [email]
 * Precisa do FIREBASE_SERVICE_ACCOUNT_B64 (ou as 3 vars) no ambiente.
 */
import { PrismaClient } from "@prisma/client";
import { JWT } from "google-auth-library";

const prisma = new PrismaClient();
const EMAIL = process.argv[2] || "1@1.com";

function loadSA() {
  const b64 = process.env.FIREBASE_SERVICE_ACCOUNT_B64 || "";
  if (b64) {
    const j = JSON.parse(Buffer.from(b64, "base64").toString("utf8"));
    return {
      projectId: j.project_id,
      clientEmail: j.client_email,
      privateKey: String(j.private_key).replace(/\\n/g, "\n"),
    };
  }
  return {
    projectId: process.env.FIREBASE_PROJECT_ID || "",
    clientEmail: process.env.FIREBASE_CLIENT_EMAIL || "",
    privateKey: (process.env.FIREBASE_PRIVATE_KEY || "").replace(/\\n/g, "\n"),
  };
}

async function main() {
  const sa = loadSA();
  if (!sa.projectId || !sa.clientEmail || !sa.privateKey) {
    console.error("❌ Firebase não configurado (FIREBASE_SERVICE_ACCOUNT_B64).");
    return;
  }

  const user = await prisma.user.findFirst({ where: { email: EMAIL } });
  if (!user) {
    console.error(`❌ Usuário ${EMAIL} não encontrado.`);
    return;
  }
  const tokens = await prisma.deviceToken.findMany({
    where: { userId: user.id },
    select: { token: true },
  });
  console.log(`Usuário: ${EMAIL} | tokens de device: ${tokens.length}`);
  if (tokens.length === 0) {
    console.error(
      "❌ Nenhum token FCM. Abra o app logado nessa conta (registra o token) e rode de novo."
    );
    return;
  }

  const jwt = new JWT({
    email: sa.clientEmail,
    key: sa.privateKey,
    scopes: ["https://www.googleapis.com/auth/firebase.messaging"],
  });
  const { access_token } = await jwt.authorize();
  if (!access_token) {
    console.error("❌ Não consegui token de acesso do Firebase.");
    return;
  }

  const notifs = [
    {
      title: "Você tem um novo match! 💛",
      body: "Ana Beatriz também curtiu você. Diga oi!",
      data: { type: "match", matchId: "teste" },
      persist: true,
    },
    {
      title: "Alguém curtiu você! 💛",
      body: "Você recebeu uma nova curtida. Veja quem foi!",
      data: { type: "like" },
      persist: true,
    },
    {
      title: "Lucas Pereira",
      body: "Oi! Tudo bem? 🙌",
      data: { type: "message", matchId: "teste" },
      persist: false,
    },
  ];

  for (const n of notifs) {
    if (n.persist) {
      await prisma.notification.create({
        data: { userId: user.id, title: n.title, body: n.body, type: n.data.type },
      });
    }
    for (const t of tokens) {
      const resp = await fetch(
        `https://fcm.googleapis.com/v1/projects/${sa.projectId}/messages:send`,
        {
          method: "POST",
          headers: {
            Authorization: `Bearer ${access_token}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            message: {
              token: t.token,
              notification: { title: n.title, body: n.body },
              data: n.data,
              android: { priority: "high" },
            },
          }),
        }
      );
      console.log(`→ [${n.data.type}] HTTP ${resp.status}`);
      if (resp.status >= 400) console.log("   " + (await resp.text()));
    }
  }
  console.log("\n✅ Notificações de teste enviadas.");
}

main()
  .catch((e) => console.error(e))
  .finally(() => prisma.$disconnect());
