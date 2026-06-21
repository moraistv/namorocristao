import { useEffect, useState } from "react";
import { IconCheck, IconAlertTriangle } from "@tabler/icons-react";

// ─────────── Diálogo de confirmação / entrada (substitui alert/confirm/prompt) ───────────
export interface DialogConfig {
  title: string;
  message?: string;
  confirmText?: string;
  cancelText?: string;
  danger?: boolean;
  icon?: any;
  input?: { label?: string; placeholder?: string; default?: string; type?: string };
  onConfirm: (value: string) => void;
}

export function Dialog({ config, onClose }: { config: DialogConfig | null; onClose: () => void }) {
  const [val, setVal] = useState("");
  useEffect(() => {
    setVal(config?.input?.default ?? "");
  }, [config]);

  if (!config) return null;
  const Icon = config.icon;

  function confirm() {
    config!.onConfirm(val);
    onClose();
  }

  return (
    <>
      <div className="modal modal-blur fade show d-block" tabIndex={-1} role="dialog">
        <div className="modal-dialog modal-sm modal-dialog-centered" role="document">
          <div className="modal-content">
            <div className="modal-header" style={{ background: "#111d40" }}>
              <h5 className="modal-title d-flex align-items-center" style={{ color: "#fff", gap: 8 }}>
                {Icon && <Icon size={18} color={config.danger ? "#ff8a8a" : "#e9c75a"} />}
                {config.title}
              </h5>
              <button type="button" className="btn-close btn-close-white" onClick={onClose} />
            </div>
            <div className="modal-body">
              {config.message && <p className="text-secondary mb-3">{config.message}</p>}
              {config.input && (
                <div>
                  {config.input.label && <label className="form-label">{config.input.label}</label>}
                  <input
                    className="form-control"
                    type={config.input.type ?? "text"}
                    placeholder={config.input.placeholder}
                    value={val}
                    autoFocus
                    onChange={(e) => setVal(e.target.value)}
                    onKeyDown={(e) => e.key === "Enter" && confirm()}
                  />
                </div>
              )}
            </div>
            <div className="modal-footer">
              <button type="button" className="btn" onClick={onClose}>
                {config.cancelText ?? "Cancelar"}
              </button>
              <button
                type="button"
                className={"btn " + (config.danger ? "btn-danger" : "btn-primary")}
                onClick={confirm}
              >
                {config.confirmText ?? "Confirmar"}
              </button>
            </div>
          </div>
        </div>
      </div>
      <div className="modal-backdrop fade show" onClick={onClose} />
    </>
  );
}

// ─────────── Toast (substitui alert de sucesso/erro) ───────────
export interface ToastMsg {
  type: "success" | "error";
  text: string;
}

export function Toast({ toast, onClose }: { toast: ToastMsg | null; onClose: () => void }) {
  useEffect(() => {
    if (toast) {
      const t = setTimeout(onClose, 3500);
      return () => clearTimeout(t);
    }
  }, [toast, onClose]);

  if (!toast) return null;
  const ok = toast.type === "success";

  return (
    <div style={{ position: "fixed", top: 18, right: 18, zIndex: 1090, minWidth: 280 }}>
      <div
        className="card shadow-sm"
        style={{ borderLeft: `4px solid ${ok ? "#2fb344" : "#d63939"}` }}
      >
        <div className="card-body d-flex align-items-center py-2">
          <span className="avatar avatar-sm me-2" style={{ background: ok ? "rgba(47,179,68,.12)" : "rgba(214,57,57,.12)", color: ok ? "#2fb344" : "#d63939" }}>
            {ok ? <IconCheck size={18} /> : <IconAlertTriangle size={18} />}
          </span>
          <div className="fw-medium">{toast.text}</div>
        </div>
      </div>
    </div>
  );
}
