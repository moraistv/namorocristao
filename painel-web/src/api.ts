export const API_BASE =
  (import.meta.env.VITE_API_BASE as string | undefined)?.replace(/\/$/, "") ||
  "http://localhost:3333/api";

const ACCESS_KEY = "nc_admin_access";
const REFRESH_KEY = "nc_admin_refresh";
const SESSION_ID_KEY = "nc_admin_session_id";
const SESSION_SYNC_KEY = "nc_admin_session_sync";
const REQUEST_TIMEOUT_MS = 15_000;

let tokenRevision = 0;
let sessionGeneration = 0;
let sessionExpiredNotified = false;

interface RefreshFlight {
  generation: number;
  sessionId: string | null;
  refreshToken: string;
  promise: Promise<void>;
}

interface TokenSnapshot {
  access: string | null;
  refresh: string | null;
  sessionId: string | null;
  generation: number;
}

let refreshFlight: RefreshFlight | null = null;
const sessionExpiredListeners = new Set<() => void>();

function randomId(): string {
  if (typeof crypto !== "undefined" && typeof crypto.randomUUID === "function") {
    return crypto.randomUUID();
  }

  const bytes = new Uint8Array(16);
  if (typeof crypto !== "undefined" && typeof crypto.getRandomValues === "function") {
    crypto.getRandomValues(bytes);
    return Array.from(bytes, (byte) => byte.toString(16).padStart(2, "0")).join("");
  }

  return `${Date.now().toString(36)}-${Math.random().toString(36).slice(2)}-${Math.random()
    .toString(36)
    .slice(2)}`;
}

function announceSessionChange(kind: "establish" | "rotate" | "clear"): void {
  localStorage.setItem(
    SESSION_SYNC_KEY,
    JSON.stringify({ kind, id: randomId(), at: Date.now() })
  );
}

function currentSnapshot(): TokenSnapshot {
  return {
    access: localStorage.getItem(ACCESS_KEY),
    refresh: localStorage.getItem(REFRESH_KEY),
    sessionId: localStorage.getItem(SESSION_ID_KEY),
    generation: sessionGeneration,
  };
}

function sameSession(snapshot: TokenSnapshot): boolean {
  return (
    snapshot.generation === sessionGeneration &&
    snapshot.sessionId === localStorage.getItem(SESSION_ID_KEY)
  );
}

export type StorageSessionChange = "ignore" | "rotate" | "session";

export const tokens = {
  get access() {
    return localStorage.getItem(ACCESS_KEY);
  },
  get refresh() {
    return localStorage.getItem(REFRESH_KEY);
  },
  get sessionId() {
    return localStorage.getItem(SESSION_ID_KEY);
  },
  capture: currentSnapshot,
  isCurrent: sameSession,
  ensureSessionIdentity() {
    if (!this.access && !this.refresh) return null;
    const existing = this.sessionId;
    if (existing) return existing;

    const sessionId = randomId();
    localStorage.setItem(SESSION_ID_KEY, sessionId);
    announceSessionChange("establish");
    return sessionId;
  },
  save(access: string, refresh: string) {
    // O identificador muda antes dos tokens para impedir replay cruzado entre contas/abas.
    localStorage.setItem(SESSION_ID_KEY, randomId());
    localStorage.setItem(ACCESS_KEY, access);
    localStorage.setItem(REFRESH_KEY, refresh);
    tokenRevision += 1;
    sessionGeneration += 1;
    sessionExpiredNotified = false;
    announceSessionChange("establish");
  },
  rotate(access: string, refresh: string, expected: TokenSnapshot): boolean {
    if (!sameSession(expected) || localStorage.getItem(REFRESH_KEY) !== expected.refresh) {
      return false;
    }

    if (!localStorage.getItem(SESSION_ID_KEY)) {
      localStorage.setItem(SESSION_ID_KEY, randomId());
    }
    localStorage.setItem(ACCESS_KEY, access);
    localStorage.setItem(REFRESH_KEY, refresh);
    tokenRevision += 1;
    sessionExpiredNotified = false;
    announceSessionChange("rotate");
    return true;
  },
  clear() {
    // A identidade some primeiro para invalidar imediatamente operações em voo.
    localStorage.removeItem(SESSION_ID_KEY);
    localStorage.removeItem(ACCESS_KEY);
    localStorage.removeItem(REFRESH_KEY);
    tokenRevision += 1;
    sessionGeneration += 1;
    announceSessionChange("clear");
  },
  handleStorageEvent(event: StorageEvent): StorageSessionChange {
    if (event.storageArea !== localStorage || event.key !== SESSION_SYNC_KEY) {
      return "ignore";
    }

    let kind: unknown;
    try {
      kind = event.newValue ? (JSON.parse(event.newValue) as { kind?: unknown }).kind : null;
    } catch {
      kind = null;
    }

    tokenRevision += 1;
    if (kind === "rotate") return "rotate";

    sessionGeneration += 1;
    sessionExpiredNotified = false;
    return "session";
  },
};

export type ApiErrorCode =
  | "HTTP"
  | "NETWORK"
  | "TIMEOUT"
  | "ABORTED"
  | "INVALID_RESPONSE"
  | "SESSION_EXPIRED";

