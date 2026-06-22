import { ReactNode, useEffect, useState } from "react";
import { NavLink } from "react-router-dom";
import {
  IconLayoutDashboard, IconUsers, IconRosetteDiscountCheck, IconFlag,
  IconBan, IconTrash, IconShieldCheck, IconSettings,
  IconLogout, IconHeart, IconShoppingCart, IconSpeakerphone, IconBook2, IconBell,
  IconRobot, IconMessageChatbot, IconChartBar,
} from "@tabler/icons-react";
import { useAuth } from "../auth";
import { get } from "../api";

export default function Layout({ children }: { children: ReactNode }) {
  const { admin, logout } = useAuth();
  const [counts, setCounts] = useState({ reports: 0, verif: 0, del: 0 });

  useEffect(() => {
    let alive = true;
    const load = () =>
      get("/admin/dashboard")
        .then((s) => alive && setCounts({ reports: s.reports || 0, verif: s.pendingVerifications || 0, del: s.deleteRequests || 0 }))
        .catch(() => {});
    load();
    const t = setInterval(load, 15000);
    return () => { alive = false; clearInterval(t); };
  }, []);

  const nav = [
    { to: "/", label: "Dashboard", icon: IconLayoutDashboard, end: true },
    { to: "/usuarios", label: "Usuários", icon: IconUsers },
    { to: "/verificacoes", label: "Verificações", icon: IconRosetteDiscountCheck, badge: counts.verif },
    { to: "/denuncias", label: "Denúncias", icon: IconFlag, badge: counts.reports },
    { to: "/banidos", label: "Banidos", icon: IconBan },
    { to: "/exclusoes", label: "Exclusões", icon: IconTrash, badge: counts.del },
    { to: "/planos", label: "Planos", icon: IconShoppingCart },
    { to: "/anuncios", label: "Anúncios", icon: IconSpeakerphone },
    { to: "/modelos", label: "Modelos", icon: IconRobot },
    { to: "/chatbot/regras", label: "Regras do Bot", icon: IconMessageChatbot },
    { to: "/chatbot/analytics", label: "Analytics Bot", icon: IconChartBar },
    { to: "/versos", label: "Versos", icon: IconBook2 },
    { to: "/notificacoes", label: "Notificações", icon: IconBell },
    ...(admin?.isSuperAdmin ? [{ to: "/admins", label: "Admins", icon: IconShieldCheck }] : []),
    { to: "/configuracoes", label: "Configurações", icon: IconSettings },
  ];

  const initials = admin?.name?.trim()?.charAt(0)?.toUpperCase() ?? "A";

  return (
    <div className="page">
      <aside className="navbar navbar-vertical navbar-expand-lg">
        <div className="container-fluid d-flex flex-column" style={{ height: "100%" }}>
          <h1 className="navbar-brand navbar-brand-autodark">
            <span className="d-flex align-items-center text-decoration-none">
              <span className="d-grid me-2" style={{ width: 34, height: 34, borderRadius: 9, background: "linear-gradient(135deg,#e9c75a,#d4af37)", placeItems: "center" }}>
                <IconHeart size={19} color="#111d40" fill="#111d40" />
              </span>
              <span style={{ lineHeight: 1.1 }}>
                <span style={{ display: "block", fontWeight: 700, fontSize: 16, color: "#fff" }}>Namoro Cristão</span>
                <span style={{ display: "block", fontSize: 11, color: "#8a96b3", fontWeight: 400 }}>Painel Admin</span>
              </span>
            </span>
          </h1>

          <div className="collapse navbar-collapse show flex-column">
            <ul className="navbar-nav pt-lg-3">
              {nav.map((n) => {
                const Icon = n.icon;
                return (
                  <li className="nav-item" key={n.to}>
                    <NavLink to={n.to} end={(n as any).end} className={({ isActive }) => "nav-link" + (isActive ? " active" : "")}>
                      <span className="nav-link-icon d-md-none d-lg-inline-block"><Icon size={20} /></span>
                      <span className="nav-link-title" style={{ display: "inline-flex", alignItems: "center", gap: 8 }}>
                        {n.label}
                        {!!(n as any).badge && (n as any).badge > 0 && (
                          <span className="badge bg-red text-white" style={{ fontSize: 10.5, padding: "2px 6px", lineHeight: 1.2 }}>
                            {(n as any).badge}
                          </span>
                        )}
                      </span>
                    </NavLink>
                  </li>
                );
              })}
            </ul>
          </div>

          {/* Rodapé: admin logado + sair */}
          <div className="mt-auto pt-3" style={{ borderTop: "1px solid rgba(255,255,255,0.08)" }}>
            <div className="d-flex align-items-center">
              <span className="avatar avatar-sm" style={{ background: "linear-gradient(135deg,#e9c75a,#d4af37)", color: "#111d40", fontWeight: 700 }}>{initials}</span>
              <div className="ps-2 flex-fill" style={{ minWidth: 0 }}>
                <div style={{ fontSize: 13, fontWeight: 600, color: "#fff", whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>{admin?.name}</div>
                <div style={{ fontSize: 11, color: "#8a96b3" }}>{admin?.isSuperAdmin ? "Super-admin" : "Admin"}</div>
              </div>
              <button className="btn btn-icon btn-ghost-light" onClick={logout} title="Sair" style={{ color: "#c7cfe2" }}>
                <IconLogout size={18} />
              </button>
            </div>
          </div>
        </div>
      </aside>

      <div className="page-wrapper">
        <div className="page-body">
          <div className="container-fluid">{children}</div>
        </div>
      </div>
    </div>
  );
}
