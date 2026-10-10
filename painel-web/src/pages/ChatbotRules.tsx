import { useEffect, useRef, useState } from "react";
import {
  IconBrain,
  IconDatabase,
  IconDeviceFloppy,
  IconEdit,
  IconKey,
  IconPlus,
  IconRefresh,
  IconRobot,
  IconShieldCheck,
  IconTrash,
} from "@tabler/icons-react";
import { ApiError, del, get, post, put } from "../api";
import { Dialog, DialogConfig, Toast, ToastMsg } from "../components/ui";
import { useModalAccessibility } from "../components/useModalAccessibility";

const PERSONALITY: Record<string, string> = {
  ALL: "Todas",
  SHY: "Tímida",
  FUNNY: "Engraçada",
  EXTROVERT: "Extrovertida",
};
const MODEL_PATTERN = /^[A-Za-z0-9][A-Za-z0-9._:/-]{0,99}$/;
const PROMPT_MAX_LENGTH = 4000;
const FALLBACK_MAX_LENGTH = 500;

interface Rule {
  id: string;
  category: string;
  personality: string;
  priority: number;
  keywords: string[];
  responses: string[];
  active: boolean;
}

interface RulesResponse {
  rules?: Rule[];
}

interface Settings {
  aiEnabled: boolean;
  aiProvider: "deepseek" | "openai";
  aiModel: string;
  hasApiKey: boolean;
  apiKeySource: "environment" | "database" | null;
  aiSystemPrompt: string;
  replyMinMs: number;
  replyMaxMs: number;
  fallbackText: string;
  memoryEnabled: boolean;
  memoryRefreshMessages: number;
  recentMessageLimit: number;
}

interface SettingsResponse {
  settings: Settings;
}

interface SettingsUpdateRequest {
  aiEnabled: boolean;
  aiProvider: Settings["aiProvider"];
  aiModel: string;
  aiSystemPrompt: string;
  replyMinMs: number;
  replyMaxMs: number;
  fallbackText: string;
  memoryEnabled: boolean;
  memoryRefreshMessages: number;
  recentMessageLimit: number;
  aiApiKey?: string;
}

const emptyRule: Rule = {
  id: "",
  category: "",
  personality: "ALL",
  priority: 5,
  keywords: [],
  responses: [],
  active: true,
};

function isAiModelCompatible(
  provider: Settings["aiProvider"],
  model: string
): boolean {
  const normalized = model.trim().toLowerCase();
  if (provider === "deepseek") {
    return normalized === "deepseek-chat" || normalized === "deepseek-reasoner";
  }
  const baseModel = normalized.startsWith("ft:")
    ? normalized.slice(3)
    : normalized;
  return /^(?:gpt-|chatgpt-|o(?:1|3|4)(?:-|$))/.test(baseModel);
}

function errorMessage(error: unknown) {
  return error instanceof Error && error.message ? error.message : "Não foi possível concluir a operação";
}

function isIntegerInRange(value: number, minimum: number, maximum: number): boolean {
  return Number.isInteger(value) && value >= minimum && value <= maximum;
}