export class ApiError extends Error {
  status: number;
  code: ApiErrorCode;

  constructor(message: string, status: number, code: ApiErrorCode = "HTTP") {
    super(message);
    this.name = "ApiError";
    this.status = status;
    this.code = code;
  }
}

export type ApiRequestOptions = RequestInit & {
  /** Tempo máximo desta tentativa. `null` desativa o timeout do cliente. */
  timeoutMs?: number | null;
  /** Define se a chamada usa autenticação/refresh. O padrão é `true`. */
  auth?: boolean;
};

export type ApiHelperOptions = Omit<ApiRequestOptions, "method" | "body">;

/** Assina a expiração definitiva da sessão. Retorna a função de cancelamento. */
export function onSessionExpired(listener: () => void): () => void {
  sessionExpiredListeners.add(listener);
  return () => sessionExpiredListeners.delete(listener);
}

function expireSession(expected: TokenSnapshot): boolean {
  if (!sameSession(expected)) return false;

  tokens.clear();
  if (sessionExpiredNotified) return true;

  sessionExpiredNotified = true;
  sessionExpiredListeners.forEach((listener) => {
    try {
      listener();
    } catch {
      // Um consumidor não deve impedir a notificação dos demais.
    }
  });
  return true;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}

function responseErrorMessage(data: unknown, status: number): string {
  if (isRecord(data)) {
    if (typeof data.error === "string" && data.error.trim()) return data.error;
    if (typeof data.message === "string" && data.message.trim()) return data.message;
  }
  return `Erro ${status}`;
}

function createRequestAbortSignal(
  source: AbortSignal | null | undefined,
  timeoutMs: number | null
) {
  const controller = new AbortController();
  let timedOut = false;
  let timeoutId: number | null = null;

  if (timeoutMs !== null) {
    const safeTimeout = Number.isFinite(timeoutMs) && timeoutMs >= 0
      ? timeoutMs
      : REQUEST_TIMEOUT_MS;
    timeoutId = window.setTimeout(() => {
      timedOut = true;
      controller.abort();
    }, safeTimeout);
  }

  const abortFromSource = () => controller.abort();
  if (source?.aborted) {
    controller.abort();
  } else {
    source?.addEventListener("abort", abortFromSource, { once: true });
  }

  return {
    signal: controller.signal,
    didTimeOut: () => timedOut,
    cleanup: () => {
      if (timeoutId !== null) window.clearTimeout(timeoutId);
      source?.removeEventListener("abort", abortFromSource);
    },
  };
}

async function rawRequest<T>(
  path: string,
  options: ApiRequestOptions,
  withAuth: boolean,
  accessToken: string | null = withAuth ? tokens.access : null
): Promise<T> {
  // Campos do cliente são removidos antes de chegar ao fetch.
  const {
    timeoutMs = REQUEST_TIMEOUT_MS,
    auth: _auth,
    signal: sourceSignal,
    ...fetchOptions
  } = options;
  const headers = new Headers(fetchOptions.headers);
  if (!headers.has("Accept")) headers.set("Accept", "application/json");
  if (typeof fetchOptions.body === "string" && !headers.has("Content-Type")) {
    headers.set("Content-Type", "application/json");
  }
  if (withAuth && accessToken) {
    headers.set("Authorization", `Bearer ${accessToken}`);
  }

  const requestAbort = createRequestAbortSignal(sourceSignal, timeoutMs);

  try {
    const response = await fetch(`${API_BASE}${path}`, {
      ...fetchOptions,
      headers,
      signal: requestAbort.signal,
    });
    const text = await response.text();
    let data: unknown = {};

    if (text.trim()) {
      try {
        data = JSON.parse(text) as unknown;
      } catch {
        const message = response.ok
          ? "O servidor retornou uma resposta inválida."
          : response.status >= 500
            ? "O serviço está temporariamente indisponível."
            : `Erro ${response.status}`;
        throw new ApiError(message, response.status, "INVALID_RESPONSE");
      }
    }

    if (!response.ok) {
      throw new ApiError(responseErrorMessage(data, response.status), response.status);
    }

    return data as T;
  } catch (error: unknown) {
    if (error instanceof ApiError) throw error;

    if (requestAbort.didTimeOut()) {
      throw new ApiError(
        "A solicitação demorou demais. Tente novamente.",
        0,
        "TIMEOUT"
      );
    }

    if (requestAbort.signal.aborted) {
      throw new ApiError("A solicitação foi cancelada.", 0, "ABORTED");
    }

    throw new ApiError(
      "Não foi possível conectar ao servidor. Verifique sua conexão.",
      0,
      "NETWORK"
    );
  } finally {
    requestAbort.cleanup();
  }
}

function changedSessionError(): ApiError {
  return new ApiError(
    "A sessão mudou enquanto a solicitação estava em andamento.",
    0,
    "ABORTED"
  );
}

