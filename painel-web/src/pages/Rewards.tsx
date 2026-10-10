import { FormEvent, useCallback, useEffect, useId, useRef, useState } from "react";
import { Link } from "react-router-dom";
import {
  IconAlertTriangle, IconAward, IconBolt, IconCheck, IconCoin, IconCopy,
  IconDeviceFloppy, IconInfoCircle, IconPencil, IconPlus, IconRefresh,
  IconSpeakerphone, IconStar, IconTrash,
} from "@tabler/icons-react";
import { API_BASE, del, get, post, put } from "../api";
import { Dialog, DialogConfig, Toast, ToastMsg } from "../components/ui";
import { useModalAccessibility } from "../components/useModalAccessibility";

type Kind = "SUPERLIKES" | "BOOSTS" | "CREDITS";

interface Reward {
  id: string;
  kind: Kind;
  title: string;
  description: string | null;
  amount: number;
  dailyLimit: number;
  cooldownSecs: number;
  active: boolean;
  sortOrder: number;
}

interface Overview {
  rewards: Reward[];
  settings: {
    rewardsRequireSsv: boolean;
    rewardsMaxPerDay: number;
    rewardsSsvAdUnit: string | null;
    ssvLastAt: string | null;
    ssvLastAdUnit: string | null;
    /** Só em memória no servidor: vale desde o último reinício da API. */
    ssvLastRejected: { at: string; reason: string; adUnit: string } | null;
  };
  ads: { enabled: boolean; rewardedEnabled: boolean; testMode: boolean; hasRewardedUnit: boolean };
  stats: {
    grantedToday: Record<Kind, { count: number; units: number }>;
    grantedWeek: number;
    grantedTotal: number;
    inProgress: number;
  };
}

const KINDS: Kind[] = ["SUPERLIKES", "BOOSTS", "CREDITS"];

const KIND_META: Record<Kind, { label: string; unit: string; icon: typeof IconStar; color: string; bg: string }> = {
  SUPERLIKES: { label: "Super Likes", unit: "Super Like(s)", icon: IconStar, color: "#4263eb", bg: "rgba(66,99,235,.15)" },
  BOOSTS: { label: "Boosts", unit: "Boost(s)", icon: IconBolt, color: "#ae3ec9", bg: "rgba(174,62,201,.15)" },
  CREDITS: { label: "Créditos (presentes)", unit: "crédito(s)", icon: IconCoin, color: "#2fb344", bg: "rgba(47,179,68,.15)" },
};

/** Converte o texto de um campo numérico; vazio ou não inteiro vira NaN (inválido). */
function intField(value: string): number {
  const text = value.trim();
  return text === "" ? Number.NaN : Number(text);
}

function waitText(secs: number): string {
  if (secs <= 0) return "sem espera entre anúncios";
  if (secs < 60) return `${secs}s de espera entre anúncios`;
  return `${Math.round(secs / 60)} min de espera entre anúncios`;
}

function limitText(limit: number): string {
  return limit > 0 ? `até ${limit} por dia` : "sem limite por dia";
}

