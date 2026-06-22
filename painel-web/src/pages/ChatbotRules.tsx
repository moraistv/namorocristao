import { useEffect, useState } from "react";
import { IconPlus, IconEdit, IconTrash, IconRobot, IconDeviceFloppy } from "@tabler/icons-react";
import { get, post, put, del } from "../api";
import { Dialog, DialogConfig, Toast, ToastMsg } from "../components/ui";

const PERSONALITY: Record<string, string> = {
  ALL: "Todas",
  SHY: "Tímida",
  FUNNY: "Engraçada",
  EXTROVERT: "Extrovertida",
};

interface Rule {
  id: string;
  category: string;
  personality: string;
  priority: number;
  keywords: string[];
  responses: string[];
  active: boolean;
}

interface Settings {
  aiEnabled: boolean;
  aiProvider: string;
  aiModel: string;
  hasApiKey: boolean;
  aiSystemPrompt: string;
  replyMinMs: number;
  replyMaxMs: number;
  fallbackText: string;
}

const empty: Rule = { id: "", category: "", personality: "ALL", priority: 5, keywords: [], responses: [], active: true };

export default function ChatbotRules() {
  const [rules, setRules] = useState<Rule[]>([]);
  const [settings, setSettings] = useState<Settings | null>(null);
  const [apiKey, setApiKey] = useState("");
  const [editing, setEditing] = useState<Rule | null>(null);
  const [kw, setKw] = useState("");
  const [resp, setResp] = useState("");
  const [dialog, setDialog] = useState<DialogConfig | null>(null);
  const [toast, setToast] = useState<ToastMsg | null>(null);

  async function load() {
    try {
      const [r, s] = await Promise.all([get("/admin/chatbot/rules"), get("/admin/chatbot/settings")]);
      setRules(r.rules);
      setSettings(s.settings);
    } catch (e: any) { setToast({ type: "error", text: e.message }); }
  }
  useEffect(() => { load(); }, []);

  function openNew() { setEditing({ ...empty }); setKw(""); setResp(""); }
  function openEdit(r: Rule) { setEditing({ ...r }); setKw(r.keywords.join(", ")); setResp(r.responses.join("\n")); }

  async function saveRule() {
    if (!editing) return;
    const body = {
      category: editing.category.trim(),
      personality: editing.personality,
      priority: editing.priority,
      active: editing.active,
      keywords: kw.split(",").map((s) => s.trim()).filter(Boolean),
      responses: resp.split("\n").map((s) => s.trim()).filter(Boolean),
    };
    if (!body.category || body.keywords.length === 0 || body.responses.length === 0) {
      setToast({ type: "error", text: "Preencha categoria, palavras-chave e respostas." });
      return;
    }
    try {
      if (editing.id) await put(`/admin/chatbot/rules/${editing.id}`, body);
      else await post("/admin/chatbot/rules", body);
      setEditing(null); load(); setToast({ type: "success", text: "Regra salva" });
    } catch (e: any) { setToast({ type: "error", text: e.message }); }
  }

  function removeRule(r: Rule) {
    setDialog({
      title: "Excluir regra", message: `Remover a regra "${r.category}"?`, icon: IconTrash, danger: true, confirmText: "Excluir",
      onConfirm: async () => { try { await del(`/admin/chatbot/rules/${r.id}`); load(); setToast({ type: "success", text: "Regra excluída" }); } catch (e: any) { setToast({ type: "error", text: e.message }); } },
    });
  }

  async function toggleActive(r: Rule) {
    try { await put(`/admin/chatbot/rules/${r.id}`, { active: !r.active }); load(); } catch (e: any) { setToast({ type: "error", text: e.message }); }
  }

  async function saveSettings() {
    if (!settings) return;
    const body: any = {
      aiEnabled: settings.aiEnabled, aiProvider: settings.aiProvider, aiModel: settings.aiModel,
      aiSystemPrompt: settings.aiSystemPrompt, replyMinMs: settings.replyMinMs, replyMaxMs: settings.replyMaxMs,
      fallbackText: settings.fallbackText,
    };
    if (apiKey.trim()) body.aiApiKey = apiKey.trim();
    try { const s = await put("/admin/chatbot/settings", body); setSettings(s.settings); setApiKey(""); setToast({ type: "success", text: "Configuração salva" }); }
    catch (e: any) { setToast({ type: "error", text: e.message }); }
  }

  return (
    <>
      <div className="d-flex align-items-center justify-content-between mb-3">
        <div>
          <div className="page-pretitle">Bots</div>
          <h2 className="page-title">Regras do Chatbot</h2>
        </div>
        <button className="btn btn-primary" onClick={openNew}><IconPlus size={16} className="me-1" />Nova Regra</button>
      </div>

      {/* Configuração de IA */}
      {settings && (
        <div className="card mb-3">
          <div className="card-header"><h3 className="card-title"><IconRobot size={18} className="me-2" />Inteligência Artificial (fallback)</h3></div>
          <div className="card-body">
            <p className="text-secondary" style={{ fontSize: 13 }}>Quando nenhuma regra casa, o bot pode responder via IA (precisa de chave). Senão, usa o texto padrão abaixo.</p>
            <div className="row g-3">
              <div className="col-md-3">
                <label className="form-check form-switch mt-2">
                  <input className="form-check-input" type="checkbox" checked={settings.aiEnabled} onChange={(e) => setSettings({ ...settings, aiEnabled: e.target.checked })} />
                  <span className="form-check-label">IA ativada</span>
                </label>
              </div>
              <div className="col-md-3"><label className="form-label">Provedor</label><input className="form-control" value={settings.aiProvider} onChange={(e) => setSettings({ ...settings, aiProvider: e.target.value })} /></div>
              <div className="col-md-3"><label className="form-label">Modelo</label><input className="form-control" value={settings.aiModel} onChange={(e) => setSettings({ ...settings, aiModel: e.target.value })} /></div>
              <div className="col-md-3"><label className="form-label">API Key {settings.hasApiKey && <span className="badge bg-green-lt ms-1">salva</span>}</label><input className="form-control" type="password" placeholder={settings.hasApiKey ? "•••• (mantém atual)" : "cole a chave"} value={apiKey} onChange={(e) => setApiKey(e.target.value)} /></div>
              <div className="col-12"><label className="form-label">Instrução base (system prompt)</label><textarea className="form-control" rows={2} value={settings.aiSystemPrompt} onChange={(e) => setSettings({ ...settings, aiSystemPrompt: e.target.value })} /></div>
              <div className="col-md-3"><label className="form-label">Atraso mín (ms)</label><input type="number" className="form-control" value={settings.replyMinMs} onChange={(e) => setSettings({ ...settings, replyMinMs: +e.target.value })} /></div>
              <div className="col-md-3"><label className="form-label">Atraso máx (ms)</label><input type="number" className="form-control" value={settings.replyMaxMs} onChange={(e) => setSettings({ ...settings, replyMaxMs: +e.target.value })} /></div>
              <div className="col-md-6"><label className="form-label">Resposta padrão (fallback)</label><input className="form-control" value={settings.fallbackText} onChange={(e) => setSettings({ ...settings, fallbackText: e.target.value })} /></div>
            </div>
            <div className="mt-3"><button className="btn btn-primary" onClick={saveSettings}><IconDeviceFloppy size={16} className="me-1" />Salvar configuração</button></div>
          </div>
        </div>
      )}

      {/* Regras */}
      <div className="card">
        <div className="card-header"><h3 className="card-title">Regras ({rules.length})</h3></div>
        <div className="table-responsive">
          <table className="table table-vcenter card-table">
            <thead><tr><th>Categoria</th><th>Personalidade</th><th>Prioridade</th><th>Palavras-chave</th><th>Respostas</th><th>Ativa</th><th className="w-1"></th></tr></thead>
            <tbody>
              {rules.map((r) => (
                <tr key={r.id}>
                  <td className="fw-medium">{r.category}</td>
                  <td><span className="badge bg-azure-lt">{PERSONALITY[r.personality] || r.personality}</span></td>
                  <td>{r.priority}</td>
                  <td className="text-secondary">{r.keywords.slice(0, 4).join(", ")}{r.keywords.length > 4 ? `  +${r.keywords.length - 4}` : ""}</td>
                  <td className="text-secondary">{r.responses.length}</td>
                  <td><label className="form-check form-switch m-0"><input className="form-check-input" type="checkbox" checked={r.active} onChange={() => toggleActive(r)} /></label></td>
                  <td>
                    <div className="d-flex gap-1 justify-content-end">
                      <button className="btn btn-sm btn-icon" onClick={() => openEdit(r)}><IconEdit size={16} /></button>
                      <button className="btn btn-sm btn-icon btn-ghost-danger" onClick={() => removeRule(r)}><IconTrash size={16} /></button>
                    </div>
                  </td>
                </tr>
              ))}
              {rules.length === 0 && <tr><td colSpan={7} className="text-center text-secondary py-4">Nenhuma regra. Crie a primeira ou rode o seed.</td></tr>}
            </tbody>
          </table>
        </div>
      </div>

      {/* Modal de regra */}
      {editing && (
        <div className="modal modal-blur show d-block" tabIndex={-1} style={{ background: "rgba(0,0,0,.4)" }}>
          <div className="modal-dialog modal-lg modal-dialog-centered">
            <div className="modal-content">
              <div className="modal-header"><h5 className="modal-title">{editing.id ? "Editar regra" : "Nova regra"}</h5><button className="btn-close" onClick={() => setEditing(null)} /></div>
              <div className="modal-body">
                <div className="row g-3">
                  <div className="col-md-5"><label className="form-label">Categoria</label><input className="form-control" value={editing.category} onChange={(e) => setEditing({ ...editing, category: e.target.value })} placeholder="ex.: saudacao" /></div>
                  <div className="col-md-4"><label className="form-label">Personalidade</label>
                    <select className="form-select" value={editing.personality} onChange={(e) => setEditing({ ...editing, personality: e.target.value })}>
                      {Object.entries(PERSONALITY).map(([v, l]) => <option key={v} value={v}>{l}</option>)}
                    </select>
                  </div>
                  <div className="col-md-3"><label className="form-label">Prioridade (0-10)</label><input type="number" min={0} max={10} className="form-control" value={editing.priority} onChange={(e) => setEditing({ ...editing, priority: Math.max(0, Math.min(10, +e.target.value)) })} /></div>
                  <div className="col-12"><label className="form-label">Palavras-chave (separadas por vírgula)</label><textarea className="form-control" rows={2} value={kw} onChange={(e) => setKw(e.target.value)} placeholder="oi, ola, e ai, bom dia" /></div>
                  <div className="col-12"><label className="form-label">Respostas (uma por linha)</label><textarea className="form-control" rows={4} value={resp} onChange={(e) => setResp(e.target.value)} placeholder={"Oi {name}! Tudo bem?\nOlá! Que bom falar com você 💛"} /><small className="text-secondary">Variáveis: {"{name}"} {"{age}"} {"{city}"} — o bot sorteia uma resposta.</small></div>
                  <div className="col-12"><label className="form-check form-switch"><input className="form-check-input" type="checkbox" checked={editing.active} onChange={(e) => setEditing({ ...editing, active: e.target.checked })} /><span className="form-check-label">Regra ativa</span></label></div>
                </div>
              </div>
              <div className="modal-footer"><button className="btn" onClick={() => setEditing(null)}>Cancelar</button><button className="btn btn-primary" onClick={saveRule}>Salvar</button></div>
            </div>
          </div>
        </div>
      )}

      <Dialog config={dialog} onClose={() => setDialog(null)} />
      <Toast toast={toast} onClose={() => setToast(null)} />
    </>
  );
}
