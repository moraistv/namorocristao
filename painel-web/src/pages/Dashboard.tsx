import { useEffect, useState } from "react";
import {
  IconTrendingUp,
  IconTrendingDown,
  IconFlag,
  IconBan,
  IconClockHour4,
  IconTrash,
  IconMapPin,
  IconUsers,
  IconRosetteDiscountCheck,
  IconHeart,
  IconThumbUp,
  IconUserPlus,
  IconStar,
  IconDeviceMobile,
  IconRefresh,
} from "@tabler/icons-react";
import { get } from "../api";
import BrazilMap from "../components/BrazilMap";

const BLUE = "#14264b";
const AZURE = "#31558f";
const GOLD = "#d4af37";
const DASHBOARD_STATS_EVENT = "nc:dashboard-stats";

interface Stats {
  users: {
    total: number;
    male: number;
    female: number;
    verified: number;
    online: number;
  };
  interactions: {
    likes: number;
    dislikes: number;
    superlikes: number;
    total: number;
  };
  matches: number;
  devices: number;
  reports: number;
  banned: number;
  pendingVerifications: number;
  deleteRequests: number;
}

interface UserRow {
  userId: string;
  fullName: string;
  profilePicture?: string;
  city?: string;
  age?: number;
}

interface StateRow {
  uf: string;
  nome: string;
  count: number;
}

interface CityRow {
  city: string;
  count: number;
}

interface SignupPoint {
  date: string;
  count: number;
}

interface UsersResponse {
  users?: UserRow[];
}

interface LocationsResponse {
  byState?: StateRow[];
  topCities?: CityRow[];
}

interface SignupsResponse {
  series?: SignupPoint[];
}

interface PartialFailures {
  online: boolean;
  recent: boolean;
  locations: boolean;
  signups: boolean;
}

const NO_PARTIAL_FAILURES: PartialFailures = {
  online: false,
  recent: false,
  locations: false,
  signups: false,
};

type Settled<T> =
  | { ok: true; value: T }
  | { ok: false; error: unknown };

function settle<T>(promise: Promise<T>): Promise<Settled<T>> {
  return promise.then(
    (value) => ({ ok: true, value }),
    (error: unknown) => ({ ok: false, error })
  );
}

function errorMessage(error: unknown): string {
  return error instanceof Error ? error.message : "Não foi possível atualizar os dados.";
}

function Trend({ value }: { value: number | null }) {
  if (value === null) {
    return <span className="text-secondary small">sem base anterior</span>;
  }
  if (value === 0) {
    return <span className="text-secondary small" aria-label="Tendência estável">Estável</span>;
  }

  const up = value > 0;
  return (
    <span
      className={`d-inline-flex align-items-center lh-1 ${up ? "text-green" : "text-red"}`}
      aria-label={`${up ? "Alta" : "Queda"} de ${Math.abs(value)} por cento`}
    >
      {Math.abs(value)}%
      {up ? (
        <IconTrendingUp size={16} className="ms-1" aria-hidden="true" />
      ) : (
        <IconTrendingDown size={16} className="ms-1" aria-hidden="true" />
      )}
    </span>
  );
}

function signupArea(data: number[], color: string) {
  if (!data.length) return null;

  const width = 320;
  const height = 48;
  const max = Math.max(1, ...data);
  const points = data
    .map((value, index) => {
      const x = data.length === 1 ? width / 2 : (index / (data.length - 1)) * width;
      const y = height - (value / max) * (height - 5) - 2;
      return `${x.toFixed(1)},${y.toFixed(1)}`;
    })
    .join(" ");

  return (
    <div className="signup-sparkline" aria-hidden="true">
      <svg viewBox={`0 0 ${width} ${height}`} preserveAspectRatio="none">
        <polygon points={`0,${height} ${points} ${width},${height}`} fill={color} opacity="0.12" />
        <polyline
          points={points}
          fill="none"
          stroke={color}
          strokeWidth="2.5"
          strokeLinecap="round"
          strokeLinejoin="round"
          vectorEffect="non-scaling-stroke"
        />
      </svg>
    </div>
  );
}

