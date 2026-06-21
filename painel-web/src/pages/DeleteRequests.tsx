import { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import { IconTrash, IconArrowRight, IconShieldLock } from "@tabler/icons-react";
import { API_BASE, get, post } from "../api";
import { Dialog, DialogConfig, Toast, ToastMsg } from "../components/ui";

const SERVER_ORIGIN = API_BASE.replace(/\/api$/, "");
const img = (s?: string | null) => (!s ? "" : s.startsWith("http") ? s : `${SERVER_ORIGIN}${s.startsWith("/") ? "" : "/"}${s}`);

interface DReq {
  id: string;
  userId: string;
  status: string;
  createdAt: string;
  email: string;
  fullName: string;
  profilePicture?: string | null;
  city?: string | null;
  isPremium?: boolean;
}

export default function DeleteRequests() {
  const [reqs, setReqs] = useState<DReq[]>([]);
  const [error, setError] = useState("");
  const navigate = useNavigate();
  const [dialog, setDialog] = useState<DialogConfig | null>(null);
  const [toast, setToast] = useState<ToastMsg | null>(null);

  async function load() {
    setError("");
    try {
      const r = await get("/admin/account-delete-requests");
      setReqs(r.requests);
    } catch (e: any) {
      setError(e.message);
    }
  }

  useEffect(() => {
    load();
  }, []);

  function process(r: DReq) {
    setDialog({
      title: "Processar exclusão (LGPD)",
      message: `A conta de ${r.fullName} será anonimizada de forma irreversível: dados pessoais removidos, matches encerrados. Confirma?`,
      icon: IconShieldLock,
      danger: true,
      confirmText: "Anonimizar conta",
      onConfirm: async () => {
        try {
          await post(`/admin/account-delete-requests/${r.userId}/process`);
          load();
          setToast({ type: "success", text: "Conta anonimizada conforme LGPD" });
        } catch (e: any) {
          setToast({ type: "error", text: e.message });
        }
      },
    });
  }

  return (
    <>
      <div className="d-flex align-items-center justify-content-between mb-3">
        <div>
          <div className="page-pretitle">LGPD</div>
          <h2 className="page-title">Pedidos de exclusão de conta</h2>
        </div>
        <span className="text-secondary">{reqs.length} pendente(s)</span>
      </div>

      <div className="alert alert-info">
        <IconShieldLock size={18} className="me-2" />
        Ao processar, a conta é <strong>anonimizada</strong> (e-mail/senha removidos, perfil apagado, matches encerrados) em conformidade com a LGPD. A ação é irreversível.
      </div>

      {error && <div className="alert alert-danger">{error}</div>}

      <div className="card">
        <div className="table-responsive">
          <table className="table table-vcenter card-table">
            <thead>
              <tr>
                <th>Usuário</th>
                <th>E-mail</th>
                <th>Cidade</th>
                <th>Solicitado em</th>
                <th className="w-1 text-end">Ação</th>
              </tr>
            </thead>
            <tbody>
              {reqs.map((r) => (
                <tr key={r.id} style={{ cursor: "pointer" }} onClick={() => navigate(`/usuarios/${r.userId}`)}>
                  <td>
                    <div className="d-flex align-items-center">
                      <span
                        className="avatar avatar-sm me-2"
                        style={r.profilePicture ? { backgroundImage: `url(${img(r.profilePicture)})` } : {}}
                      >
                        {!r.profilePicture && r.fullName?.charAt(0)}
                      </span>
                      <div>
                        <div className="fw-medium">{r.fullName}</div>
                        {r.isPremium && <span className="badge bg-yellow-lt">VIP</span>}
                      </div>
                    </div>
                  </td>
                  <td className="text-secondary">{r.email}</td>
                  <td className="text-secondary">{r.city || "—"}</td>
                  <td className="text-secondary">{new Date(r.createdAt).toLocaleString("pt-BR")}</td>
                  <td onClick={(e) => e.stopPropagation()}>
                    <div className="d-flex gap-1 justify-content-end">
                      <button className="btn btn-sm btn-danger" onClick={() => process(r)}>
                        <IconTrash size={14} className="me-1" />Processar
                      </button>
                      <button className="btn btn-sm" onClick={() => navigate(`/usuarios/${r.userId}`)}>
                        Ver<IconArrowRight size={14} className="ms-1" />
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
              {reqs.length === 0 && (
                <tr>
                  <td colSpan={5} className="text-center text-secondary py-4">Nenhum pedido pendente.</td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </div>

      <Dialog config={dialog} onClose={() => setDialog(null)} />
      <Toast toast={toast} onClose={() => setToast(null)} />
    </>
  );
}
