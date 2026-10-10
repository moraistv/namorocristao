import { lazy, Suspense, type ReactNode } from "react";
import { Navigate, Route, Routes, useLocation } from "react-router-dom";
import { useAuth } from "./auth";
import Layout from "./components/Layout";
import RouteErrorBoundary from "./components/RouteErrorBoundary";

const Login = lazy(() => import("./pages/Login"));
const Dashboard = lazy(() => import("./pages/Dashboard"));
const Users = lazy(() => import("./pages/Users"));
const UserDetail = lazy(() => import("./pages/UserDetail"));
const Reports = lazy(() => import("./pages/Reports"));
const ReportDetail = lazy(() => import("./pages/ReportDetail"));
const Verifications = lazy(() => import("./pages/Verifications"));
const Banned = lazy(() => import("./pages/Banned"));
const DeleteRequests = lazy(() => import("./pages/DeleteRequests"));
const Admins = lazy(() => import("./pages/Admins"));
const Settings = lazy(() => import("./pages/Settings"));
const Rewards = lazy(() => import("./pages/Rewards"));
const Gifts = lazy(() => import("./pages/Gifts"));
const Ads = lazy(() => import("./pages/Ads"));
const Verses = lazy(() => import("./pages/Verses"));
const Notifications = lazy(() => import("./pages/Notifications"));
const Bots = lazy(() => import("./pages/Bots"));
const ChatbotRules = lazy(() => import("./pages/ChatbotRules"));
const ChatbotAnalytics = lazy(() => import("./pages/ChatbotAnalytics"));
const Forbidden = lazy(() => import("./pages/Forbidden"));

type AdminPermission = "VERIFICATION" | "REPORT" | "ACCOUNT_DELETE";

function LoadingShell({ fullScreen = false }: { fullScreen?: boolean }) {
  return (
    <div
      className={fullScreen ? "app-loader app-loader-full" : "app-loader"}
      role="status"
      aria-live="polite"
      aria-label="Carregando conteúdo"
    >
      <div className="app-loader-card">
        <span className="app-loader-mark" aria-hidden="true">NC</span>
        <span className="app-loader-copy">
          <strong>Namoro Cristão</strong>
          <small>Preparando o painel</small>
        </span>
        <span className="spinner-border spinner-border-sm" aria-hidden="true" />
      </div>
    </div>
  );
}

function SessionUnavailable({ message, onRetry }: { message: string; onRetry: () => void }) {
  return (
    <div className="session-unavailable app-loader-full">
      <div className="card session-unavailable-card" role="alert">
        <div className="card-body text-center">
          <span className="app-loader-mark mx-auto mb-3" aria-hidden="true">NC</span>
          <h1 className="h3 mb-2">Painel temporariamente indisponível</h1>
          <p className="text-secondary mb-4">{message}</p>
          <button type="button" className="btn btn-primary" onClick={onRetry}>
            Tentar novamente
          </button>
        </div>
      </div>
    </div>
  );
}

function RequireAccess({
  children,
  superOnly = false,
  permission,
}: {
  children: ReactNode;
  superOnly?: boolean;
  permission?: AdminPermission;
}) {
  const { admin } = useAuth();
  const location = useLocation();
  const allowed = Boolean(
    admin &&
      (admin.isSuperAdmin ||
        (!superOnly && (!permission || admin.permissions.includes(permission))))
  );

  if (allowed) return <>{children}</>;
  return (
    <Navigate
      to="/403"
      replace
      state={{ from: location.pathname }}
    />
  );
}

function SuperAdminRoute({ children }: { children: ReactNode }) {
  return <RequireAccess superOnly>{children}</RequireAccess>;
}

function AppContent() {
  const { admin, loading, sessionError, retrySession } = useAuth();

  if (loading) return <LoadingShell fullScreen />;

  if (sessionError) {
    return <SessionUnavailable message={sessionError} onRetry={retrySession} />;
  }

  if (!admin) {
    return (
      <Suspense fallback={<LoadingShell fullScreen />}>
        <Login />
      </Suspense>
    );
  }

  return (
    <Layout>
      <Suspense fallback={<LoadingShell />}>
        <Routes>
          <Route path="/" element={<Dashboard />} />
          <Route path="/usuarios" element={<Users />} />
          <Route path="/usuarios/:userId" element={<UserDetail />} />
          <Route
            path="/verificacoes"
            element={<RequireAccess permission="VERIFICATION"><Verifications /></RequireAccess>}
          />
          <Route
            path="/denuncias"
            element={<RequireAccess permission="REPORT"><Reports /></RequireAccess>}
          />
          <Route
            path="/denuncias/:id"
            element={<RequireAccess permission="REPORT"><ReportDetail /></RequireAccess>}
          />
          <Route
            path="/banidos"
            element={<RequireAccess permission="REPORT"><Banned /></RequireAccess>}
          />
          <Route
            path="/exclusoes"
            element={<RequireAccess permission="ACCOUNT_DELETE"><DeleteRequests /></RequireAccess>}
          />
          <Route path="/recompensas" element={<SuperAdminRoute><Rewards /></SuperAdminRoute>} />
          <Route path="/presentes" element={<SuperAdminRoute><Gifts /></SuperAdminRoute>} />
          {/* Endereços antigos da loja paga (favoritos): levam para as novas telas. */}
          <Route path="/planos" element={<Navigate to="/recompensas" replace />} />
          <Route path="/planos/presentes" element={<Navigate to="/presentes" replace />} />
          <Route path="/anuncios" element={<SuperAdminRoute><Ads /></SuperAdminRoute>} />
          <Route path="/versos" element={<SuperAdminRoute><Verses /></SuperAdminRoute>} />
          <Route path="/notificacoes" element={<SuperAdminRoute><Notifications /></SuperAdminRoute>} />
          <Route path="/modelos" element={<SuperAdminRoute><Bots /></SuperAdminRoute>} />
          <Route path="/chatbot/regras" element={<SuperAdminRoute><ChatbotRules /></SuperAdminRoute>} />
          <Route path="/chatbot/analytics" element={<ChatbotAnalytics />} />
          <Route path="/admins" element={<SuperAdminRoute><Admins /></SuperAdminRoute>} />
          <Route path="/configuracoes" element={<SuperAdminRoute><Settings /></SuperAdminRoute>} />
          <Route path="/403" element={<Forbidden />} />
          <Route path="*" element={<Navigate to="/" replace />} />
        </Routes>
      </Suspense>
    </Layout>
  );
}

export default function App() {
  const location = useLocation();
  return (
    <RouteErrorBoundary resetKey={location.pathname} fullScreen>
      <AppContent />
    </RouteErrorBoundary>
  );
}
