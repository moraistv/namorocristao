import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useRef,
  useState,
  type ReactNode,
} from "react";
import { ApiError, get, onSessionExpired, post, tokens } from "./api";

export interface Admin {
  id: string;
  name: string;
  email: string;
  permissions: string[];
  isSuperAdmin: boolean;
}

interface AuthCtx {
  admin: Admin | null;
  loading: boolean;
  sessionError: string | null;
  retrySession: () => void;
  login: (email: string, password: string) => Promise<void>;
  registerSuper: (name: string, email: string, password: string) => Promise<void>;
  logout: () => void;
}

interface AuthSession {
  admin: Admin;
  accessToken: string;
  refreshToken: string;
}

const Ctx = createContext<AuthCtx | undefined>(undefined);

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}

function normalizeAdmin(value: unknown): Admin | null {
  if (
    !isRecord(value) ||
    typeof value.id !== "string" ||
    typeof value.name !== "string" ||
    typeof value.email !== "string"
  ) {
    return null;
  }

  const permissions = Array.isArray(value.permissions)
    ? value.permissions.filter(
        (permission): permission is string => typeof permission === "string"
      )
    : [];

  return {
    id: value.id,
    name: value.name,
    email: value.email,
    permissions,
    isSuperAdmin: value.isSuperAdmin === true,
  };
}

function normalizeAuthSession(value: unknown): AuthSession {
  if (!isRecord(value)) {
    throw new ApiError("Resposta de autenticação inválida.", 0, "INVALID_RESPONSE");
  }

  const admin = normalizeAdmin(value.admin);
  if (
    !admin ||
    typeof value.accessToken !== "string" ||
    !value.accessToken ||
    typeof value.refreshToken !== "string" ||
    !value.refreshToken
  ) {
    throw new ApiError("Resposta de autenticação inválida.", 0, "INVALID_RESPONSE");
  }

  return {
    admin,
    accessToken: value.accessToken,
    refreshToken: value.refreshToken,
  };
}

function bootstrapErrorMessage(error: unknown): string {
  if (error instanceof ApiError) {
    if (error.status >= 500 || error.code === "INVALID_RESPONSE") {
      return "O painel não conseguiu validar sua sessão porque o serviço está indisponível ou retornou uma resposta inesperada.";
    }
    return error.message;
  }
  return "O painel não conseguiu validar sua sessão. Verifique sua conexão e tente novamente.";
}

function changedSessionError(): ApiError {
  return new ApiError(
    "A sessão mudou enquanto a autenticação estava em andamento.",
    0,
    "ABORTED"
  );
}

export function AuthProvider({ children }: { children: ReactNode }) {
  const [admin, setAdmin] = useState<Admin | null>(null);
  const [loading, setLoading] = useState(true);
  const [sessionError, setSessionError] = useState<string | null>(null);
  const [bootstrapKey, setBootstrapKey] = useState(0);
  const bootstrapOperationRef = useRef(0);

  useEffect(() => {
    const unsubscribe = onSessionExpired(() => {
      bootstrapOperationRef.current += 1;
      setAdmin(null);
      setSessionError(null);
      setLoading(false);
    });
    return () => {
      unsubscribe();
    };
  }, []);

  useEffect(() => {
    const handleStorage = (event: StorageEvent) => {
      const change = tokens.handleStorageEvent(event);
      if (change !== "session") return;

      bootstrapOperationRef.current += 1;
      setAdmin(null);
      setSessionError(null);
      setLoading(true);
      setBootstrapKey((key) => key + 1);
    };

    window.addEventListener("storage", handleStorage);
    return () => window.removeEventListener("storage", handleStorage);
  }, []);

  useEffect(() => {
    let active = true;
    const operation = ++bootstrapOperationRef.current;
    const controller = new AbortController();

    const isCurrentOperation = () =>
      active && operation === bootstrapOperationRef.current;

    const bootstrap = async () => {
      if (!tokens.access && !tokens.refresh) {
        if (isCurrentOperation()) {
          setAdmin(null);
          setSessionError(null);
          setLoading(false);
        }
        return;
      }

      tokens.ensureSessionIdentity();
      const sessionAtStart = tokens.capture();
      setAdmin(null);
      setSessionError(null);
      setLoading(true);

      try {
        // Com apenas refresh token, o 401 inicial aciona o refresh single-flight.
        const response = await get<unknown>("/admin/auth/me", {
          signal: controller.signal,
        });
        if (!isCurrentOperation() || !tokens.isCurrent(sessionAtStart)) return;

        const nextAdmin = isRecord(response) ? normalizeAdmin(response.admin) : null;
        if (!nextAdmin) {
          // Uma resposta 2xx inválida de /me não destrói credenciais recuperáveis.
          throw new ApiError(
            "O servidor retornou uma sessão administrativa inválida.",
            200,
            "INVALID_RESPONSE"
          );
        }
        setAdmin(nextAdmin);
      } catch (error: unknown) {
        if (!isCurrentOperation() || !tokens.isCurrent(sessionAtStart)) return;

        if (error instanceof ApiError && error.code === "SESSION_EXPIRED") {
          setAdmin(null);
          setSessionError(null);
        } else if (!(error instanceof ApiError && error.code === "ABORTED")) {
          // Rede, timeout, gateway/5xx e HTML inesperado preservam ambos os tokens.
          setAdmin(null);
          setSessionError(bootstrapErrorMessage(error));
        }
      } finally {
        if (isCurrentOperation()) setLoading(false);
      }
    };

    void bootstrap();

    return () => {
      active = false;
      controller.abort();
    };
  }, [bootstrapKey]);

  const applySession = useCallback(
    (response: unknown, expectedSession: ReturnType<typeof tokens.capture>) => {
      const session = normalizeAuthSession(response);
      if (!tokens.isCurrent(expectedSession)) throw changedSessionError();

      tokens.save(session.accessToken, session.refreshToken);
      setAdmin(session.admin);
      setSessionError(null);
      setLoading(false);
    },
    []
  );

  const login = useCallback(
    async (email: string, password: string) => {
      const expectedSession = tokens.capture();
      const response = await post<unknown>(
        "/admin/auth/login",
        { email, password },
        { auth: false }
      );
      applySession(response, expectedSession);
    },
    [applySession]
  );

  const registerSuper = useCallback(
    async (name: string, email: string, password: string) => {
      const expectedSession = tokens.capture();
      const response = await post<unknown>(
        "/admin/auth/register-super",
        { name, email, password },
        { auth: false }
      );
      applySession(response, expectedSession);
    },
    [applySession]
  );

  const retrySession = useCallback(() => {
    bootstrapOperationRef.current += 1;
    setSessionError(null);
    setLoading(true);
    setBootstrapKey((key) => key + 1);
  }, []);

  const logout = useCallback(() => {
    bootstrapOperationRef.current += 1;
    tokens.clear();
    setAdmin(null);
    setSessionError(null);
    setLoading(false);
  }, []);

  const value = useMemo<AuthCtx>(
    () => ({
      admin,
      loading,
      sessionError,
      retrySession,
      login,
      registerSuper,
      logout,
    }),
    [
      admin,
      loading,
      sessionError,
      retrySession,
      login,
      registerSuper,
      logout,
    ]
  );

  return <Ctx.Provider value={value}>{children}</Ctx.Provider>;
}

export function useAuth(): AuthCtx {
  const context = useContext(Ctx);
  if (!context) {
    throw new Error("useAuth deve ser usado dentro de AuthProvider.");
  }
  return context;
}
