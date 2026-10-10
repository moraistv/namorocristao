import {
  useEffect,
  useRef,
  useState,
  type ReactNode,
} from "react";
import { NavLink, useLocation } from "react-router-dom";
import {
  IconLayoutDashboard,
  IconUsers,
  IconRosetteDiscountCheck,
  IconFlag,
  IconBan,
  IconTrash,
  IconShieldCheck,
  IconSettings,
  IconLogout,
  IconHeart,
  IconAward,
  IconGift,
  IconSpeakerphone,
  IconBook2,
  IconBell,
  IconRobot,
  IconMessageChatbot,
  IconChartBar,
  IconMenu2,
  IconX,
} from "@tabler/icons-react";
import { useAuth } from "../auth";
import { get } from "../api";

const DASHBOARD_STATS_EVENT = "nc:dashboard-stats";
const DESKTOP_MEDIA = "(min-width: 992px)";
const FOCUSABLE_SELECTOR = [
  "a[href]",
  "button:not([disabled])",
  "input:not([disabled])",
  "select:not([disabled])",
  "textarea:not([disabled])",
  "[tabindex]:not([tabindex='-1'])",
].join(",");

type NavIcon = typeof IconLayoutDashboard;

interface NavItem {
  to: string;
  label: string;
  icon: NavIcon;
  end?: boolean;
  badge?: number;
}

interface NavGroup {
  label: string;
  items: NavItem[];
}

interface DashboardBadgeResponse {
  reports?: number;
  pendingVerifications?: number;
  deleteRequests?: number;
}

interface BadgeCounts {
  reports: number;
  verifications: number;
  deletions: number;
}

function safeCount(value: unknown): number {
  return typeof value === "number" && Number.isFinite(value)
    ? Math.max(0, Math.trunc(value))
    : 0;
}

function toBadgeCounts(stats: DashboardBadgeResponse): BadgeCounts {
  return {
    reports: safeCount(stats.reports),
    verifications: safeCount(stats.pendingVerifications),
    deletions: safeCount(stats.deleteRequests),
  };
}

function setBackgroundUnavailable(element: HTMLElement | null, unavailable: boolean) {
  if (!element) return;
  if (unavailable) {
    element.setAttribute("inert", "");
    element.setAttribute("aria-hidden", "true");
  } else {
    element.removeAttribute("inert");
    element.removeAttribute("aria-hidden");
  }
}

