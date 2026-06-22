import { useEffect, useState } from "react";
import { IconMessage, IconCategory, IconAlertTriangle, IconTrendingUp } from "@tabler/icons-react";
import { get } from "../api";

interface Analytics {
  total: number;
  fallbacks: number;
  matched: number;
  matchRate: number;
  uniqueCategories: number;
  topCategories: { category: string; count: number }[];
  recentFallbacks: { id: string; message: string; language: string; usedAi: boolean; createdAt: string }[];
}

function Stat({ icon: Icon, label, value, color }: any) {
  return (
    <div className="col-sm-6 col-lg-3">
      <div className="card">
        <div className="card-body d-flex align-items-center">
          <span className="bg-azure-lt rounded p-2 me-3" style={{ color }}><Icon size={24} /></span>
          <div><div className="h1 m-0">{value}</div><div className="text-secondary">{label}</div></div>
        </div>
      </div>
    </div>
  );
}

export default function ChatbotAnalytics() {
  const [a, setA] = useState<Analytics | null>(null);
  const [err, setErr] = useState("");

  useEffect(() => {
    get("/admin/chatbot/analytics").then(setA).catch((e) => setErr(e.message));
  }, []);

  if (err) return <div className="alert alert-danger">{err}</div>;
  if (!a) return <div className="text-secondary">Carregando...</div>;

  const max = Math.max(1, ...a.topCategories.map((c) => c.count));

  return (
    <>
      <div className="mb-3"><div className="page-pretitle">Bots</div><h2 className="page-title">Analytics do Chatbot</h2></div>

      <div className="row row-deck row-cards mb-3">
        <Stat icon={IconMessage} label="Total de interações" value={a.total} color="#4263eb" />
        <Stat icon={IconCategory} label="Categorias acionadas" value={a.uniqueCategories} color="#ae3ec9" />
        <Stat icon={IconAlertTriangle} label="Sem resposta (fallback)" value={a.fallbacks} color="#f76707" />
        <Stat icon={IconTrendingUp} label="Taxa de match" value={`${a.matchRate}%`} color="#2fb344" />
      </div>

      <div className="row">
        <div className="col-lg-6 mb-3">
          <div className="card">
            <div className="card-header"><h3 className="card-title">Top categorias</h3></div>
            <div className="card-body">
              {a.topCategories.length === 0 && <div className="text-secondary">Sem dados ainda.</div>}
              {a.topCategories.map((c) => (
                <div key={c.category} className="mb-2">
                  <div className="d-flex justify-content-between"><span className="fw-medium">{c.category}</span><span className="text-secondary">{c.count}</span></div>
                  <div className="progress" style={{ height: 8 }}><div className="progress-bar" style={{ width: `${(c.count / max) * 100}%`, background: "#d4af37" }} /></div>
                </div>
              ))}
            </div>
          </div>
        </div>

        <div className="col-lg-6 mb-3">
          <div className="card">
            <div className="card-header"><h3 className="card-title">Mensagens sem match (fallbacks)</h3></div>
            <div className="table-responsive">
              <table className="table table-vcenter card-table">
                <thead><tr><th>Mensagem</th><th>IA?</th><th className="text-end">Data</th></tr></thead>
                <tbody>
                  {a.recentFallbacks.map((f) => (
                    <tr key={f.id}>
                      <td>{f.message}</td>
                      <td>{f.usedAi ? <span className="badge bg-green-lt">IA</span> : <span className="badge bg-secondary-lt">não</span>}</td>
                      <td className="text-end text-secondary">{new Date(f.createdAt).toLocaleString("pt-BR")}</td>
                    </tr>
                  ))}
                  {a.recentFallbacks.length === 0 && <tr><td colSpan={3} className="text-center text-secondary py-4">Nenhum fallback — ótimo! 🎉</td></tr>}
                </tbody>
              </table>
            </div>
            <div className="card-footer text-secondary" style={{ fontSize: 12 }}>Dica: vire essas mensagens em novas regras pra aumentar a taxa de match.</div>
          </div>
        </div>
      </div>
    </>
  );
}
