import { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import { IconBan, IconArrowRight } from "@tabler/icons-react";
import { API_BASE, del, get } from "../api";
import { Dialog, DialogConfig, Toast, ToastMsg } from "../components/ui";

const SERVER_ORIGIN = API_BASE.replace(/\/api$/, "");
const img = (s?: string | null) => (!s ? "" : s.startsWith("http") ? s : `${SERVER_ORIGIN}${s.startsWith("/") ? "" : "/"}${s}`);

interface UserRow {
  userId: string;
  fullName: string;
  email: string;
  age: number;
  city: string | null;
  profilePicture?: string | null;
}

export default function Banned() {
  const [users, setUsers] = useState<UserRow[]>([]);
  const [error, setError] = useState("");
  const navigate = useNavigate();
  const [dialog, setDialog] = useState<DialogConfig | null>(null);
  const [toast, setToast] = useState<ToastMsg | null>(null);

  async function load() {
    setError("");
    try {
      const r = await get("/admin/users?banned=true");
      setUsers(r.users);
    } catch (e: any) {
      setError(e.message);
    }
  }

  useEffect(() => {
    load();
  }, []);

  function unban(u: UserRow) {
    setDialog({
      title: "Desbanir usuário",
      message: `Liberar o acesso de ${u.fullName}?`,
      icon: IconBan,
      confirmText: "Desbanir",
      onConfirm: async () => {
        try {
          await del(`/admin/users/${u.userId}/ban`);
          load();
          setToast({ type: "success", text: "Usuário desbanido" });
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
          <div className="page-pretitle">Moderação</div>
          <h2 className="page-title">Usuários banidos</h2>
        </div>
        <span className="text-secondary">{users.length} conta(s) banida(s)</span>
      </div>

      {error && <div className="alert alert-danger">{error}</div>}

      <div className="card">
        <div className="table-responsive">
          <table className="table table-vcenter card-table">
            <thead>
              <tr>
                <th>Usuário</th>
                <th>E-mail</th>
                <th>Idade</th>
                <th>Cidade</th>
                <th className="w-1 text-end">Ação</th>
              </tr>
            </thead>
            <tbody>
              {users.map((u) => (
                <tr key={u.userId} style={{ cursor: "pointer" }} onClick={() => navigate(`/usuarios/${u.userId}`)}>
                  <td>
                    <div className="d-flex align-items-center">
                      <span
                        className="avatar avatar-sm me-2"
                        style={u.profilePicture ? { backgroundImage: `url(${img(u.profilePicture)})` } : {}}
                      >
                        {!u.profilePicture && u.fullName?.charAt(0)}
                      </span>
                      <span className="fw-medium">{u.fullName}</span>
                    </div>
                  </td>
                  <td className="text-secondary">{u.email}</td>
                  <td className="text-secondary">{u.age}</td>
                  <td className="text-secondary">{u.city || "—"}</td>
                  <td onClick={(e) => e.stopPropagation()}>
                    <div className="d-flex gap-1 justify-content-end">
                      <button className="btn btn-sm" onClick={() => unban(u)}>Desbanir</button>
                      <button className="btn btn-sm btn-primary" onClick={() => navigate(`/usuarios/${u.userId}`)}>
                        Ver<IconArrowRight size={14} className="ms-1" />
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
              {users.length === 0 && (
                <tr>
                  <td colSpan={5} className="text-center text-secondary py-4">Nenhum usuário banido.</td>
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
