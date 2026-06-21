import { useCallback, useEffect, useState } from "react";
import { useNavigate, useParams } from "react-router-dom";
import {
  IconArrowLeft, IconFlag, IconBan, IconClockPause, IconCheck, IconX,
  IconHeart, IconMessage, IconUserCircle, IconArrowRight, IconAlertTriangle,
  IconShieldCheck,
} from "@tabler/icons-react";
import { API_BASE, get, post, del } from "../api";
import { Dialog, DialogConfig, Toast, ToastMsg } from "../components/ui";

const SERVER_ORIGIN = API_BASE.replace(/\/api$/, "");
const img = (s?: string | null) => (!s ? "" : s.startsWith("http") ? s : `${SERVER_ORIGIN}${s.startsWith("/") ? "" : "/"}${s}`);
const dt = (s?: string | null) => (s ? new Date(s).toLocaleString("pt-BR") : "—");
const dia = (s?: string | null) => (s ? new Date(s).toLocaleDateString("pt-BR") : "—");
const GENDER_PT: Record<string, string> = { MALE: "Masculino", FEMALE: "Feminino", OTHER: "Outro" };

const STATUS: Record<string, { label: string; cls: string }> = {
  PENDING: { label: "Pendente", cls: "bg-yellow-lt" },
  REVIEWED: { label: "Revisado", cls: "bg-green-lt" },
  DISMISSED: { label: "Descartado", cls: "bg-secondary-lt" },
};

function PersonCard({ title, person, onOpen }: { title: string; person: any; onOpen: () => void }) {
  if (!person?.exists) {
    return (
      <div className="card h-100">
        <div className="card-header"><h3 className="card-title">{title}</h3></div>
        <div className="card-body text-secondary">Usuário não encontrado (conta removida).</div>
      </div>
    );
  }
  return (
    <div className="card h-100">
      <div className="card-header"><h3 className="card-title">{title}</h3></div>
      <div className="card-body">
        <div className="d-flex align-items-center mb-3">
          <span
            className="avatar avatar-lg me-3"
            style={person.profilePicture ? { backgroundImage: `url(${img(person.profilePicture)})` } : { background: "linear-gradient(135deg,#e9c75a,#d4af37)", color: "#111d40", fontWeight: 700 }}
          >
            {!person.profilePicture && (person.fullName?.charAt(0) ?? "?")}
          </span>
          <div className="flex-fill">
            <div className="fw-bold" style={{ fontSize: 16 }}>{person.fullName}</div>
            <div className="text-secondary" style={{ fontSize: 13 }}>{person.email}</div>
          </div>
        </div>
        <div className="d-flex flex-wrap gap-2 mb-3">
          {person.isVerified && <span className="badge bg-green-lt">Verificado</span>}
          {person.isOnline ? <span className="badge bg-green-lt">Online</span> : <span className="badge bg-secondary-lt">Offline</span>}
          {person.isPremium && <span className="badge bg-yellow-lt">VIP</span>}
          {person.isSuspended && <span className="badge bg-orange-lt">Suspenso</span>}
          {person.isBanned && <span className="badge bg-red-lt">Banido</span>}
        </div>
        <div className="text-secondary" style={{ fontSize: 13 }}>
          {GENDER_PT[person.gender] ?? person.gender ?? "—"}{person.age ? `, ${person.age}` : ""} · {person.city || "cidade não informada"}
        </div>
        <button className="btn btn-primary w-100 mt-3" onClick={onOpen}>
          <IconUserCircle size={16} className="me-1" />Abrir perfil completo<IconArrowRight size={16} className="ms-1" />
        </button>
      </div>
    </div>
  );
}

