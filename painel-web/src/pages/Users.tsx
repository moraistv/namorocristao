import {
  useCallback,
  useEffect,
  useRef,
  useState,
  type FormEvent,
} from "react";
import { useNavigate } from "react-router-dom";
import {
  IconSearch,
  IconInfoCircle,
  IconBan,
  IconClockPause,
  IconMail,
  IconChevronLeft,
  IconChevronRight,
  IconRefresh,
  IconX,
} from "@tabler/icons-react";
import { del, get, post } from "../api";
import { useAuth } from "../auth";
import { Dialog, type DialogConfig, Toast, type ToastMsg } from "../components/ui";

const PAGE_SIZE = 25;

/** Logo "G" do Google (multicolor) para indicar login via Google. */
function GoogleG({ size = 15 }: { size?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 48 48" aria-hidden="true">
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

interface UsersResponse {
  users?: UserRow[];
  total?: number;
}

const GENDER_PT: Record<string, string> = {
  MALE: "Masculino",
  FEMALE: "Feminino",
  OTHER: "Outro",
};

function genderLabel(gender?: string): string {
  return gender ? GENDER_PT[gender] ?? gender : "—";
}

function errorMessage(error: unknown): string {
  return error instanceof Error ? error.message : "Não foi possível carregar os usuários.";
}

function visiblePages(current: number, total: number): number[] {
  const length = Math.min(5, total);
  const start = Math.max(1, Math.min(current - 2, total - length + 1));
  return Array.from({ length }, (_, index) => start + index);
}

export default function Users() {
  const navigate = useNavigate();
  const { admin } = useAuth();
  const canModerate = Boolean(
    admin && (admin.isSuperAdmin || admin.permissions.includes("REPORT"))
  );
  const requestIdRef = useRef(0);
  const [users, setUsers] = useState<UserRow[]>([]);
  const [total, setTotal] = useState(0);
  const [searchInput, setSearchInput] = useState("");
  const [appliedSearch, setAppliedSearch] = useState("");
  const [page, setPage] = useState(1);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [dialog, setDialog] = useState<DialogConfig | null>(null);
  const [toast, setToast] = useState<ToastMsg | null>(null);

  const load = useCallback(async () => {
    const requestId = ++requestIdRef.current;
    setLoading(true);
    setError("");

    const params = new URLSearchParams({
      skip: String((page - 1) * PAGE_SIZE),
      take: String(PAGE_SIZE),
    });
    if (appliedSearch) params.set("search", appliedSearch);

    try {
      const response = await get<UsersResponse>(`/admin/users?${params.toString()}`);
      if (requestId !== requestIdRef.current) return;

      const nextUsers = Array.isArray(response.users) ? response.users : [];
      const nextTotal =
        typeof response.total === "number" && Number.isFinite(response.total)
          ? Math.max(0, Math.trunc(response.total))
          : 0;
      const nextTotalPages = Math.max(1, Math.ceil(nextTotal / PAGE_SIZE));

      setTotal(nextTotal);
      if (page > nextTotalPages) {
        setPage(nextTotalPages);
        return;
      }
      setUsers(nextUsers);
    } catch (loadError: unknown) {
      if (requestId === requestIdRef.current) {
        setError(errorMessage(loadError));
      }
    } finally {
      if (requestId === requestIdRef.current) setLoading(false);
    }
  }, [appliedSearch, page]);

  useEffect(() => {
    void load();
    return () => {
      requestIdRef.current += 1;
    };
  }, [load]);

  function submitSearch(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const nextSearch = searchInput.trim();

    if (nextSearch === appliedSearch && page === 1) {
      void load();
      return;
    }

    setPage(1);
    setAppliedSearch(nextSearch);
  }

  function clearSearch() {
    setSearchInput("");
    if (!appliedSearch && page === 1) return;
    setPage(1);
    setAppliedSearch("");
  }

  async function act(action: () => Promise<unknown>, message: string): Promise<void> {
    try {
      await action();
      setToast({ type: "success", text: message });
      await load();
    } catch (actionError: unknown) {
      setToast({
        type: "error",
        text: actionError instanceof Error ? actionError.message : "Falha na ação",
      });
      throw actionError;
    }
  }

  function toggleBan(user: UserRow) {
    if (!canModerate) return;
    if (user.isBanned) {
      setDialog({
        title: "Desbanir usuário",
        message: `Liberar o acesso de ${user.fullName}?`,
        icon: IconBan,
        confirmText: "Desbanir",
        onConfirm: () => act(
          () => del<void>(`/admin/users/${user.userId}/ban`),
          "Usuário desbanido"
        ),
      });
      return;
    }

    setDialog({
      title: "Banir usuário",
      message: `Banimento permanente de ${user.fullName}.`,
      icon: IconBan,
      danger: true,
      confirmText: "Banir",
      input: { label: "Motivo (opcional)", placeholder: "Ex.: conteúdo impróprio" },
      onConfirm: (reason) => act(
        () => post<void>(`/admin/users/${user.userId}/ban`, { reason: reason || undefined }),
        "Usuário banido"
      ),
    });
  }

  function toggleSuspend(user: UserRow) {
    if (!canModerate) return;
    if (user.isSuspended) {
      setDialog({
        title: "Reativar conta",
        message: `Remover a suspensão de ${user.fullName}?`,
        icon: IconClockPause,
        confirmText: "Reativar",
        onConfirm: () => act(
          () => del<void>(`/admin/users/${user.userId}/suspend`),
          "Conta reativada"
        ),
      });
      return;
    }

    setDialog({
      title: "Suspender conta",
      message: `Banimento temporário de ${user.fullName}.`,
      icon: IconClockPause,
      danger: true,
      confirmText: "Suspender",
      input: { label: "Por quantos dias?", type: "number", default: "7" },
      onConfirm: (rawDays) => {
        const days = Math.max(1, Math.min(365, Number.parseInt(rawDays, 10) || 7));
        return act(
          () => post<void>(`/admin/users/${user.userId}/suspend`, { days }),
          `Suspenso por ${days} dia(s)`
        );
      },
    });
  }

  const totalPages = Math.max(1, Math.ceil(total / PAGE_SIZE));
  const firstResult = total > 0 ? (page - 1) * PAGE_SIZE + 1 : 0;
  const lastResult = Math.min(page * PAGE_SIZE, total);

  return (
    <>
      <div className="page-heading">
        <div>
          <div className="page-pretitle">Gestão</div>
          <h1 className="page-title mb-0">Usuários</h1>
        </div>
        <span className="page-count" aria-live="polite">
          {appliedSearch ? `${total} resultado(s)` : `${total} cadastrado(s)`}
        </span>
      </div>

      {error && (
        <div className="alert alert-danger" role="alert">
          <div className="d-flex flex-wrap align-items-center justify-content-between gap-2">
            <span>{error}</span>
            <button type="button" className="btn btn-sm" onClick={() => void load()}>
              <IconRefresh size={16} className="me-1" aria-hidden="true" />
              Tentar novamente
            </button>
          </div>
        </div>
      )}

      <div className="card" aria-busy={loading}>
        <div className="card-body border-bottom py-3">
          <form className="user-toolbar" role="search" onSubmit={submitSearch}>
            <div className="user-search">
              <label className="form-label visually-hidden" htmlFor="user-search">
                Buscar usuários por nome ou cidade
              </label>
              <div className="input-icon">
                <span className="input-icon-addon" aria-hidden="true">
                  <IconSearch size={18} />
                </span>
                <input
                  id="user-search"
                  type="search"
                  className="form-control"
                  placeholder="Buscar por nome ou cidade..."
                  value={searchInput}
                  onChange={(event) => setSearchInput(event.target.value)}
                />
              </div>
            </div>
            <button type="submit" className="btn btn-primary" disabled={loading}>
              {loading && <span className="spinner-border spinner-border-sm me-2" aria-hidden="true" />}
              Buscar
            </button>
            {(searchInput || appliedSearch) && (
              <button type="button" className="btn" onClick={clearSearch}>
                <IconX size={16} className="me-1" aria-hidden="true" />
                Limpar
              </button>
            )}
          </form>
        </div>

        <div className="table-responsive">
          <table className="table table-vcenter card-table">
            <caption className="visually-hidden">
              Lista paginada de usuários administrativos
            </caption>
            <thead>
              <tr>
                <th>Nome</th>
                <th>E-mail</th>
                <th>Sexo</th>
                <th>Idade</th>
                <th>Cidade</th>
                <th>Status</th>
                <th className="text-end">Ações</th>
              </tr>
            </thead>
            <tbody>
              {loading && (
                <tr>
                  <td colSpan={7} className="table-state text-center text-secondary">
                    <div role="status" aria-live="polite">
                      <span className="spinner-border spinner-border-sm me-2" aria-hidden="true" />
                      Carregando usuários...
                    </div>
                  </td>
                </tr>
              )}

              {!loading && !error && users.length === 0 && (
                <tr>
                  <td colSpan={7} className="table-state text-center text-secondary">
                    {appliedSearch
                      ? "Nenhum usuário corresponde à busca."
                      : "Nenhum usuário cadastrado."}
                  </td>
                </tr>
              )}

              {!loading && users.map((user) => (
                <tr key={user.userId}>
                  <td className="fw-semibold">{user.fullName}</td>
                  <td className="text-secondary">
                    <span
                      className="d-inline-flex align-items-center gap-2"
                      title={user.provider === "GOOGLE" ? "Cadastro via Google" : "Cadastro via e-mail"}
                    >
                      {user.provider === "GOOGLE" ? (
                        <GoogleG />
                      ) : (
                        <IconMail size={15} aria-hidden="true" />
                      )}
                      {user.email}
                    </span>
                  </td>
                  <td className="text-secondary">{genderLabel(user.gender)}</td>
                  <td className="text-secondary">{user.age}</td>
                  <td className="text-secondary">{user.city || "—"}</td>
                  <td>
                    <div className="d-flex gap-1 flex-wrap">
                      {user.isOnline && <span className="badge bg-green-lt">Online</span>}
                      {user.isVerified && <span className="badge bg-yellow-lt">Verificado</span>}
                      {user.isSuspended && <span className="badge bg-orange-lt">Suspenso</span>}
                      {user.isBanned && <span className="badge bg-red-lt">Banido</span>}
                    </div>
                  </td>
                  <td>
                    <div className="user-actions">
                      <button
                        type="button"
                        className="btn btn-sm btn-primary"
                        onClick={() => navigate(`/usuarios/${user.userId}`)}
                        aria-label={`Ver informações de ${user.fullName}`}
                        title="Informações"
                      >
                        <IconInfoCircle size={15} aria-hidden="true" />
                        <span className="d-none d-xxl-inline ms-1">Informações</span>
                      </button>
                      {canModerate && (
                        <>
                          <button
                            type="button"
                            className={user.isSuspended ? "btn btn-sm" : "btn btn-sm btn-warning"}
                            onClick={() => toggleSuspend(user)}
                            aria-label={`${user.isSuspended ? "Reativar" : "Suspender"} ${user.fullName}`}
                            title={user.isSuspended ? "Reativar" : "Suspender"}
                          >
                            <IconClockPause size={15} aria-hidden="true" />
                            <span className="d-none d-xxl-inline ms-1">
                              {user.isSuspended ? "Reativar" : "Suspender"}
                            </span>
                          </button>
                          <button
                            type="button"
                            className={user.isBanned ? "btn btn-sm" : "btn btn-sm btn-danger"}
                            onClick={() => toggleBan(user)}
                            aria-label={`${user.isBanned ? "Desbanir" : "Banir"} ${user.fullName}`}
                            title={user.isBanned ? "Desbanir" : "Banir"}
                          >
                            <IconBan size={15} aria-hidden="true" />
                            <span className="d-none d-xxl-inline ms-1">
                              {user.isBanned ? "Desbanir" : "Banir"}
                            </span>
                          </button>
                        </>
                      )}
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        {!loading && !error && total > 0 && (
          <div className="pagination-shell">
            <div className="pagination-meta" aria-live="polite">
              Mostrando {firstResult}–{lastResult} de {total}
            </div>
            <nav aria-label="Paginação de usuários">
              <ul className="pagination m-0">
                <li className={`page-item${page === 1 ? " disabled" : ""}`}>
                  <button
                    type="button"
                    className="page-link"
                    onClick={() => setPage((current) => Math.max(1, current - 1))}
                    disabled={page === 1}
                    aria-label="Página anterior"
                  >
                    <IconChevronLeft size={17} aria-hidden="true" />
                  </button>
                </li>
                {visiblePages(page, totalPages).map((pageNumber) => (
                  <li
                    className={`page-item pagination-number${pageNumber === page ? " active" : ""}${Math.abs(pageNumber - page) > 1 ? " pagination-number-narrow-hidden" : ""}`}
                    key={pageNumber}
                  >
                    <button
                      type="button"
                      className="page-link"
                      onClick={() => setPage(pageNumber)}
                      aria-label={`Ir para a página ${pageNumber}`}
                      aria-current={pageNumber === page ? "page" : undefined}
                    >
                      {pageNumber}
                    </button>
                  </li>
                ))}
                <li className={`page-item${page === totalPages ? " disabled" : ""}`}>
                  <button
                    type="button"
                    className="page-link"
                    onClick={() => setPage((current) => Math.min(totalPages, current + 1))}
                    disabled={page === totalPages}
                    aria-label="Próxima página"
                  >
                    <IconChevronRight size={17} aria-hidden="true" />
                  </button>
                </li>
              </ul>
            </nav>
          </div>
        )}
      </div>

      <Dialog config={dialog} onClose={() => setDialog(null)} />
      <Toast toast={toast} onClose={() => setToast(null)} />
    </>
  );
}
