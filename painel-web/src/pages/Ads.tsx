import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import {
  IconSpeakerphone, IconDeviceFloppy, IconWindowMaximize, IconLayoutNavbar,
  IconRectangle, IconGift, IconArticle, IconAppWindow, IconAdjustments,
} from "@tabler/icons-react";
import { get, put } from "../api";
import { Toast, ToastMsg } from "../components/ui";

interface AdSettings {
  enabled: boolean;
  testMode: boolean;
  testDeviceIds: string | null;
  appOpenEnabled: boolean;
  bannerEnabled: boolean;
  interstitialEnabled: boolean;
  rewardedEnabled: boolean;
  rewardedInterstitialEnabled: boolean;
  nativeEnabled: boolean;
  androidAppOpenId: string | null;
  androidBannerId: string | null;
  androidInterstitialId: string | null;
  androidRewardedId: string | null;
  androidRewardedInterstitialId: string | null;
  androidNativeId: string | null;
  bannerPosition: string;
  appOpenOnResume: boolean;
  appOpenEverySecs: number;
  interstitialEverySecs: number;
  interstitialEveryClicks: number;
  interstitialOnOpenChat: boolean;
  interstitialOnOpenProfile: boolean;
  interstitialOnSwipe: boolean;
  maxAdsPerSession: number;
  maxAdsPerDay: number;
  /** Vem do servidor (configurado em Recompensas); bloqueia a troca do bloco Premiado. */
  rewardsRequireSsv?: boolean;
}

const EMPTY: AdSettings = {
  enabled: false, testMode: true, testDeviceIds: "",
  appOpenEnabled: false, bannerEnabled: true, interstitialEnabled: true,
  rewardedEnabled: true, rewardedInterstitialEnabled: false, nativeEnabled: false,
  androidAppOpenId: "", androidBannerId: "", androidInterstitialId: "",
  androidRewardedId: "", androidRewardedInterstitialId: "", androidNativeId: "",
  bannerPosition: "bottom", appOpenOnResume: true, appOpenEverySecs: 0,
  interstitialEverySecs: 120, interstitialEveryClicks: 0,
  interstitialOnOpenChat: false, interstitialOnOpenProfile: false, interstitialOnSwipe: false,
  maxAdsPerSession: 0, maxAdsPerDay: 0,
};

/** Caminho de bloco do Google Ad Manager: /REDE/bloco (com ou sem pastas). */
const AD_MANAGER_UNIT = /^\/\d+(\/[^\s/]+)+$/;

const FORMATS: { key: keyof AdSettings; idKey: keyof AdSettings; label: string; icon: any; desc: string }[] = [
  { key: "appOpenEnabled", idKey: "androidAppOpenId", label: "App Open (abertura)", icon: IconAppWindow, desc: "Tela cheia ao abrir/retomar o app. O app ainda não exibe este formato." },
  { key: "bannerEnabled", idKey: "androidBannerId", label: "Banner", icon: IconLayoutNavbar, desc: "Faixa fixa no topo ou rodapé" },
  { key: "interstitialEnabled", idKey: "androidInterstitialId", label: "Intersticial", icon: IconWindowMaximize, desc: "Tela cheia entre ações" },
  { key: "rewardedEnabled", idKey: "androidRewardedId", label: "Premiado (rewarded)", icon: IconGift, desc: "Usado nas Recompensas: o usuário assiste e ganha Super Likes, Boosts, créditos ou VIP" },
  { key: "rewardedInterstitialEnabled", idKey: "androidRewardedInterstitialId", label: "Intersticial premiado", icon: IconRectangle, desc: "Intersticial com recompensa opcional. O app ainda não exibe este formato." },
  { key: "nativeEnabled", idKey: "androidNativeId", label: "Nativo (native)", icon: IconArticle, desc: "Anúncio integrado ao layout. O app ainda não exibe este formato." },
];

