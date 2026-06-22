import { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import { IconSearch, IconInfoCircle, IconBan, IconClockPause, IconMail } from "@tabler/icons-react";
import { del, get, post } from "../api";
import { Dialog, DialogConfig, Toast, ToastMsg } from "../components/ui";

/** Logo "G" do Google (multicolor) para indicar login via Google. */
function GoogleG({ size = 15 }: { size?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 48 48" aria-label="Google">
      <path fill="#FFC107" d="M43.611 20.083H42V20H24v8h11.303c-1.649 4.657-6.08 8-11.303 8-6.627 0-12-5.373-12-12s5.373-12 12-12c3.059 0 5.842 1.154 7.961 3.039l5.657-5.657C34.046 6.053 29.268 4 24 4 12.955 4 4 12.955 4 24s8.955 20 20 20 20-8.955 20-20c0-1.341-.138-2.65-.389-3.917z" />
      <path fill="#FF3D00" d="M6.306 14.691l6.571 4.819C14.655 15.108 18.961 12 24 12c3.059 0 5.842 1.154 7.961 3.039l5.657-5.657C34.046 6.053 29.268 4 24 4 16.318 4 9.656 8.337 6.306 14.691z" />
      <path fill="#4CAF50" d="M24 44c5.166 0 9.86-1.977 13.409-5.192l-6.19-5.238C29.211 35.091 26.715 36 24 36c-5.202 0-9.619-3.317-11.283-7.946l-6.522 5.025C9.505 39.556 16.227 44 24 44z" />
      <path fill="#1976D2" d="M43.611 20.083H42V20H24v8h11.303c-.792 2.237-2.231 4.166-4.087 5.571l6.19 5.238C36.971 39.205 44 34 44 24c0-1.341-.138-2.65-.389-3.917z" />
    </svg>
  );
}

interface UserRow {
  userId: string;
  fullName: string;
  email: string;
  provider?: string;
  gender: string;
  age: number;
  city: string | null;
  isVerified: boolean;
  isBanned: boolean;
  isSuspended: boolean;
  suspendedUntil: string | null;
  isOnline: boolean;
}

const GENDER_PT: Record<string, string> = {
  MALE: "Masculino",
  FEMALE: "Feminino",
  OTHER: "Outro",
};
const genderLabel = (g?: string) => (g ? GENDER_PT[g] ?? g : "—");

export default function Users() {
  const [users, setUsers] = useState<UserRow[]>([]);
  const [total, setTotal] = useState(0);
  const [search, setSearch] = useState("");
  const [error, setError] = useState("");
  const navigate = useNavigate();
  const [dialog, setDialog] = useState<DialogConfig | null>(null);
  const [toast, setToast] = useState<ToastMsg | null>(null);

  async function load() {
    setError("");
    try {
      const r = await get(`/admin/users?search=${encodeURIComponent(search)}`);
      setUsers(r.users);
      setTotal(r.total);
    } catch (e: any) {
      setError(e.message);
    }
  }

  useEffect(() => {
    load();
  }, []);

  async function act(fn: () => Promise<any>, msg: string) {
    try { await fn(); load(); setToast({ type: "success", text: msg }); }
    catch (e: any) { setToast({ type: "error", text: e.message || "Falha na ação" }); }
  }

  function toggleBan(u: UserRow) {
    if (u.isBanned) {
      setDialog({
        title: "Desbanir usuário",
        message: `Liberar o acesso de ${u.fullName}?`,
        icon: IconBan,
        confirmText: "Desbanir",
        onConfirm: () => act(() => del(`/admin/users/${u.userId}/ban`), "Usuário desbanido"),
      });
    } else {
      setDialog({
        title: "Banir usuário",
        message: `Banimento permanente de ${u.fullName}.`,
        icon: IconBan,
        danger: true,
        confirmText: "Banir",
        input: { label: "Motivo (opcional)", placeholder: "Ex.: conteúdo impróprio" },
        onConfirm: (reason) => act(() => post(`/admin/users/${u.userId}/ban`, { reason: reason || undefined }), "Usuário banido"),
      });
    }
  }

  function toggleSuspend(u: UserRow) {
    if (u.isSuspended) {
      setDialog({
        title: "Reativar conta",
        message: `Remover a suspensão de ${u.fullName}?`,
        icon: IconClockPause,
        confirmText: "Reativar",
        onConfirm: () => act(() => del(`/admin/users/${u.userId}/suspend`), "Conta reativada"),
      });
    } else {
      setDialog({
        title: "Suspender conta",
        message: `Banimento temporário de ${u.fullName}.`,
        icon: IconClockPause,
        danger: true,
        confirmText: "Suspender",
        input: { label: "Por quantos dias?", type: "number", default: "7" },
        onConfirm: (raw) => {
          const days = Math.max(1, Math.min(365, parseInt(raw, 10) || 7));
          act(() => post(`/admin/users/${u.userId}/suspend`, { days }), `Suspenso por ${days} dia(s)`);
        },
      });
    }
  }

  return (
    <>
      <div className="d-flex align-items-center justify-content-between mb-3">
        <div>
          <div className="page-pretitle">Gestão</div>
          <h2 className="page-title">Usuários</h2>
        </div>
        <span className="text-secondary">{total} cadastrado(s)</span>
      </div>

      {error && <div className="alert alert-danger">{error}</div>}

      <div className="card">
        <div className="card-body border-bottom py-3">
          <div className="d-flex">
            <div className="input-icon" style={{ maxWidth: 340 }}>
              <span className="input-icon-addon"><IconSearch size={18} /></span>
              <input
                className="form-control"
                placeholder="Buscar por nome ou cidade..."
                value={search}
                onChange={(e) => setSearch(e.target.value)}
                onKeyDown={(e) => e.key === "Enter" && load()}
              />
            </div>
            <button className="btn btn-primary ms-2" onClick={load}>Buscar</button>
          </div>
        </div>
        <div className="table-responsive">
          <table className="table table-vcenter card-table">
            <thead>
              <tr>
                <th>Nome</th>
                <th>E-mail</th>
                <th>Sexo</th>
                <th>Idade</th>
                <th>Cidade</th>
                <th>Status</th>
                <th className="w-1 text-end">Ações</th>
              </tr>
            </thead>
            <tbody>
              {users.map((u) => (
                <tr key={u.userId} style={{ cursor: "pointer" }} onClick={() => navigate(`/usuarios/${u.userId}`)}>
                  <td className="fw-medium">{u.fullName}</td>
                  <td className="text-secondary">
                    <span className="d-inline-flex align-items-center gap-2" title={u.provider === "GOOGLE" ? "Cadastro via Google" : "Cadastro via e-mail"}>
                      {u.provider === "GOOGLE" ? <GoogleG /> : <IconMail size={15} className="text-secondary" />}
                      {u.email}
                    </span>
                  </td>
                  <td className="text-secondary">{genderLabel(u.gender)}</td>
                  <td className="text-secondary">{u.age}</td>
                  <td className="text-secondary">{u.city || "—"}</td>
                  <td>
                    <div className="d-flex gap-1 flex-wrap">
                      {u.isOnline && <span className="badge bg-green-lt">online</span>}
                      {u.isVerified && <span className="badge bg-yellow-lt">Verificado</span>}
                      {u.isSuspended && <span className="badge bg-orange-lt">Suspenso</span>}
                      {u.isBanned && <span className="badge bg-red-lt">Banido</span>}
                    </div>
                  </td>
                  <td onClick={(e) => e.stopPropagation()}>
                    <div className="d-flex gap-1 justify-content-end">
                      <button className="btn btn-sm btn-primary" onClick={() => navigate(`/usuarios/${u.userId}`)}>
                        <IconInfoCircle size={15} className="me-1" />Informações
                      </button>
                      <button
                        className={u.isSuspended ? "btn btn-sm" : "btn btn-sm btn-warning"}
                        onClick={() => toggleSuspend(u)}
                      >
                        <IconClockPause size={15} className="me-1" />{u.isSuspended ? "Reativar" : "Suspender"}
                      </button>
                      <button
                        className={u.isBanned ? "btn btn-sm" : "btn btn-sm btn-danger"}
                        onClick={() => toggleBan(u)}
                      >
                        <IconBan size={15} className="me-1" />{u.isBanned ? "Desbanir" : "Banir"}
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
              {users.length === 0 && (
                <tr>
                  <td colSpan={7} className="text-center text-secondary py-4">
                    Nenhum usuário encontrado.
                  </td>
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
