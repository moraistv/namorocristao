import { FormEvent, useEffect, useRef, useState } from "react";
import {
  IconBell, IconSend, IconPhoto, IconMoodSmile, IconX, IconLink,
  IconAppWindow, IconUsers, IconChecks, IconClick, IconRefresh,
} from "@tabler/icons-react";
import { API_BASE, get, post } from "../api";
import { Toast, ToastMsg } from "../components/ui";
import EmojiPicker from "emoji-picker-react";

const ORIGIN = API_BASE.replace(/\/api$/, "");

interface Campaign {
  id: string;
  title: string;
  body: string;
  audience: string;
  imageUrl: string | null;
  actionType: string | null;
  actionValue: string | null;
  targetedCount: number;
  sentCount: number;
  deliveredCount: number;
  clickedCount: number;
  createdAt: string;
}

const AUDIENCES = [
  { value: "all", label: "Todos os usuários" },
  { value: "premium", label: "Apenas VIP" },
  { value: "free", label: "Apenas grátis" },
  { value: "online", label: "Online agora" },
  { value: "user", label: "Usuário específico (ID)" },
];

const AUDIENCE_LABEL: Record<string, string> = Object.fromEntries(AUDIENCES.map((a) => [a.value, a.label]));

// Telas internas do app para onde a notificação pode levar.
const INTERNAL_ROUTES = [
  { value: "discover", label: "Descobrir" },
  { value: "likes", label: "Curtidas" },
  { value: "chat", label: "Conversas" },
  { value: "profile", label: "Meu Perfil" },
  { value: "plans", label: "Planos / VIP" },
];

const QUICK_EMOJIS = ["😊", "💛", "😍", "🙏", "✨", "💕", "🔥", "🎉", "❤️", "🥰", "😇", "💖"];