function Switch({ checked, onChange, label, desc }: { checked: boolean; onChange: (v: boolean) => void; label: string; desc?: string }) {
  return (
    <label className="d-flex align-items-center justify-content-between p-2" style={{ cursor: "pointer" }}>
      <span>
        <span className="d-block">{label}</span>
        {desc && <span className="text-secondary" style={{ fontSize: 12 }}>{desc}</span>}
      </span>
      <span className="form-check form-switch m-0 ms-2">
        <input type="checkbox" className="form-check-input" checked={checked} onChange={(e) => onChange(e.target.checked)} />
      </span>
    </label>
  );
}

export default function Ads() {
  const [a, setA] = useState<AdSettings>(EMPTY);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [toast, setToast] = useState<ToastMsg | null>(null);

  useEffect(() => {
    get("/admin/ads")
      .then((r) => setA({ ...EMPTY, ...r.ads }))
      .catch((e) => setToast({ type: "error", text: e.message }))
      .finally(() => setLoading(false));
  }, []);

  function set<K extends keyof AdSettings>(k: K, v: AdSettings[K]) {
    setA((s) => ({ ...s, [k]: v }));
  }

  async function save() {
    // O app usa o Google Ad Manager: cada bloco é um caminho /REDE/bloco
    // (um ID do AdMob ou o código do site não carregariam nada).
    const invalid = FORMATS.filter((f) => {
      const value = String(a[f.idKey] ?? "").trim();
      return value !== "" && !AD_MANAGER_UNIT.test(value);
    }).map((f) => f.label);
    if (invalid.length > 0) {
      setToast({
        type: "error",
        text: `Use o caminho do bloco do Google Ad Manager, que começa com / (ex.: /23340104016/mypair.app/namoro-android-banner), em: ${invalid.join(", ")}.`,
      });
      return;
    }
    setSaving(true);
    try {
      await put("/admin/ads", {
        ...a,
        appOpenEverySecs: Number(a.appOpenEverySecs) || 0,
        interstitialEverySecs: Number(a.interstitialEverySecs) || 0,
        interstitialEveryClicks: Number(a.interstitialEveryClicks) || 0,
        maxAdsPerSession: Number(a.maxAdsPerSession) || 0,
        maxAdsPerDay: Number(a.maxAdsPerDay) || 0,
        androidAppOpenId: a.androidAppOpenId || null,
        androidBannerId: a.androidBannerId || null,
        androidInterstitialId: a.androidInterstitialId || null,
        androidRewardedId: a.androidRewardedId || null,
        androidRewardedInterstitialId: a.androidRewardedInterstitialId || null,
        androidNativeId: a.androidNativeId || null,
        testDeviceIds: a.testDeviceIds || null,
      });
      setToast({ type: "success", text: "Configuração de anúncios salva" });
      // Recarrega só o que o servidor define: trocar o ID do Premiado zera a verificação do Google.
      void refreshServerFlags();
    } catch (e: any) {
      setToast({ type: "error", text: e.message });
      // Um 409 pode ser a trava do bloco Premiado (exigência ligada em outra aba): atualiza o estado do campo.
      if (e?.status === 409) void refreshServerFlags();
    }
    finally { setSaving(false); }
  }

  /** Atualiza só o que vem do servidor, preservando as edições ainda não salvas. */
  async function refreshServerFlags() {
    try {
      const r = await get("/admin/ads");
      const locked = Boolean(r.ads?.rewardsRequireSsv);
      setA((s) => ({
        ...s,
        rewardsRequireSsv: locked,
        // Travado: o campo volta ao ID salvo, senão mostraria bloqueado um valor que o servidor recusou.
        ...(locked ? { androidRewardedId: r.ads?.androidRewardedId ?? "" } : {}),
      }));
    } catch {
      // Sem a atualização, o servidor continua sendo quem valida.
    }
  }

  return (
    <>
      <div className="d-flex align-items-center justify-content-between mb-3">
        <div>
          <div className="page-pretitle">Monetização</div>
          <h2 className="page-title"><IconSpeakerphone size={22} className="me-2" />Anúncios (Google Ad Manager)</h2>
        </div>
        <button className="btn btn-primary" onClick={save} disabled={saving || loading}>
          <IconDeviceFloppy size={16} className="me-1" />{saving ? "Salvando..." : "Salvar tudo"}
        </button>
      </div>

      <div className="alert alert-info">
        O <strong>App ID do Google Ad Manager</strong> (<code>ca-app-pub-6101425731822799~7959031353</code>) fica fixo no app Android, como o SDK exige.
        Os blocos abaixo usam o caminho do Ad Manager (<code>/REDE/pasta/bloco</code>). Todo o resto é controlado aqui em tempo real e lido pelo app
        em <code>/api/config/ads</code>. Com o Modo teste ligado, o app usa os blocos de demonstração do Google no lugar destes.
      </div>

      {loading ? (
        <div className="text-secondary p-4">Carregando...</div>
      ) : (
        <>
          {/* Status geral + teste */}
          <div className="card mb-3">
            <div className="card-body">
              <div className="row align-items-center">
                <div className="col-md-4">
                  <label className="d-flex align-items-center justify-content-between p-2" style={{ cursor: "pointer", border: "1px solid var(--tblr-border-color)", borderRadius: 8 }}>
                    <span className="fw-bold">Anúncios ativados</span>
                    <span className="form-check form-switch m-0">
                      <input type="checkbox" className="form-check-input" checked={a.enabled} onChange={(e) => set("enabled", e.target.checked)} />
                    </span>
                  </label>
                </div>
                <div className="col-md-3">
                  <Switch checked={a.testMode} onChange={(v) => set("testMode", v)} label="Modo teste" desc="Usa os blocos de demonstração do Google (sem receita)" />
                </div>
                <div className="col-md-5">
                  <label className="form-label">IDs de dispositivos de teste (separados por vírgula)</label>
                  <input className="form-control" value={a.testDeviceIds || ""} onChange={(e) => set("testDeviceIds", e.target.value)} placeholder="ABC123, DEF456" />
                </div>
              </div>
            </div>
          </div>

          {/* Formatos + IDs */}
          <div className="card mb-3">
            <div className="card-header"><h3 className="card-title">Formatos e blocos (Ad Unit IDs — Android)</h3></div>
            <div className="table-responsive">
              <table className="table table-vcenter card-table">
                <thead><tr><th>Formato</th><th style={{ width: 90 }}>Ativo</th><th>Ad Unit ID</th></tr></thead>
                <tbody>
                  {FORMATS.map((f) => {
                    const Icon = f.icon;
                    // Com a confirmação do Google exigida, o servidor recusa trocar o ID do Premiado.
                    const locked = f.idKey === "androidRewardedId" && Boolean(a.rewardsRequireSsv);
                    const lockedId = `ad-id-locked-${f.idKey as string}`;
                    return (
                      <tr key={f.key as string}>
                        <td>
                          <div className="d-flex align-items-center">
                            <span className="avatar avatar-sm me-2" style={{ background: "rgba(17,29,64,.07)", color: "#111d40" }}><Icon size={18} /></span>
                            <div>
                              <div className="fw-medium">{f.label}</div>
                              <div className="text-secondary" style={{ fontSize: 12 }}>{f.desc}</div>
                            </div>
                          </div>
                        </td>
                        <td>
                          <label className="form-check form-switch m-0">
                            <input type="checkbox" className="form-check-input" checked={a[f.key] as boolean} onChange={(e) => set(f.key, e.target.checked as any)} />
                          </label>
                        </td>
                        <td>
                          <input
                            className="form-control"
                            aria-label={`Ad Unit ID: ${f.label}`}
                            value={(a[f.idKey] as string) || ""}
                            readOnly={locked}
                            aria-describedby={locked ? lockedId : undefined}
                            onChange={(e) => set(f.idKey, e.target.value as any)}
                            placeholder="/REDE/pasta/bloco (Google Ad Manager)"
                          />
                          {locked && (
                            <div id={lockedId} className="text-secondary mt-1" style={{ fontSize: 12 }}>
                              Bloqueado enquanto a confirmação do Google estiver exigida. Para trocar o ID, desligue a exigência em{" "}
                              <Link to="/recompensas">Recompensas</Link>.
                            </div>
                          )}
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
            <div className="card-footer text-secondary" style={{ fontSize: 13 }}>
              O que cada anúncio premiado concede (Super Likes, Boosts, créditos), os limites por dia e a verificação do
              Google ficam em <Link to="/recompensas">Recompensas</Link>. Trocar o ID do bloco Premiado zera essa
              verificação (último callback e ad_unit esperado), que precisa ser refeita com o bloco novo.
            </div>
          </div>

          <div className="row row-cards mb-3">
            {/* App Open */}
            <div className="col-lg-4">
              <div className="card h-100">
                <div className="card-header"><h3 className="card-title"><IconAppWindow size={18} className="me-2" />App Open</h3></div>
                <div className="card-body">
                  <Switch checked={a.appOpenOnResume} onChange={(v) => set("appOpenOnResume", v)} label="Exibir ao retomar o app" />
                  <div className="mt-2">
                    <label className="form-label">Mostrar no máximo a cada (segundos)</label>
                    <input className="form-control" type="number" min={0} value={a.appOpenEverySecs} onChange={(e) => set("appOpenEverySecs", Number(e.target.value))} />
                    <div className="text-secondary mt-1" style={{ fontSize: 12 }}>0 = sem limite de tempo.</div>
                  </div>
                </div>
              </div>
            </div>

            {/* Banner */}
            <div className="col-lg-4">
              <div className="card h-100">
                <div className="card-header"><h3 className="card-title"><IconLayoutNavbar size={18} className="me-2" />Banner</h3></div>
                <div className="card-body">
                  <label className="form-label">Posição</label>
                  <select className="form-select" value={a.bannerPosition} onChange={(e) => set("bannerPosition", e.target.value)}>
                    <option value="bottom">Rodapé (embaixo)</option>
                    <option value="top">Topo (em cima)</option>
                  </select>
                </div>
              </div>
            </div>

            {/* Caps */}
            <div className="col-lg-4">
              <div className="card h-100">
                <div className="card-header"><h3 className="card-title"><IconAdjustments size={18} className="me-2" />Limites globais</h3></div>
                <div className="card-body">
                  <label className="form-label">Máx. anúncios por sessão</label>
                  <input className="form-control mb-2" type="number" min={0} value={a.maxAdsPerSession} onChange={(e) => set("maxAdsPerSession", Number(e.target.value))} />
                  <label className="form-label">Máx. anúncios por dia</label>
                  <input className="form-control" type="number" min={0} value={a.maxAdsPerDay} onChange={(e) => set("maxAdsPerDay", Number(e.target.value))} />
                  <div className="text-secondary mt-1" style={{ fontSize: 12 }}>0 = ilimitado.</div>
                </div>
              </div>
            </div>
          </div>

          {/* Intersticial — gatilhos */}
          <div className="card mb-3">
            <div className="card-header"><h3 className="card-title"><IconWindowMaximize size={18} className="me-2" />Intersticial — quando exibir</h3></div>
            <div className="card-body">
              <div className="row">
                <div className="col-md-6">
                  <label className="form-label">Intervalo mínimo (segundos)</label>
                  <input className="form-control mb-3" type="number" min={0} value={a.interstitialEverySecs} onChange={(e) => set("interstitialEverySecs", Number(e.target.value))} />
                  <label className="form-label">A cada N cliques/ações</label>
                  <input className="form-control" type="number" min={0} value={a.interstitialEveryClicks} onChange={(e) => set("interstitialEveryClicks", Number(e.target.value))} />
                  <div className="text-secondary mt-1" style={{ fontSize: 12 }}>0 = não usar esse gatilho.</div>
                </div>
                <div className="col-md-6">
                  <Switch checked={a.interstitialOnOpenChat} onChange={(v) => set("interstitialOnOpenChat", v)} label="Ao abrir uma conversa" />
                  <Switch checked={a.interstitialOnOpenProfile} onChange={(v) => set("interstitialOnOpenProfile", v)} label="Ao abrir um perfil" />
                  <Switch checked={a.interstitialOnSwipe} onChange={(v) => set("interstitialOnSwipe", v)} label="Ao deslizar (swipe)" />
                </div>
              </div>
            </div>
          </div>
        </>
      )}

      <Toast toast={toast} onClose={() => setToast(null)} />
    </>
  );
}
