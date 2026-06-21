import { FormEvent, useEffect, useState } from "react";
import { IconHeart, IconMail, IconLock, IconUser } from "@tabler/icons-react";
import { get } from "../api";
import { useAuth } from "../auth";

export default function Login() {
  const { login, registerSuper } = useAuth();
  const [needsSetup, setNeedsSetup] = useState<boolean | null>(null);
  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    get("/admin/auth/needs-setup")
      .then((r) => setNeedsSetup(r.needsSetup))
      .catch(() => setNeedsSetup(false));
  }, []);

  async function onSubmit(e: FormEvent) {
    e.preventDefault();
    setError("");
    setBusy(true);
    try {
      if (needsSetup) {
        await registerSuper(name, email, password);
      } else {
        await login(email, password);
      }
    } catch (err: any) {
      setError(err.message || "Falha ao entrar");
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="page page-center" style={{ minHeight: "100vh", background: "#111d40" }}>
      <div className="container container-tight py-4">
        <div className="text-center mb-4">
          <span
            className="d-inline-grid mb-2"
            style={{ width: 56, height: 56, borderRadius: 14, background: "linear-gradient(135deg,#e9c75a,#d4af37)", placeItems: "center" }}
          >
            <IconHeart size={30} color="#111d40" fill="#111d40" />
          </span>
          <div style={{ color: "#fff", fontSize: 22, fontWeight: 700 }}>Namoro Cristão</div>
          <div style={{ color: "#d4af37", fontSize: 13 }}>Painel administrativo</div>
        </div>
        <div className="card card-md">
          <div className="card-body">
            <h2 className="h3 text-center mb-4">
              {needsSetup ? "Criar super-administrador" : "Entre na sua conta"}
            </h2>
            <form onSubmit={onSubmit} autoComplete="off">
              {needsSetup && (
                <div className="mb-3">
                  <label className="form-label">Nome</label>
                  <div className="input-icon">
                    <span className="input-icon-addon">
                      <IconUser size={18} />
                    </span>
                    <input
                      className="form-control"
                      placeholder="Seu nome"
                      value={name}
                      onChange={(e) => setName(e.target.value)}
                      required
                    />
                  </div>
                </div>
              )}
              <div className="mb-3">
                <label className="form-label">E-mail</label>
                <div className="input-icon">
                  <span className="input-icon-addon">
                    <IconMail size={18} />
                  </span>
                  <input
                    className="form-control"
                    type="email"
                    placeholder="seu@email.com"
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                    required
                  />
                </div>
              </div>
              <div className="mb-2">
                <label className="form-label">Senha</label>
                <div className="input-icon">
                  <span className="input-icon-addon">
                    <IconLock size={18} />
                  </span>
                  <input
                    className="form-control"
                    type="password"
                    placeholder="Sua senha"
                    value={password}
                    onChange={(e) => setPassword(e.target.value)}
                    required
                  />
                </div>
              </div>
              {error && (
                <div className="alert alert-danger mt-3 mb-0 py-2" role="alert">
                  {error}
                </div>
              )}
              <div className="form-footer">
                <button type="submit" className="btn btn-primary w-100" disabled={busy}>
                  {busy ? "Aguarde..." : needsSetup ? "Criar e entrar" : "Entrar"}
                </button>
              </div>
            </form>
          </div>
        </div>
        <div className="text-center mt-3" style={{ color: "#7884a0", fontSize: 12 }}>
          © {new Date().getFullYear()} Namoro Cristão
        </div>
      </div>
    </div>
  );
}