export default function Layout({ children }: { children: ReactNode }) {
  const { admin, logout } = useAuth();
  const location = useLocation();
  const menuButtonRef = useRef<HTMLButtonElement>(null);
  const sidebarRef = useRef<HTMLElement>(null);
  const mobileHeaderRef = useRef<HTMLElement>(null);
  const mainRef = useRef<HTMLElement>(null);
  const previousFocusRef = useRef<HTMLElement | null>(null);
  const [drawerOpen, setDrawerOpen] = useState(false);
  const [counts, setCounts] = useState<BadgeCounts>({
    reports: 0,
    verifications: 0,
    deletions: 0,
  });

  useEffect(() => {
    const receiveDashboardStats = (event: Event) => {
      const detail = (event as CustomEvent<DashboardBadgeResponse>).detail;
      if (detail) setCounts(toBadgeCounts(detail));
    };

    window.addEventListener(DASHBOARD_STATS_EVENT, receiveDashboardStats);
    return () => window.removeEventListener(DASHBOARD_STATS_EVENT, receiveDashboardStats);
  }, []);

  useEffect(() => {
    // Na home, o próprio Dashboard publica estes números e evita polling duplicado.
    if (location.pathname === "/") return;

    let active = true;
    let inFlight = false;

    const loadCounts = async () => {
      if (!active || inFlight || document.hidden) return;
      inFlight = true;
      try {
        const stats = await get<DashboardBadgeResponse>("/admin/dashboard");
        if (active) setCounts(toBadgeCounts(stats));
      } catch {
        // Badges mantêm o último valor; erros de sessão são tratados pelo AuthProvider.
      } finally {
        inFlight = false;
      }
    };

    const handleVisibility = () => {
      if (!document.hidden) void loadCounts();
    };

    void loadCounts();
    const timer = window.setInterval(() => void loadCounts(), 60_000);
    document.addEventListener("visibilitychange", handleVisibility);

    return () => {
      active = false;
      window.clearInterval(timer);
      document.removeEventListener("visibilitychange", handleVisibility);
    };
  }, [location.pathname]);

  useEffect(() => {
    setDrawerOpen(false);
  }, [location.pathname]);

  useEffect(() => {
    if (!drawerOpen) {
      const previousFocus = previousFocusRef.current;
      previousFocusRef.current = null;
      if (previousFocus?.isConnected) {
        window.requestAnimationFrame(() => previousFocus.focus());
      }
      return;
    }

    const desktopMedia = window.matchMedia(DESKTOP_MEDIA);
    if (desktopMedia.matches) {
      setDrawerOpen(false);
      return;
    }

    previousFocusRef.current =
      document.activeElement instanceof HTMLElement
        ? document.activeElement
        : menuButtonRef.current;

    document.body.classList.add("nav-drawer-open");
    setBackgroundUnavailable(mobileHeaderRef.current, true);
    setBackgroundUnavailable(mainRef.current, true);

    const sidebar = sidebarRef.current;
    const firstLink = sidebar?.querySelector<HTMLElement>(".sidebar-nav a[href]");
    (firstLink ?? sidebar)?.focus();

    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === "Escape") {
        event.preventDefault();
        setDrawerOpen(false);
        return;
      }
      if (event.key !== "Tab" || !sidebar) return;

      const focusable = Array.from(
        sidebar.querySelectorAll<HTMLElement>(FOCUSABLE_SELECTOR)
      ).filter((element) => !element.hasAttribute("disabled"));
      if (focusable.length === 0) {
        event.preventDefault();
        sidebar.focus();
        return;
      }

      const first = focusable[0];
      const last = focusable[focusable.length - 1];
      if (event.shiftKey && document.activeElement === first) {
        event.preventDefault();
        last.focus();
      } else if (!event.shiftKey && document.activeElement === last) {
        event.preventDefault();
        first.focus();
      }
    };

    const handleDesktop = (event: MediaQueryListEvent) => {
      if (event.matches) setDrawerOpen(false);
    };

    document.addEventListener("keydown", handleKeyDown);
    desktopMedia.addEventListener("change", handleDesktop);

    return () => {
      document.body.classList.remove("nav-drawer-open");
      setBackgroundUnavailable(mobileHeaderRef.current, false);
      setBackgroundUnavailable(mainRef.current, false);
      document.removeEventListener("keydown", handleKeyDown);
      desktopMedia.removeEventListener("change", handleDesktop);
    };
  }, [drawerOpen]);

  const hasPermission = (permission: string) =>
    Boolean(admin?.isSuperAdmin || admin?.permissions.includes(permission));
  const isSuperAdmin = admin?.isSuperAdmin === true;

  const groups: NavGroup[] = [
    {
      label: "Visão geral",
      items: [
        { to: "/", label: "Dashboard", icon: IconLayoutDashboard, end: true },
      ],
    },
    {
      label: "Comunidade",
      items: [
        { to: "/usuarios", label: "Usuários", icon: IconUsers },
        ...(hasPermission("VERIFICATION")
          ? [{
              to: "/verificacoes",
              label: "Verificações",
              icon: IconRosetteDiscountCheck,
              badge: counts.verifications,
            }]
          : []),
        ...(hasPermission("REPORT")
          ? [
              {
                to: "/denuncias",
                label: "Denúncias",
                icon: IconFlag,
                badge: counts.reports,
              },
              { to: "/banidos", label: "Banidos", icon: IconBan },
            ]
          : []),
        ...(hasPermission("ACCOUNT_DELETE")
          ? [{
              to: "/exclusoes",
              label: "Exclusões",
              icon: IconTrash,
              badge: counts.deletions,
            }]
          : []),
      ],
    },
    ...(isSuperAdmin
      ? [{
          label: "Negócio & conteúdo",
          items: [
            { to: "/recompensas", label: "Recompensas", icon: IconAward },
            { to: "/anuncios", label: "Anúncios", icon: IconSpeakerphone },
            { to: "/presentes", label: "Presentes", icon: IconGift },
            { to: "/versos", label: "Versos", icon: IconBook2 },
            { to: "/notificacoes", label: "Notificações", icon: IconBell },
          ],
        }]
      : []),
    {
      label: "Automação",
      items: [
        ...(isSuperAdmin
          ? [
              { to: "/modelos", label: "Modelos", icon: IconRobot },
              { to: "/chatbot/regras", label: "Regras do bot", icon: IconMessageChatbot },
            ]
          : []),
        { to: "/chatbot/analytics", label: "Analytics do bot", icon: IconChartBar },
      ],
    },
    ...(isSuperAdmin
      ? [{
          label: "Administração",
          items: [
            { to: "/admins", label: "Administradores", icon: IconShieldCheck },
            { to: "/configuracoes", label: "Configurações", icon: IconSettings },
          ],
        }]
      : []),
  ];

  const initials = admin?.name?.trim().charAt(0).toUpperCase() || "A";
  const closeDrawer = () => setDrawerOpen(false);

  return (
    <div className={`admin-shell${drawerOpen ? " sidebar-open" : ""}`}>
      <a className="skip-link" href="#main-content">Pular para o conteúdo</a>

      <header ref={mobileHeaderRef} className="mobile-admin-header">
        <button
          ref={menuButtonRef}
          type="button"
          className="mobile-menu-button"
          aria-label={drawerOpen ? "Fechar menu principal" : "Abrir menu principal"}
          aria-controls="admin-sidebar"
          aria-expanded={drawerOpen}
          onClick={() => setDrawerOpen((open) => !open)}
        >
          {drawerOpen ? <IconX size={22} /> : <IconMenu2 size={22} />}
        </button>
        <NavLink to="/" className="mobile-brand" aria-label="Ir ao Dashboard">
          <span className="sidebar-brand-mark sidebar-brand-mark-sm" aria-hidden="true">
            <IconHeart size={17} fill="currentColor" />
          </span>
          <span>
            <strong>Namoro Cristão</strong>
            <small>Painel administrativo</small>
          </span>
        </NavLink>
      </header>

      <aside
        ref={sidebarRef}
        id="admin-sidebar"
        className="admin-sidebar"
        aria-label="Navegação principal"
        aria-modal={drawerOpen ? true : undefined}
        role={drawerOpen ? "dialog" : undefined}
        tabIndex={-1}
      >
        <div className="sidebar-inner">
          <div className="sidebar-brand-row">
            <NavLink
              to="/"
              className="sidebar-brand"
              aria-label="Namoro Cristão — Dashboard"
              onClick={closeDrawer}
            >
              <span className="sidebar-brand-mark" aria-hidden="true">
                <IconHeart size={20} fill="currentColor" />
              </span>
              <span className="sidebar-brand-copy">
                <strong>Namoro Cristão</strong>
                <small>Painel administrativo</small>
              </span>
            </NavLink>
            <button
              type="button"
              className="sidebar-drawer-close"
              aria-label="Fechar menu principal"
              onClick={closeDrawer}
            >
              <IconX size={20} aria-hidden="true" />
            </button>
          </div>

          <nav className="sidebar-nav" aria-label="Módulos administrativos">
            {groups.map((group, groupIndex) => {
              const labelId = `nav-group-${groupIndex}`;
              return (
                <section className="sidebar-group" key={group.label} aria-labelledby={labelId}>
                  <h2 id={labelId} className="sidebar-group-label">{group.label}</h2>
                  <ul className="sidebar-list">
                    {group.items.map((item) => {
                      const Icon = item.icon;
                      return (
                        <li key={item.to}>
                          <NavLink
                            to={item.to}
                            end={item.end}
                            onClick={closeDrawer}
                            className={({ isActive }) =>
                              `sidebar-link${isActive ? " active" : ""}`
                            }
                          >
                            <span className="sidebar-link-icon" aria-hidden="true">
                              <Icon size={19} stroke={1.8} />
                            </span>
                            <span className="sidebar-link-label">{item.label}</span>
                            {!!item.badge && item.badge > 0 && (
                              <span
                                className="sidebar-badge"
                                aria-label={`${item.badge} pendentes`}
                              >
                                {item.badge > 99 ? "99+" : item.badge}
                              </span>
                            )}
                          </NavLink>
                        </li>
                      );
                    })}
                  </ul>
                </section>
              );
            })}
          </nav>

          <footer className="sidebar-footer">
            <span className="sidebar-avatar" aria-hidden="true">{initials}</span>
            <span className="sidebar-admin-copy">
              <strong title={admin?.name}>{admin?.name}</strong>
              <small>{isSuperAdmin ? "Super-admin" : "Administrador"}</small>
            </span>
            <button
              type="button"
              className="sidebar-logout"
              onClick={logout}
              aria-label="Sair do painel"
              title="Sair"
            >
              <IconLogout size={19} />
            </button>
          </footer>
        </div>
      </aside>

      {drawerOpen && (
        <button
          type="button"
          className="sidebar-backdrop"
          aria-hidden="true"
          tabIndex={-1}
          onClick={closeDrawer}
        />
      )}

      <main ref={mainRef} id="main-content" className="admin-main" tabIndex={-1}>
        <div className="admin-content">{children}</div>
      </main>
    </div>
  );
}
