import { useEffect, useState } from "react";
import Chart from "react-apexcharts";
import {
  IconTrendingUp, IconTrendingDown, IconFlag, IconBan, IconClockHour4,
  IconTrash, IconMapPin, IconUsers, IconRosetteDiscountCheck, IconHeart,
  IconThumbUp, IconUserPlus, IconStar, IconDeviceMobile,
} from "@tabler/icons-react";
import { get } from "../api";
import BrazilMap from "../components/BrazilMap";

const BLUE = "#111d40", GREEN = "#2fb344", AZURE = "#2e4a8a", GOLD = "#d4af37";

interface Stats {
  users: { total: number; male: number; female: number; verified: number; online: number };
  interactions: { likes: number; dislikes: number; superlikes: number; total: number };
  matches: number; devices: number; reports: number; banned: number;
  pendingVerifications: number; deleteRequests: number;
}
interface UserRow { userId: string; fullName: string; profilePicture?: string; city?: string; age?: number; }
interface StateRow { uf: string; nome: string; count: number; }

function Up({ v }: { v: number }) {
  const up = v >= 0;
  return (
    <span className={"d-inline-flex align-items-center lh-1 " + (up ? "text-green" : "text-red")}>
      {Math.abs(v)}% {up ? <IconTrendingUp size={16} className="ms-1" /> : <IconTrendingDown size={16} className="ms-1" />}
    </span>
  );
}

function area(data: number[], color: string, height = 48) {
  return (
    <Chart type="area" height={height} series={[{ name: "v", data: data.length ? data : [0, 0] }]}
      options={{
        chart: { sparkline: { enabled: true }, animations: { enabled: false } },
        stroke: { width: 2, lineCap: "round", curve: "smooth" },
        fill: { type: "gradient", gradient: { opacityFrom: 0.3, opacityTo: 0 } },
        colors: [color], tooltip: { enabled: false }, dataLabels: { enabled: false },
      }} />
  );
}

