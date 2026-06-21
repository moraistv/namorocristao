export const API_BASE =
  (import.meta.env.VITE_API_BASE as string | undefined)?.replace(/\/$/, "") ||
  "http://localhost:3333/api";

const ACCESS_KEY = "nc_admin_access";
const REFRESH_KEY = "nc_admin_refresh";

export const tokens = {
  get access() {
    return localStorage.getItem(ACCESS_KEY);
  },
  get refresh() {
    return localStorage.getItem(REFRESH_KEY);
  },
  save(access: string, refresh: string) {
    localStorage.setItem(ACCESS_KEY, access);
    localStorage.setItem(REFRESH_KEY, refresh);
  },
  clear() {
    localStorage.removeItem(ACCESS_KEY);
    localStorage.removeItem(REFRESH_KEY);
  },
};

export class ApiError extends Error {
  status: number;
  constructor(message: string, status: number) {
    super(message);
    this.status = status;
  }
}

async function rawRequest(
  path: string,
  options: RequestInit,
  withAuth: boolean
): Promise<any> {
  const headers: Record<string, string> = {
    "Content-Type": "application/json",
    ...(options.headers as Record<string, string>),
  };
  if (withAuth && tokens.access) {
    headers.Authorization = `Bearer ${tokens.access}`;
  }

  const res = await fetch(`${API_BASE}${path}`, { ...options, headers });
  const text = await res.text();
  const json = text ? JSON.parse(text) : {};

  if (!res.ok) {
    throw new ApiError(json.error || `Erro ${res.status}`, res.status);
  }
  return json;
}

/** Faz a requisição, tentando refresh do token uma vez em caso de 401. */
export async function api(
  path: string,
  options: RequestInit = {},
  withAuth = true
): Promise<any> {
  try {
    return await rawRequest(path, options, withAuth);
  } catch (e) {
    if (e instanceof ApiError && e.status === 401 && withAuth && tokens.refresh) {
      // tenta renovar
      try {
        const r = await rawRequest(
          "/admin/auth/refresh",
          { method: "POST", body: JSON.stringify({ refreshToken: tokens.refresh }) },
          false
        );
        tokens.save(r.accessToken, r.refreshToken);
        return await rawRequest(path, options, true);
      } catch {
        tokens.clear();
        throw e;
      }
    }
    throw e;
  }
}

export const get = (path: string) => api(path, { method: "GET" });
export const post = (path: string, body?: unknown) =>
  api(path, { method: "POST", body: body ? JSON.stringify(body) : undefined });
export const put = (path: string, body?: unknown) =>
  api(path, { method: "PUT", body: body ? JSON.stringify(body) : undefined });
export const del = (path: string) => api(path, { method: "DELETE" });