// ─────────── Modal criar/editar recompensa ───────────
function RewardModal({ reward, onClose, onSaved }: {
  reward: Reward | null;
  onClose: () => void;
  onSaved: (message: string) => void;
}) {
  const titleId = useId();
  const [kind, setKind] = useState<Kind>(reward?.kind ?? "SUPERLIKES");
  const [title, setTitle] = useState(reward?.title ?? "");
  const [description, setDescription] = useState(reward?.description ?? "");
  const [amount, setAmount] = useState(String(reward?.amount ?? 1));
  const [dailyLimit, setDailyLimit] = useState(String(reward?.dailyLimit ?? 5));
  const [cooldownSecs, setCooldownSecs] = useState(String(reward?.cooldownSecs ?? 30));
  const [sortOrder, setSortOrder] = useState(String(reward?.sortOrder ?? 0));
  const [active, setActive] = useState(reward?.active ?? true);
  const [saving, setSaving] = useState(false);
  const [formError, setFormError] = useState("");

  const close = () => {
    if (!saving) onClose();
  };
  const dialogRef = useModalAccessibility({ open: true, onClose: close, canClose: !saving });

  async function submit(event: FormEvent) {
    event.preventDefault();
    if (saving) return;

    const payload = {
      kind,
      title: title.trim(),
      description: description.trim() || null,
      amount: intField(amount),
      dailyLimit: intField(dailyLimit),
      cooldownSecs: intField(cooldownSecs),
      sortOrder: intField(sortOrder),
      active,
    };

    if (!payload.title) return setFormError("Informe o título.");
    if (!Number.isInteger(payload.amount) || payload.amount < 1 || payload.amount > 100) {
      return setFormError("A quantidade por anúncio deve ser um número inteiro de 1 a 100.");
    }
    if (!Number.isInteger(payload.dailyLimit) || payload.dailyLimit < 0 || payload.dailyLimit > 100) {
      return setFormError("O limite por dia deve ser de 0 a 100 (0 = sem limite).");
    }
    if (!Number.isInteger(payload.cooldownSecs) || payload.cooldownSecs < 0 || payload.cooldownSecs > 3600) {
      return setFormError("A espera entre anúncios deve ser de 0 a 3600 segundos.");
    }
    if (!Number.isInteger(payload.sortOrder) || payload.sortOrder < -1000 || payload.sortOrder > 1000) {
      return setFormError("A ordem deve ser um número inteiro entre -1000 e 1000.");
    }

    setSaving(true);
    setFormError("");
    try {
      if (reward) await put(`/admin/rewards/${reward.id}`, payload);
      else await post("/admin/rewards", payload);
      onSaved(reward ? "Recompensa atualizada" : "Recompensa criada");
    } catch (error: unknown) {
      setFormError(error instanceof Error ? error.message : "Não foi possível salvar.");
      setSaving(false);
    }
  }

  return (
    <>
      <div
        ref={dialogRef}
        className="modal modal-blur fade show d-block"
        tabIndex={-1}
        role="dialog"
        aria-modal="true"
        aria-labelledby={titleId}
      >
        <div className="modal-dialog modal-dialog-centered modal-dialog-scrollable" role="document">
          <form className="modal-content" onSubmit={submit} noValidate>
            <div className="modal-header" style={{ background: "#111d40" }}>
              <h2 id={titleId} className="modal-title h5 text-white">
                {reward ? "Editar recompensa" : "Nova recompensa"}
              </h2>
              <button type="button" className="btn-close btn-close-white" aria-label="Fechar" disabled={saving} onClick={close} />
            </div>
            <div className="modal-body">
              <div className="mb-3">
                <label className="form-label" htmlFor="reward-kind">O que o usuário ganha</label>
                <select id="reward-kind" className="form-select" value={kind} onChange={(e) => setKind(e.target.value as Kind)}>
                  {KINDS.map((k) => <option key={k} value={k}>{KIND_META[k].label}</option>)}
                </select>
              </div>
              <div className="mb-3">
                <label className="form-label" htmlFor="reward-title">Título (aparece no app)</label>
                <input id="reward-title" className="form-control" value={title} maxLength={80} onChange={(e) => setTitle(e.target.value)} placeholder="Ex.: Super Likes grátis" data-modal-initial />
              </div>
              <div className="mb-3">
                <label className="form-label" htmlFor="reward-description">Descrição (opcional)</label>
                <input id="reward-description" className="form-control" value={description} maxLength={200} onChange={(e) => setDescription(e.target.value)} placeholder="Ex.: Chame a atenção de quem você gostou." />
              </div>
              <div className="row g-2 mb-3">
                <div className="col-12 col-sm-4">
                  <label className="form-label" htmlFor="reward-amount">Ganha por anúncio</label>
                  <input id="reward-amount" className="form-control" type="number" min={1} max={100} value={amount} onChange={(e) => setAmount(e.target.value)} />
                </div>
                <div className="col-12 col-sm-4">
                  <label className="form-label" htmlFor="reward-limit">Anúncios por dia</label>
                  <input id="reward-limit" className="form-control" type="number" min={0} max={100} value={dailyLimit} onChange={(e) => setDailyLimit(e.target.value)} />
                </div>
                <div className="col-12 col-sm-4">
                  <label className="form-label" htmlFor="reward-wait">Espera (segundos)</label>
                  <input id="reward-wait" className="form-control" type="number" min={0} max={3600} value={cooldownSecs} onChange={(e) => setCooldownSecs(e.target.value)} />
                </div>
              </div>
              <div className="text-secondary mb-3" style={{ fontSize: 12 }}>
                Limites valem por usuário. Anúncios por dia: 0 = sem limite. Espera: tempo mínimo entre dois anúncios desta recompensa.
              </div>
              <div className="row g-2 align-items-end">
                <div className="col-6">
                  <label className="form-label" htmlFor="reward-order">Ordem de exibição</label>
                  <input id="reward-order" className="form-control" type="number" value={sortOrder} onChange={(e) => setSortOrder(e.target.value)} />
                </div>
                <div className="col-6">
                  <label className="form-check mt-3">
                    <input type="checkbox" className="form-check-input" checked={active} onChange={(e) => setActive(e.target.checked)} />
                    <span className="form-check-label">Ativa no app</span>
                  </label>
                </div>
              </div>
              {formError && <div className="alert alert-danger mt-3 mb-0 py-2" role="alert">{formError}</div>}
            </div>
            <div className="modal-footer">
              <button type="button" className="btn" disabled={saving} onClick={close}>Cancelar</button>
              <button type="submit" className="btn btn-primary" disabled={saving} aria-busy={saving}>
                <IconDeviceFloppy size={16} className="me-1" aria-hidden="true" />{saving ? "Salvando..." : "Salvar"}
              </button>
            </div>
          </form>
        </div>
      </div>
      <div className="modal-backdrop fade show" aria-hidden="true" onMouseDown={close} />
    </>
  );
}