function refreshAccessToken(expected: TokenSnapshot): Promise<void> {
  const refreshToken = expected.refresh;
  if (!refreshToken) {
    return Promise.reject(
      new ApiError("Sua sessão expirou. Entre novamente.", 401, "SESSION_EXPIRED")
    );
  }
  if (!sameSession(expected)) return Promise.reject(changedSessionError());

  if (
    refreshFlight &&
    refreshFlight.generation === expected.generation &&
    refreshFlight.sessionId === expected.sessionId &&
    refreshFlight.refreshToken === refreshToken
  ) {
    return refreshFlight.promise;
  }

  const revisionAtStart = tokenRevision;
  const flight: RefreshFlight = {
    generation: expected.generation,
    sessionId: expected.sessionId,
    refreshToken,
    promise: Promise.resolve(),
  };

  flight.promise = (async () => {
    const response = await rawRequest<unknown>(
      "/admin/auth/refresh",
      {
        method: "POST",
        body: JSON.stringify({ refreshToken }),
      },
      false
    );

    if (
      !isRecord(response) ||
      typeof response.accessToken !== "string" ||
      !response.accessToken ||
      typeof response.refreshToken !== "string" ||
      !response.refreshToken
    ) {
      // Somente uma resposta 2xx realmente inválida é terminal por formato.
      throw new ApiError(
        "O servidor retornou uma sessão inválida.",
        200,
        "INVALID_RESPONSE"
      );
    }

    if (
      tokenRevision !== revisionAtStart ||
      !sameSession(expected) ||
      tokens.refresh !== refreshToken
    ) {
      throw changedSessionError();
    }

    if (!tokens.rotate(response.accessToken, response.refreshToken, expected)) {
      throw changedSessionError();
    }
  })().finally(() => {
    if (refreshFlight === flight) refreshFlight = null;
  });

  refreshFlight = flight;
  return flight.promise;
}

function isTerminalRefreshFailure(error: unknown): boolean {
  return (
    error instanceof ApiError &&
    (error.status === 400 ||
      error.status === 401 ||
      error.status === 403 ||
      error.code === "SESSION_EXPIRED" ||
      (error.code === "INVALID_RESPONSE" && error.status >= 200 && error.status < 300))
  );
}

/** Faz no máximo uma renovação e uma repetição da requisição original. */
export async function api<T = any>(
  path: string,
  options: ApiRequestOptions = {},
  withAuthOverride?: boolean
): Promise<T> {
  const withAuth = withAuthOverride ?? options.auth ?? true;
  const sessionAtStart = currentSnapshot();
  const accessTokenAtStart = withAuth ? sessionAtStart.access : null;

  try {
    return await rawRequest<T>(path, options, withAuth, accessTokenAtStart);
  } catch (error: unknown) {
    if (!(error instanceof ApiError) || error.status !== 401 || !withAuth) {
      throw error;
    }

    if (!sameSession(sessionAtStart)) throw changedSessionError();

    if (!tokens.refresh) {
      if (expireSession(sessionAtStart)) {
        throw new ApiError(
          "Sua sessão expirou. Entre novamente.",
          401,
          "SESSION_EXPIRED"
        );
      }
      throw changedSessionError();
    }

    try {
      // Outra requisição/aba pode ter concluído o refresh antes deste 401 chegar.
      if (!tokens.access || tokens.access === accessTokenAtStart) {
        await refreshAccessToken({ ...sessionAtStart, refresh: tokens.refresh });
      }
    } catch (refreshError: unknown) {
      if (!sameSession(sessionAtStart)) throw changedSessionError();

      const tokenWasRotated = Boolean(
        tokens.access && tokens.access !== accessTokenAtStart
      );
      if (!tokenWasRotated) {
        if (isTerminalRefreshFailure(refreshError)) {
          if (expireSession(sessionAtStart)) {
            throw new ApiError(
              "Sua sessão expirou. Entre novamente.",
              401,
              "SESSION_EXPIRED"
            );
          }
          throw changedSessionError();
        }
        throw refreshError;
      }
    }

    if (!sameSession(sessionAtStart)) throw changedSessionError();

    try {
      return await rawRequest<T>(path, options, true, tokens.access);
    } catch (retryError: unknown) {
      if (retryError instanceof ApiError && retryError.status === 401) {
        if (expireSession(sessionAtStart)) {
          throw new ApiError(
            "Sua sessão expirou. Entre novamente.",
            401,
            "SESSION_EXPIRED"
          );
        }
        throw changedSessionError();
      }
      throw retryError;
    }
  }
}

export const get = <T = any>(path: string, options: ApiHelperOptions = {}) =>
  api<T>(path, { ...options, method: "GET" });

export const post = <T = any>(
  path: string,
  body?: unknown,
  options: ApiHelperOptions = {}
) =>
  api<T>(path, {
    ...options,
    method: "POST",
    body: body === undefined ? undefined : JSON.stringify(body),
  });

export const put = <T = any>(
  path: string,
  body?: unknown,
  options: ApiHelperOptions = {}
) =>
  api<T>(path, {
    ...options,
    method: "PUT",
    body: body === undefined ? undefined : JSON.stringify(body),
  });

export const del = <T = any>(path: string, options: ApiHelperOptions = {}) =>
  api<T>(path, { ...options, method: "DELETE" });
