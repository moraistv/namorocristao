import { FormEvent, useEffect, useRef, useState } from "react";
import { useNavigate } from "react-router-dom";
import {
  IconArrowLeft, IconGift, IconTrash, IconUpload, IconCoin, IconDeviceFloppy,
  IconPencil, IconPlus,
} from "@tabler/icons-react";
import { API_BASE, del, get, post, put } from "../api";
import { Dialog, DialogConfig, Toast, ToastMsg } from "../components/ui";

const SERVER_ORIGIN = API_BASE.replace(/\/api$/, "");
const img = (s?: string | null) => {
  if (!s) return "";
  const i = s.indexOf("/uploads/");
  if (i >= 0) return SERVER_ORIGIN + s.substring(i);
  return s;
};

interface Gift {
  id: string;
  name: string;
  imageUrl: string;
  costCredits: number;
  active: boolean;
  sortOrder: number;
}

// ─────────── Modal criar/editar presente ───────────
function GiftModal({ gift, onClose, onSaved, onError }: {
  gift: Gift | null;
  onClose: () => void;
  onSaved: (msg: string) => void;
  onError: (msg: string) => void;
}) {
  const [name, setName] = useState(gift?.name ?? "");
  const [cost, setCost] = useState(String(gift?.costCredits ?? 1));
  const [sortOrder, setSortOrder] = useState(String(gift?.sortOrder ?? 0));
  const [active, setActive] = useState(gift?.active ?? true);
  const [imageUrl, setImageUrl] = useState(gift?.imageUrl ?? "");
  const [uploading, setUploading] = useState(false);
  const [saving, setSaving] = useState(false);
  const fileRef = useRef<HTMLInputElement>(null);

  async function onPickFile(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    if (!file) return;
    const ext = (file.name.split(".").pop() || "png").toLowerCase();
    setUploading(true);
    try {
      const base64 = await new Promise<string>((resolve, reject) => {
        const r = new FileReader();
        r.onload = () => resolve(r.result as string);
        r.onerror = reject;
        r.readAsDataURL(file);
      });
      const r = await post("/admin/gifts/upload", { image: base64, ext });
      setImageUrl(r.url);
    } catch (err: any) {
      onError(err.message);
    } finally {
      setUploading(false);
    }
  }

  async function submit(e: FormEvent) {
    e.preventDefault();
    if (!imageUrl) return onError("Envie a imagem do presente");
    setSaving(true);
    const payload = {
      name,
      imageUrl,
      costCredits: Number(cost) || 1,
      sortOrder: Number(sortOrder) || 0,
      active,
    };
    try {
      if (gift) await put(`/admin/gifts/${gift.id}`, payload);
      else await post("/admin/gifts", payload);
      onSaved(gift ? "Presente atualizado" : "Presente criado");
    } catch (err: any) { onError(err.message); setSaving(false); }
  }

  return (
    <>
      <div className="modal modal-blur fade show d-block" tabIndex={-1}>
        <div className="modal-dialog modal-dialog-centered" role="document">
          <form className="modal-content" onSubmit={submit}>
            <div className="modal-header" style={{ background: "#111d40" }}>
              <h5 className="modal-title text-white">{gift ? "Editar presente" : "Novo presente"}</h5>
              <button type="button" className="btn-close btn-close-white" onClick={onClose} />
            </div>
            <div className="modal-body">
              <div className="d-flex gap-3">
                <div style={{ textAlign: "center" }}>
                  <div
                    onClick={() => fileRef.current?.click()}
                    style={{ width: 120, height: 120, borderRadius: 14, border: "2px dashed var(--tblr-border-color)", display: "grid", placeItems: "center", background: "#f6f7fb", overflow: "hidden", cursor: "pointer" }}
                  >
                    {imageUrl ? <img src={img(imageUrl)} alt="" style={{ width: "100%", height: "100%", objectFit: "contain" }} /> : <IconUpload size={28} className="text-secondary" />}
                  </div>
                  <input ref={fileRef} type="file" accept=".gif,.png,.svg,.jpg,.jpeg,.webp,image/*" hidden onChange={onPickFile} />
                  <button type="button" className="btn btn-sm mt-2" onClick={() => fileRef.current?.click()} disabled={uploading}>
                    {uploading ? "Enviando..." : "Imagem"}
                  </button>
                </div>
                <div className="flex-fill">
                  <div className="mb-2">
                    <label className="form-label">Nome</label>
                    <input className="form-control" value={name} onChange={(e) => setName(e.target.value)} required placeholder="Ex.: Rosa" />
                  </div>
                  <div className="mb-2">
                    <label className="form-label">Custo (créditos)</label>
                    <input className="form-control" type="number" min={1} value={cost} onChange={(e) => setCost(e.target.value)} required />
                  </div>
                  <div className="row g-2 align-items-end">
                    <div className="col-6">
                      <label className="form-label">Ordem</label>
                      <input className="form-control" type="number" value={sortOrder} onChange={(e) => setSortOrder(e.target.value)} />
                    </div>
                    <div className="col-6">
                      <label className="form-check mt-3">
                        <input type="checkbox" className="form-check-input" checked={active} onChange={(e) => setActive(e.target.checked)} />
                        <span className="form-check-label">Ativo</span>
                      </label>
                    </div>
                  </div>
                </div>
              </div>
              <div className="text-secondary mt-2" style={{ fontSize: 12 }}>Formatos: GIF, PNG, SVG, JPG, WebP (máx 5MB).</div>
            </div>
            <div className="modal-footer">
              <button type="button" className="btn" onClick={onClose}>Cancelar</button>
              <button type="submit" className="btn btn-primary" disabled={saving}>
                <IconDeviceFloppy size={16} className="me-1" />{saving ? "Salvando..." : "Salvar"}
              </button>
            </div>
          </form>
        </div>
      </div>
      <div className="modal-backdrop fade show" onClick={onClose} />
    </>
  );
}

