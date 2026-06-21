import {
  createContext,
  useContext,
  useEffect,
  useState,
  ReactNode,
} from "react";
import { get, post, tokens } from "./api";

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
  login: (email: string, password: string) => Promise<void>;
  registerSuper: (name: string, email: string, password: string) => Promise<void>;
  logout: () => void;
}

const Ctx = createContext<AuthCtx>(null as any);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [admin, setAdmin] = useState<Admin | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    (async () => {
      if (tokens.access) {
        try {
          const r = await get("/admin/auth/me");
          setAdmin(r.admin);
        } catch {
          tokens.clear();
        }
      }
      setLoading(false);
    })();
  }, []);

  async function login(email: string, password: string) {
    const r = await post("/admin/auth/login", { email, password });
    tokens.save(r.accessToken, r.refreshToken);
    setAdmin(r.admin);
  }

  async function registerSuper(name: string, email: string, password: string) {
    const r = await post("/admin/auth/register-super", { name, email, password });
    tokens.save(r.accessToken, r.refreshToken);
    setAdmin(r.admin);
  }

  function logout() {
    tokens.clear();
    setAdmin(null);
  }

  return (
    <Ctx.Provider value={{ admin, loading, login, registerSuper, logout }}>
      {children}
    </Ctx.Provider>
  );
}

export const useAuth = () => useContext(Ctx);