export default function Dashboard() {
  const [s, setS] = useState<Stats | null>(null);
  const [series, setSeries] = useState<{ date: string; count: number }[]>([]);
  const [online, setOnline] = useState<UserRow[]>([]);
  const [recent, setRecent] = useState<UserRow[]>([]);
  const [states, setStates] = useState<StateRow[]>([]);
  const [cities, setCities] = useState<{ city: string; count: number }[]>([]);
  const [err, setErr] = useState("");

  useEffect(() => {
    let alive = true;
    const load = () => {
      get("/admin/dashboard").then((d) => alive && setS(d)).catch((e) => alive && setErr(e.message));
      get("/admin/users?online=true&take=6").then((r) => alive && setOnline(r.users || [])).catch(() => {});
      get("/admin/users?take=6").then((r) => alive && setRecent(r.users || [])).catch(() => {});
      get("/admin/stats/locations").then((r) => { if (alive) { setStates(r.byState || []); setCities(r.topCities || []); } }).catch(() => {});
    };
    load();
    get("/admin/stats/signups?days=14").then((r) => alive && setSeries(r.series || [])).catch(() => {});
    const t = setInterval(load, 10000);
    return () => { alive = false; clearInterval(t); };
  }, []);

  if (err) return <div className="alert alert-danger">{err}</div>;
  if (!s) return <div className="text-secondary p-4">Carregando...</div>;

  const spark = series.map((x) => x.count);
  const last7 = series.slice(-7).reduce((a, b) => a + b.count, 0);
  const prev7 = series.slice(-14, -7).reduce((a, b) => a + b.count, 0);
  const trend = prev7 === 0 ? (last7 > 0 ? 100 : 0) : Math.round(((last7 - prev7) / prev7) * 100);
  const verifRate = s.users.total ? Math.round((s.users.verified / s.users.total) * 100) : 0;
  const matchRate = s.interactions.likes + s.interactions.superlikes > 0
    ? Math.min(100, Math.round((s.matches * 2 / (s.interactions.likes + s.interactions.superlikes)) * 100)) : 0;

  const smalls = [
    { icon: IconFlag, color: "orange", value: s.reports, label: "Denúncias" },
    { icon: IconBan, color: "red", value: s.banned, label: "Banidos" },
    { icon: IconClockHour4, color: "purple", value: s.pendingVerifications, label: "Verif. pendentes" },
    { icon: IconTrash, color: "blue", value: s.deleteRequests, label: "Exclusões" },
  ];

  return (
    <>
      <div className="d-flex align-items-center justify-content-between mb-3">
        <div>
          <div className="page-pretitle">Visão geral</div>
          <h2 className="page-title">Dashboard</h2>
        </div>
        <div className="d-flex align-items-center text-secondary" style={{ fontSize: 13, gap: 6 }}>
          <span className="status-dot status-dot-animated bg-green" /> Tempo real
        </div>
      </div>

      <div className="row row-deck row-cards">
        {/* Bem-vindo */}
        <div className="col-sm-12 col-lg-6">
          <div className="card">
            <div className="card-body">
              <div className="row">
                <div className="col-7">
                  <h3 className="h2">Bem-vindo! 🙏</h3>
                  <p className="text-secondary">
                    {s.reports} denúncia(s) e {s.pendingVerifications} verificação(ões) pendente(s).
                  </p>
                  <div className="row g-3 mt-3">
                    <div className="col-auto">
                      <div className="subheader">Novos (7 dias)</div>
                      <div className="d-flex align-items-baseline"><div className="h3 me-2">{last7}</div><Up v={trend} /></div>
                    </div>
                    <div className="col-auto">
                      <div className="subheader">Online agora</div>
                      <div className="d-flex align-items-baseline">
                        <div className="h3 me-2">{s.users.online}</div>
                        <span className="status-dot status-dot-animated bg-green" />
                      </div>
                    </div>
                    <div className="col-auto">
                      <div className="subheader">Matches</div>
                      <div className="h3">{s.matches}</div>
                    </div>
                  </div>
                </div>
                <div className="col-5 d-flex align-items-center justify-content-center">
                  <div style={{ width: 120, height: 120, borderRadius: "50%", background: "rgba(212,175,55,0.14)", display: "grid", placeItems: "center" }}>
                    <span style={{ fontSize: 56 }}>💛</span>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* Usuários totais */}
        <div className="col-sm-6 col-lg-3">
          <div className="card">
            <div className="card-body">
              <div className="d-flex align-items-center"><div className="subheader">Usuários totais</div><span className="ms-auto text-blue"><IconUsers size={20} /></span></div>
              <div className="d-flex align-items-baseline">
                <div className="h1 mb-0 me-2">{s.users.total}</div>
                <div className="me-auto"><Up v={trend} /></div>
              </div>
              <div className="text-secondary mt-2">{last7} novos nos últimos 7 dias</div>
            </div>
            {area(spark, AZURE)}
          </div>
        </div>

        {/* Verificados (gauge) */}
        <div className="col-sm-6 col-lg-3">
          <div className="card">
            <div className="card-body">
              <div className="d-flex align-items-center mb-2"><div className="subheader">Verificados</div><span className="ms-auto text-blue"><IconRosetteDiscountCheck size={20} /></span></div>
              <Chart type="radialBar" height={150} series={[verifRate]}
                options={{
                  chart: { animations: { enabled: false } },
                  plotOptions: { radialBar: { hollow: { size: "60%" }, track: { background: "#e9ecef" }, dataLabels: { name: { show: false }, value: { fontSize: "22px", fontWeight: 700, color: "#1d273b", offsetY: 8 } } } },
                  colors: [BLUE], labels: ["Verificados"],
                }} />
              <div className="text-secondary text-center">{s.users.verified} de {s.users.total}</div>
            </div>
          </div>
        </div>

        {/* Taxa de match */}
        <div className="col-sm-6 col-lg-3">
          <div className="card"><div className="card-body">
            <div className="d-flex align-items-center"><div className="subheader">Taxa de match</div><span className="ms-auto text-pink"><IconHeart size={20} /></span></div>
            <div className="h1 mb-3">{matchRate}%</div>
            <div className="d-flex mb-2"><div>Conversão</div><div className="ms-auto"><Up v={trend} /></div></div>
            <div className="progress progress-sm"><div className="progress-bar bg-primary" style={{ width: `${matchRate}%` }} /></div>
            <div className="text-secondary mt-2" style={{ fontSize: 13 }}>{s.matches} matches ativos</div>
          </div></div>
        </div>

        {/* Likes */}
        <div className="col-sm-6 col-lg-3">
          <div className="card">
            <div className="card-body">
              <div className="d-flex align-items-center"><div className="subheader">Likes</div><span className="ms-auto text-green"><IconThumbUp size={20} /></span></div>
              <div className="h1 mb-0">{s.interactions.likes}</div>
              <div className="text-secondary mt-2">curtidas no total</div>
            </div>
            {area(spark, GREEN)}
          </div>
        </div>

        {/* Novos usuários */}
        <div className="col-sm-6 col-lg-3">
          <div className="card">
            <div className="card-body">
              <div className="d-flex align-items-center"><div className="subheader">Novos usuários</div><span className="ms-auto text-blue"><IconUserPlus size={20} /></span></div>
              <div className="d-flex align-items-baseline"><div className="h1 mb-0 me-2">{last7}</div><Up v={trend} /></div>
              <div className="text-secondary mt-2">últimos 7 dias</div>
            </div>
            {area(spark, BLUE)}
          </div>
        </div>

        {/* Super likes */}
        <div className="col-sm-6 col-lg-3">
          <div className="card">
            <div className="card-body">
              <div className="d-flex align-items-center"><div className="subheader">Super Likes</div><span className="ms-auto text-yellow"><IconStar size={20} /></span></div>
              <div className="h1 mb-0">{s.interactions.superlikes}</div>
              <div className="text-secondary mt-2">enviados</div>
            </div>
            <Chart type="bar" height={48} series={[{ name: "v", data: spark }]}
              options={{ chart: { sparkline: { enabled: true }, animations: { enabled: false } }, plotOptions: { bar: { columnWidth: "55%" } }, colors: [GOLD], tooltip: { enabled: false } }} />
          </div>
        </div>

        {/* Dispositivos */}
        <div className="col-sm-6 col-lg-3">
          <div className="card"><div className="card-body">
            <div className="d-flex align-items-center"><div className="subheader">Dispositivos</div><span className="ms-auto text-purple"><IconDeviceMobile size={20} /></span></div>
            <div className="h1 mb-0">{s.devices}</div>
            <div className="text-secondary mt-2">push registrados</div>
          </div></div>
        </div>

        {/* Small stats */}
        <div className="col-12">
          <div className="row row-cards">
            {smalls.map((x, i) => {
              const Icon = x.icon;
              return (
                <div className="col-sm-6 col-lg-3" key={i}>
                  <div className="card card-sm"><div className="card-body">
                    <div className="row align-items-center">
                      <div className="col-auto"><span className={`bg-${x.color} text-white avatar`}><Icon size={22} /></span></div>
                      <div className="col"><div style={{ fontWeight: 700, fontSize: 18 }}>{x.value}</div><div className="text-secondary">{x.label}</div></div>
                    </div>
                  </div></div>
                </div>
              );
            })}
          </div>
        </div>

        {/* Cadastros (14 dias) */}
        <div className="col-lg-12">
          <div className="card"><div className="card-body">
            <h3 className="card-title">Cadastros (14 dias)</h3>
            <Chart type="bar" height={280} series={[{ name: "Cadastros", data: spark }]}
              options={{
                chart: { toolbar: { show: false }, animations: { enabled: false } },
                plotOptions: { bar: { columnWidth: "55%", borderRadius: 3 } },
                colors: [BLUE], dataLabels: { enabled: false },
                grid: { borderColor: "#e9ecef", strokeDashArray: 4 },
                xaxis: { categories: series.map((x) => x.date.slice(5)), labels: { style: { colors: "#919baf", fontSize: "11px" } }, axisBorder: { show: false }, axisTicks: { show: false } },
                yaxis: { labels: { style: { colors: "#919baf", fontSize: "11px" } } },
              }} />
          </div></div>
        </div>

        {/* Usuários por estado */}
        <div className="col-12">
          <div className="card"><div className="card-body">
            <h3 className="card-title d-flex align-items-center"><IconMapPin size={18} className="me-2 text-secondary" /> Usuários por estado</h3>
            {states.length === 0 ? (
              <div className="text-secondary">Sem dados.</div>
            ) : (
              <div className="row align-items-center">
                <div className="col-lg-5">
                  <BrazilMap data={states} height={340} />
                </div>
                <div className="col-lg-7">
                  {states.map((st) => (
                    <div key={st.uf} className="d-flex align-items-center py-2" style={{ borderBottom: "1px solid #f1f3f7" }}>
                      <span className="badge me-2" style={{ background: "rgba(212,175,55,0.16)", color: "#9a7d1f", minWidth: 34 }}>{st.uf}</span>
                      <span className="text-secondary" style={{ minWidth: 130 }}>{st.nome}</span>
                      <div className="flex-fill mx-3">
                        <div className="progress progress-sm">
                          <div className="progress-bar" style={{ width: `${(st.count / Math.max(1, ...states.map((x) => x.count))) * 100}%`, background: "#d4af37" }} />
                        </div>
                      </div>
                      <strong style={{ minWidth: 34, textAlign: "right" }}>{st.count}</strong>
                    </div>
                  ))}
                </div>
              </div>
            )}
          </div></div>
        </div>

        {/* Cidades com mais usuários */}
        <div className="col-lg-6">
          <div className="card">
            <div className="card-header"><h3 className="card-title">Cidades com mais usuários</h3></div>
            <div className="table-responsive">
              <table className="table card-table table-vcenter">
                <thead><tr><th>Cidade</th><th className="text-end">Usuários</th></tr></thead>
                <tbody>
                  {cities.length === 0 && <tr><td colSpan={2} className="text-secondary text-center">Sem dados.</td></tr>}
                  {cities.map((c, i) => (
                    <tr key={i}><td>{c.city}</td><td className="text-end" style={{ fontWeight: 600 }}>{c.count}</td></tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        </div>

        {/* Online agora */}
        <div className="col-lg-6">
          <div className="card"><div className="card-body">
            <h3 className="card-title">Online agora</h3>
            <div className="text-secondary mb-2">{s.users.online} pessoas ativas</div>
            {online.length === 0 && <div className="text-secondary">Ninguém online.</div>}
            {online.map((u) => (
              <div key={u.userId} className="d-flex align-items-center py-2" style={{ borderTop: "1px solid var(--tblr-border-color)" }}>
                <span className="avatar avatar-sm me-2" style={u.profilePicture ? { backgroundImage: `url(${u.profilePicture})` } : {}}>{!u.profilePicture && u.fullName?.charAt(0)}</span>
                <div className="flex-fill"><div style={{ fontWeight: 600 }}>{u.fullName?.split(" ")[0]}{u.age ? `, ${u.age}` : ""}</div><div className="text-secondary" style={{ fontSize: 12 }}>{u.city || "—"}</div></div>
                <span className="status-dot status-dot-animated bg-green" />
              </div>
            ))}
          </div></div>
        </div>

        {/* Últimos cadastros */}
        <div className="col-12">
          <div className="card">
            <div className="card-header"><h3 className="card-title">Últimos cadastros</h3></div>
            <div className="table-responsive">
              <table className="table card-table table-vcenter">
                <thead><tr><th>Usuário</th><th>Cidade</th><th>Idade</th></tr></thead>
                <tbody>
                  {recent.map((u) => (
                    <tr key={u.userId}>
                      <td><div className="d-flex align-items-center"><span className="avatar avatar-sm me-2" style={u.profilePicture ? { backgroundImage: `url(${u.profilePicture})` } : {}}>{!u.profilePicture && u.fullName?.charAt(0)}</span>{u.fullName}</div></td>
                      <td className="text-secondary">{u.city || "—"}</td>
                      <td className="text-secondary">{u.age ?? "—"}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        </div>
      </div>

      <footer className="footer mt-4">
        <div className="text-center text-secondary" style={{ fontSize: 13 }}>Copyright © 2025 Namoro Cristão · Painel Admin</div>
      </footer>
    </>
  );
}