type Tone = "ok" | "warn" | "info";

const TONE_META: Record<Tone, { color: string; icon: typeof IconCheck; hidden: string }> = {
  ok: { color: "#2fb344", icon: IconCheck, hidden: " (ok)" },
  warn: { color: "#d63939", icon: IconAlertTriangle, hidden: " (pendente)" },
  info: { color: "#667382", icon: IconInfoCircle, hidden: " (informação)" },
};

function StatusLine({ tone, children }: { tone: Tone; children: string }) {
  const meta = TONE_META[tone];
  const Icon = meta.icon;
  return (
    <li className="d-flex align-items-center mb-1" style={{ color: meta.color }}>
      <Icon size={16} className="me-2" aria-hidden="true" />
      <span className="text-body">{children}</span>
      <span className="visually-hidden">{meta.hidden}</span>
    </li>
  );
}

export default function Rewards() {
  const [data, setData] = useState<Overview | null>(null);
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState("");
  const [modal, setModal] = useState<{ reward: Reward | null } | null>(null);
  const [dialog, setDialog] = useState<DialogConfig | null>(null);
  const [toast, setToast] = useState<ToastMsg | null>(null);

  const [requireSsv, setRequireSsv] = useState(false);
  const [maxPerDay, setMaxPerDay] = useState("0");
  const [ssvAdUnit, setSsvAdUnit] = useState("");
  const [savingSettings, setSavingSettings] = useState(false);
  const [copied, setCopied] = useState(false);
  const requestRef = useRef(0);
  /** Últimos valores dos campos de segurança vindos do servidor (base para saber o que o admin editou). */
  const syncedRef = useRef<{ requireSsv: boolean; maxPerDay: string; ssvAdUnit: string } | null>(null);

  const ssvUrl = `${API_BASE}/ads/ssv`;

  /**
   * `syncSettings` recarrega também os campos de segurança (descarta edições não
   * salvas). Sem ele, só atualiza os campos que o admin não editou.
   */
  const load = useCallback(async (syncSettings = false) => {
    const request = ++requestRef.current;
    setLoading(true);
    setLoadError("");
    try {
      const overview = await get<Overview>("/admin/rewards");
      if (request !== requestRef.current) return;
      setData(overview);
      const next = {
        requireSsv: overview.settings.rewardsRequireSsv,
        maxPerDay: String(overview.settings.rewardsMaxPerDay),
        ssvAdUnit: overview.settings.rewardsSsvAdUnit ?? "",
      };
      const previous = syncedRef.current;
      if (syncSettings || previous === null) {
        setRequireSsv(next.requireSsv);
        setMaxPerDay(next.maxPerDay);
        setSsvAdUnit(next.ssvAdUnit);
      } else {
        // Só troca o que o admin não editou desde a última sincronização, para um
        // formulário antigo não regravar valores que mudaram no servidor (ex.: o
        // ad_unit esperado zerado pela troca do bloco Premiado).
        setRequireSsv((current) => (current === previous.requireSsv ? next.requireSsv : current));
        setMaxPerDay((current) => (current === previous.maxPerDay ? next.maxPerDay : current));
        setSsvAdUnit((current) => (current === previous.ssvAdUnit ? next.ssvAdUnit : current));
      }
      syncedRef.current = next;
    } catch (error: unknown) {
      if (request !== requestRef.current) return;
      setLoadError(error instanceof Error ? error.message : "Não foi possível carregar.");
    } finally {
      if (request === requestRef.current) setLoading(false);
    }
  }, []);

  useEffect(() => {
    void load(true);
    return () => { requestRef.current += 1; };
  }, [load]);

  async function toggleActive(reward: Reward) {
    try {
      await put(`/admin/rewards/${reward.id}`, { active: !reward.active });
      await load();
    } catch (error: unknown) {
      setToast({ type: "error", text: error instanceof Error ? error.message : "Falha ao atualizar." });
    }
  }

  function remove(reward: Reward) {
    setDialog({
      title: "Excluir recompensa",
      message: `Remover "${reward.title}"? Só é possível excluir recompensas que nunca foram resgatadas. Para tirar uma recompensa com histórico do app, desative-a.`,
      icon: IconTrash,
      danger: true,
      confirmText: "Excluir",
      onConfirm: async () => {
        await del(`/admin/rewards/${reward.id}`);
        await load();
        setToast({ type: "success", text: "Recompensa removida" });
      },
    });
  }

  async function saveSettings() {
    const cap = intField(maxPerDay);
    if (!Number.isInteger(cap) || cap < 0 || cap > 1000) {
      setToast({ type: "error", text: "O teto por dia deve ser um número inteiro de 0 a 1000." });
      return;
    }
    setSavingSettings(true);
    try {
      await put("/admin/reward-settings", {
        rewardsRequireSsv: requireSsv,
        rewardsMaxPerDay: cap,
        rewardsSsvAdUnit: ssvAdUnit.trim() || null,
      });
      setToast({ type: "success", text: "Configuração salva" });
      await load(true);
    } catch (error: unknown) {
      setToast({ type: "error", text: error instanceof Error ? error.message : "Falha ao salvar." });
    } finally {
      setSavingSettings(false);
    }
  }

  /** Preencher com o ad_unit do último callback exige confirmar que ele é do bloco do admin. */
  function confirmLastAdUnit() {
    const last = data?.settings.ssvLastAdUnit;
    if (!last) return;
    const when = data?.settings.ssvLastAt
      ? new Date(data.settings.ssvLastAt).toLocaleString("pt-BR")
      : "horário desconhecido";
    setDialog({
      title: "Usar este ad_unit?",
      message: `O último callback aceito veio do ad_unit "${last}" em ${when}. Confira se esse horário é o do SEU teste agora e se o ad_unit é o do seu bloco Premiado no Google Ad Manager. Se for de outro bloco, os usuários deixam de receber as recompensas quando a exigência estiver ligada.`,
      icon: IconAlertTriangle,
      confirmText: "É o meu bloco",
      onConfirm: () => setSsvAdUnit(last),
    });
  }

  async function copyUrl() {
    try {
      await navigator.clipboard.writeText(ssvUrl);
      setCopied(true);
      window.setTimeout(() => setCopied(false), 2500);
    } catch {
      setToast({ type: "error", text: "Não foi possível copiar. Selecione a URL e copie manualmente." });
    }
  }

  const ads = data?.ads;
  const stats = data?.stats;
  const savedSsv = data?.settings.rewardsRequireSsv ?? false;
  const savedAdUnit = data?.settings.rewardsSsvAdUnit ?? "";
  const lastAdUnit = data?.settings.ssvLastAdUnit ?? null;
  const rejected = data?.settings.ssvLastRejected ?? null;
  const adUnitText = ssvAdUnit.trim();
  const settingsChanged =
    data !== null &&
    (requireSsv !== savedSsv ||
      maxPerDay !== String(data.settings.rewardsMaxPerDay) ||
      adUnitText !== savedAdUnit);

  // O que falta para salvar com a exigência ligada. O servidor confere as mesmas
  // condições; aqui só evitamos oferecer um botão que falharia.
  const ssvMissing: string[] = [];
  if (data && ads) {
    if (!savedSsv) {
      if (ads.testMode) ssvMissing.push("desligar o Modo teste");
      if (!ads.enabled || !ads.rewardedEnabled) ssvMissing.push("ligar os anúncios e o formato Premiado");
      if (!ads.hasRewardedUnit) ssvMissing.push("informar o ID do bloco Premiado");
      if (!data.settings.ssvLastAt) ssvMissing.push("receber um callback do Google");
    }
    if (!adUnitText) {
      ssvMissing.push("informar o ad_unit esperado");
    } else if ((!savedSsv || adUnitText !== savedAdUnit) && adUnitText !== lastAdUnit) {
      ssvMissing.push("usar como ad_unit esperado o do último callback recebido");
    }
  }
  const canEnableSsv = ssvMissing.length === 0;
  const ssvBlocksSave = requireSsv && !canEnableSsv;
  const totalToday = stats ? KINDS.reduce((sum, k) => sum + stats.grantedToday[k].count, 0) : 0;
  const activeCount = data ? data.rewards.filter((r) => r.active).length : 0;

  return (
    <>
      <div className="d-flex align-items-center justify-content-between flex-wrap gap-2 mb-3">
        <div>
          <div className="page-pretitle">Monetização</div>
          <h1 className="page-title h2"><IconAward size={22} className="me-2" aria-hidden="true" />Recompensas por anúncio</h1>
        </div>
        <div className="d-flex align-items-center gap-2">
          {data && <span className="text-secondary">{activeCount}/{data.rewards.length} ativas</span>}
          <button type="button" className="btn" disabled={loading} aria-busy={loading} onClick={() => void load()}>
            <IconRefresh size={16} className="me-1" aria-hidden="true" />Atualizar
          </button>
          <button type="button" className="btn btn-primary" disabled={loading || !data} onClick={() => setModal({ reward: null })}>
            <IconPlus size={16} className="me-1" aria-hidden="true" />Nova recompensa
          </button>
        </div>
      </div>

      <div className="alert alert-info">
        O app não vende mais nada. O usuário assiste a um <strong>anúncio premiado</strong> e ganha Super Likes, Boosts ou
        créditos para presentes, conforme as recompensas abaixo. O bloco de anúncio é configurado em{" "}
        <Link to="/anuncios">Anúncios</Link>.
      </div>

      {loadError && (
        <div className="alert alert-danger retry-state" role="alert">
          <span>{loadError}</span>
          <button type="button" className="btn btn-sm" disabled={loading} onClick={() => void load(!data)}>
            <IconRefresh size={16} className="me-1" aria-hidden="true" />Tentar novamente
          </button>
        </div>
      )}

      {loading && !data && <div className="text-secondary p-4" role="status">Carregando...</div>}

      {data && ads && stats && (
        <>
          <div className="row row-cards mb-3">
            {/* Situação dos anúncios premiados */}
            <div className="col-lg-5">
              <div className="card h-100">
                <div className="card-header">
                  <h2 className="card-title h3"><IconSpeakerphone size={18} className="me-2" aria-hidden="true" />Situação dos anúncios</h2>
                </div>
                <div className="card-body">
                  <ul className="list-unstyled mb-3">
                    <StatusLine tone={ads.enabled ? "ok" : "warn"}>Anúncios ativados</StatusLine>
                    <StatusLine tone={ads.rewardedEnabled ? "ok" : "warn"}>Formato Premiado ligado</StatusLine>
                    <StatusLine tone={ads.hasRewardedUnit || ads.testMode ? "ok" : "warn"}>
                      {ads.hasRewardedUnit
                        ? "ID do bloco Premiado preenchido"
                        : ads.testMode
                          ? "Sem ID do bloco (usando o bloco de demonstração do Google)"
                          : "ID do bloco Premiado não preenchido"}
                    </StatusLine>
                    {savedSsv ? (
                      <StatusLine tone={ads.testMode ? "warn" : "ok"}>
                        {ads.testMode
                          ? "Confirmação do Google exigida, mas suspensa pelo Modo teste"
                          : "Confirmação do Google exigida (SSV)"}
                      </StatusLine>
                    ) : (
                      <StatusLine tone="info">
                        Confirmação do Google dispensada: o app confirma, com os limites do servidor
                      </StatusLine>
                    )}
                  </ul>
                  {ads.testMode && (
                    <div className="alert alert-warning py-2 mb-3" role="note">
                      Modo teste ligado: o app mostra anúncios de demonstração, sem receita. Desligue em Anúncios antes de publicar.
                    </div>
                  )}
                  {!(ads.enabled && ads.rewardedEnabled && (ads.hasRewardedUnit || ads.testMode)) ? (
                    <div className="text-secondary" style={{ fontSize: 13 }}>
                      Enquanto houver pendências, o app mostra “Recompensas indisponíveis”.{" "}
                      <Link to="/anuncios">Ajustar em Anúncios</Link>
                    </div>
                  ) : (
                    <div className="text-secondary" style={{ fontSize: 13 }}>
                      Tudo pronto: as recompensas ativas aparecem para os usuários.
                    </div>
                  )}
                </div>
              </div>
            </div>

            {/* Números */}
            <div className="col-lg-7">
              <div className="card h-100">
                <div className="card-header"><h2 className="card-title h3">Resgates</h2></div>
                <div className="card-body">
                  <div className="row g-3">
                    <div className="col-6 col-md-3">
                      <div className="text-secondary" style={{ fontSize: 12 }}>Hoje</div>
                      <div className="h2 mb-0">{totalToday}</div>
                    </div>
                    <div className="col-6 col-md-3">
                      <div className="text-secondary" style={{ fontSize: 12 }}>Últimos 7 dias</div>
                      <div className="h2 mb-0">{stats.grantedWeek}</div>
                    </div>
                    <div className="col-6 col-md-3">
                      <div className="text-secondary" style={{ fontSize: 12 }}>Total</div>
                      <div className="h2 mb-0">{stats.grantedTotal}</div>
                    </div>
                    <div className="col-6 col-md-3">
                      <div className="text-secondary" style={{ fontSize: 12 }}>Em andamento</div>
                      <div className="h2 mb-0">{stats.inProgress}</div>
                    </div>
                  </div>
                  <hr className="my-3" />
                  <div className="text-secondary mb-1" style={{ fontSize: 12 }}>Concedido hoje</div>
                  <div className="d-flex flex-wrap gap-3">
                    {KINDS.map((k) => {
                      const meta = KIND_META[k];
                      const Icon = meta.icon;
                      const today = stats.grantedToday[k];
                      return (
                        <span key={k} className="d-inline-flex align-items-center">
                          <span className="avatar avatar-xs me-2" style={{ background: meta.bg, color: meta.color }} aria-hidden="true"><Icon size={14} /></span>
                          <span><strong>{today.units}</strong> {meta.unit} <span className="text-secondary">({today.count} anúncios)</span></span>
                        </span>
                      );
                    })}
                  </div>
                </div>
              </div>
            </div>
          </div>

          {/* Recompensas */}
          <div className="card mb-3">
            <div className="card-header"><h2 className="card-title h3">Recompensas ({data.rewards.length})</h2></div>
            <div className="card-body">
              {data.rewards.length === 0 ? (
                <div className="text-center text-secondary py-4">
                  Nenhuma recompensa. Clique em <strong>Nova recompensa</strong>.
                </div>
              ) : (
                <div className="row g-3">
                  {data.rewards.map((reward) => {
                    const meta = KIND_META[reward.kind];
                    const Icon = meta.icon;
                    return (
                      <div className="col-md-6 col-xl-4" key={reward.id}>
                        <div className="card card-sm h-100" style={{ border: "1px solid var(--tblr-border-color)", opacity: reward.active ? 1 : 0.6 }}>
                          <div className="card-body d-flex flex-column">
                            <div className="d-flex align-items-start">
                              <span className="avatar me-3" style={{ background: meta.bg, color: meta.color }} aria-hidden="true"><Icon size={20} /></span>
                              <div className="flex-fill">
                                <div className="fw-bold">{reward.title}</div>
                                <div style={{ color: meta.color, fontWeight: 600 }}>+{reward.amount} {meta.unit} por anúncio</div>
                              </div>
                            </div>
                            {reward.description && <div className="text-secondary mt-2" style={{ fontSize: 13 }}>{reward.description}</div>}
                            <div className="text-secondary mt-2" style={{ fontSize: 12 }}>
                              {limitText(reward.dailyLimit)} · {waitText(reward.cooldownSecs)}
                            </div>
                            <div className="d-flex align-items-center mt-auto pt-2" style={{ borderTop: "1px solid var(--tblr-border-color)" }}>
                              <label className="form-check form-switch m-0">
                                <input type="checkbox" className="form-check-input" checked={reward.active} onChange={() => void toggleActive(reward)} aria-label={`${reward.title}: ${reward.active ? "ativa" : "inativa"}`} />
                                <span className="form-check-label" style={{ fontSize: 12 }}>{reward.active ? "Ativa" : "Inativa"}</span>
                              </label>
                              <div className="ms-auto d-flex gap-1">
                                <button type="button" className="btn btn-sm btn-icon" aria-label={`Editar ${reward.title}`} title="Editar" onClick={() => setModal({ reward })}><IconPencil size={15} aria-hidden="true" /></button>
                                <button type="button" className="btn btn-sm btn-icon" aria-label={`Excluir ${reward.title}`} title="Excluir" onClick={() => remove(reward)}><IconTrash size={15} aria-hidden="true" /></button>
                              </div>
                            </div>
                          </div>
                        </div>
                      </div>
                    );
                  })}
                </div>
              )}
            </div>
          </div>

          {/* Segurança e limites */}
          <div className="card mb-3">
            <div className="card-header"><h2 className="card-title h3">Segurança e limites</h2></div>
            <div className="card-body">
              <div className="row g-4">
                <div className="col-lg-6">
                  <label className="form-label" htmlFor="rewards-max-day">Teto de recompensas por usuário, por dia</label>
                  <input id="rewards-max-day" className="form-control" style={{ maxWidth: 200 }} type="number" min={0} max={1000} value={maxPerDay} onChange={(e) => setMaxPerDay(e.target.value)} />
                  <div className="text-secondary mt-1" style={{ fontSize: 12 }}>
                    Soma de todas as recompensas. 0 = sem teto (valem só os limites de cada recompensa).
                  </div>

                  <label className="form-check form-switch mt-4">
                    <input
                      type="checkbox"
                      className="form-check-input"
                      checked={requireSsv}
                      disabled={!requireSsv && !canEnableSsv}
                      aria-describedby="rewards-ssv-help"
                      onChange={(e) => setRequireSsv(e.target.checked)}
                    />
                    <span className="form-check-label fw-medium">Exigir confirmação do Google (SSV)</span>
                  </label>
                  <div id="rewards-ssv-help" className="text-secondary mt-1" style={{ fontSize: 12 }}>
                    Ligado: a recompensa só é creditada quando o Google confirma que o anúncio foi visto até o fim (mais seguro
                    contra fraude, pode levar alguns segundos). Desligado: o app confirma sozinho, com os limites do servidor.
                    {!canEnableSsv && (
                      <> <strong>{requireSsv ? "Para salvar assim, falta:" : "Para ligar, falta:"}</strong> {ssvMissing.join("; ")}.</>
                    )}
                    {requireSsv && ads.testMode && (
                      <> <strong>Com o Modo teste ligado esta exigência fica suspensa</strong> (o bloco de demonstração não chama a URL).</>
                    )}
                    {savedSsv && (
                      <> Com a exigência ligada, o ID do bloco Premiado fica bloqueado em Anúncios.</>
                    )}
                  </div>
                </div>

                <div className="col-lg-6">
                  <label className="form-label" htmlFor="rewards-ssv-url">URL do callback (SSV)</label>
                  <div className="input-group">
                    <input id="rewards-ssv-url" className="form-control" value={ssvUrl} readOnly onFocus={(e) => e.currentTarget.select()} />
                    <button type="button" className="btn" onClick={() => void copyUrl()} aria-label="Copiar URL do callback">
                      {copied ? <IconCheck size={16} aria-hidden="true" /> : <IconCopy size={16} aria-hidden="true" />}
                    </button>
                  </div>
                  <div className="text-secondary mt-1" style={{ fontSize: 12 }}>
                    Cole esta URL na verificação no servidor (SSV) do bloco Premiado no Google Ad Manager. O Google só chama
                    endereços públicos com HTTPS.
                  </div>
                  {!ssvUrl.startsWith("https://") && (
                    <div className="alert alert-warning py-2 mt-2 mb-0" role="note">
                      Esta URL não é HTTPS (provavelmente ambiente local). Em produção ela será https://.
                    </div>
                  )}

                  <label className="form-label mt-3" htmlFor="rewards-ssv-adunit">Bloco esperado no callback (ad_unit)</label>
                  <div className="input-group">
                    <input id="rewards-ssv-adunit" className="form-control" value={ssvAdUnit} maxLength={120} onChange={(e) => setSsvAdUnit(e.target.value)} placeholder="Copie do último callback recebido" />
                    <button
                      type="button"
                      className="btn"
                      disabled={!lastAdUnit}
                      onClick={confirmLastAdUnit}
                    >
                      Usar o último
                    </button>
                  </div>
                  <div className="text-secondary mt-1" style={{ fontSize: 12 }}>
                    O Google assina callbacks de qualquer conta, então só vale o que vier do bloco informado aqui. Enquanto
                    este campo estiver preenchido, callbacks de outro ad_unit são ignorados, mesmo com a exigência desligada.
                  </div>
                  <div className="text-secondary mt-1" style={{ fontSize: 12 }}>
                    Para descobrir o valor ou trocar de bloco: com a exigência desligada, deixe o campo vazio e salve, cole a
                    URL no Ad Manager, desligue o Modo teste, assista você mesmo a um anúncio premiado no app e toque em{" "}
                    <strong>Atualizar</strong>. Confira se o ad_unit do último callback é do seu bloco, use-o e salve.
                  </div>
                  {/* Região viva: quem usa leitor de tela ouve o resultado de "Atualizar". */}
                  <div className="text-secondary mt-1" style={{ fontSize: 12 }} role="status">
                    {data.settings.ssvLastAt ? (
                      <>Último callback aceito: <strong>{new Date(data.settings.ssvLastAt).toLocaleString("pt-BR")}</strong>
                        {lastAdUnit ? <> (ad_unit <code>{lastAdUnit}</code>)</> : null}.</>
                    ) : (
                      <>Nenhum callback aceito ainda.</>
                    )}
                    {rejected && (!data.settings.ssvLastAt || new Date(rejected.at) > new Date(data.settings.ssvLastAt)) && (
                      <> Último callback recusado em <strong>{new Date(rejected.at).toLocaleString("pt-BR")}</strong>.</>
                    )}
                  </div>
                  {lastAdUnit && savedAdUnit && lastAdUnit !== savedAdUnit && (
                    <div className="alert alert-warning py-2 mt-2 mb-0" role="note">
                      O último callback aceito veio de <code>{lastAdUnit}</code>, diferente do esperado salvo (<code>{savedAdUnit}</code>).
                      Callbacks de outro ad_unit são ignorados: confira se o valor esperado está certo.
                    </div>
                  )}
                  {rejected && (!data.settings.ssvLastAt || new Date(rejected.at) > new Date(data.settings.ssvLastAt)) && (
                    <div className="alert alert-warning py-2 mt-2 mb-0" role="note">
                      Chegou um callback assinado pelo Google em <strong>{new Date(rejected.at).toLocaleString("pt-BR")}</strong>, mas
                      foi recusado: {rejected.reason}
                      {rejected.adUnit ? <> (ad_unit <code>{rejected.adUnit}</code>)</> : null}. Pode ser o teste que o Google
                      envia ao salvar a URL ou o anúncio de outra conta. Este aviso vale desde o último reinício do servidor.
                    </div>
                  )}
                </div>
              </div>
            </div>
            <div className="card-footer text-end">
              {/* aria-disabled (e não disabled) quando a exigência ficaria inválida: o botão
                  continua focável e o leitor de tela anuncia o motivo em rewards-ssv-help. */}
              <button
                type="button"
                className={`btn btn-primary${ssvBlocksSave ? " disabled" : ""}`}
                disabled={savingSettings || !settingsChanged}
                aria-disabled={ssvBlocksSave || undefined}
                aria-busy={savingSettings}
                aria-describedby={ssvBlocksSave ? "rewards-ssv-help" : undefined}
                onClick={() => {
                  if (ssvBlocksSave) {
                    // Teclado (Enter/Espaço) chega aqui: diz o motivo em vez de não fazer nada.
                    setToast({ type: "error", text: `Não dá para salvar assim. Falta: ${ssvMissing.join("; ")}.` });
                    return;
                  }
                  void saveSettings();
                }}
              >
                <IconDeviceFloppy size={16} className="me-1" aria-hidden="true" />{savingSettings ? "Salvando..." : "Salvar"}
              </button>
            </div>
          </div>
        </>
      )}

      {modal && (
        <RewardModal
          reward={modal.reward}
          onClose={() => setModal(null)}
          onSaved={(message) => {
            setModal(null);
            setToast({ type: "success", text: message });
            void load();
          }}
        />
      )}
      <Dialog config={dialog} onClose={() => setDialog(null)} />
      <Toast toast={toast} onClose={() => setToast(null)} />
    </>
  );
}
