import { useEffect, useState } from "react";
import {
  IconAlertTriangle,
  IconBrain,
  IconCategory,
  IconMessage,
  IconRefresh,
  IconRoute,
  IconTrendingUp,
} from "@tabler/icons-react";
import { get } from "../api";

interface AnalyticsResponse {
  total: number;
  ai: number;
  rules: number;
  fallbacks: number;
  matched: number;
  matchRate: number;
  uniqueCategories: number;
  bySource: { AI: number; RULE: number; FALLBACK: number };
  topCategories: { category: string; count: number }[];
  recentFallbacks: {
    id: string;
    message: string;
    language: string;
    responseSource: "FALLBACK";
    latencyMs: number | null;
    createdAt: string;
  }[];
}

interface StatProps {
  icon: typeof IconMessage;
  label: string;
  value: string | number;
  color: string;
  hint: string;
}

function Stat({ icon: Icon, label, value, color, hint }: StatProps) {
  return (
    <div className="col-sm-6 col-xl-4">
      <div className="card h-100">
        <div className="card-body d-flex align-items-center">
          <span className="rounded-3 p-2 me-3" style={{ color, background: `${color}16` }} aria-hidden="true"><Icon size={24} /></span>
          <div><div className="h2 m-0">{value}</div><div className="fw-medium">{label}</div><div className="text-secondary small">{hint}</div></div>
        </div>
      </div>
    </div>
  );
}

function errorMessage(error: unknown): string {
  return error instanceof Error && error.message
    ? error.message
    : "Falha ao carregar analytics";
}

function formatDate(value: string): string {
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? "Data indisponível" : date.toLocaleString("pt-BR");
}

export default function ChatbotAnalytics() {
  const [analytics, setAnalytics] = useState<AnalyticsResponse | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  async function load() {
    setLoading(true);
    setError("");
    try {
      const response = await get<AnalyticsResponse>("/admin/chatbot/analytics");
      setAnalytics(response);
    } catch (loadError: unknown) {
      setError(errorMessage(loadError));
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    void load();
  }, []);

  if (error && !analytics) {
    return (
      <div className="card">
        <div className="card-body text-center py-5" role="alert">
          <h2 className="h3 mb-2">Não foi possível carregar os indicadores da IA</h2>
          <p className="text-secondary mb-3">{error}</p>
          <button type="button" className="btn btn-primary" disabled={loading} onClick={() => void load()}>
            <IconRefresh size={17} className="me-2" aria-hidden="true" />
            Tentar novamente
          </button>
        </div>
      </div>
    );
  }

  if (!analytics) {
    return (
      <div className="app-loader" role="status" aria-live="polite">
        <div className="app-loader-card">
          <span className="spinner-border spinner-border-sm" aria-hidden="true" />
          <span className="app-loader-copy"><strong>Carregando indicadores da IA</strong><small>Consolidando respostas e fallbacks</small></span>
        </div>
      </div>
    );
  }

  const maxCategory = Math.max(1, ...analytics.topCategories.map((category) => category.count));

  return (
    <>
      <div className="page-heading">
        <div><div className="page-pretitle">Automação inteligente</div><h2 className="page-title mb-0">Desempenho da IA</h2><div className="text-secondary mt-1">Métricas reais por origem da resposta, sem misturar IA com fallback.</div></div>
        {loading && <span className="dashboard-status" role="status" aria-live="polite"><span className="spinner-border spinner-border-sm" aria-hidden="true" />Atualizando</span>}
      </div>

      {error && (
        <div className="alert alert-warning retry-state" role="alert">
          <span>Exibindo os últimos dados disponíveis. {error}</span>
          <button type="button" className="btn btn-sm" disabled={loading} onClick={() => void load()}><IconRefresh size={16} className="me-1" aria-hidden="true" />Tentar novamente</button>
        </div>
      )}

      <div className="row row-cards mb-4" aria-busy={loading}>
        <Stat icon={IconMessage} label="Interações" value={analytics.total} color="#4263eb" hint="Mensagens processadas" />
        <Stat icon={IconBrain} label="Respondidas pela IA" value={analytics.ai} color="#8b5cf6" hint="DeepSeek ou OpenAI" />
        <Stat icon={IconRoute} label="Respondidas por regra" value={analytics.rules} color="#0ea5e9" hint="Respostas determinísticas" />
        <Stat icon={IconAlertTriangle} label="Fallbacks" value={analytics.fallbacks} color="#f76707" hint="Resposta de emergência" />
        <Stat icon={IconTrendingUp} label="Cobertura inteligente" value={`${analytics.matchRate}%`} color="#2fb344" hint="IA ou regra bem-sucedida" />
        <Stat icon={IconCategory} label="Categorias usadas" value={analytics.uniqueCategories} color="#d4af37" hint="Somente regras classificadas" />
      </div>

      <div className="row row-cards">
        <div className="col-lg-5">
          <div className="card h-100">
            <div className="card-header"><div><h3 className="card-title">Categorias das regras</h3><div className="text-secondary small mt-1">Quais respostas determinísticas mais ajudaram.</div></div></div>
            <div className="card-body">
              {analytics.topCategories.length === 0 && <div className="text-secondary text-center py-4">Nenhuma regra acionada ainda.</div>}
              {analytics.topCategories.map((category) => {
                const count = Math.max(0, category.count);
                const percentage = Math.min(100, (count / maxCategory) * 100);
                return (
                  <div key={category.category} className="mb-3">
                    <div className="d-flex justify-content-between"><span className="fw-medium">{category.category}</span><span className="text-secondary">{count}</span></div>
                    <div
                      className="progress mt-1"
                      style={{ height: 8 }}
                      role="progressbar"
                      aria-label={`Uso da categoria ${category.category}`}
                      aria-valuemin={0}
                      aria-valuemax={maxCategory}
                      aria-valuenow={count}
                      aria-valuetext={`${count} acionamento(s) de ${maxCategory}`}
                    >
                      <div className="progress-bar" style={{ width: `${percentage}%`, background: "linear-gradient(90deg, #d4af37, #f2d675)" }} />
                    </div>
                  </div>
                );
              })}
            </div>
          </div>
        </div>

        <div className="col-lg-7">
          <div className="card h-100">
            <div className="card-header"><div><h3 className="card-title">Fallbacks recentes</h3><div className="text-secondary small mt-1">Use estes exemplos para melhorar o prompt ou criar regras úteis.</div></div></div>
            <div className="table-responsive">
              <table className="table table-vcenter card-table">
                <caption className="visually-hidden">Fallbacks recentes do chatbot, com latência e data</caption>
                <thead><tr><th>Mensagem recebida</th><th>Latência</th><th className="text-end">Data</th></tr></thead>
                <tbody>
                  {analytics.recentFallbacks.map((fallback) => <tr key={fallback.id}><td style={{ minWidth: 220 }}>{fallback.message}</td><td className="text-secondary">{fallback.latencyMs == null ? "—" : `${fallback.latencyMs} ms`}</td><td className="text-end text-secondary text-nowrap">{formatDate(fallback.createdAt)}</td></tr>)}
                  {analytics.recentFallbacks.length === 0 && <tr><td colSpan={3} className="text-center text-secondary py-5">Nenhum fallback registrado — excelente cobertura.</td></tr>}
                </tbody>
              </table>
            </div>
          </div>
        </div>
      </div>
    </>
  );
}
