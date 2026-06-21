import { FormEvent, useEffect, useState } from "react";
import { IconTrash, IconShieldCheck, IconCrown, IconUserPlus } from "@tabler/icons-react";
import { del, get, post } from "../api";
import { Dialog, DialogConfig, Toast, ToastMsg } from "../components/ui";

interface Admin {
  id: string;
  name: string;
  email: string;
  permissions: string[];
  isSuperAdmin: boolean;
  createdAt?: string;
}

const ALL_PERMS = [
  { key: "VERIFICATION", label: "Verificações", desc: "Aprovar/rejeitar selfies" },
  { key: "REPORT", label: "Denúncias e banimentos", desc: "Moderar e banir usuários" },
  { key: "ACCOUNT_DELETE", label: "Exclusões (LGPD)", desc: "Processar exclusão de contas" },
];
const PERM_LABEL: Record<string, string> = Object.fromEntries(ALL_PERMS.map((p) => [p.key, p.label]));

export default function Admins() {
  const [admins, setAdmins] = useState<Admin[]>([]);
  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [perms, setPerms] = useState<string[]>([]);
  const [formErr, setFormErr] = useState("");
  const [dialog, setDialog] = useState<DialogConfig | null>(null);
  const [toast, setToast] = useState<ToastMsg | null>(null);

  async function load() {
    try {
      const r = await get("/admin/admins");
      setAdmins(r.admins);
    } catch (e: any) {
      setToast({ type: "error", text: e.message });
    }
  }

  useEffect(() => {
    load();
  }, []);

  function togglePerm(p: string) {
    setPerms((prev) => (prev.includes(p) ? prev.filter((x) => x !== p) : [...prev, p]));
  }

  async function create(e: FormEvent) {
    e.preventDefault();
    setFormErr("");
    try {
      await post("/admin/admins", { name, email, password, permissions: perms });
      setName(""); setEmail(""); setPassword(""); setPerms([]);
      load();
      setToast({ type: "success", text: "Admin criado" });
    } catch (e: any) {
      setFormErr(e.message);
    }
  }

  function remove(a: Admin) {
    setDialog({
      title: "Remover administrador",
      message: `Remover ${a.name} da equipe? Perde o acesso ao painel.`,
      icon: IconTrash,
      danger: true,
      confirmText: "Remover",
      onConfirm: async () => {
        try {
          await del(`/admin/admins/${a.id}`);
          load();
          setToast({ type: "success", text: "Admin removido" });
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
          <div className="page-pretitle">Equipe</div>
          <h2 className="page-title">Administradores</h2>
        </div>
        <span className="text-secondary">{admins.length} no time</span>
      </div>

      <div className="row row-cards">
        <div className="col-lg-8">
          <div className="card">
            <div className="table-responsive">
              <table className="table table-vcenter card-table">
                <thead>
                  <tr>
                    <th>Administrador</th>
                    <th>Permissões</th>
                    <th>Desde</th>
                    <th className="w-1"></th>
                  </tr>
                </thead>
                <tbody>
                  {admins.map((a) => (
                    <tr key={a.id}>
                      <td>
                        <div className="d-flex align-items-center">
                          <span
                            className="avatar avatar-sm me-2"
                            style={{ background: a.isSuperAdmin ? "linear-gradient(135deg,#e9c75a,#d4af37)" : "rgba(17,29,64,0.08)", color: a.isSuperAdmin ? "#111d40" : "#111d40", fontWeight: 700 }}
                          >
                            {a.name?.charAt(0)?.toUpperCase()}
                          </span>
                          <div>
                            <div className="fw-medium d-flex align-items-center gap-1">
                              {a.name}
                              {a.isSuperAdmin && <IconCrown size={15} color="#d4af37" />}
                            </div>
                            <div className="text-secondary" style={{ fontSize: 12 }}>{a.email}</div>
                          </div>
                        </div>
                      </td>
                      <td>
                        <div className="d-flex gap-1 flex-wrap">
                          {a.isSuperAdmin ? (
                            <span className="badge bg-yellow-lt">Acesso total</span>
                          ) : a.permissions.length ? (
                            a.permissions.map((p) => (
                              <span key={p} className="badge bg-secondary-lt">{PERM_LABEL[p] ?? p}</span>
                            ))
                          ) : (
                            <span className="text-secondary">Sem permissões</span>
                          )}
                        </div>
                      </td>
                      <td className="text-secondary">{a.createdAt ? new Date(a.createdAt).toLocaleDateString("pt-BR") : "—"}</td>
                      <td>
                        {!a.isSuperAdmin && (
                          <button className="btn btn-sm btn-icon" onClick={() => remove(a)} title="Remover">
                            <IconTrash size={16} />
                          </button>
                        )}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        </div>

        <div className="col-lg-4">
          <form className="card" onSubmit={create}>
            <div className="card-header">
              <h3 className="card-title"><IconUserPlus size={18} className="me-2" />Novo admin</h3>
            </div>
            <div className="card-body">
              <div className="mb-3">
                <label className="form-label">Nome</label>
                <input className="form-control" value={name} onChange={(e) => setName(e.target.value)} required />
              </div>
              <div className="mb-3">
                <label className="form-label">E-mail</label>
                <input className="form-control" type="email" value={email} onChange={(e) => setEmail(e.target.value)} required />
              </div>
              <div className="mb-3">
                <label className="form-label">Senha (mín. 8)</label>
                <input className="form-control" type="password" value={password} onChange={(e) => setPassword(e.target.value)} required />
              </div>
              <label className="form-label">Permissões</label>
              <div className="mb-3">
                {ALL_PERMS.map((p) => (
                  <label key={p.key} className="form-selectgroup-item d-block mb-2" style={{ cursor: "pointer" }}>
                    <div className="d-flex align-items-start">
                      <input
                        type="checkbox"
                        className="form-check-input m-0 me-2 mt-1"
                        checked={perms.includes(p.key)}
                        onChange={() => togglePerm(p.key)}
                      />
                      <div>
                        <div className="fw-medium" style={{ fontSize: 14 }}>{p.label}</div>
                        <div className="text-secondary" style={{ fontSize: 12 }}>{p.desc}</div>
                      </div>
                    </div>
                  </label>
                ))}
              </div>
              <button className="btn btn-primary w-100">Criar admin</button>
              {formErr && <div className="alert alert-danger mt-3 mb-0">{formErr}</div>}
            </div>
          </form>
        </div>
      </div>

      <Dialog config={dialog} onClose={() => setDialog(null)} />
      <Toast toast={toast} onClose={() => setToast(null)} />
    </>
  );
}
