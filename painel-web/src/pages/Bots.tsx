import { useEffect, useRef, useState } from "react";
import { IconPlus, IconEdit, IconTrash, IconRobot, IconHeart, IconSend } from "@tabler/icons-react";
import { API_BASE, get, post, put, del } from "../api";
import { Dialog, DialogConfig, Toast, ToastMsg } from "../components/ui";

const ORIGIN = API_BASE.replace(/\/api$/, "");
const PERSONALITY: Record<string, string> = { ALL: "Todas", SHY: "Tímida", FUNNY: "Engraçada", EXTROVERT: "Extrovertida" };

interface Bot {
  userId: string;
  fullName: string;
  gender: string | null;
  age: number | null;
  about: string | null;
  city: string | null;
  interests: string[];
  photos: string[];
  profilePicture: string | null;
  personality: string;
  aiEnabled: boolean;
  matchCount: number;
}

interface Form {
  userId?: string;
  fullName: string;
  gender: string;
  age: number;
  about: string;
  city: string;
  interests: string;
  photos: string[];
  personality: string;
  aiEnabled: boolean;
}

const emptyForm: Form = { fullName: "", gender: "FEMALE", age: 24, about: "", city: "", interests: "", photos: [], personality: "ALL", aiEnabled: false };

export default function Bots() {
  const [bots, setBots] = useState<Bot[]>([]);
  const [form, setForm] = useState<Form | null>(null);
  const [uploading, setUploading] = useState(false);
  const [blast, setBlast] = useState<Bot | null>(null);
  const [blastText, setBlastText] = useState("");
  const [blastAudience, setBlastAudience] = useState("all");
  const [blastSending, setBlastSending] = useState(false);
  const [dialog, setDialog] = useState<DialogConfig | null>(null);
  const [toast, setToast] = useState<ToastMsg | null>(null);
  const fileRef = useRef<HTMLInputElement>(null);

  async function load() {
    try { const r = await get("/admin/bots"); setBots(r.bots); } catch (e: any) { setToast({ type: "error", text: e.message }); }
  }
  useEffect(() => { load(); }, []);

  function openNew() { setForm({ ...emptyForm }); }
  function openEdit(b: Bot) {
    setForm({
      userId: b.userId, fullName: b.fullName, gender: b.gender || "FEMALE", age: b.age || 24,
      about: b.about || "", city: b.city || "", interests: b.interests.join(", "), photos: [...b.photos],
      personality: b.personality, aiEnabled: b.aiEnabled,
    });
  }

  async function onPickFile(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    if (!file || !form) return;
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
      const abs = r.url.startsWith("http") ? r.url : `${ORIGIN}${r.url}`;
      setForm({ ...form, photos: [...form.photos, abs] });
    } catch (e: any) { setToast({ type: "error", text: e.message || "Falha no upload" }); }
    finally { setUploading(false); if (fileRef.current) fileRef.current.value = ""; }
  }

  async function save() {
    if (!form) return;
    if (form.fullName.trim().length < 2) { setToast({ type: "error", text: "Informe o nome" }); return; }
    if (form.photos.length === 0) { setToast({ type: "error", text: "Adicione ao menos 1 foto" }); return; }
    const body = {
      fullName: form.fullName.trim(), gender: form.gender, age: form.age,
      about: form.about.trim() || null, city: form.city.trim() || null,
      interests: form.interests.split(",").map((s) => s.trim()).filter(Boolean),
      photos: form.photos, personality: form.personality, aiEnabled: form.aiEnabled,
    };
    try {
      if (form.userId) await put(`/admin/bots/${form.userId}`, body);
      else await post("/admin/bots", body);
      setForm(null); load(); setToast({ type: "success", text: "Modelo salvo" });
    } catch (e: any) { setToast({ type: "error", text: e.message }); }
  }

  async function sendBlast() {
    if (!blast) return;
    if (blastText.trim().length < 1) { setToast({ type: "error", text: "Escreva a mensagem" }); return; }
    setBlastSending(true);
    try {
      const r = await post(`/admin/bots/${blast.userId}/broadcast`, { text: blastText.trim(), audience: blastAudience });
      setBlast(null); setBlastText("");
      setToast({ type: "success", text: `Disparado para ${r.sent} usuário(s)` });
    } catch (e: any) { setToast({ type: "error", text: e.message }); }
    finally { setBlastSending(false); }
  }

  function remove(b: Bot) {
    setDialog({
      title: "Excluir modelo", message: `Remover ${b.fullName}? Apaga matches e conversas dele.`, icon: IconTrash, danger: true, confirmText: "Excluir",
      onConfirm: async () => { try { await del(`/admin/bots/${b.userId}`); load(); setToast({ type: "success", text: "Modelo excluído" }); } catch (e: any) { setToast({ type: "error", text: e.message }); } },
    });
  }

  return (
    <>
      <div className="d-flex align-items-center justify-content-between mb-3">
        <div><div className="page-pretitle">Bots</div><h2 className="page-title">Modelos</h2></div>
        <button className="btn btn-primary" onClick={openNew}><IconPlus size={16} className="me-1" />Novo Modelo</button>
      </div>
      <p className="text-secondary">Perfis controlados pelo sistema. Aparecem na descoberta, dão match automático e respondem sozinhos (regras → IA).</p>

      <div className="row row-cards">
        {bots.map((b) => (
          <div className="col-md-6 col-lg-4" key={b.userId}>
            <div className="card">
              <div className="card-body d-flex">
                <span className="avatar avatar-lg me-3" style={{ backgroundImage: b.profilePicture ? `url(${b.profilePicture})` : undefined }}>
                  {!b.profilePicture && <IconRobot size={24} />}
                </span>
                <div className="flex-fill" style={{ minWidth: 0 }}>
                  <div className="d-flex align-items-center gap-2">
                    <strong>{b.fullName}</strong>
                    {b.age && <span className="text-secondary">{b.age}</span>}
                    {b.aiEnabled && <span className="badge bg-purple-lt">IA</span>}
                  </div>
                  <div className="text-secondary text-truncate" style={{ fontSize: 13 }}>{b.about || "—"}</div>
                  <div className="mt-1 d-flex gap-2 align-items-center" style={{ fontSize: 12 }}>
                    <span className="badge bg-azure-lt">{PERSONALITY[b.personality]}</span>
                    <span className="text-secondary"><IconHeart size={13} className="me-1" />{b.matchCount} matches</span>
                  </div>
                </div>
              </div>
              <div className="card-footer d-flex gap-1 justify-content-end">
                <button className="btn btn-sm btn-ghost-primary" onClick={() => { setBlast(b); setBlastText(""); setBlastAudience("all"); }}><IconSend size={15} className="me-1" />Disparar</button>
                <button className="btn btn-sm" onClick={() => openEdit(b)}><IconEdit size={15} className="me-1" />Editar</button>
                <button className="btn btn-sm btn-ghost-danger" onClick={() => remove(b)}><IconTrash size={15} /></button>
              </div>
            </div>
          </div>
        ))}
        {bots.length === 0 && <div className="col-12"><div className="card"><div className="card-body text-center text-secondary py-5">Nenhum modelo ainda. Crie o primeiro para atrair e engajar usuários.</div></div></div>}
      </div>

      {form && (
        <div className="modal modal-blur show d-block" tabIndex={-1} style={{ background: "rgba(0,0,0,.4)" }}>
          <div className="modal-dialog modal-lg modal-dialog-centered">
            <div className="modal-content">
              <div className="modal-header"><h5 className="modal-title">{form.userId ? "Editar modelo" : "Novo modelo"}</h5><button className="btn-close" onClick={() => setForm(null)} /></div>
              <div className="modal-body">
                <div className="row g-3">
                  <div className="col-md-6"><label className="form-label">Nome</label><input className="form-control" value={form.fullName} onChange={(e) => setForm({ ...form, fullName: e.target.value })} /></div>
                  <div className="col-md-3"><label className="form-label">Idade</label><input type="number" min={18} max={99} className="form-control" value={form.age} onChange={(e) => setForm({ ...form, age: +e.target.value })} /></div>
                  <div className="col-md-3"><label className="form-label">Gênero</label>
                    <select className="form-select" value={form.gender} onChange={(e) => setForm({ ...form, gender: e.target.value })}>
                      <option value="FEMALE">Feminino</option><option value="MALE">Masculino</option><option value="OTHER">Outro</option>
                    </select>
                  </div>
                  <div className="col-md-8"><label className="form-label">Cidade</label><input className="form-control" value={form.city} onChange={(e) => setForm({ ...form, city: e.target.value })} /></div>
                  <div className="col-md-4"><label className="form-label">Personalidade</label>
                    <select className="form-select" value={form.personality} onChange={(e) => setForm({ ...form, personality: e.target.value })}>
                      {Object.entries(PERSONALITY).map(([v, l]) => <option key={v} value={v}>{l}</option>)}
                    </select>
                  </div>
                  <div className="col-12"><label className="form-label">Bio</label><textarea className="form-control" rows={2} value={form.about} onChange={(e) => setForm({ ...form, about: e.target.value })} /></div>
                  <div className="col-12"><label className="form-label">Interesses (separados por vírgula)</label><input className="form-control" value={form.interests} onChange={(e) => setForm({ ...form, interests: e.target.value })} placeholder="Louvor & Adoração, Viagens, Café" /></div>
                  <div className="col-12">
                    <label className="form-label">Fotos (até 6)</label>
                    <div className="d-flex gap-2 flex-wrap">
                      {form.photos.map((p, i) => (
                        <div key={i} style={{ position: "relative" }}>
                          <span className="avatar avatar-lg" style={{ backgroundImage: `url(${p})` }} />
                          <button className="btn btn-icon btn-sm btn-danger" style={{ position: "absolute", top: -8, right: -8, width: 22, height: 22 }} onClick={() => setForm({ ...form, photos: form.photos.filter((_, j) => j !== i) })}>×</button>
                        </div>
                      ))}
                      {form.photos.length < 6 && (
                        <button className="btn btn-outline-secondary" disabled={uploading} onClick={() => fileRef.current?.click()} style={{ width: 56, height: 56 }}>{uploading ? "..." : "+"}</button>
                      )}
                    </div>
                    <input ref={fileRef} type="file" accept="image/*" hidden onChange={onPickFile} />
                  </div>
                  <div className="col-12"><label className="form-check form-switch"><input className="form-check-input" type="checkbox" checked={form.aiEnabled} onChange={(e) => setForm({ ...form, aiEnabled: e.target.checked })} /><span className="form-check-label">Responder com IA quando nenhuma regra casar</span></label></div>
                </div>
              </div>
              <div className="modal-footer"><button className="btn" onClick={() => setForm(null)}>Cancelar</button><button className="btn btn-primary" onClick={save}>Salvar</button></div>
            </div>
          </div>
        </div>
      )}

      <Dialog config={dialog} onClose={() => setDialog(null)} />
      <Toast toast={toast} onClose={() => setToast(null)} />

      {blast && (
        <div className="modal modal-blur show d-block" tabIndex={-1} style={{ background: "rgba(0,0,0,.4)" }}>
          <div className="modal-dialog modal-dialog-centered">
            <div className="modal-content">
              <div className="modal-header"><h5 className="modal-title">Disparar como {blast.fullName}</h5><button className="btn-close" onClick={() => setBlast(null)} /></div>
              <div className="modal-body">
                <p className="text-secondary" style={{ fontSize: 13 }}>A mensagem chega como se o Modelo tivesse mandado. Cria o match automaticamente e notifica (push) quem receber.</p>
                <label className="form-label">Público</label>
                <select className="form-select mb-3" value={blastAudience} onChange={(e) => setBlastAudience(e.target.value)}>
                  <option value="all">Todos os usuários</option>
                  <option value="free">Somente grátis (não-VIP)</option>
                  <option value="premium">Somente VIP</option>
                  <option value="online">Online agora</option>
                </select>
                <label className="form-label">Mensagem</label>
                <textarea className="form-control" rows={3} value={blastText} onChange={(e) => setBlastText(e.target.value)} placeholder="Oi! Vi seu perfil e queria te conhecer melhor 😊" />
              </div>
              <div className="modal-footer">
                <button className="btn" onClick={() => setBlast(null)}>Cancelar</button>
                <button className="btn btn-primary" disabled={blastSending} onClick={sendBlast}><IconSend size={16} className="me-1" />{blastSending ? "Enviando..." : "Disparar"}</button>
              </div>
            </div>
          </div>
        </div>
      )}
    </>
  );
}