export default function ChatbotRules() {
  const [rules, setRules] = useState<Rule[]>([]);
  const [settings, setSettings] = useState<Settings | null>(null);
  const [persistedProvider, setPersistedProvider] = useState<Settings["aiProvider"] | null>(null);
  const [apiKey, setApiKey] = useState("");
  const [editing, setEditing] = useState<Rule | null>(null);
  const [keywords, setKeywords] = useState("");
  const [responses, setResponses] = useState("");
  const [loadingRules, setLoadingRules] = useState(true);
  const [loadingSettings, setLoadingSettings] = useState(true);
  const [rulesError, setRulesError] = useState("");
  const [settingsError, setSettingsError] = useState("");
  const [savingRule, setSavingRule] = useState(false);
  const [togglingRuleId, setTogglingRuleId] = useState<string | null>(null);
  const [savingSettings, setSavingSettings] = useState(false);
  const [dialog, setDialog] = useState<DialogConfig | null>(null);
  const [toast, setToast] = useState<ToastMsg | null>(null);
  const rulesRequestRef = useRef(0);
  const settingsRequestRef = useRef(0);

  const ruleModalRef = useModalAccessibility({
    open: Boolean(editing),
    onClose: closeRuleModal,
    canClose: !savingRule,
  });

  async function loadRules() {
    const request = ++rulesRequestRef.current;
    setLoadingRules(true);
    setRulesError("");
    try {
      const response = await get<RulesResponse>("/admin/chatbot/rules");
      if (request !== rulesRequestRef.current) return;
      setRules(Array.isArray(response.rules) ? response.rules : []);
    } catch (error: unknown) {
      if (request === rulesRequestRef.current) setRulesError(errorMessage(error));
    } finally {
      if (request === rulesRequestRef.current) setLoadingRules(false);
    }
  }

  async function loadSettings() {
    const request = ++settingsRequestRef.current;
    setLoadingSettings(true);
    setSettingsError("");
    try {
      const response = await get<SettingsResponse>("/admin/chatbot/settings");
      if (!response.settings) {
        throw new ApiError("O servidor retornou configurações inválidas.", 200, "INVALID_RESPONSE");
      }
      if (request !== settingsRequestRef.current) return;
      setSettings(response.settings);
      setPersistedProvider(response.settings.aiProvider);
    } catch (error: unknown) {
      if (request === settingsRequestRef.current) setSettingsError(errorMessage(error));
    } finally {
      if (request === settingsRequestRef.current) setLoadingSettings(false);
    }
  }

  useEffect(() => {
    void Promise.allSettled([loadRules(), loadSettings()]);
    return () => {
      rulesRequestRef.current += 1;
      settingsRequestRef.current += 1;
    };
  }, []);

  function closeRuleModal() {
    if (savingRule) return;
    setEditing(null);
  }

  function openNew() {
    if (savingRule) return;
    setEditing({ ...emptyRule, keywords: [], responses: [] });
    setKeywords("");
    setResponses("");
  }

  function openEdit(rule: Rule) {
    if (savingRule) return;
    setEditing({ ...rule, keywords: [...rule.keywords], responses: [...rule.responses] });
    setKeywords(rule.keywords.join(", "));
    setResponses(rule.responses.join("\n"));
  }

  async function saveRule() {
    if (!editing || savingRule) return;

    const category = editing.category.trim();
    const normalizedKeywords = keywords
      .split(",")
      .map((item) => item.trim())
      .filter(Boolean);
    const normalizedResponses = responses
      .split("\n")
      .map((item) => item.trim())
      .filter(Boolean);

    if (category.length < 1 || category.length > 60) {
      setToast({ type: "error", text: "A categoria deve ter entre 1 e 60 caracteres." });
      return;
    }
    if (!isIntegerInRange(editing.priority, 0, 10)) {
      setToast({ type: "error", text: "A prioridade deve ser um número inteiro entre 0 e 10." });
      return;
    }
    if (normalizedKeywords.length === 0) {
      setToast({ type: "error", text: "Informe ao menos uma palavra-chave." });
      return;
    }
    if (normalizedKeywords.some((keyword) => keyword.length > 60)) {
      setToast({ type: "error", text: "Cada palavra-chave deve ter no máximo 60 caracteres." });
      return;
    }
    if (normalizedResponses.length === 0) {
      setToast({ type: "error", text: "Informe ao menos uma resposta." });
      return;
    }
    if (normalizedResponses.some((response) => response.length > 500)) {
      setToast({ type: "error", text: "Cada resposta deve ter no máximo 500 caracteres." });
      return;
    }

    const body = {
      category,
      personality: editing.personality,
      priority: editing.priority,
      active: editing.active,
      keywords: normalizedKeywords,
      responses: normalizedResponses,
    };

    setSavingRule(true);
    try {
      if (editing.id) await put<void>(`/admin/chatbot/rules/${editing.id}`, body);
      else await post<void>("/admin/chatbot/rules", body);
      setEditing(null);
      await loadRules();
      setToast({ type: "success", text: "Regra salva." });
    } catch (error: unknown) {
      setToast({ type: "error", text: errorMessage(error) });
    } finally {
      setSavingRule(false);
    }
  }

  function removeRule(rule: Rule) {
    setDialog({
      title: "Excluir regra",
      message: `Remover a regra “${rule.category}”?`,
      icon: IconTrash,
      danger: true,
      confirmText: "Excluir",
      onConfirm: async () => {
        try {
          await del<void>(`/admin/chatbot/rules/${rule.id}`);
          await loadRules();
          setToast({ type: "success", text: "Regra excluída." });
        } catch (error: unknown) {
          setToast({ type: "error", text: errorMessage(error) });
          throw error;
        }
      },
    });
  }

  async function toggleActive(rule: Rule) {
    if (togglingRuleId) return;
    setTogglingRuleId(rule.id);
    try {
      await put<void>(`/admin/chatbot/rules/${rule.id}`, { active: !rule.active });
      setRules((current) => current.map((item) => item.id === rule.id
        ? { ...item, active: !item.active }
        : item));
    } catch (error: unknown) {
      setToast({ type: "error", text: errorMessage(error) });
    } finally {
      setTogglingRuleId(null);
    }
  }

  function validateSettings(current: Settings): string | null {
    const model = current.aiModel.trim();
    const prompt = current.aiSystemPrompt.trim();
    const fallback = current.fallbackText.trim();

    if (!MODEL_PATTERN.test(model)) {
      return "O modelo deve ter 1 a 100 caracteres e usar apenas letras, números, ponto, hífen, sublinhado, dois-pontos ou barra.";
    }
    if (!isAiModelCompatible(current.aiProvider, model)) {
      return "O modelo global não pertence ao provider selecionado.";
    }
    if (!prompt || prompt.length > PROMPT_MAX_LENGTH) {
      return `A instrução global é obrigatória e deve ter no máximo ${PROMPT_MAX_LENGTH} caracteres.`;
    }
    if (!fallback || fallback.length > FALLBACK_MAX_LENGTH) {
      return `A resposta de emergência é obrigatória e deve ter no máximo ${FALLBACK_MAX_LENGTH} caracteres.`;
    }
    if (!isIntegerInRange(current.replyMinMs, 0, 60_000)) {
      return "O atraso mínimo deve ser um inteiro entre 0 e 60000 ms.";
    }
    if (!isIntegerInRange(current.replyMaxMs, 0, 120_000)) {
      return "O atraso máximo deve ser um inteiro entre 0 e 120000 ms.";
    }
    if (current.replyMaxMs < current.replyMinMs) {
      return "O atraso máximo deve ser maior ou igual ao mínimo.";
    }
    if (!isIntegerInRange(current.memoryRefreshMessages, 2, 100)) {
      return "A atualização da memória deve usar um inteiro entre 2 e 100 mensagens.";
    }
    if (!isIntegerInRange(current.recentMessageLimit, 4, 100)) {
      return "A janela recente deve usar um inteiro entre 4 e 100 mensagens.";
    }
    return null;
  }

  async function saveSettings() {
    if (!settings || savingSettings) return;
    const validationError = validateSettings(settings);
    if (validationError) {
      setToast({ type: "error", text: validationError });
      return;
    }

    const body: SettingsUpdateRequest = {
      aiEnabled: settings.aiEnabled,
      aiProvider: settings.aiProvider,
      aiModel: settings.aiModel.trim(),
      aiSystemPrompt: settings.aiSystemPrompt.trim(),
      replyMinMs: settings.replyMinMs,
      replyMaxMs: settings.replyMaxMs,
      fallbackText: settings.fallbackText.trim(),
      memoryEnabled: settings.memoryEnabled,
      memoryRefreshMessages: settings.memoryRefreshMessages,
      recentMessageLimit: settings.recentMessageLimit,
    };
    const nextApiKey = apiKey.trim();
    if (nextApiKey) body.aiApiKey = nextApiKey;

    setSavingSettings(true);
    try {
      const response = await put<SettingsResponse>("/admin/chatbot/settings", body);
      if (!response.settings) {
        throw new ApiError("O servidor retornou configurações inválidas.", 200, "INVALID_RESPONSE");
      }
      setSettings(response.settings);
      setPersistedProvider(response.settings.aiProvider);
      setApiKey("");
      setToast({ type: "success", text: "Motor de IA configurado com segurança." });
    } catch (error: unknown) {
      setToast({ type: "error", text: errorMessage(error) });
    } finally {
      setSavingSettings(false);
    }
  }

  function clearDatabaseKey() {
    setDialog({
      title: "Remover chave salva",
      message: "Remover a chave criptografada do banco? Uma chave definida no ambiente continuará tendo prioridade.",
      icon: IconKey,
      danger: true,
      confirmText: "Remover chave",
      onConfirm: async () => {
        try {
          const response = await put<SettingsResponse>("/admin/chatbot/settings", { aiApiKey: null });
          if (!response.settings) {
            throw new ApiError("O servidor retornou configurações inválidas.", 200, "INVALID_RESPONSE");
          }
          setSettings(response.settings);
          setPersistedProvider(response.settings.aiProvider);
          setApiKey("");
          setToast({ type: "success", text: "Chave salva removida." });
        } catch (error: unknown) {
          setToast({ type: "error", text: errorMessage(error) });
          throw error;
        }
      },
    });
  }

  const keyLabel = settings?.apiKeySource === "environment"
    ? "Ambiente (protegida)"
    : settings?.apiKeySource === "database"
      ? "Banco (criptografada)"
      : "Não configurada";
  const providerChangedWithoutNewKey = Boolean(
    settings &&
    persistedProvider &&
    settings.aiProvider !== persistedProvider &&
    settings.apiKeySource !== null &&
    !apiKey.trim()
  );

  return (
    <>
      <div className="d-flex flex-wrap align-items-center justify-content-between gap-2 mb-3">
        <div><div className="page-pretitle">Automação inteligente</div><h2 className="page-title">Regras, IA e memória</h2></div>
        <button type="button" className="btn btn-primary" onClick={openNew}><IconPlus size={16} className="me-1" aria-hidden="true" /> Nova regra</button>
      </div>

      {settingsError && (
        <div className="alert alert-danger retry-state" role="alert">
          <span>Configurações da IA: {settingsError}</span>
          <button type="button" className="btn btn-sm" disabled={loadingSettings} onClick={() => void loadSettings()}><IconRefresh size={16} className="me-1" aria-hidden="true" />Tentar novamente</button>
        </div>
      )}
      {loadingSettings && !settings && <div className="card mb-4"><div className="card-body text-secondary text-center py-5" role="status"><span className="spinner-border spinner-border-sm me-2" aria-hidden="true" />Carregando configurações da IA...</div></div>}

      {settings && (
        <div className="card mb-4 overflow-hidden" aria-busy={loadingSettings || savingSettings}>
          <div className="card-header bg-transparent"><div><h3 className="card-title"><IconBrain size={20} className="me-2 text-purple" aria-hidden="true" />Motor de inteligência</h3><div className="text-secondary small mt-1">Configuração global usada pelos perfis que não possuem modelo ou prompt próprios.</div></div></div>
          <div className="card-body">
            <div className="row row-cards mb-3">
              <div className="col-sm-4"><div className="border rounded-3 p-3 h-100"><div className="text-secondary small">Estado</div><div className="fw-bold mt-1"><span className={`status-dot me-2 ${settings.aiEnabled ? "status-dot-animated bg-success" : "bg-secondary"}`} aria-hidden="true" />{settings.aiEnabled ? "IA ativa" : "IA pausada"}</div></div></div>
              <div className="col-sm-4"><div className="border rounded-3 p-3 h-100"><div className="text-secondary small">Credencial</div><div className="fw-bold mt-1"><IconShieldCheck size={17} className="me-1 text-success" aria-hidden="true" />{keyLabel}</div></div></div>
              <div className="col-sm-4"><div className="border rounded-3 p-3 h-100"><div className="text-secondary small">Memória</div><div className="fw-bold mt-1"><IconDatabase size={17} className="me-1 text-azure" aria-hidden="true" />{settings.memoryEnabled ? "Longo prazo ativa" : "Desativada"}</div></div></div>
            </div>

            <div className="alert alert-info small" role="note"><IconRobot size={18} className="me-2" aria-hidden="true" /><strong>Transparência obrigatória:</strong> os perfis são identificados como IA. O prompt individual não pode instruir o sistema a fingir que é humano.</div>
            <div className="alert alert-secondary small" role="note">Overrides individuais vinculados a outro provider são preservados, mas ficam ignorados enquanto não coincidirem com o provider global. O sistema usa o modelo global seguro e não apaga essas configurações.</div>
            {providerChangedWithoutNewKey && <div className="alert alert-warning small" role="alert">A credencial atual de {persistedProvider === "deepseek" ? "DeepSeek" : "OpenAI"} não será usada pelo novo provider. Confirme uma credencial para o provider escolhido no ambiente ou informe uma nova chave.</div>}

            <fieldset disabled={savingSettings} className="border-0 m-0 p-0">
              <div className="row g-3">
                <div className="col-md-3"><label className="form-check form-switch mt-4"><input className="form-check-input" type="checkbox" checked={settings.aiEnabled} onChange={(event) => setSettings({ ...settings, aiEnabled: event.target.checked })} /><span className="form-check-label">Ativar respostas por IA</span></label></div>
                <div className="col-md-3"><label className="form-label" htmlFor="ai-provider">Provedor</label><select id="ai-provider" className="form-select" value={settings.aiProvider} onChange={(event) => { const provider = event.target.value as Settings["aiProvider"]; setApiKey(""); setSettings({ ...settings, aiProvider: provider, aiModel: provider === "deepseek" ? "deepseek-chat" : "gpt-4o-mini" }); }}><option value="deepseek">DeepSeek</option><option value="openai">OpenAI</option></select></div>
                <div className="col-md-3"><label className="form-label" htmlFor="ai-model">Modelo global</label><input id="ai-model" className="form-control" maxLength={100} value={settings.aiModel} onChange={(event) => setSettings({ ...settings, aiModel: event.target.value })} placeholder="deepseek-chat" /></div>
                <div className="col-md-3"><label className="form-label" htmlFor="ai-key">Nova API key {settings.hasApiKey && <span className="badge bg-green-lt ms-1">configurada</span>}</label><input id="ai-key" className="form-control" type="password" autoComplete="new-password" placeholder={settings.hasApiKey ? "Deixe vazio para manter" : "Cole a chave"} value={apiKey} onChange={(event) => setApiKey(event.target.value)} /><div className="form-hint">Campo vazio mantém a configuração atual e não é enviado à API.</div></div>

                <div className="col-12"><label className="form-label" htmlFor="ai-prompt">Instrução global</label><textarea id="ai-prompt" className="form-control" rows={4} maxLength={PROMPT_MAX_LENGTH} value={settings.aiSystemPrompt} onChange={(event) => setSettings({ ...settings, aiSystemPrompt: event.target.value })} /><div className="form-hint d-flex justify-content-between"><span>Defina tom, objetivos e limites. Regras de identidade e segurança são aplicadas pela API.</span><span>{settings.aiSystemPrompt.length}/{PROMPT_MAX_LENGTH}</span></div></div>

                <div className="col-12"><hr /><div className="d-flex align-items-center gap-2 mb-1"><IconDatabase size={19} className="text-azure" aria-hidden="true" /><strong>Memória persistente</strong></div><div className="text-secondary small">A IA combina um resumo acumulado com as mensagens recentes; assim a conversa continua coerente mesmo após milhares de mensagens.</div></div>
                <div className="col-md-3"><label className="form-check form-switch mt-4"><input className="form-check-input" type="checkbox" checked={settings.memoryEnabled} onChange={(event) => setSettings({ ...settings, memoryEnabled: event.target.checked })} /><span className="form-check-label">Ativar globalmente</span></label></div>
                <div className="col-md-3"><label className="form-label" htmlFor="memory-refresh">Atualizar resumo a cada</label><div className="input-group"><input id="memory-refresh" type="number" min={2} max={100} step={1} className="form-control" value={settings.memoryRefreshMessages} onChange={(event) => setSettings({ ...settings, memoryRefreshMessages: Number(event.target.value) })} /><span className="input-group-text">mensagens</span></div></div>
                <div className="col-md-3"><label className="form-label" htmlFor="recent-limit">Janela recente</label><div className="input-group"><input id="recent-limit" type="number" min={4} max={100} step={1} className="form-control" value={settings.recentMessageLimit} onChange={(event) => setSettings({ ...settings, recentMessageLimit: Number(event.target.value) })} /><span className="input-group-text">mensagens</span></div></div>
                <div className="col-md-3"><label className="form-label" htmlFor="fallback">Resposta de emergência</label><input id="fallback" className="form-control" maxLength={FALLBACK_MAX_LENGTH} value={settings.fallbackText} onChange={(event) => setSettings({ ...settings, fallbackText: event.target.value })} /></div>

                <div className="col-md-3"><label className="form-label" htmlFor="reply-min">Atraso mínimo</label><div className="input-group"><input id="reply-min" type="number" min={0} max={60000} step={1} className="form-control" value={settings.replyMinMs} onChange={(event) => setSettings({ ...settings, replyMinMs: Number(event.target.value) })} /><span className="input-group-text">ms</span></div></div>
                <div className="col-md-3"><label className="form-label" htmlFor="reply-max">Atraso máximo</label><div className="input-group"><input id="reply-max" type="number" min={0} max={120000} step={1} className="form-control" value={settings.replyMaxMs} onChange={(event) => setSettings({ ...settings, replyMaxMs: Number(event.target.value) })} /><span className="input-group-text">ms</span></div></div>
              </div>
            </fieldset>

            <div className="d-flex flex-wrap gap-2 mt-4"><button type="button" className="btn btn-primary" disabled={savingSettings} aria-busy={savingSettings} onClick={() => void saveSettings()}><IconDeviceFloppy size={16} className="me-1" aria-hidden="true" />{savingSettings ? "Salvando..." : "Salvar configuração"}</button>{settings.apiKeySource === "database" && <button type="button" className="btn btn-ghost-danger" disabled={savingSettings} onClick={clearDatabaseKey}><IconKey size={16} className="me-1" aria-hidden="true" />Remover chave do banco</button>}</div>
          </div>
        </div>
      )}

      {rulesError && (
        <div className="alert alert-danger retry-state" role="alert">
          <span>Regras determinísticas: {rulesError}</span>
          <button type="button" className="btn btn-sm" disabled={loadingRules} onClick={() => void loadRules()}><IconRefresh size={16} className="me-1" aria-hidden="true" />Tentar novamente</button>
        </div>
      )}

      <div className="card" aria-busy={loadingRules}>
        <div className="card-header"><div><h3 className="card-title">Respostas determinísticas ({rules.length})</h3><div className="text-secondary small mt-1">Usadas quando a IA está desativada, indisponível ou não consegue responder.</div></div></div>
        <div className="table-responsive">
          <table className="table table-vcenter card-table">
            <caption className="visually-hidden">Regras determinísticas do chatbot</caption>
            <thead><tr><th>Categoria</th><th>Personalidade</th><th>Prioridade</th><th>Palavras-chave</th><th>Respostas</th><th>Ativa</th><th className="w-1"><span className="visually-hidden">Ações</span></th></tr></thead>
            <tbody>
              {loadingRules && rules.length === 0 && <tr><td colSpan={7} className="text-center text-secondary py-4" role="status"><span className="spinner-border spinner-border-sm me-2" aria-hidden="true" />Carregando regras...</td></tr>}
              {rules.map((rule) => <tr key={rule.id}><td className="fw-medium">{rule.category}</td><td><span className="badge bg-azure-lt">{PERSONALITY[rule.personality] || rule.personality}</span></td><td>{rule.priority}</td><td className="text-secondary">{rule.keywords.slice(0, 4).join(", ")}{rule.keywords.length > 4 ? ` +${rule.keywords.length - 4}` : ""}</td><td className="text-secondary">{rule.responses.length}</td><td><label className="form-check form-switch m-0" aria-label={`${rule.active ? "Desativar" : "Ativar"} ${rule.category}`}><input className="form-check-input" type="checkbox" checked={rule.active} disabled={Boolean(togglingRuleId)} onChange={() => void toggleActive(rule)} /></label></td><td><div className="d-flex gap-1 justify-content-end"><button type="button" className="btn btn-sm btn-icon" aria-label={`Editar ${rule.category}`} disabled={savingRule} onClick={() => openEdit(rule)}><IconEdit size={16} aria-hidden="true" /></button><button type="button" className="btn btn-sm btn-icon btn-ghost-danger" aria-label={`Excluir ${rule.category}`} disabled={savingRule} onClick={() => removeRule(rule)}><IconTrash size={16} aria-hidden="true" /></button></div></td></tr>)}
              {!loadingRules && !rulesError && rules.length === 0 && <tr><td colSpan={7} className="text-center text-secondary py-4">Nenhuma regra criada. A resposta de emergência continuará protegendo o fluxo.</td></tr>}
            </tbody>
          </table>
        </div>
      </div>

      {editing && (
        <>
          <div ref={ruleModalRef} className="modal modal-blur fade show d-block" tabIndex={-1} role="dialog" aria-modal="true" aria-labelledby="rule-modal-title">
            <div className="modal-dialog modal-lg modal-dialog-centered" role="document">
              <div className="modal-content">
                <div className="modal-header"><h5 className="modal-title" id="rule-modal-title">{editing.id ? "Editar regra" : "Nova regra"}</h5><button type="button" className="btn-close" aria-label="Fechar" disabled={savingRule} onClick={closeRuleModal} /></div>
                <div className="modal-body"><fieldset disabled={savingRule} className="border-0 m-0 p-0"><div className="row g-3">
                  <div className="col-md-5"><label className="form-label" htmlFor="rule-category">Categoria</label><input id="rule-category" className="form-control" data-modal-initial maxLength={60} value={editing.category} onChange={(event) => setEditing({ ...editing, category: event.target.value })} placeholder="ex.: saudacao" /></div>
                  <div className="col-md-4"><label className="form-label" htmlFor="rule-personality">Personalidade</label><select id="rule-personality" className="form-select" value={editing.personality} onChange={(event) => setEditing({ ...editing, personality: event.target.value })}>{Object.entries(PERSONALITY).map(([value, label]) => <option key={value} value={value}>{label}</option>)}</select></div>
                  <div className="col-md-3"><label className="form-label" htmlFor="rule-priority">Prioridade</label><input id="rule-priority" type="number" min={0} max={10} step={1} className="form-control" value={editing.priority} onChange={(event) => setEditing({ ...editing, priority: Number(event.target.value) })} /></div>
                  <div className="col-12"><label className="form-label" htmlFor="rule-keywords">Palavras-chave, separadas por vírgula (máximo 60 caracteres cada)</label><textarea id="rule-keywords" className="form-control" rows={2} value={keywords} onChange={(event) => setKeywords(event.target.value)} placeholder="oi, olá, bom dia" /></div>
                  <div className="col-12"><label className="form-label" htmlFor="rule-responses">Respostas, uma por linha (máximo 500 caracteres cada)</label><textarea id="rule-responses" className="form-control" rows={5} value={responses} onChange={(event) => setResponses(event.target.value)} placeholder={"Oi {name}! Tudo bem?\nOlá! Que bom falar com você 💛"} /><div className="form-hint">Variáveis disponíveis: {"{name}"}, {"{age}"} e {"{city}"}.</div></div>
                  <div className="col-12"><label className="form-check form-switch"><input className="form-check-input" type="checkbox" checked={editing.active} onChange={(event) => setEditing({ ...editing, active: event.target.checked })} /><span className="form-check-label">Regra ativa</span></label></div>
                </div></fieldset></div>
                <div className="modal-footer"><button type="button" className="btn" disabled={savingRule} onClick={closeRuleModal}>Cancelar</button><button type="button" className="btn btn-primary" disabled={savingRule} aria-busy={savingRule} onClick={() => void saveRule()}>{savingRule ? "Salvando..." : "Salvar regra"}</button></div>
              </div>
            </div>
          </div>
          <div className="modal-backdrop fade show" aria-hidden="true" onMouseDown={closeRuleModal} />
        </>
      )}

      <Dialog config={dialog} onClose={() => setDialog(null)} />
      <Toast toast={toast} onClose={() => setToast(null)} />
    </>
  );
}