export default function Notifications() {
  const [title, setTitle] = useState("");
  const [body, setBody] = useState("");
  const [audience, setAudience] = useState("all");
  const [userId, setUserId] = useState("");
  const [imageUrl, setImageUrl] = useState("");
  const [uploading, setUploading] = useState(false);
  const [actionType, setActionType] = useState<"" | "internal" | "external">("");
  const [actionValue, setActionValue] = useState("");
  const [sending, setSending] = useState(false);
  const [recent, setRecent] = useState<Campaign[]>([]);
  const [emojiTarget, setEmojiTarget] = useState<"" | "title" | "body">("");
  const [toast, setToast] = useState<ToastMsg | null>(null);
  const fileRef = useRef<HTMLInputElement>(null);

  function loadRecent() {
    get("/admin/notifications/recent")
      .then((r) => setRecent(r.notifications))
      .catch(() => {});
  }
  useEffect(() => {
    loadRecent();
    // Auto-atualiza as estatísticas (cliques chegam em tempo real conforme usuários tocam).
    const t = setInterval(loadRecent, 5000);
    return () => clearInterval(t);
  }, []);

  async function onPickImage(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    if (!file) return;
    setUploading(true);
    try {
      const b64: string = await new Promise((res, rej) => {
        const fr = new FileReader();
        fr.onload = () => res((fr.result as string).split(",")[1]);
        fr.onerror = rej;
        fr.readAsDataURL(file);
      });
      const ext = (file.name.split(".").pop() || "jpg").toLowerCase();
      const r = await post("/admin/gifts/upload", { image: b64, ext });
      setImageUrl(r.url.startsWith("http") ? r.url : `${ORIGIN}${r.url}`);
    } catch (e: any) {
      setToast({ type: "error", text: e.message || "Falha no upload" });
    } finally {
      setUploading(false);
      if (fileRef.current) fileRef.current.value = "";
    }
  }

  function addEmoji(emoji: string) {
    if (emojiTarget === "title") setTitle((t) => t + emoji);
    else if (emojiTarget === "body") setBody((b) => b + emoji);
  }

  async function send(e: FormEvent) {
    e.preventDefault();
    if (actionType && !actionValue) {
      setToast({ type: "error", text: actionType === "internal" ? "Escolha a tela de destino" : "Informe a URL" });
      return;
    }
    setSending(true);
    try {
      const payload: any = {
        title,
        body,
        audience,
        userId: audience === "user" ? userId : undefined,
      };
      if (imageUrl.trim()) payload.imageUrl = imageUrl.trim();
      if (actionType && actionValue) {
        payload.actionType = actionType;
        payload.actionValue = actionValue;
      }
      const r = await post("/admin/notifications/broadcast", payload);
      setToast({ type: "success", text: `Enviado: ${r.sent} • com push: ${r.delivered}` });
      setTitle(""); setBody(""); setImageUrl(""); setActionType(""); setActionValue("");
      loadRecent();
    } catch (e: any) {
      setToast({ type: "error", text: e.message });
    } finally {
      setSending(false);
    }
  }

  return (
    <>
      <div className="d-flex align-items-center justify-content-between mb-3">
        <div>
          <div className="page-pretitle">Engajamento</div>
          <h2 className="page-title"><IconBell size={22} className="me-2" />Notificações</h2>
        </div>
        <button className="btn btn-sm btn-ghost-secondary" onClick={loadRecent}>
          <IconRefresh size={16} className="me-1" />Atualizar
        </button>
      </div>

      <div className="row row-cards">
        {/* ───────── Formulário ───────── */}
        <div className="col-lg-6">
          <form className="card" onSubmit={send}>
            <div className="card-header"><h3 className="card-title">Enviar notificação</h3></div>
            <div className="card-body">
              <div className="mb-3">
                <label className="form-label">Público</label>
                <select className="form-select" value={audience} onChange={(e) => setAudience(e.target.value)}>
                  {AUDIENCES.map((a) => <option key={a.value} value={a.value}>{a.label}</option>)}
                </select>
              </div>

              {audience === "user" && (
                <div className="mb-3">
                  <label className="form-label">ID do usuário</label>
                  <input className="form-control" value={userId} onChange={(e) => setUserId(e.target.value)} placeholder="uuid do usuário" />
                </div>
              )}

              <div className="mb-3">
                <div className="d-flex align-items-center justify-content-between">
                  <label className="form-label mb-0">Título</label>
                  <button type="button" className="btn btn-sm btn-ghost-secondary p-1" onClick={() => setEmojiTarget(emojiTarget === "title" ? "" : "title")}>
                    <IconMoodSmile size={16} />
                  </button>
                </div>
                <input className="form-control" value={title} onChange={(e) => setTitle(e.target.value)} maxLength={120} required placeholder="Ex.: Novidade no Namoro Cristão! ✨" />
              </div>

              <div className="mb-2">
                <div className="d-flex align-items-center justify-content-between">
                  <label className="form-label mb-0">Mensagem</label>
                  <button type="button" className="btn btn-sm btn-ghost-secondary p-1" onClick={() => setEmojiTarget(emojiTarget === "body" ? "" : "body")}>
                    <IconMoodSmile size={16} />
                  </button>
                </div>
                <textarea className="form-control" rows={3} value={body} onChange={(e) => setBody(e.target.value)} maxLength={500} required placeholder="Texto da notificação" />
              </div>

              {/* Emojis rápidos + picker completo */}
              <div className="mb-3">
                <div className="d-flex flex-wrap gap-1">
                  {QUICK_EMOJIS.map((em) => (
                    <button key={em} type="button" className="btn btn-sm btn-outline-secondary px-2 py-0"
                      onClick={() => (emojiTarget === "title" ? setTitle((t) => t + em) : setBody((b) => b + em))}>
                      {em}
                    </button>
                  ))}
                </div>
                {emojiTarget && (
                  <div className="mt-2">
                    <div className="text-secondary mb-1" style={{ fontSize: 12 }}>
                      Inserindo emoji em: <strong>{emojiTarget === "title" ? "Título" : "Mensagem"}</strong>
                    </div>
                    <EmojiPicker onEmojiClick={(e) => addEmoji(e.emoji)} width="100%" height={320} />
                  </div>
                )}
              </div>

              {/* Imagem: upload ou URL externa */}
              <div className="mb-3">
                <label className="form-label">Imagem (opcional)</label>
                <div className="input-group">
                  <span className="input-group-text"><IconLink size={16} /></span>
                  <input className="form-control" value={imageUrl} onChange={(e) => setImageUrl(e.target.value)} placeholder="Cole uma URL OU faça upload →" />
                  <button type="button" className="btn btn-outline-secondary" disabled={uploading} onClick={() => fileRef.current?.click()}>
                    <IconPhoto size={16} className="me-1" />{uploading ? "..." : "Upload"}
                  </button>
                </div>
                <input ref={fileRef} type="file" accept="image/*" hidden onChange={onPickImage} />
                {imageUrl && (
                  <div className="mt-2 position-relative d-inline-block">
                    <img src={imageUrl} alt="prévia" style={{ maxWidth: 220, maxHeight: 140, borderRadius: 8, objectFit: "cover" }} />
                    <button type="button" className="btn btn-icon btn-sm btn-danger" style={{ position: "absolute", top: -8, right: -8, width: 24, height: 24 }} onClick={() => setImageUrl("")}>
                      <IconX size={14} />
                    </button>
                  </div>
                )}
              </div>

              {/* Ação ao tocar: tela interna ou link externo */}
              <div className="mb-3">
                <label className="form-label">Ao tocar na notificação</label>
                <select className="form-select mb-2" value={actionType} onChange={(e) => { setActionType(e.target.value as any); setActionValue(""); }}>
                  <option value="">Abrir o app (padrão)</option>
                  <option value="internal">Abrir uma tela do app</option>
                  <option value="external">Abrir um link externo</option>
                </select>
                {actionType === "internal" && (
                  <select className="form-select" value={actionValue} onChange={(e) => setActionValue(e.target.value)}>
                    <option value="">Escolha a tela…</option>
                    {INTERNAL_ROUTES.map((r) => <option key={r.value} value={r.value}>{r.label}</option>)}
                  </select>
                )}
                {actionType === "external" && (
                  <input className="form-control" value={actionValue} onChange={(e) => setActionValue(e.target.value)} placeholder="https://exemplo.com/promo" />
                )}
              </div>

              <button className="btn btn-primary w-100" disabled={sending}>
                <IconSend size={16} className="me-1" />{sending ? "Enviando..." : "Enviar notificação"}
              </button>
            </div>
          </form>
        </div>

        {/* ───────── Histórico + estatísticas ───────── */}
        <div className="col-lg-6">
          <div className="card">
            <div className="card-header">
              <h3 className="card-title">Enviadas recentemente</h3>
              <span className="card-subtitle text-secondary ms-auto" style={{ fontSize: 12 }}>atualiza a cada 5s</span>
            </div>
            <div className="card-body">
              {recent.length === 0 ? (
                <div className="text-center text-secondary py-4">Nenhuma notificação enviada ainda.</div>
              ) : (
                <div className="d-flex flex-column gap-2">
                  {recent.slice(0, 20).map((n) => {
                    const ctr = n.deliveredCount > 0 ? Math.round((n.clickedCount / n.deliveredCount) * 100) : 0;
                    return (
                      <div key={n.id} className="border rounded p-2">
                        <div className="d-flex gap-2">
                          {n.imageUrl && (
                            <img src={n.imageUrl} alt="" style={{ width: 44, height: 44, borderRadius: 6, objectFit: "cover", flexShrink: 0 }} />
                          )}
                          <div className="flex-fill" style={{ minWidth: 0 }}>
                            <div className="fw-medium text-truncate">{n.title}</div>
                            <div className="text-secondary text-truncate" style={{ fontSize: 13 }}>{n.body}</div>
                          </div>
                        </div>
                        <div className="d-flex flex-wrap align-items-center gap-2 mt-2" style={{ fontSize: 12 }}>
                          <span className="badge bg-secondary-lt">{AUDIENCE_LABEL[n.audience] || n.audience}</span>
                          <span className="text-secondary" title="Enviados"><IconUsers size={13} className="me-1" />{n.sentCount}</span>
                          <span className="text-secondary" title="Com push (recebeu)"><IconChecks size={13} className="me-1" />{n.deliveredCount}</span>
                          <span className="text-azure" title="Cliques"><IconClick size={13} className="me-1" />{n.clickedCount} <span className="text-secondary">({ctr}%)</span></span>
                          {n.actionType === "internal" && <span className="badge bg-blue-lt"><IconAppWindow size={11} className="me-1" />{n.actionValue}</span>}
                          {n.actionType === "external" && <span className="badge bg-green-lt"><IconLink size={11} className="me-1" />link</span>}
                          <span className="text-secondary ms-auto">{new Date(n.createdAt).toLocaleString("pt-BR")}</span>
                        </div>
                      </div>
                    );
                  })}
                </div>
              )}
            </div>
          </div>
        </div>
      </div>

      <Toast toast={toast} onClose={() => setToast(null)} />
    </>
  );
}
