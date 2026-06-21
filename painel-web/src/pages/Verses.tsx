import { FormEvent, useEffect, useState } from "react";
import { IconBook2, IconTrash, IconPlus, IconDeviceFloppy } from "@tabler/icons-react";
import { del, get, post, put } from "../api";
import { Dialog, DialogConfig, Toast, ToastMsg } from "../components/ui";

interface Verse {
  id: string;
  reference: string;
  text: string;
  active: boolean;
  sortOrder: number;
}

export default function Verses() {
  const [verses, setVerses] = useState<Verse[]>([]);
  const [reference, setReference] = useState("");
  const [text, setText] = useState("");
  const [dialog, setDialog] = useState<DialogConfig | null>(null);
  const [toast, setToast] = useState<ToastMsg | null>(null);

  function load() {
    get("/admin/verses").then((r) => setVerses(r.verses)).catch((e) => setToast({ type: "error", text: e.message }));
  }
  useEffect(() => { load(); }, []);

  async function create(e: FormEvent) {
    e.preventDefault();
    try {
      await post("/admin/verses", { reference, text, sortOrder: verses.length });
      setReference(""); setText("");
      load();
      setToast({ type: "success", text: "Verso adicionado" });
    } catch (err: any) { setToast({ type: "error", text: err.message }); }
  }

  async function toggleActive(v: Verse) {
    try { await put(`/admin/verses/${v.id}`, { active: !v.active }); load(); }
    catch (e: any) { setToast({ type: "error", text: e.message }); }
  }

  function remove(v: Verse) {
    setDialog({
      title: "Excluir verso", message: `Remover "${v.reference}"?`,
      icon: IconTrash, danger: true, confirmText: "Excluir",
      onConfirm: async () => {
        try { await del(`/admin/verses/${v.id}`); load(); setToast({ type: "success", text: "Verso removido" }); }
        catch (e: any) { setToast({ type: "error", text: e.message }); }
      },
    });
  }

  return (
    <>
      <div className="d-flex align-items-center justify-content-between mb-3">
        <div>
          <div className="page-pretitle">Conteúdo</div>
          <h2 className="page-title"><IconBook2 size={22} className="me-2" />Verso do dia</h2>
        </div>
        <span className="text-secondary">{verses.length} cadastrado(s)</span>
      </div>

      <div className="alert alert-info">
        O app mostra um versículo por dia (rotaciona). Se nenhum estiver ativo aqui, usa uma lista padrão embutida.
      </div>

      <div className="row row-cards">
        <div className="col-lg-5">
          <form className="card" onSubmit={create}>
            <div className="card-header"><h3 className="card-title"><IconPlus size={18} className="me-2" />Novo verso</h3></div>
            <div className="card-body">
              <div className="mb-3">
                <label className="form-label">Referência</label>
                <input className="form-control" value={reference} onChange={(e) => setReference(e.target.value)} placeholder="Ex.: Provérbios 3:5" required />
              </div>
              <div className="mb-3">
                <label className="form-label">Texto</label>
                <textarea className="form-control" rows={3} value={text} onChange={(e) => setText(e.target.value)} placeholder="Texto do versículo" required />
              </div>
              <button className="btn btn-primary w-100"><IconDeviceFloppy size={16} className="me-1" />Adicionar</button>
            </div>
          </form>
        </div>

        <div className="col-lg-7">
          <div className="card">
            <div className="table-responsive">
              <table className="table table-vcenter card-table">
                <thead>
                  <tr><th>Referência</th><th>Texto</th><th style={{ width: 80 }}>Ativo</th><th className="w-1"></th></tr>
                </thead>
                <tbody>
                  {verses.map((v) => (
                    <tr key={v.id}>
                      <td className="fw-medium">{v.reference}</td>
                      <td className="text-secondary" style={{ fontSize: 13 }}>{v.text}</td>
                      <td>
                        <label className="form-check form-switch m-0">
                          <input type="checkbox" className="form-check-input" checked={v.active} onChange={() => toggleActive(v)} />
                        </label>
                      </td>
                      <td>
                        <button className="btn btn-sm btn-icon" onClick={() => remove(v)} title="Excluir"><IconTrash size={15} /></button>
                      </td>
                    </tr>
                  ))}
                  {verses.length === 0 && (
                    <tr><td colSpan={4} className="text-center text-secondary py-4">Nenhum verso cadastrado (usando a lista padrão).</td></tr>
                  )}
                </tbody>
              </table>
            </div>
          </div>
        </div>
      </div>

      <Dialog config={dialog} onClose={() => setDialog(null)} />
      <Toast toast={toast} onClose={() => setToast(null)} />
    </>
  );
}
