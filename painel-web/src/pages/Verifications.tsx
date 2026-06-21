import { useEffect, useState } from "react";
import { get, post } from "../api";

interface VForm {
  id: string;
  userId: string;
  selfieUrl: string;
  status: string;
  createdAt: string;
}

export default function Verifications() {
  const [forms, setForms] = useState<VForm[]>([]);
  const [error, setError] = useState("");

  async function load() {
    setError("");
    try {
      const r = await get("/admin/verifications?status=PENDING");
      setForms(r.verifications);
    } catch (e: any) {
      setError(e.message);
    }
  }

  useEffect(() => {
    load();
  }, []);

  async function review(id: string, approve: boolean) {
    await post(`/admin/verifications/${id}/review`, { approve });
    load();
  }

  return (
    <>
      <div className="d-flex align-items-center justify-content-between mb-3">
        <div>
          <div className="page-pretitle">Moderação</div>
          <h2 className="page-title">Verificações pendentes</h2>
        </div>
        <span className="text-secondary">{forms.length} pendente(s)</span>
      </div>

      {error && <div className="alert alert-danger">{error}</div>}

      {forms.length === 0 ? (
        <div className="card">
          <div className="card-body text-center text-secondary py-5">
            Nenhuma verificação pendente.
          </div>
        </div>
      ) : (
        <div className="row row-cards">
          {forms.map((f) => (
            <div className="col-sm-6 col-lg-3" key={f.id}>
              <div className="card">
                <img
                  src={f.selfieUrl}
                  alt="selfie"
                  className="card-img-top"
                  style={{ height: 220, objectFit: "cover", background: "#eef0f4" }}
                />
                <div className="card-body">
                  <div className="text-secondary mb-3" style={{ fontSize: 12 }}>
                    {f.userId.slice(0, 8)}… · {new Date(f.createdAt).toLocaleDateString("pt-BR")}
                  </div>
                  <div className="d-flex gap-2">
                    <button className="btn btn-primary flex-fill" onClick={() => review(f.id, true)}>Aprovar</button>
                    <button className="btn btn-danger flex-fill" onClick={() => review(f.id, false)}>Rejeitar</button>
                  </div>
                </div>
              </div>
            </div>
          ))}
        </div>
      )}
    </>
  );
}
