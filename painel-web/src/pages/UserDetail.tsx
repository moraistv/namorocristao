import { useCallback, useEffect, useState } from "react";
import { useNavigate, useParams } from "react-router-dom";
import {
  IconArrowLeft, IconHeart, IconStar, IconThumbDown, IconMessage, IconFlag,
  IconBan, IconShieldLock, IconDeviceMobile, IconPhoto, IconLock,
  IconMapPin, IconCalendar, IconMail, IconCreditCard, IconWorld,
  IconUserCheck, IconClock, IconClockPause, IconCrown, IconBolt,
  IconRosetteDiscountCheck, IconCoin,
} from "@tabler/icons-react";
import { API_BASE, get, post, del } from "../api";
import { Dialog, DialogConfig, Toast, ToastMsg } from "../components/ui";
import UserLocationMap from "../components/UserLocationMap";

const SERVER_ORIGIN = API_BASE.replace(/\/api$/, "");
const img = (s?: string | null) => (!s ? "" : s.startsWith("http") ? s : `${SERVER_ORIGIN}${s.startsWith("/") ? "" : "/"}${s}`);
const dt = (s?: string | null) => (s ? new Date(s).toLocaleString("pt-BR") : "—");
const dia = (s?: string | null) => (s ? new Date(s).toLocaleDateString("pt-BR") : "—");
const GENDER_PT: Record<string, string> = { MALE: "Masculino", FEMALE: "Feminino", OTHER: "Outro" };

