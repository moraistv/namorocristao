import { FormEvent, useEffect, useState } from "react";
import { IconBell, IconSend } from "@tabler/icons-react";
import { get, post } from "../api";
import { Toast, ToastMsg } from "../components/ui";

interface Notif {
  id: string;
  title: string;
  body: string;
  createdAt: string;
}

const AUDIENCES = [
  { value: "all", label: "Todos os usuários" },
  { value: "premium", label: "Apenas VIP" },
  { value: "free", label: "Apenas grátis" },
  { value: "online", label: "Online agora" },
  { value: "user", label: "Usuário específico (ID)" },
];

export default function Notifications() {
  const [title, setTitle] = useState("");
  const [body, setBody] = useState("");
  const [audience, setAudience] = useState("all");
  const [userId, setUserId] = useState("");
  const [sending, setSending] = useState(false);
  const [recent, setRecent] = useState<Notif[]>([]);
  const [toast, setToast] = useState<ToastMsg | null>(null);

  function loadRecent() {
    get("/admin/notifications/recent")
      .then((r) => setRecent(r.notifications))
      .catch(() => {});
  }
  useEffect(() => { loadRecent(); }, []);

  async function send(e: FormEvent) {
    e.preventDefault();
    setSending(true);
    try {
      const r = await post("/admin/notifications/broadcast", {
        title,
        body,
        audience,
        userId: audience === "user" ? userId : undefined,
      });
      setToast({ type: "success", text: `Enviado para ${r.sent} usuário(s)` });
      setTitle(""); setBody("");
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
      </div>

      <div className="alert alert-info">
        As notificações aparecem no app em tempo real (e como push, quando o FCM estiver configurado no servidor).
      </div>

      <div className="row row-cards">
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
                <label className="form-label">Título</label>
                <input className="form-control" value={title} onChange={(e) => setTitle(e.target.value)} maxLength={120} required placeholder="Ex.: Novidade no Namoro Cristão!" />
              </div>
              <div className="mb-3">
                <label className="form-label">Mensagem</label>
                <textarea className="form-control" rows={3} value={body} onChange={(e) => setBody(e.target.value)} maxLength={500} required placeholder="Texto da notificação" />
              </div>
              <button className="btn btn-primary w-100" disabled={sending}>
                <IconSend size={16} className="me-1" />{sending ? "Enviando..." : "Enviar notificação"}
              </button>
            </div>
          </form>
        </div>

        <div className="col-lg-6">
          <div className="card">
            <div className="card-header"><h3 className="card-title">Enviadas recentemente</h3></div>
            <div className="card-body">
              {recent.length === 0 ? (
                <div className="text-center text-secondary py-4">Nenhuma notificação enviada ainda.</div>
              ) : (
                <div className="list-group list-group-flush">
                  {recent.slice(0, 20).map((n) => (
                    <div key={n.id} className="list-group-item px-0">
                      <div className="fw-medium">{n.title}</div>
                      <div className="text-secondary" style={{ fontSize: 13 }}>{n.body}</div>
                      <div className="text-secondary" style={{ fontSize: 11 }}>{new Date(n.createdAt).toLocaleString("pt-BR")}</div>
                    </div>
                  ))}
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
