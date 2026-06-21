import { FormEvent, useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import {
  IconCrown, IconCoin, IconStar, IconBolt, IconGift, IconSpeakerphone,
  IconTrash, IconPencil, IconDeviceFloppy, IconArrowRight, IconPlus,
} from "@tabler/icons-react";
import { del, get, post, put } from "../api";
import { Dialog, DialogConfig, Toast, ToastMsg } from "../components/ui";

type Kind = "PREMIUM" | "CREDITS" | "SUPERLIKES" | "BOOSTS";

interface Product {
  id: string;
  kind: Kind;
  title: string;
  description?: string | null;
  googleProductId?: string | null;
  priceCents: number;
  amount: number;
  durationDays?: number | null;
  active: boolean;
  sortOrder: number;
}

const KIND_META: Record<Kind, { label: string; icon: any; color: string; bg: string; amountLabel: string }> = {
  PREMIUM: { label: "Planos VIP", icon: IconCrown, color: "#b8941f", bg: "rgba(212,175,55,.15)", amountLabel: "Duração" },
  CREDITS: { label: "Pacotes de Créditos", icon: IconCoin, color: "#2fb344", bg: "rgba(47,179,68,.15)", amountLabel: "Créditos" },
  SUPERLIKES: { label: "Super Likes", icon: IconStar, color: "#4263eb", bg: "rgba(66,99,235,.15)", amountLabel: "Super Likes" },
  BOOSTS: { label: "Boosts", icon: IconBolt, color: "#ae3ec9", bg: "rgba(174,62,201,.15)", amountLabel: "Boosts" },
};
const KINDS: Kind[] = ["PREMIUM", "CREDITS", "SUPERLIKES", "BOOSTS"];
const reais = (cents: number) => `R$ ${(cents / 100).toFixed(2).replace(".", ",")}`;

// ─────────── Modal de produto ───────────
function ProductModal({ kind, product, onClose, onSaved, onError }: {
  kind: Kind; product: Product | null; onClose: () => void;
  onSaved: (msg: string) => void; onError: (msg: string) => void;
}) {
  const meta = KIND_META[kind];
  const [title, setTitle] = useState(product?.title ?? "");
  const [description, setDescription] = useState(product?.description ?? "");
  const [priceReais, setPriceReais] = useState(product ? (product.priceCents / 100).toFixed(2) : "");
  const [amount, setAmount] = useState(String(product?.amount ?? ""));
  const [durationDays, setDurationDays] = useState(String(product?.durationDays ?? ""));
  const [googleProductId, setGoogleProductId] = useState(product?.googleProductId ?? "");
  const [sortOrder, setSortOrder] = useState(String(product?.sortOrder ?? 0));
  const [active, setActive] = useState(product?.active ?? true);
  const [saving, setSaving] = useState(false);

  async function submit(e: FormEvent) {
    e.preventDefault();
    setSaving(true);
    const payload = {
      kind,
      title,
      description: description || null,
      googleProductId: googleProductId || null,
      priceCents: Math.round(parseFloat((priceReais || "0").replace(",", ".")) * 100),
      amount: kind === "PREMIUM" ? 0 : Number(amount) || 0,
      durationDays: kind === "PREMIUM" ? Number(durationDays) || 0 : null,
      active,
      sortOrder: Number(sortOrder) || 0,
    };
    try {
      if (product) await put(`/admin/products/${product.id}`, payload);
      else await post("/admin/products", payload);
      onSaved(product ? "Produto atualizado" : "Produto criado");
    } catch (err: any) { onError(err.message); setSaving(false); }
  }

  return (
    <>
      <div className="modal modal-blur fade show d-block" tabIndex={-1}>
        <div className="modal-dialog modal-dialog-centered" role="document">
          <form className="modal-content" onSubmit={submit}>
            <div className="modal-header" style={{ background: "#111d40" }}>
              <h5 className="modal-title text-white">{product ? "Editar" : "Novo"} — {meta.label}</h5>
              <button type="button" className="btn-close btn-close-white" onClick={onClose} />
            </div>
            <div className="modal-body">
              <div className="mb-3">
                <label className="form-label">Título</label>
                <input className="form-control" value={title} onChange={(e) => setTitle(e.target.value)} required placeholder={kind === "PREMIUM" ? "Ex.: VIP Mensal" : "Ex.: Pacote 100 créditos"} />
              </div>
              <div className="row g-2 mb-3">
                <div className="col-6">
                  <label className="form-label">Preço (R$)</label>
                  <input className="form-control" value={priceReais} onChange={(e) => setPriceReais(e.target.value)} placeholder="0,00" required />
                </div>
                <div className="col-6">
                  <label className="form-label">{kind === "PREMIUM" ? "Duração (dias)" : meta.amountLabel}</label>
                  {kind === "PREMIUM" ? (
                    <input className="form-control" type="number" min={1} value={durationDays} onChange={(e) => setDurationDays(e.target.value)} placeholder="30" />
                  ) : (
                    <input className="form-control" type="number" min={1} value={amount} onChange={(e) => setAmount(e.target.value)} placeholder="100" />
                  )}
                </div>
              </div>
              <div className="mb-3">
                <label className="form-label">ID do produto na Google Play (SKU)</label>
                <input className="form-control" value={googleProductId} onChange={(e) => setGoogleProductId(e.target.value)} placeholder="ex.: vip_mensal" />
                <div className="text-secondary mt-1" style={{ fontSize: 12 }}>Deve ser igual ao cadastrado no Google Play Console.</div>
              </div>
              <div className="mb-3">
                <label className="form-label">Descrição (opcional)</label>
                <input className="form-control" value={description} onChange={(e) => setDescription(e.target.value)} />
              </div>
              <div className="row g-2 align-items-end">
                <div className="col-6">
                  <label className="form-label">Ordem de exibição</label>
                  <input className="form-control" type="number" value={sortOrder} onChange={(e) => setSortOrder(e.target.value)} />
                </div>
                <div className="col-6">
                  <label className="form-check mt-3">
                    <input type="checkbox" className="form-check-input" checked={active} onChange={(e) => setActive(e.target.checked)} />
                    <span className="form-check-label">Ativo no app</span>
                  </label>
                </div>
              </div>
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

export default function Plans() {
  const navigate = useNavigate();
  const [products, setProducts] = useState<Product[]>([]);
  const [creditReais, setCreditReais] = useState("");
  const [modal, setModal] = useState<{ kind: Kind; product: Product | null } | null>(null);
  const [dialog, setDialog] = useState<DialogConfig | null>(null);
  const [toast, setToast] = useState<ToastMsg | null>(null);

  function load() {
    get("/admin/products").then((r) => setProducts(r.products)).catch((e) => setToast({ type: "error", text: e.message }));
    get("/admin/monetization").then((r) => setCreditReais((r.settings.creditPriceCents / 100).toFixed(2))).catch(() => {});
  }
  useEffect(() => { load(); }, []);

  async function saveCreditPrice() {
    const cents = Math.round(parseFloat(creditReais.replace(",", ".")) * 100);
    if (!cents || cents < 1) return setToast({ type: "error", text: "Valor inválido" });
    try { await put("/admin/monetization", { creditPriceCents: cents, currency: "BRL" }); setToast({ type: "success", text: "Valor do crédito salvo" }); }
    catch (e: any) { setToast({ type: "error", text: e.message }); }
  }

  async function toggleActive(p: Product) {
    try { await put(`/admin/products/${p.id}`, { active: !p.active }); load(); }
    catch (e: any) { setToast({ type: "error", text: e.message }); }
  }
  function removeProduct(p: Product) {
    setDialog({
      title: "Excluir produto", message: `Remover "${p.title}"?`,
      icon: IconTrash, danger: true, confirmText: "Excluir",
      onConfirm: async () => {
        try { await del(`/admin/products/${p.id}`); load(); setToast({ type: "success", text: "Produto removido" }); }
        catch (e: any) { setToast({ type: "error", text: e.message }); }
      },
    });
  }

  const counts = { total: products.length, active: products.filter((p) => p.active).length };

  return (
    <>
      <div className="d-flex align-items-center justify-content-between mb-3">
        <div>
          <div className="page-pretitle">Monetização</div>
          <h2 className="page-title">Planos e Produtos</h2>
        </div>
        <span className="text-secondary">{counts.active}/{counts.total} ativos</span>
      </div>

      <div className="alert alert-info">
        Compras processadas pela <strong>Google Play (in-app billing)</strong>. Defina aqui valores, quantidades e o <strong>SKU</strong> de cada item — o app lê em tempo real.
      </div>

      {/* Atalhos */}
      <div className="row row-cards mb-3">
        <div className="col-sm-6 col-lg-3">
          <div className="card" style={{ cursor: "pointer" }} onClick={() => navigate("/planos/presentes")}>
            <div className="card-body d-flex align-items-center">
              <span className="avatar me-3" style={{ background: "rgba(245,159,0,.15)", color: "#f59f00" }}><IconGift size={22} /></span>
              <div className="flex-fill"><div className="fw-bold">Presentes</div><div className="text-secondary" style={{ fontSize: 13 }}>Gifs/PNG/SVG</div></div>
              <IconArrowRight size={18} className="text-secondary" />
            </div>
          </div>
        </div>
        <div className="col-sm-6 col-lg-3">
          <div className="card" style={{ cursor: "pointer" }} onClick={() => navigate("/anuncios")}>
            <div className="card-body d-flex align-items-center">
              <span className="avatar me-3" style={{ background: "rgba(17,29,64,.08)", color: "#111d40" }}><IconSpeakerphone size={22} /></span>
              <div className="flex-fill"><div className="fw-bold">Anúncios</div><div className="text-secondary" style={{ fontSize: 13 }}>AdMob remoto</div></div>
              <IconArrowRight size={18} className="text-secondary" />
            </div>
          </div>
        </div>
        <div className="col-lg-6">
          <div className="card">
            <div className="card-body d-flex align-items-center">
              <span className="avatar me-3" style={{ background: "rgba(47,179,68,.15)", color: "#2fb344" }}><IconCoin size={22} /></span>
              <div className="flex-fill"><div className="fw-bold">Valor de 1 crédito</div><div className="text-secondary" style={{ fontSize: 13 }}>Base dos presentes</div></div>
              <div className="input-group" style={{ maxWidth: 200 }}>
                <span className="input-group-text">R$</span>
                <input className="form-control" value={creditReais} onChange={(e) => setCreditReais(e.target.value)} />
                <button className="btn btn-primary" onClick={saveCreditPrice}><IconDeviceFloppy size={16} /></button>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Categorias */}
      {KINDS.map((k) => {
        const meta = KIND_META[k];
        const Icon = meta.icon;
        const items = products.filter((p) => p.kind === k).sort((a, b) => a.sortOrder - b.sortOrder);
        return (
          <div className="card mb-3" key={k}>
            <div className="card-header d-flex align-items-center">
              <span className="avatar avatar-sm me-2" style={{ background: meta.bg, color: meta.color }}><Icon size={18} /></span>
              <h3 className="card-title mb-0">{meta.label}</h3>
              <span className="text-secondary ms-2">({items.length})</span>
              <button className="btn btn-primary btn-sm ms-auto" onClick={() => setModal({ kind: k, product: null })}>
                <IconPlus size={15} className="me-1" />Adicionar
              </button>
            </div>
            <div className="card-body">
              {items.length === 0 ? (
                <div className="text-center text-secondary py-3">Nenhum item. Clique em <strong>Adicionar</strong>.</div>
              ) : (
                <div className="row g-3">
                  {items.map((p) => (
                    <div className="col-md-6 col-xl-4" key={p.id}>
                      <div className="card card-sm" style={{ border: "1px solid var(--tblr-border-color)", opacity: p.active ? 1 : 0.6 }}>
                        <div className="card-body">
                          <div className="d-flex align-items-start">
                            <div className="flex-fill">
                              <div className="fw-bold">{p.title}</div>
                              <div className="text-secondary" style={{ fontSize: 13 }}>
                                {k === "PREMIUM" ? `${p.durationDays ?? 0} dias` : `${p.amount} ${meta.amountLabel.toLowerCase()}`}
                              </div>
                            </div>
                            <div className="text-end">
                              <div style={{ fontSize: 18, fontWeight: 700, color: meta.color }}>{reais(p.priceCents)}</div>
                            </div>
                          </div>
                          {p.googleProductId && <div className="mt-1"><code style={{ fontSize: 11 }}>{p.googleProductId}</code></div>}
                          {p.description && <div className="text-secondary mt-1" style={{ fontSize: 12 }}>{p.description}</div>}
                          <div className="d-flex align-items-center mt-2 pt-2" style={{ borderTop: "1px solid var(--tblr-border-color)" }}>
                            <label className="form-check form-switch m-0">
                              <input type="checkbox" className="form-check-input" checked={p.active} onChange={() => toggleActive(p)} />
                              <span className="form-check-label" style={{ fontSize: 12 }}>{p.active ? "Ativo" : "Inativo"}</span>
                            </label>
                            <div className="ms-auto d-flex gap-1">
                              <button className="btn btn-sm btn-icon" onClick={() => setModal({ kind: k, product: p })} title="Editar"><IconPencil size={15} /></button>
                              <button className="btn btn-sm btn-icon" onClick={() => removeProduct(p)} title="Excluir"><IconTrash size={15} /></button>
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
        );
      })}

      {modal && (
        <ProductModal
          kind={modal.kind}
          product={modal.product}
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