function Stat({ icon: Icon, value, label, color = "#111d40" }: any) {
  return (
    <div className="col-6 col-md-3">
      <div className="card card-sm">
        <div className="card-body">
          <div className="row align-items-center">
            <div className="col-auto">
              <span className="avatar" style={{ background: "rgba(17,29,64,0.08)", color }}><Icon size={20} /></span>
            </div>
            <div className="col">
              <div style={{ fontWeight: 700, fontSize: 18 }}>{value}</div>
              <div className="text-secondary" style={{ fontSize: 12 }}>{label}</div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

function Row({ label, value }: { label: string; value: React.ReactNode }) {
  return (
    <div className="d-flex justify-content-between py-2" style={{ borderBottom: "1px solid var(--tblr-border-color)" }}>
      <span className="text-secondary">{label}</span>
      <span className="fw-medium text-end" style={{ maxWidth: "60%", wordBreak: "break-word" }}>{value}</span>
    </div>
  );
}

export default function UserDetail() {
  const { userId } = useParams();
  const navigate = useNavigate();
  const [data, setData] = useState<any>(null);
  const [err, setErr] = useState("");
  const [busy, setBusy] = useState(false);
  const [vipOpen, setVipOpen] = useState(false);
  const [dialog, setDialog] = useState<DialogConfig | null>(null);
  const [toast, setToast] = useState<ToastMsg | null>(null);

  const load = useCallback(() => {
    if (!userId) return;
    get(`/admin/users/${userId}`).then(setData).catch((e) => setErr(e.message));
  }, [userId]);

  useEffect(() => { load(); }, [load]);

  async function act(fn: () => Promise<any>, successMsg = "Ação concluída") {
    setBusy(true);
    try { await fn(); load(); setToast({ type: "success", text: successMsg }); }
    catch (e: any) { setToast({ type: "error", text: e.message || "Falha na ação" }); }
    finally { setBusy(false); }
  }

  const u = data?.user;
  const p = data?.profile;
  const st = data?.stats;
  const sec = data?.security;
  const bill = data?.billing;
  const loc = data?.location;

  function banToggle() {
    if (u.isBanned) {
      setDialog({
        title: "Desbanir usuário",
        message: "O usuário poderá voltar a usar o app. Confirma?",
        icon: IconBan,
        confirmText: "Desbanir",
        onConfirm: () => act(() => del(`/admin/users/${userId}/ban`), "Usuário desbanido"),
      });
    } else {
      setDialog({
        title: "Banir usuário",
        message: "Banimento permanente. O usuário perde o acesso imediatamente.",
        icon: IconBan,
        danger: true,
        confirmText: "Banir",
        input: { label: "Motivo (opcional)", placeholder: "Ex.: conteúdo impróprio" },
        onConfirm: (reason) => act(() => post(`/admin/users/${userId}/ban`, { reason: reason || undefined }), "Usuário banido"),
      });
    }
  }
  function suspendToggle() {
    if (u.isSuspended) {
      setDialog({
        title: "Reativar conta",
        message: "Remove a suspensão e libera o acesso. Confirma?",
        icon: IconClockPause,
        confirmText: "Reativar",
        onConfirm: () => act(() => del(`/admin/users/${userId}/suspend`), "Conta reativada"),
      });
    } else {
      setDialog({
        title: "Suspender conta",
        message: "Banimento temporário. O usuário fica bloqueado até a data.",
        icon: IconClockPause,
        danger: true,
        confirmText: "Suspender",
        input: { label: "Por quantos dias?", type: "number", default: "7" },
        onConfirm: (raw) => {
          const days = Math.max(1, Math.min(365, parseInt(raw, 10) || 7));
          act(() => post(`/admin/users/${userId}/suspend`, { days }), `Suspenso por ${days} dia(s)`);
        },
      });
    }
  }
  function grantVip(plan: string) {
    act(() => post(`/admin/users/${userId}/premium`, { plan }), "VIP concedido");
  }
  function revokeVip() {
    setDialog({
      title: "Remover VIP",
      message: "Remove o premium do usuário imediatamente. Confirma?",
      icon: IconCrown,
      danger: true,
      confirmText: "Remover VIP",
      onConfirm: () => act(() => del(`/admin/users/${userId}/premium`), "VIP removido"),
    });
  }
  function addCredits(kind: "superLikes" | "boosts" | "credits") {
    const nome = kind === "boosts" ? "boosts" : kind === "credits" ? "créditos" : "super likes";
    setDialog({
      title: `Adicionar ${nome}`,
      icon: kind === "boosts" ? IconBolt : kind === "credits" ? IconCoin : IconStar,
      confirmText: "Adicionar",
      input: { label: `Quantos ${nome}?`, type: "number", default: "5" },
      onConfirm: (raw) => {
        const n = Math.max(1, Math.min(100000, parseInt(raw, 10) || 0));
        act(() => post(`/admin/users/${userId}/credits`, { [kind]: n }), `+${n} ${nome}`);
      },
    });
  }
  function verifyToggle() {
    const verifying = !p?.isVerified;
    setDialog({
      title: verifying ? "Verificar usuário" : "Remover verificação",
      message: verifying ? "Marca o perfil como verificado." : "Remove o selo de verificado.",
      icon: IconRosetteDiscountCheck,
      danger: !verifying,
      confirmText: verifying ? "Verificar" : "Remover",
      onConfirm: () => act(() => post(`/admin/users/${userId}/verify`, { verified: verifying }), verifying ? "Usuário verificado" : "Verificação removida"),
    });
  }

  if (err) return <div className="alert alert-danger">{err}</div>;
  if (!data) return <div className="text-secondary p-4">Carregando...</div>;

  return (
    <>
      {/* Cabeçalho */}
      <div className="d-flex align-items-center mb-3">
        <button className="btn btn-icon me-3" onClick={() => navigate("/usuarios")}><IconArrowLeft size={18} /></button>
        <span
          className="avatar avatar-lg me-3"
          style={p?.profilePicture ? { backgroundImage: `url(${img(p.profilePicture)})` } : { background: "linear-gradient(135deg,#e9c75a,#d4af37)", color: "#111d40", fontWeight: 700 }}
        >
          {!p?.profilePicture && (p?.fullName?.charAt(0) ?? "?")}
        </span>
        <div className="flex-fill">
          <h2 className="page-title mb-0">{p?.fullName ?? "—"}</h2>
          <div className="text-secondary">{u.email}</div>
        </div>
      </div>

      {/* Selos */}
      <div className="d-flex flex-wrap gap-2 mb-3">
        {u.isPremium && <span className="badge bg-yellow-lt">★ VIP {u.premiumPlan ? `(${u.premiumPlan})` : ""}</span>}
        {p?.isVerified && <span className="badge bg-green-lt">Verificado</span>}
        {p?.isOnline ? <span className="badge bg-green-lt">Online</span> : <span className="badge bg-secondary-lt">Offline</span>}
        {u.isSuspended && <span className="badge bg-orange-lt">Suspenso até {dia(u.suspendedUntil)}</span>}
        {u.isBanned && <span className="badge bg-red-lt">Banido</span>}
        {u.emailVerified && <span className="badge bg-azure-lt">E-mail verificado</span>}
        <span className="badge bg-secondary-lt">{u.provider}</span>
        {data.deleteRequest && <span className="badge bg-red-lt">Exclusão: {data.deleteRequest.status}</span>}
      </div>

      {/* Painel de AÇÕES */}
      <div className="card mb-3">
        <div className="card-header"><h3 className="card-title">Ações administrativas</h3></div>
        <div className="card-body">
          <div className="d-flex flex-wrap gap-2">
            <button className={u.isBanned ? "btn" : "btn btn-danger"} disabled={busy} onClick={banToggle}>
              <IconBan size={16} className="me-1" />{u.isBanned ? "Desbanir" : "Banir"}
            </button>
            <button className={u.isSuspended ? "btn" : "btn btn-warning"} disabled={busy} onClick={suspendToggle}>
              <IconClockPause size={16} className="me-1" />{u.isSuspended ? "Reativar" : "Suspender"}
            </button>
            <button className={p?.isVerified ? "btn" : "btn btn-success"} disabled={busy} onClick={verifyToggle}>
              <IconRosetteDiscountCheck size={16} className="me-1" />{p?.isVerified ? "Remover verificação" : "Verificar"}
            </button>
            <div className="vr mx-1" />
            <div className="dropdown">
              <button className="btn btn-primary" disabled={busy} onClick={() => setVipOpen((v) => !v)}>
                <IconCrown size={16} className="me-1" />Dar VIP
              </button>
              {vipOpen && (
                <div className="dropdown-menu show" style={{ position: "absolute", display: "block", zIndex: 30 }}>
                  <button className="dropdown-item" onClick={() => { setVipOpen(false); grantVip("monthly"); }}>Mensal (30 dias)</button>
                  <button className="dropdown-item" onClick={() => { setVipOpen(false); grantVip("quarterly"); }}>Trimestral (90 dias)</button>
                  <button className="dropdown-item" onClick={() => { setVipOpen(false); grantVip("yearly"); }}>Anual (365 dias)</button>
                </div>
              )}
            </div>
            {u.isPremium && (
              <button className="btn" disabled={busy} onClick={revokeVip}>Remover VIP</button>
            )}
            <button className="btn" disabled={busy} onClick={() => addCredits("superLikes")}>
              <IconStar size={16} className="me-1" />+ Super Likes
            </button>
            <button className="btn" disabled={busy} onClick={() => addCredits("boosts")}>
              <IconBolt size={16} className="me-1" />+ Boosts
            </button>
            <button className="btn" disabled={busy} onClick={() => addCredits("credits")}>
              <IconCoin size={16} className="me-1" />+ Créditos
            </button>
          </div>
        </div>
      </div>

      {/* Métricas */}
      <div className="row row-cards mb-1">
        <Stat icon={IconHeart} value={st.likesReceived} label="Curtidas recebidas" color="#e23744" />
        <Stat icon={IconStar} value={st.superlikesReceived} label="Super likes recebidos" color="#d4af37" />
        <Stat icon={IconUserCheck} value={st.activeMatches} label="Matches ativos" color="#2fb344" />
        <Stat icon={IconMessage} value={st.messagesSent} label="Mensagens enviadas" color="#111d40" />
        <Stat icon={IconHeart} value={st.likesGiven} label="Curtidas dadas" color="#e23744" />
        <Stat icon={IconThumbDown} value={st.dislikesGiven} label="Descurtidas" color="#6b7a99" />
        <Stat icon={IconPhoto} value={st.photos} label="Fotos no perfil" color="#4263eb" />
        <Stat icon={IconLock} value={st.lockedPhotos} label="Fotos privadas" color="#ae3ec9" />
        <Stat icon={IconFlag} value={st.reportsAgainst} label="Denúncias recebidas" color="#f76707" />
        <Stat icon={IconFlag} value={st.reportsMade} label="Denúncias feitas" color="#f76707" />
        <Stat icon={IconBan} value={st.blockedByOthers} label="Bloqueado por" color="#d63939" />
        <Stat icon={IconCoin} value={`R$ ${Number(bill.estimatedSpend).toFixed(2)}`} label="Gasto estimado" color="#2fb344" />
      </div>

      <div className="row mt-2">
        <div className="col-lg-6">
          <div className="card mb-3">
            <div className="card-header"><h3 className="card-title">Perfil</h3></div>
            <div className="card-body py-2">
              <Row label="Nome completo" value={p?.fullName ?? "—"} />
              <Row label="Sexo" value={p?.gender ? GENDER_PT[p.gender] ?? p.gender : "—"} />
              <Row label="Aniversário" value={dia(p?.birthday)} />
              <Row label="Cidade" value={<><IconMapPin size={14} className="me-1" />{p?.city ?? "—"}</>} />
              <Row label="Intenção" value={p?.intention ?? "—"} />
              <Row label="Denominação" value={p?.denomination ?? "—"} />
              <Row label="Frequência igreja" value={p?.churchFrequency ?? "—"} />
              <Row label="Interesses" value={p?.interests?.length ? p.interests.join(", ") : "—"} />
              <Row label="Sobre" value={p?.about ?? "—"} />
              <Row label="Coordenadas" value={p?.latitude ? `${p.latitude.toFixed(4)}, ${p.longitude?.toFixed(4)}` : "—"} />
              <Row label="Última atividade" value={dt(p?.lastActiveAt)} />
            </div>
          </div>

          <div className="card mb-3">
            <div className="card-header"><h3 className="card-title"><IconCreditCard size={18} className="me-2" />Financeiro / VIP</h3></div>
            <div className="card-body py-2">
              <Row label="Premium" value={bill.isPremium ? "Sim" : "Não"} />
              <Row label="Plano" value={bill.plan ?? "—"} />
              <Row label="Valor do plano" value={bill.planPrice ? `R$ ${bill.planPrice.toFixed(2)}` : "—"} />
              <Row label="Gasto estimado" value={<strong className="text-green">R$ {Number(bill.estimatedSpend).toFixed(2)}</strong>} />
              <Row label="Premium até" value={dia(bill.premiumUntil)} />
              <Row label="Super likes usados hoje" value={u.superLikesUsedToday} />
              <Row label="Boosts restantes" value={u.boostsRemaining} />
              <Row label="Créditos (saldo)" value={<strong>{u.credits ?? 0}</strong>} />
            </div>
          </div>
        </div>

        <div className="col-lg-6">
          <div className="card mb-3">
            <div className="card-header"><h3 className="card-title">Conta</h3></div>
            <div className="card-body py-2">
              <Row label="ID" value={<code style={{ fontSize: 11 }}>{u.id}</code>} />
              <Row label="E-mail" value={<><IconMail size={14} className="me-1" />{u.email}</>} />
              <Row label="Provedor" value={u.provider} />
              <Row label="Criada em" value={<><IconCalendar size={14} className="me-1" />{dia(u.createdAt)}</>} />
              <Row label="Idade da conta" value={`${u.accountAgeDays} dia(s)`} />
              <Row label="Notificações" value={st.notifications} />
              <Row label="Publicações (feed)" value={st.feeds} />
              <Row label="Verificações enviadas" value={`${st.verificationsCount}${st.lastVerificationStatus ? ` (${st.lastVerificationStatus})` : ""}`} />
              {data.ban && <Row label="Banido em" value={`${dia(data.ban.since)} — ${data.ban.reason || "sem motivo"}`} />}
            </div>
          </div>

          <div className="card mb-3">
            <div className="card-header"><h3 className="card-title"><IconShieldLock size={18} className="me-2" />Segurança</h3></div>
            <div className="card-body py-2">
              <Row label="Último IP" value={<code>{sec.lastIp ?? "—"}</code>} />
              <Row label="Endereço MAC" value={<span className="text-secondary" style={{ fontSize: 12 }}>indisponível (não exposto pelo dispositivo)</span>} />
              <div className="mt-2 mb-1 text-secondary d-flex align-items-center"><IconDeviceMobile size={15} className="me-1" />Dispositivos</div>
              {sec.devices.length ? sec.devices.map((d: any, i: number) => (
                <div key={i} className="d-flex justify-content-between" style={{ fontSize: 13 }}>
                  <span>{d.platform || "desconhecido"}</span>
                  <span className="text-secondary">{dia(d.since)}</span>
                </div>
              )) : <div className="text-secondary" style={{ fontSize: 13 }}>Nenhum dispositivo registrado</div>}
            </div>
          </div>
        </div>
      </div>

      {/* Localização + Denúncias */}
      <div className="row row-cards mb-3">
        <div className="col-lg-5">
          <div className="card h-100">
            <div className="card-header"><h3 className="card-title"><IconMapPin size={18} className="me-2" />Localização</h3></div>
            <div className="card-body">
              <div className="mb-2">
                <span className="fw-medium">{loc?.city ?? "Cidade não informada"}</span>
                {loc?.stateName && <span className="text-secondary"> · {loc.stateName} ({loc.uf})</span>}
              </div>
              {loc?.uf || (loc?.latitude != null) ? (
                <UserLocationMap uf={loc?.uf} latitude={loc?.latitude} longitude={loc?.longitude} />
              ) : (
                <div className="text-secondary text-center py-5">Localização não disponível no mapa.</div>
              )}
              {loc?.latitude != null && (
                <div className="text-secondary mt-2" style={{ fontSize: 12 }}>
                  Coordenadas: {loc.latitude.toFixed(4)}, {loc.longitude?.toFixed(4)}
                </div>
              )}
            </div>
          </div>
        </div>
        <div className="col-lg-7">
          <div className="card h-100">
            <div className="card-header"><h3 className="card-title"><IconFlag size={18} className="me-2" />Denúncias recebidas ({data.reportsReceived?.length ?? 0})</h3></div>
            <div className="table-responsive">
              <table className="table table-vcenter card-table">
                <thead><tr><th>Motivo</th><th>Status</th><th>Quem denunciou</th><th>Data</th></tr></thead>
                <tbody>
                  {data.reportsReceived?.length ? data.reportsReceived.map((r: any) => (
                    <tr key={r.id}>
                      <td className="fw-medium">{r.reason}</td>
                      <td><span className="badge bg-secondary-lt">{r.status}</span></td>
                      <td className="text-secondary" style={{ fontSize: 12 }}>{r.reporterId.slice(0, 8)}…</td>
                      <td className="text-secondary">{dia(r.at)}</td>
                    </tr>
                  )) : (
                    <tr><td colSpan={4} className="text-center text-secondary py-3">Nenhuma denúncia recebida.</td></tr>
                  )}
                </tbody>
              </table>
            </div>
          </div>
        </div>
      </div>

      {/* Logs de acesso */}
      <div className="card mb-3">
        <div className="card-header"><h3 className="card-title"><IconWorld size={18} className="me-2" />Logs de acesso (IP)</h3></div>
        <div className="table-responsive">
          <table className="table table-vcenter card-table">
            <thead><tr><th>Ação</th><th>IP</th><th>Dispositivo / navegador</th><th>Data</th></tr></thead>
            <tbody>
              {sec.accessLogs.length ? sec.accessLogs.map((l: any, i: number) => (
                <tr key={i}>
                  <td><span className="badge bg-secondary-lt">{l.action}</span></td>
                  <td><code>{l.ip ?? "—"}</code></td>
                  <td className="text-secondary" style={{ fontSize: 12, maxWidth: 360, whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>{l.userAgent ?? "—"}</td>
                  <td className="text-secondary"><IconClock size={13} className="me-1" />{dt(l.at)}</td>
                </tr>
              )) : (
                <tr><td colSpan={4} className="text-center text-secondary py-3">Nenhum acesso registrado ainda (logs começam a partir de agora).</td></tr>
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* Fotos */}
      {p?.mediaFiles?.length > 0 && (
        <div className="card">
          <div className="card-header"><h3 className="card-title"><IconPhoto size={18} className="me-2" />Fotos ({p.mediaFiles.length})</h3></div>
          <div className="card-body">
            <div className="d-flex flex-wrap gap-2">
              {p.mediaFiles.map((m: string, i: number) => (
                <a key={i} href={img(m)} target="_blank" rel="noreferrer">
                  <img src={img(m)} alt="" style={{ width: 110, height: 110, objectFit: "cover", borderRadius: 8, border: "1px solid var(--tblr-border-color)" }} />
                </a>
              ))}
            </div>
          </div>
        </div>
      )}

      <Dialog config={dialog} onClose={() => setDialog(null)} />
      <Toast toast={toast} onClose={() => setToast(null)} />
    </>
  );
}
