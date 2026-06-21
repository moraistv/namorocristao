import { useEffect, useState } from "react";
import { IconDeviceFloppy } from "@tabler/icons-react";
import { get, put } from "../api";
import { Toast, ToastMsg } from "../components/ui";

interface Settings {
  isChattingEnabledBeforeMatch: boolean;
  boostDurationMin: number;
  superLikeMessageEnabled: boolean;
  rewindPremiumOnly: boolean;
  incognitoPremiumOnly: boolean;
  dailyVerseEnabled: boolean;
  freeDailyLikes: number;
}

const EMPTY: Settings = {
  isChattingEnabledBeforeMatch: false,
  boostDurationMin: 30,
  superLikeMessageEnabled: true,
  rewindPremiumOnly: true,
  incognitoPremiumOnly: true,
  dailyVerseEnabled: true,
  freeDailyLikes: 0,
};

function Switch({ label, desc, checked, onChange }: { label: string; desc: string; checked: boolean; onChange: (v: boolean) => void }) {
  return (
    <label className="d-flex align-items-start p-2" style={{ cursor: "pointer" }}>
      <div className="flex-fill">
        <div className="fw-medium">{label}</div>
        <div className="text-secondary" style={{ fontSize: 12.5 }}>{desc}</div>
      </div>
      <span className="form-check form-switch m-0 ms-3">
        <input type="checkbox" className="form-check-input" checked={checked} onChange={(e) => onChange(e.target.checked)} />
      </span>
    </label>
  );
}

export default function Settings() {
  const [s, setS] = useState<Settings>(EMPTY);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [toast, setToast] = useState<ToastMsg | null>(null);

  useEffect(() => {
    get("/admin/settings")
      .then((r) => setS({ ...EMPTY, ...r.settings }))
      .catch((e) => setToast({ type: "error", text: e.message }))
      .finally(() => setLoading(false));
  }, []);

  function set<K extends keyof Settings>(k: K, v: Settings[K]) {
    setS((p) => ({ ...p, [k]: v }));
  }

  async function save() {
    setSaving(true);
    try {
      await put("/admin/settings", {
        isChattingEnabledBeforeMatch: s.isChattingEnabledBeforeMatch,
        boostDurationMin: Number(s.boostDurationMin) || 30,
        superLikeMessageEnabled: s.superLikeMessageEnabled,
        rewindPremiumOnly: s.rewindPremiumOnly,
        incognitoPremiumOnly: s.incognitoPremiumOnly,
        dailyVerseEnabled: s.dailyVerseEnabled,
        freeDailyLikes: Number(s.freeDailyLikes) || 0,
      });
      setToast({ type: "success", text: "Configurações salvas" });
    } catch (e: any) {
      setToast({ type: "error", text: e.message });
    } finally {
      setSaving(false);
    }
  }

  return (
    <>
      <div className="d-flex align-items-center justify-content-between mb-3">
        <div>
          <div className="page-pretitle">Sistema</div>
          <h2 className="page-title">Configurações</h2>
        </div>
        <button className="btn btn-primary" onClick={save} disabled={saving || loading}>
          <IconDeviceFloppy size={16} className="me-1" />{saving ? "Salvando..." : "Salvar"}
        </button>
      </div>

      {loading ? (
        <div className="text-secondary p-4">Carregando...</div>
      ) : (
        <div className="row row-cards">
          <div className="col-lg-7">
            <div className="card">
              <div className="card-header"><h3 className="card-title">Chat e descoberta</h3></div>
              <div className="card-body">
                <Switch
                  label="Conversa antes do match"
                  desc="Permite trocar mensagens sem ter dado match. Desligado, só após o match."
                  checked={s.isChattingEnabledBeforeMatch}
                  onChange={(v) => set("isChattingEnabledBeforeMatch", v)}
                />
                <div className="mt-2">
                  <label className="form-label">Curtidas grátis por dia (0 = ilimitado)</label>
                  <input className="form-control" type="number" min={0} style={{ maxWidth: 200 }}
                    value={s.freeDailyLikes} onChange={(e) => set("freeDailyLikes", Number(e.target.value))} />
                </div>
              </div>
            </div>

            <div className="card mt-3">
              <div className="card-header"><h3 className="card-title">Recursos premium</h3></div>
              <div className="card-body">
                <Switch
                  label="Super Like com recado"
                  desc="Permite enviar uma mensagem junto com o Super Like."
                  checked={s.superLikeMessageEnabled}
                  onChange={(v) => set("superLikeMessageEnabled", v)}
                />
                <Switch
                  label="Rewind só para VIP"
                  desc="Desfazer o último swipe é exclusivo de assinantes."
                  checked={s.rewindPremiumOnly}
                  onChange={(v) => set("rewindPremiumOnly", v)}
                />
                <Switch
                  label="Modo incógnito só para VIP"
                  desc="Navegar invisível é exclusivo de assinantes."
                  checked={s.incognitoPremiumOnly}
                  onChange={(v) => set("incognitoPremiumOnly", v)}
                />
                <div className="mt-2">
                  <label className="form-label">Duração do Boost/Turbo (minutos)</label>
                  <input className="form-control" type="number" min={1} style={{ maxWidth: 200 }}
                    value={s.boostDurationMin} onChange={(e) => set("boostDurationMin", Number(e.target.value))} />
                </div>
              </div>
            </div>
          </div>

          <div className="col-lg-5">
            <div className="card">
              <div className="card-header"><h3 className="card-title">Verso do dia</h3></div>
              <div className="card-body">
                <Switch
                  label="Mostrar verso do dia no app"
                  desc="Exibe um versículo na tela de descoberta, rotacionando por dia."
                  checked={s.dailyVerseEnabled}
                  onChange={(v) => set("dailyVerseEnabled", v)}
                />
                <div className="text-secondary mt-2" style={{ fontSize: 12.5 }}>
                  Cadastre os versículos na página <strong>Versos</strong> no menu. Se não houver nenhum, o app usa uma lista padrão embutida.
                </div>
              </div>
            </div>
          </div>
        </div>
      )}

      <Toast toast={toast} onClose={() => setToast(null)} />
    </>
  );
}
