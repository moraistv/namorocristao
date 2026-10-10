import { FormEvent, useEffect, useState } from "react";
import { IconHeart, IconMail, IconLock, IconRefresh, IconUser } from "@tabler/icons-react";
import { ApiError, get } from "../api";
import { useAuth } from "../auth";

interface NeedsSetupResponse {
  needsSetup: boolean;
}

function errorMessage(error: unknown, fallback: string): string {
  return error instanceof Error && error.message ? error.message : fallback;
}

export default function Login() {
  const { login, registerSuper } = useAuth();
  const [needsSetup, setNeedsSetup] = useState<boolean | null>(null);
  const [checkingSetup, setCheckingSetup] = useState(true);
  const [setupError, setSetupError] = useState("");
  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [submitError, setSubmitError] = useState("");
  const [busy, setBusy] = useState(false);

  async function checkSetup() {
    setCheckingSetup(true);
    setSetupError("");
    setNeedsSetup(null);
    try {
      const response = await get<NeedsSetupResponse>("/admin/auth/needs-setup", { auth: false });
      if (typeof response.needsSetup !== "boolean") {
        throw new ApiError("O servidor retornou um estado de configuração inválido.", 200, "INVALID_RESPONSE");
      }
      setNeedsSetup(response.needsSetup);
    } catch (error: unknown) {
      setSetupError(errorMessage(error, "Não foi possível verificar a configuração do painel."));
    } finally {
      setCheckingSetup(false);
    }
  }

  useEffect(() => {
    void checkSetup();
  }, []);

  async function onSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (needsSetup === null || checkingSetup || setupError || busy) return;

    setSubmitError("");
    setBusy(true);
    try {
      if (needsSetup) {
        await registerSuper(name, email, password);
      } else {
        await login(email, password);
      }
    } catch (error: unknown) {
      setSubmitError(errorMessage(error, "Falha ao entrar"));
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
            aria-hidden="true"
          >
            <IconHeart size={30} color="#111d40" fill="#111d40" />
          </span>
          <div style={{ color: "#fff", fontSize: 22, fontWeight: 700 }}>Namoro Cristão</div>
          <div style={{ color: "#d4af37", fontSize: 13 }}>Painel administrativo</div>
        </div>
        <div className="card card-md">
          <div className="card-body">
            <h1 className="h3 text-center mb-4">
              {needsSetup === true ? "Criar super-administrador" : needsSetup === false ? "Entre na sua conta" : "Verificando o painel"}
            </h1>

            {checkingSetup && (
              <div className="text-secondary text-center py-4" role="status" aria-live="polite">
                <span className="spinner-border spinner-border-sm me-2" aria-hidden="true" />
                Verificando a configuração inicial...
              </div>
            )}

            {!checkingSetup && setupError && (
              <div className="text-center" role="alert">
                <div className="alert alert-danger">{setupError}</div>
                <button type="button" className="btn btn-primary" onClick={() => void checkSetup()}>
                  <IconRefresh size={17} className="me-2" aria-hidden="true" />
                  Tentar novamente
                </button>
              </div>
            )}

            {!checkingSetup && !setupError && needsSetup !== null && (
              <form onSubmit={onSubmit} autoComplete="on" aria-busy={busy}>
                {needsSetup && (
                  <div className="mb-3">
                    <label className="form-label" htmlFor="admin-name">Nome</label>
                    <div className="input-icon">
                      <span className="input-icon-addon" aria-hidden="true">
                        <IconUser size={18} />
                      </span>
                      <input
                        id="admin-name"
                        className="form-control"
                        autoComplete="name"
                        placeholder="Seu nome"
                        value={name}
                        onChange={(event) => setName(event.target.value)}
                        required
                      />
                    </div>
                  </div>
                )}
                <div className="mb-3">
                  <label className="form-label" htmlFor="admin-email">E-mail</label>
                  <div className="input-icon">
                    <span className="input-icon-addon" aria-hidden="true">
                      <IconMail size={18} />
                    </span>
                    <input
                      id="admin-email"
                      className="form-control"
                      type="email"
                      autoComplete="email"
                      placeholder="seu@email.com"
                      value={email}
                      onChange={(event) => setEmail(event.target.value)}
                      required
                    />
                  </div>
                </div>
                <div className="mb-2">
                  <label className="form-label" htmlFor="admin-password">Senha</label>
                  <div className="input-icon">
                    <span className="input-icon-addon" aria-hidden="true">
                      <IconLock size={18} />
                    </span>
                    <input
                      id="admin-password"
                      className="form-control"
                      type="password"
                      autoComplete={needsSetup ? "new-password" : "current-password"}
                      placeholder="Sua senha"
                      value={password}
                      onChange={(event) => setPassword(event.target.value)}
                      required
                    />
                  </div>
                </div>
                {submitError && (
                  <div className="alert alert-danger mt-3 mb-0 py-2" role="alert">
                    {submitError}
                  </div>
                )}
                <div className="form-footer">
                  <button type="submit" className="btn btn-primary w-100" disabled={busy || needsSetup === null}>
                    {busy ? "Aguarde..." : needsSetup ? "Criar e entrar" : "Entrar"}
                  </button>
                </div>
              </form>
            )}
          </div>
        </div>
        <div className="text-center mt-3" style={{ color: "#7884a0", fontSize: 12 }}>
          © {new Date().getFullYear()} Namoro Cristão
        </div>
      </div>
    </div>
  );
}
