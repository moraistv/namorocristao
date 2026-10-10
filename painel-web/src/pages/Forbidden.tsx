import { IconLockAccess } from "@tabler/icons-react";
import { Link, useLocation } from "react-router-dom";

interface ForbiddenState {
  from?: string;
}

export default function Forbidden() {
  const location = useLocation();
  const state = location.state as ForbiddenState | null;

  return (
    <div className="forbidden-page">
      <div className="card forbidden-card" role="alert">
        <div className="card-body text-center">
          <span className="forbidden-icon" aria-hidden="true">
            <IconLockAccess size={34} />
          </span>
          <div className="page-pretitle mt-3">Erro 403</div>
          <h1 className="h2 mt-1">Acesso não autorizado</h1>
          <p className="text-secondary mx-auto">
            Sua conta administrativa não possui permissão para acessar este recurso.
            {state?.from ? " Volte ao painel ou escolha outro módulo no menu." : ""}
          </p>
          <Link className="btn btn-primary" to="/" replace>
            Voltar ao Dashboard
          </Link>
        </div>
      </div>
    </div>
  );
}
