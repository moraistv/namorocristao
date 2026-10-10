import {
  useEffect,
  useId,
  useRef,
  useState,
  type HTMLInputTypeAttribute,
} from "react";
import { IconAlertTriangle, IconCheck, IconX } from "@tabler/icons-react";
import { useModalAccessibility } from "./useModalAccessibility";

// Diálogo de confirmação/entrada compartilhado.
export interface DialogConfig {
  title: string;
  message?: string;
  confirmText?: string;
  cancelText?: string;
  danger?: boolean;
  icon?: typeof IconCheck;
  input?: {
    label?: string;
    placeholder?: string;
    default?: string;
    type?: HTMLInputTypeAttribute;
  };
  onConfirm: (value: string) => void | Promise<void>;
}

export function Dialog({ config, onClose }: { config: DialogConfig | null; onClose: () => void }) {
  const titleId = useId();
  const descriptionId = useId();
  const inputId = useId();
  const [val, setVal] = useState("");
  const [pending, setPending] = useState(false);
  const [error, setError] = useState("");

  useEffect(() => {
    setVal(config?.input?.default ?? "");
    setPending(false);
    setError("");
  }, [config]);

  const close = () => {
    if (!pending) onClose();
  };
  const dialogRef = useModalAccessibility({
    open: Boolean(config),
    onClose: close,
    canClose: !pending,
  });

  if (!config) return null;
  const Icon = config.icon;

  async function confirm() {
    if (pending) return;
    setPending(true);
    setError("");
    try {
      await config!.onConfirm(val);
      onClose();
    } catch (confirmError: unknown) {
      setError(
        confirmError instanceof Error && confirmError.message
          ? confirmError.message
          : "Não foi possível concluir a operação."
      );
    } finally {
      setPending(false);
    }
  }

  return (
    <>
      <div
        ref={dialogRef}
        className="modal modal-blur fade show d-block"
        tabIndex={-1}
        role="dialog"
        aria-modal="true"
        aria-labelledby={titleId}
        aria-describedby={config.message ? descriptionId : undefined}
      >
        <div className="modal-dialog modal-sm modal-dialog-centered" role="document">
          <div className="modal-content">
            <div className="modal-header" style={{ background: "#111d40" }}>
              <h2 id={titleId} className="modal-title h5 d-flex align-items-center" style={{ color: "#fff", gap: 8 }}>
                {Icon && <Icon size={18} color={config.danger ? "#ff8a8a" : "#e9c75a"} aria-hidden="true" />}
                {config.title}
              </h2>
              <button
                type="button"
                className="btn-close btn-close-white"
                aria-label="Fechar diálogo"
                disabled={pending}
                onClick={close}
              />
            </div>
            <div className="modal-body">
              {config.message && <p id={descriptionId} className="text-secondary mb-3">{config.message}</p>}
              {config.input && (
                <div>
                  {config.input.label && <label className="form-label" htmlFor={inputId}>{config.input.label}</label>}
                  <input
                    id={inputId}
                    className="form-control"
                    type={config.input.type ?? "text"}
                    placeholder={config.input.placeholder}
                    value={val}
                    data-modal-initial
                    disabled={pending}
                    aria-invalid={error ? true : undefined}
                    onChange={(event) => setVal(event.target.value)}
                    onKeyDown={(event) => {
                      if (event.key === "Enter") {
                        event.preventDefault();
                        void confirm();
                      }
                    }}
                  />
                </div>
              )}
              {error && <div className="alert alert-danger mt-3 mb-0 py-2" role="alert">{error}</div>}
            </div>
            <div className="modal-footer">
              <button
                type="button"
                className="btn"
                data-modal-initial={config.input ? undefined : true}
                disabled={pending}
                onClick={close}
              >
                {config.cancelText ?? "Cancelar"}
              </button>
              <button
                type="button"
                className={`btn ${config.danger ? "btn-danger" : "btn-primary"}`}
                disabled={pending}
                aria-busy={pending}
                onClick={() => void confirm()}
              >
                {pending && <span className="spinner-border spinner-border-sm me-2" aria-hidden="true" />}
                {pending ? "Aguarde..." : config.confirmText ?? "Confirmar"}
              </button>
            </div>
          </div>
        </div>
      </div>
      <div
        className="modal-backdrop fade show"
        aria-hidden="true"
        onMouseDown={close}
      />
    </>
  );
}

export interface ToastMsg {
  type: "success" | "error";
  text: string;
}

export function Toast({ toast, onClose }: { toast: ToastMsg | null; onClose: () => void }) {
  const onCloseRef = useRef(onClose);
  onCloseRef.current = onClose;

  useEffect(() => {
    if (!toast) return;
    const timer = window.setTimeout(() => onCloseRef.current(), 5_000);
    return () => window.clearTimeout(timer);
  }, [toast]);

  if (!toast) return null;
  const ok = toast.type === "success";

  return (
    <div className="toast-region">
      <div
        className="card shadow-sm toast-card"
        style={{ borderLeft: `4px solid ${ok ? "#2fb344" : "#d63939"}` }}
        role={ok ? "status" : "alert"}
        aria-live={ok ? "polite" : "assertive"}
        aria-atomic="true"
      >
        <div className="card-body d-flex align-items-center py-2">
          <span
            className="avatar avatar-sm me-2"
            style={{
              background: ok ? "rgba(47,179,68,.12)" : "rgba(214,57,57,.12)",
              color: ok ? "#2fb344" : "#d63939",
            }}
            aria-hidden="true"
          >
            {ok ? <IconCheck size={18} /> : <IconAlertTriangle size={18} />}
          </span>
          <div className="fw-medium flex-fill">{toast.text}</div>
          <button
            type="button"
            className="btn btn-sm btn-icon btn-ghost-secondary ms-2"
            aria-label="Fechar notificação"
            onClick={onClose}
          >
            <IconX size={16} aria-hidden="true" />
          </button>
        </div>
      </div>
    </div>
  );
}
