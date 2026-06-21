import { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import { IconArrowRight } from "@tabler/icons-react";
import { get } from "../api";

interface Report {
  id: string;
  reporterId: string;
  reportedId: string;
  reason: string;
  status: string;
  createdAt: string;
}

const STATUS: Record<string, { label: string; cls: string }> = {
  PENDING: { label: "Pendente", cls: "bg-yellow-lt" },
  REVIEWED: { label: "Revisado", cls: "bg-green-lt" },
  DISMISSED: { label: "Descartado", cls: "bg-secondary-lt" },
};

export default function Reports() {
  const [reports, setReports] = useState<Report[]>([]);
  const [error, setError] = useState("");
  const navigate = useNavigate();

  async function load() {
    setError("");
    try {
      const r = await get("/admin/reports");
      setReports(r.reports);
    } catch (e: any) {
      setError(e.message);
    }
  }

  useEffect(() => {
    load();
  }, []);

  return (
    <>
      <div className="d-flex align-items-center justify-content-between mb-3">
        <div>
          <div className="page-pretitle">Moderação</div>
          <h2 className="page-title">Denúncias</h2>
        </div>
        <span className="text-secondary">{reports.length} registro(s)</span>
      </div>

      {error && <div className="alert alert-danger">{error}</div>}

      <div className="card">
        <div className="table-responsive">
          <table className="table table-vcenter card-table">
            <thead>
              <tr>
                <th>Denunciado</th>
                <th>Motivo</th>
                <th>Status</th>
                <th>Data</th>
                <th className="w-1 text-end">Ação</th>
              </tr>
            </thead>
            <tbody>
              {reports.map((r) => {
                const st = STATUS[r.status] || { label: r.status, cls: "bg-secondary-lt" };
                return (
                  <tr key={r.id} style={{ cursor: "pointer" }} onClick={() => navigate(`/denuncias/${r.id}`)}>
                    <td className="text-secondary" style={{ fontSize: 12 }}>{r.reportedId.slice(0, 8)}…</td>
                    <td className="fw-medium">{r.reason}</td>
                    <td><span className={`badge ${st.cls}`}>{st.label}</span></td>
                    <td className="text-secondary">{new Date(r.createdAt).toLocaleDateString("pt-BR")}</td>
                    <td onClick={(e) => e.stopPropagation()}>
                      <div className="d-flex gap-1 justify-content-end">
                        <button className="btn btn-sm btn-primary" onClick={() => navigate(`/denuncias/${r.id}`)}>
                          Investigar<IconArrowRight size={15} className="ms-1" />
                        </button>
                      </div>
                    </td>
                  </tr>
                );
              })}
              {reports.length === 0 && (
                <tr>
                  <td colSpan={5} className="text-center text-secondary py-4">Nenhuma denúncia.</td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </div>
    </>
  );
}