function SignupBars({ points }: { points: SignupPoint[] }) {
  const max = Math.max(1, ...points.map((point) => point.count));

  return (
    <div className="signup-chart-scroll">
      <div className="signup-bars" role="list" aria-label="Cadastros por dia">
        {points.map((point) => (
          <div
            className="signup-bar-column"
            role="listitem"
            aria-label={`${point.date}: ${point.count} cadastro(s)`}
            title={`${point.date}: ${point.count} cadastro(s)`}
            key={point.date}
          >
            <span className="signup-bar-value">{point.count}</span>
            <span className="signup-bar-track" aria-hidden="true">
              <span
                style={{
                  height: `${point.count === 0 ? 0 : Math.max(3, (point.count / max) * 100)}%`,
                }}
              />
            </span>
            <span className="signup-bar-label">{point.date.slice(5)}</span>
          </div>
        ))}
      </div>
    </div>
  );
}

export default function Dashboard() {
  const [stats, setStats] = useState<Stats | null>(null);
  const [series, setSeries] = useState<SignupPoint[]>([]);
  const [online, setOnline] = useState<UserRow[]>([]);
  const [recent, setRecent] = useState<UserRow[]>([]);
  const [states, setStates] = useState<StateRow[]>([]);
  const [cities, setCities] = useState<CityRow[]>([]);
  const [error, setError] = useState("");
  const [partialFailures, setPartialFailures] = useState<PartialFailures>(NO_PARTIAL_FAILURES);
  const [refreshing, setRefreshing] = useState(false);
  const [lastUpdated, setLastUpdated] = useState<Date | null>(null);
  const [retryKey, setRetryKey] = useState(0);

  useEffect(() => {
    let active = true;
    let inFlight = false;

    const load = async (includeSupplemental: boolean) => {
      if (!active || inFlight || document.hidden) return;

      inFlight = true;
      setRefreshing(true);

      const supplementalPromise = includeSupplemental
        ? Promise.all([
            settle(get<LocationsResponse>("/admin/stats/locations")),
            settle(get<SignupsResponse>("/admin/stats/signups?days=14")),
          ])
        : Promise.resolve(null);

      const [statsResult, onlineResult, recentResult, supplemental] =
        await Promise.all([
          settle(get<Stats>("/admin/dashboard")),
          settle(get<UsersResponse>("/admin/users?online=true&take=6")),
          settle(get<UsersResponse>("/admin/users?take=6")),
          supplementalPromise,
        ]);

      if (active) {
        if (statsResult.ok) {
          setStats(statsResult.value);
          setError("");
          setLastUpdated(new Date());
          window.dispatchEvent(
            new CustomEvent(DASHBOARD_STATS_EVENT, { detail: statsResult.value })
          );
        } else {
          setError(errorMessage(statsResult.error));
        }

        if (onlineResult.ok) setOnline(onlineResult.value.users ?? []);
        if (recentResult.ok) setRecent(recentResult.value.users ?? []);

        if (supplemental) {
          const [locationsResult, signupsResult] = supplemental;
          if (locationsResult.ok) {
            setStates(locationsResult.value.byState ?? []);
            setCities(locationsResult.value.topCities ?? []);
          }
          if (signupsResult.ok) setSeries(signupsResult.value.series ?? []);

          setPartialFailures({
            online: !onlineResult.ok,
            recent: !recentResult.ok,
            locations: !locationsResult.ok,
            signups: !signupsResult.ok,
          });
        } else {
          setPartialFailures((current) => ({
            ...current,
            online: !onlineResult.ok,
            recent: !recentResult.ok,
          }));
        }

        setRefreshing(false);
      }

      inFlight = false;
    };

    const handleVisibility = () => {
      if (!document.hidden) void load(true);
    };

    void load(true);
    const timer = window.setInterval(() => void load(false), 30_000);
    document.addEventListener("visibilitychange", handleVisibility);

    return () => {
      active = false;
      window.clearInterval(timer);
      document.removeEventListener("visibilitychange", handleVisibility);
    };
  }, [retryKey]);

  if (!stats && error) {
    return (
      <div className="card">
        <div className="card-body text-center py-5" role="alert">
          <h2 className="h3 mb-2">Não foi possível carregar o Dashboard</h2>
          <p className="text-secondary mb-3">{error}</p>
          <button
            type="button"
            className="btn btn-primary"
            onClick={() => setRetryKey((key) => key + 1)}
          >
            <IconRefresh size={17} className="me-2" aria-hidden="true" />
            Tentar novamente
          </button>
        </div>
      </div>
    );
  }

  if (!stats) {
    return (
      <div className="app-loader" role="status" aria-live="polite">
        <div className="app-loader-card">
          <span className="spinner-border spinner-border-sm" aria-hidden="true" />
          <span className="app-loader-copy">
            <strong>Carregando indicadores</strong>
            <small>Consolidando os dados administrativos</small>
          </span>
        </div>
      </div>
    );
  }

  const signupValues = series.map((point) => point.count);
  const last7 = series.slice(-7).reduce((total, point) => total + point.count, 0);
  const previous7 = series
    .slice(-14, -7)
    .reduce((total, point) => total + point.count, 0);
  const signupTrend =
    previous7 > 0
      ? Math.round(((last7 - previous7) / previous7) * 100)
      : last7 === 0
        ? 0
        : null;
  const verificationRate = stats.users.total
    ? Math.min(
        100,
        Math.max(0, Math.round((stats.users.verified / stats.users.total) * 100))
      )
    : 0;
  const maxStateCount = Math.max(1, ...states.map((state) => state.count));
  const updatedLabel = lastUpdated
    ? lastUpdated.toLocaleTimeString("pt-BR", { hour: "2-digit", minute: "2-digit" })
    : null;
  const hasPartialFailure = Boolean(error) || Object.values(partialFailures).some(Boolean);

  const smallMetrics = [
    {
      icon: IconFlag,
      color: "orange",
      value: stats.reports,
      label: "Denúncias pendentes",
    },
    { icon: IconBan, color: "red", value: stats.banned, label: "Banidos" },
    {
      icon: IconClockHour4,
      color: "purple",
      value: stats.pendingVerifications,
      label: "Verificações pendentes",
    },
    {
      icon: IconTrash,
      color: "blue",
      value: stats.deleteRequests,
      label: "Exclusões pendentes",
    },
  ];

  return (
    <>
      <div className="page-heading">
        <div>
          <div className="page-pretitle">Visão geral</div>
          <h1 className="page-title mb-0">Dashboard</h1>
        </div>
        <div className="dashboard-status" role="status" aria-live="polite">
          <span
            className={`status-dot ${refreshing ? "status-dot-animated bg-yellow" : hasPartialFailure ? "bg-yellow" : "bg-green"}`}
            aria-hidden="true"
          />
          {refreshing
            ? "Atualizando dados"
            : hasPartialFailure
              ? updatedLabel
                ? `Atualização parcial às ${updatedLabel}`
                : "Atualização parcial"
              : updatedLabel
                ? `Atualizado às ${updatedLabel}`
                : "Atualização automática"}
        </div>
      </div>

      {error && (
        <div className="alert alert-warning dashboard-degraded" role="alert">
          <div className="d-flex flex-wrap align-items-center justify-content-between gap-2">
            <span>Exibindo os últimos dados disponíveis. {error}</span>
            <button
              type="button"
              className="btn btn-sm"
              onClick={() => setRetryKey((key) => key + 1)}
            >
              Atualizar agora
            </button>
          </div>
        </div>
      )}

      <div className="row row-deck row-cards">
        <div className="col-12 col-xl-6">
          <div className="card dashboard-welcome">
            <div className="card-body">
              <div className="row align-items-center g-3">
                <div className="col-8">
                  <h2 className="h2">Bem-vindo ao painel</h2>
                  <p className="text-secondary">
                    {stats.reports} denúncia(s) pendente(s) e {stats.pendingVerifications} verificação(ões) aguardando análise.
                  </p>
                  <div className="row g-3 mt-2">
                    <div className="col-auto">
                      <div className="subheader">Cadastros em 7 dias</div>
                      <div className="d-flex align-items-baseline gap-2">
                        <div className="h3 mb-0">{partialFailures.signups && series.length === 0 ? "Indisponível" : last7}</div>
                        {(!partialFailures.signups || series.length > 0) && <Trend value={signupTrend} />}
                      </div>
                      {partialFailures.signups && series.length > 0 && <div className="text-warning small mt-1">Dados anteriores</div>}
                    </div>
                    <div className="col-auto">
                      <div className="subheader">Online agora</div>
                      <div className="d-flex align-items-center gap-2">
                        <div className="h3 mb-0">{stats.users.online}</div>
                        <span className="status-dot status-dot-animated bg-green" aria-hidden="true" />
                      </div>
                    </div>
                    <div className="col-auto">
                      <div className="subheader">Matches</div>
                      <div className="h3 mb-0">{stats.matches}</div>
                    </div>
                  </div>
                </div>
                <div className="col-4 d-flex justify-content-center">
                  <div className="dashboard-heart" aria-hidden="true">
                    <IconHeart size={52} stroke={1.6} fill="currentColor" />
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>

        <div className="col-sm-6 col-xl-3">
          <div className="card metric-card">
            <div className="card-body">
              <div className="d-flex align-items-center">
                <div className="subheader">Usuários totais</div>
                <span className="metric-icon ms-auto"><IconUsers size={20} /></span>
              </div>
              <div className="h1 mb-1 mt-2">{stats.users.total}</div>
              <div className="text-secondary small">
                {partialFailures.signups && series.length === 0
                  ? "Cadastros recentes indisponíveis"
                  : `${last7} novo(s) nos últimos 7 dias${partialFailures.signups ? " · dados anteriores" : ""}`}
              </div>
            </div>
            {signupArea(signupValues, AZURE)}
          </div>
        </div>

        <div className="col-sm-6 col-xl-3">
          <div className="card metric-card">
            <div className="card-body">
              <div className="d-flex align-items-center mb-1">
                <div className="subheader">Perfis verificados</div>
                <span className="metric-icon ms-auto"><IconRosetteDiscountCheck size={20} /></span>
              </div>
              <div
                className="verification-gauge"
                role="img"
                aria-label={`${verificationRate}% dos perfis estão verificados`}
                style={{
                  background: `conic-gradient(${GOLD} ${verificationRate * 3.6}deg, #edf0f4 0deg)`,
                }}
              >
                <span>{verificationRate}%</span>
              </div>
              <div className="text-secondary text-center small">
                {stats.users.verified} de {stats.users.total}
              </div>
            </div>
          </div>
        </div>

        <div className="col-sm-6 col-xl-3">
          <div className="card metric-card">
            <div className="card-body">
              <div className="d-flex align-items-center">
                <div className="subheader">Matches</div>
                <span className="metric-icon ms-auto text-pink"><IconHeart size={20} /></span>
              </div>
              <div className="h1 mb-1 mt-3">{stats.matches}</div>
              <div className="text-secondary small">matches registrados</div>
            </div>
          </div>
        </div>

        <div className="col-sm-6 col-xl-3">
          <div className="card metric-card">
            <div className="card-body">
              <div className="d-flex align-items-center">
                <div className="subheader">Likes</div>
                <span className="metric-icon ms-auto text-green"><IconThumbUp size={20} /></span>
              </div>
              <div className="h1 mb-1 mt-3">{stats.interactions.likes}</div>
              <div className="text-secondary small">curtidas registradas</div>
            </div>
          </div>
        </div>

        <div className="col-sm-6 col-xl-3">
          <div className="card metric-card">
            <div className="card-body">
              <div className="d-flex align-items-center">
                <div className="subheader">Novos usuários</div>
                <span className="metric-icon ms-auto"><IconUserPlus size={20} /></span>
              </div>
              <div className="d-flex align-items-baseline gap-2 mt-2">
                <div className="h1 mb-0">{partialFailures.signups && series.length === 0 ? "—" : last7}</div>
                {(!partialFailures.signups || series.length > 0) && <Trend value={signupTrend} />}
              </div>
              <div className="text-secondary small mt-1">
                {partialFailures.signups
                  ? series.length > 0 ? "dados anteriores; atualização indisponível" : "indisponível"
                  : "cadastros nos últimos 7 dias"}
              </div>
            </div>
            {signupArea(signupValues, BLUE)}
          </div>
        </div>

        <div className="col-sm-6 col-xl-3">
          <div className="card metric-card">
            <div className="card-body">
              <div className="d-flex align-items-center">
                <div className="subheader">Super Likes</div>
                <span className="metric-icon ms-auto text-yellow"><IconStar size={20} /></span>
              </div>
              <div className="h1 mb-1 mt-3">{stats.interactions.superlikes}</div>
              <div className="text-secondary small">envios registrados</div>
            </div>
          </div>
        </div>

        <div className="col-sm-6 col-xl-3">
          <div className="card metric-card">
            <div className="card-body">
              <div className="d-flex align-items-center">
                <div className="subheader">Dispositivos</div>
                <span className="metric-icon ms-auto text-purple"><IconDeviceMobile size={20} /></span>
              </div>
              <div className="h1 mb-1 mt-3">{stats.devices}</div>
              <div className="text-secondary small">dispositivos com push registrado</div>
            </div>
          </div>
        </div>

        <div className="col-12">
          <div className="row row-cards">
            {smallMetrics.map((metric) => {
              const Icon = metric.icon;
              return (
                <div className="col-sm-6 col-xl-3" key={metric.label}>
                  <div className="card card-sm metric-card">
                    <div className="card-body">
                      <div className="row align-items-center g-3">
                        <div className="col-auto">
                          <span className={`bg-${metric.color} text-white avatar`}>
                            <Icon size={21} />
                          </span>
                        </div>
                        <div className="col">
                          <div className="h3 mb-0">{metric.value}</div>
                          <div className="text-secondary small">{metric.label}</div>
                        </div>
                      </div>
                    </div>
                  </div>
                </div>
              );
            })}
          </div>
        </div>

        <div className="col-12">
          <div className="card">
            <div className="card-body">
              <h2 className="card-title">Cadastros nos últimos 14 dias</h2>
              {partialFailures.signups && series.length > 0 && <div className="alert alert-warning py-2 small" role="status">Atualização indisponível; exibindo o último histórico válido.</div>}
              {series.length ? (
                <SignupBars points={series} />
              ) : (
                <div className="text-secondary py-5 text-center">
                  {partialFailures.signups ? "Dados de cadastros indisponíveis." : "Sem histórico de cadastros."}
                </div>
              )}
            </div>
          </div>
        </div>

        <div className="col-12">
          <div className="card">
            <div className="card-body">
              <h2 className="card-title d-flex align-items-center">
                <IconMapPin size={18} className="me-2 text-secondary" />
                Usuários por estado
              </h2>
              {partialFailures.locations && states.length > 0 && <div className="alert alert-warning py-2 small" role="status">Atualização indisponível; exibindo os últimos dados de localização válidos.</div>}
              {states.length === 0 ? (
                <div className="text-secondary py-4">{partialFailures.locations ? "Dados de localização indisponíveis." : "Sem dados de localização."}</div>
              ) : (
                <div className="row align-items-center g-4">
                  <div className="col-lg-5">
                    <BrazilMap data={states} height={340} />
                  </div>
                  <div className="col-lg-7">
                    {states.map((state) => (
                      <div key={state.uf} className="state-row d-flex align-items-center py-2">
                        <span className="badge bg-yellow-lt me-2" style={{ minWidth: 38 }}>
                          {state.uf}
                        </span>
                        <span className="text-secondary" style={{ minWidth: 130 }}>
                          {state.nome}
                        </span>
                        <div className="flex-fill mx-3">
                          <div className="progress progress-sm">
                            <div
                              className="progress-bar"
                              style={{
                                width: `${(state.count / maxStateCount) * 100}%`,
                                background: GOLD,
                              }}
                            />
                          </div>
                        </div>
                        <strong className="text-end" style={{ minWidth: 36 }}>{state.count}</strong>
                      </div>
                    ))}
                  </div>
                </div>
              )}
            </div>
          </div>
        </div>

        <div className="col-lg-6">
          <div className="card">
            <div className="card-header">
              <h2 className="card-title">Cidades com mais usuários</h2>
            </div>
            {partialFailures.locations && cities.length > 0 && <div className="alert alert-warning py-2 small mx-3 mt-3 mb-0" role="status">Atualização indisponível; exibindo o último ranking válido.</div>}
            <div className="table-responsive">
              <table className="table card-table table-vcenter">
                <caption className="visually-hidden">Ranking de cidades por quantidade de usuários</caption>
                <thead><tr><th>Cidade</th><th className="text-end">Usuários</th></tr></thead>
                <tbody>
                  {cities.length === 0 && (
                    <tr><td colSpan={2} className="text-secondary text-center py-4">{partialFailures.locations ? "Indisponível" : "Sem dados."}</td></tr>
                  )}
                  {cities.map((city) => (
                    <tr key={city.city}>
                      <td>{city.city}</td>
                      <td className="text-end fw-semibold">{city.count}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        </div>

        <div className="col-lg-6">
          <div className="card">
            <div className="card-body">
              <h2 className="card-title">Online agora</h2>
              <div className="text-secondary small mb-2">
                {stats.users.online} pessoa(s) ativa(s)
              </div>
              {partialFailures.online && online.length > 0 && <div className="alert alert-warning py-2 small" role="status">Lista indisponível; exibindo os últimos usuários válidos.</div>}
              {online.length === 0 && <div className="text-secondary py-3">{partialFailures.online ? "Lista de usuários online indisponível." : "Ninguém online."}</div>}
              {online.map((user) => (
                <div key={user.userId} className="dashboard-list-row d-flex align-items-center py-2">
                  <span
                    className="avatar avatar-sm me-2"
                    style={user.profilePicture ? { backgroundImage: `url(${user.profilePicture})` } : {}}
                    aria-hidden="true"
                  >
                    {!user.profilePicture && user.fullName?.charAt(0)}
                  </span>
                  <div className="flex-fill">
                    <div className="fw-semibold">
                      {user.fullName?.split(" ")[0]}{user.age ? `, ${user.age}` : ""}
                    </div>
                    <div className="text-secondary small">{user.city || "—"}</div>
                  </div>
                  <span className="status-dot status-dot-animated bg-green" aria-label="Online" />
                </div>
              ))}
            </div>
          </div>
        </div>

        <div className="col-12">
          <div className="card">
            <div className="card-header"><h2 className="card-title">Últimos cadastros</h2></div>
            {partialFailures.recent && recent.length > 0 && <div className="alert alert-warning py-2 small mx-3 mt-3 mb-0" role="status">Atualização indisponível; exibindo os últimos cadastros válidos.</div>}
            <div className="table-responsive">
              <table className="table card-table table-vcenter">
                <caption className="visually-hidden">Usuários cadastrados recentemente</caption>
                <thead><tr><th>Usuário</th><th>Cidade</th><th>Idade</th></tr></thead>
                <tbody>
                  {recent.length === 0 && (
                    <tr><td colSpan={3} className="text-secondary text-center py-4">{partialFailures.recent ? "Cadastros recentes indisponíveis." : "Sem cadastros recentes."}</td></tr>
                  )}
                  {recent.map((user) => (
                    <tr key={user.userId}>
                      <td>
                        <div className="d-flex align-items-center">
                          <span
                            className="avatar avatar-sm me-2"
                            style={user.profilePicture ? { backgroundImage: `url(${user.profilePicture})` } : {}}
                            aria-hidden="true"
                          >
                            {!user.profilePicture && user.fullName?.charAt(0)}
                          </span>
                          {user.fullName}
                        </div>
                      </td>
                      <td className="text-secondary">{user.city || "—"}</td>
                      <td className="text-secondary">{user.age ?? "—"}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        </div>
      </div>

      <footer className="footer mt-4">
        <div className="text-center text-secondary small">
          Copyright © {new Date().getFullYear()} Namoro Cristão · Painel Admin
        </div>
      </footer>
    </>
  );
}
