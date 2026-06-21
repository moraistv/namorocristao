import { Navigate, Route, Routes } from "react-router-dom";
import { useAuth } from "./auth";
import Layout from "./components/Layout";
import Login from "./pages/Login";
import Dashboard from "./pages/Dashboard";
import Users from "./pages/Users";
import UserDetail from "./pages/UserDetail";
import Reports from "./pages/Reports";
import ReportDetail from "./pages/ReportDetail";
import Verifications from "./pages/Verifications";
import Banned from "./pages/Banned";
import DeleteRequests from "./pages/DeleteRequests";
import Admins from "./pages/Admins";
import Settings from "./pages/Settings";
import Plans from "./pages/Plans";
import Gifts from "./pages/Gifts";
import Ads from "./pages/Ads";
import Verses from "./pages/Verses";
import Notifications from "./pages/Notifications";

export default function App() {
  const { admin, loading } = useAuth();

  if (loading) {
    return <div style={{ display: "grid", placeItems: "center", height: "100vh" }}>Carregando...</div>;
  }
  if (!admin) return <Login />;

  return (
    <Layout>
      <Routes>
        <Route path="/" element={<Dashboard />} />
        <Route path="/usuarios" element={<Users />} />
        <Route path="/usuarios/:userId" element={<UserDetail />} />
        <Route path="/verificacoes" element={<Verifications />} />
        <Route path="/denuncias" element={<Reports />} />
        <Route path="/denuncias/:id" element={<ReportDetail />} />
        <Route path="/banidos" element={<Banned />} />
        <Route path="/exclusoes" element={<DeleteRequests />} />
        <Route path="/planos" element={<Plans />} />
        <Route path="/planos/presentes" element={<Gifts />} />
        <Route path="/anuncios" element={<Ads />} />
        <Route path="/versos" element={<Verses />} />
        <Route path="/notificacoes" element={<Notifications />} />
        {admin.isSuperAdmin && <Route path="/admins" element={<Admins />} />}
        <Route path="/configuracoes" element={<Settings />} />
        <Route path="*" element={<Navigate to="/" />} />
      </Routes>
    </Layout>
  );
}