export default function ReportDetail() {
  const { id } = useParams();
  const navigate = useNavigate();
  const [data, setData] = useState<any>(null);
  const [err, setErr] = useState("");
  const [busy, setBusy] = useState(false);
  const [dialog, setDialog] = useState<DialogConfig | null>(null);
  const [toast, setToast] = useState<ToastMsg | null>(null);

  const load = useCallback(() => {
    if (!id) return;
    get(`/admin/reports/${id}`).then(setData).catch((e) => setErr(e.message));
  }, [id]);
  useEffect(() => { load(); }, [load]);

  async function act(fn: () => Promise<any>, msg: string) {
    setBusy(true);
    try { await fn(); load(); setToast({ type: "success", text: msg }); }
    catch (e: any) { setToast({ type: "error", text: e.message || "Falha" }); }
    finally { setBusy(false); }
  }

  if (err) return <div className="alert alert-danger">{err}</div>;
  if (!data) return <div className="text-secondary p-4">Carregando...</div>;

  const r = data.report;
  const rep = data.reported;
  const rel = data.relationship;
  const hist = data.history;
  const st = STATUS[r.status] || { label: r.status, cls: "bg-secondary-lt" };

  function setStatus(status: string, msg: string) {
    return act(() => post(`/admin/reports/${id}`, { status }), msg);
  }
  function banReported() {
    setDialog({
      title: "Banir denunciado",
      message: `Banir ${rep.fullName} permanentemente?`,
      icon: IconBan, danger: true, confirmText: "Banir",
      input: { label: "Motivo (opcional)", default: `Denúncia: ${r.reason}` },
      onConfirm: (reason) => act(() => post(`/admin/users/${rep.id}/ban`, { reason: reason || undefined }), "Denunciado banido"),
    });
  }
  function suspendReported() {
    setDialog({
      title: "Suspender denunciado",
      icon: IconClockPause, danger: true, confirmText: "Suspender",
      input: { label: "Por quantos dias?", type: "number", default: "7" },
      onConfirm: (raw) => {
        const days = Math.max(1, Math.min(365, parseInt(raw, 10) || 7));
        act(() => post(`/admin/users/${rep.id}/suspend`, { days }), `Suspenso por ${days} dia(s)`);
      },
    });
  }

  return (
    <>
      <div className="d-flex align-items-center mb-3">
        <button className="btn btn-icon me-3" onClick={() => navigate("/denuncias")}><IconArrowLeft size={18} /></button>
        <div className="flex-fill">
          <div className="page-pretitle">Moderação · investigação</div>
          <h2 className="page-title mb-0"><IconFlag size={22} className="me-2" />Denúncia</h2>
        </div>
        <span className={`badge ${st.cls}`} style={{ fontSize: 13 }}>{st.label}</span>
      </div>

      {/* Resumo da denúncia */}
      <div className="card mb-3" style={{ borderLeft: "4px solid #f76707" }}>
        <div className="card-body">
          <div className="row">
            <div className="col-md-8">
              <div className="text-secondary">Motivo da denúncia</div>
              <div style={{ fontSize: 18, fontWeight: 600 }}>{r.reason}</div>
            </div>
            <div className="col-md-4 text-md-end">
              <div className="text-secondary">Registrada em</div>
              <div className="fw-medium">{dt(r.createdAt)}</div>
            </div>
          </div>
        </div>
      </div>

      {/* Pessoas envolvidas */}
      <div className="row row-cards mb-3">
        <div className="col-md-6">
          <PersonCard title="👤 Quem denunciou (autor)" person={data.reporter} onOpen={() => navigate(`/usuarios/${data.reporter.id}`)} />
        </div>
        <div className="col-md-6">
          <PersonCard title="🚩 Quem foi denunciado" person={data.reported} onOpen={() => navigate(`/usuarios/${data.reported.id}`)} />
        </div>
      </div>

      {/* Ações */}
      <div className="card mb-3">
        <div className="card-header"><h3 className="card-title">Ações da denúncia</h3></div>
        <div className="card-body">
          <div className="d-flex flex-wrap gap-2">
            <button className="btn btn-success" disabled={busy} onClick={() => setStatus("REVIEWED", "Marcada como revisada")}>
              <IconCheck size={16} className="me-1" />Marcar revisada
            </button>
            <button className="btn" disabled={busy} onClick={() => setStatus("DISMISSED", "Denúncia descartada")}>
              <IconX size={16} className="me-1" />Descartar
            </button>
            <button className="btn" disabled={busy} onClick={() => setStatus("PENDING", "Reaberta")}>
              Reabrir
            </button>
            <div className="vr mx-1" />
            {rep.exists && !rep.isSuspended && (
              <button className="btn btn-warning" disabled={busy} onClick={suspendReported}>
                <IconClockPause size={16} className="me-1" />Suspender denunciado
              </button>
            )}
            {rep.exists && !rep.isBanned && (
              <button className="btn btn-danger" disabled={busy} onClick={banReported}>
                <IconBan size={16} className="me-1" />Banir denunciado
              </button>
            )}
          </div>
        </div>
      </div>

      {/* Relação entre as contas */}
      <div className="row row-cards mb-3">
        <div className="col-lg-6">
          <div className="card h-100">
            <div className="card-header"><h3 className="card-title"><IconHeart size={18} className="me-2" />Relação entre eles</h3></div>
            <div className="card-body py-2">
              <Line ok={rel.isMatched} label="Deram match" extra={rel.isMatched ? `desde ${dia(rel.matchSince)}${rel.matchActive ? "" : " (inativo)"}` : ""} />
              <Line ok={rel.reporterBlockedReported} label="Autor bloqueou o denunciado" />
              <Line ok={rel.reportedBlockedReporter} label="Denunciado bloqueou o autor" />
              <div className="d-flex align-items-center py-2">
                <IconMessage size={16} className="me-2 text-secondary" />
                <span>{rel.interactions.length} interação(ões) registrada(s) entre eles</span>
              </div>
            </div>
          </div>
        </div>
        <div className="col-lg-6">
          <div className="card h-100">
            <div className="card-header"><h3 className="card-title"><IconAlertTriangle size={18} className="me-2" />Histórico</h3></div>
            <div className="card-body py-2">
              <div className="d-flex justify-content-between py-2" style={{ borderBottom: "1px solid var(--tblr-border-color)" }}>
                <span className="text-secondary">Denúncias contra o denunciado</span>
                <span className={"fw-bold " + (hist.reportsAgainstReported > 1 ? "text-red" : "")}>{hist.reportsAgainstReported}</span>
              </div>
              <div className="d-flex justify-content-between py-2">
                <span className="text-secondary">Denúncias feitas pelo autor</span>
                <span className="fw-bold">{hist.reportsByReporter}</span>
              </div>
              {hist.reportsByReporter > 3 && (
                <div className="alert alert-warning mt-2 mb-0 py-2" style={{ fontSize: 13 }}>
                  <IconShieldCheck size={15} className="me-1" />Autor faz muitas denúncias — possível abuso.
                </div>
              )}
            </div>
          </div>
        </div>
      </div>

      {/* Outras denúncias contra o denunciado */}
      {hist.otherReportsAgainst.length > 0 && (
        <div className="card mb-3">
          <div className="card-header"><h3 className="card-title">Outras denúncias contra o denunciado ({hist.otherReportsAgainst.length})</h3></div>
          <div className="table-responsive">
            <table className="table table-vcenter card-table">
              <thead><tr><th>Motivo</th><th>Status</th><th>Data</th><th className="w-1"></th></tr></thead>
              <tbody>
                {hist.otherReportsAgainst.map((o: any) => (
                  <tr key={o.id} style={{ cursor: "pointer" }} onClick={() => navigate(`/denuncias/${o.id}`)}>
                    <td className="fw-medium">{o.reason}</td>
                    <td><span className={`badge ${STATUS[o.status]?.cls ?? "bg-secondary-lt"}`}>{STATUS[o.status]?.label ?? o.status}</span></td>
                    <td className="text-secondary">{dia(o.at)}</td>
                    <td><IconArrowRight size={16} className="text-secondary" /></td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      <Dialog config={dialog} onClose={() => setDialog(null)} />
      <Toast toast={toast} onClose={() => setToast(null)} />
    </>
  );
}

function Line({ ok, label, extra }: { ok: boolean; label: string; extra?: string }) {
  return (
    <div className="d-flex align-items-center py-2" style={{ borderBottom: "1px solid var(--tblr-border-color)" }}>
      <span className="avatar avatar-xs me-2" style={{ background: ok ? "rgba(47,179,68,.15)" : "rgba(150,150,150,.12)", color: ok ? "#2fb344" : "#909bb0" }}>
        {ok ? <IconCheck size={14} /> : <IconX size={14} />}
      </span>
      <span className={ok ? "fw-medium" : "text-secondary"}>{label}</span>
      {extra && <span className="text-secondary ms-1" style={{ fontSize: 12 }}>{extra}</span>}
    </div>
  );
}