export default function Gifts() {
  const navigate = useNavigate();
  const [gifts, setGifts] = useState<Gift[]>([]);
  const [creditReais, setCreditReais] = useState("");
  const [modal, setModal] = useState<{ gift: Gift | null } | null>(null);
  const [dialog, setDialog] = useState<DialogConfig | null>(null);
  const [toast, setToast] = useState<ToastMsg | null>(null);

  function load() {
    get("/admin/gifts").then((r) => setGifts(r.gifts)).catch((e) => setToast({ type: "error", text: e.message }));
    get("/admin/monetization").then((r) => setCreditReais((r.settings.creditPriceCents / 100).toFixed(2))).catch(() => {});
  }
  useEffect(() => { load(); }, []);

  async function saveCreditPrice() {
    const cents = Math.round(parseFloat(creditReais.replace(",", ".")) * 100);
    if (!cents || cents < 1) return setToast({ type: "error", text: "Valor inválido" });
    try { await put("/admin/monetization", { creditPriceCents: cents, currency: "BRL" }); setToast({ type: "success", text: "Valor do crédito salvo" }); }
    catch (e: any) { setToast({ type: "error", text: e.message }); }
  }

  async function toggleActive(g: Gift) {
    try { await put(`/admin/gifts/${g.id}`, { active: !g.active }); load(); }
    catch (e: any) { setToast({ type: "error", text: e.message }); }
  }

  function remove(g: Gift) {
    setDialog({
      title: "Excluir presente", message: `Remover "${g.name}"?`,
      icon: IconTrash, danger: true, confirmText: "Excluir",
      onConfirm: async () => {
        try { await del(`/admin/gifts/${g.id}`); load(); setToast({ type: "success", text: "Presente removido" }); }
        catch (e: any) { setToast({ type: "error", text: e.message }); }
      },
    });
  }

  const creditValue = parseFloat((creditReais || "0").replace(",", ".")) || 0;

  return (
    <>
      <div className="d-flex align-items-center mb-3">
        <button className="btn btn-icon me-3" onClick={() => navigate("/planos")}><IconArrowLeft size={18} /></button>
        <div className="flex-fill">
          <div className="page-pretitle">Monetização</div>
          <h2 className="page-title mb-0"><IconGift size={22} className="me-2" />Presentes</h2>
        </div>
        <button className="btn btn-primary" onClick={() => setModal({ gift: null })}>
          <IconPlus size={16} className="me-1" />Novo presente
        </button>
      </div>

      {/* Valor do crédito */}
      <div className="card mb-3">
        <div className="card-body d-flex align-items-center flex-wrap gap-3">
          <span className="avatar" style={{ background: "rgba(47,179,68,.15)", color: "#2fb344" }}><IconCoin size={22} /></span>
          <div className="flex-fill">
            <div className="fw-bold">Valor de 1 crédito</div>
            <div className="text-secondary" style={{ fontSize: 13 }}>Base de cálculo do que o usuário paga nos presentes.</div>
          </div>
          <div className="input-group" style={{ maxWidth: 220 }}>
            <span className="input-group-text">R$</span>
            <input className="form-control" value={creditReais} onChange={(e) => setCreditReais(e.target.value)} />
            <button className="btn btn-primary" onClick={saveCreditPrice}><IconDeviceFloppy size={16} /></button>
          </div>
        </div>
      </div>

      {/* Grade de presentes */}
      <div className="card">
        <div className="card-header">
          <h3 className="card-title">Presentes cadastrados ({gifts.length})</h3>
        </div>
        <div className="card-body">
          {gifts.length === 0 ? (
            <div className="text-center text-secondary py-5">
              Nenhum presente ainda. Clique em <strong>Novo presente</strong>.
            </div>
          ) : (
            <div className="row g-3">
              {gifts.map((g) => (
                <div className="col-6 col-md-4 col-xl-3" key={g.id}>
                  <div className="card" style={{ border: "1px solid var(--tblr-border-color)", opacity: g.active ? 1 : 0.55 }}>
                    {/* Imagem isolada (caixa quadrada fixa, padrão igual ao chat) */}
                    <div style={{ height: 140, background: "#f6f7fb", borderTopLeftRadius: 8, borderTopRightRadius: 8, display: "grid", placeItems: "center", padding: 10 }}>
                      <img src={img(g.imageUrl)} alt={g.name} style={{ width: 104, height: 104, objectFit: "contain", display: "block" }} />
                    </div>
                    {/* Texto isolado abaixo */}
                    <div className="card-body p-2 text-center">
                      <div className="fw-bold text-truncate" style={{ fontSize: 14 }}>{g.name}</div>
                      <div className="my-1">
                        <span className="badge bg-yellow-lt"><IconCoin size={12} className="me-1" />{g.costCredits} créd.</span>
                      </div>
                      <div className="text-secondary" style={{ fontSize: 11 }}>
                        ≈ R$ {(g.costCredits * creditValue).toFixed(2).replace(".", ",")}
                      </div>
                      <div className="d-flex align-items-center justify-content-between mt-2 pt-2" style={{ borderTop: "1px solid var(--tblr-border-color)" }}>
                        <label className="form-check form-switch m-0">
                          <input type="checkbox" className="form-check-input" checked={g.active} onChange={() => toggleActive(g)} />
                        </label>
                        <div className="d-flex gap-1">
                          <button className="btn btn-sm btn-icon" onClick={() => setModal({ gift: g })} title="Editar"><IconPencil size={14} /></button>
                          <button className="btn btn-sm btn-icon" onClick={() => remove(g)} title="Excluir"><IconTrash size={14} /></button>
                        </div>
                      </div>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>

      {modal && (
        <GiftModal
          gift={modal.gift}
          onClose={() => setModal(null)}
          onSaved={(msg) => { setModal(null); load(); setToast({ type: "success", text: msg }); }}
          onError={(msg) => setToast({ type: "error", text: msg })}
        />
      )}
      <Dialog config={dialog} onClose={() => setDialog(null)} />
      <Toast toast={toast} onClose={() => setToast(null)} />
    </>
  );
}
