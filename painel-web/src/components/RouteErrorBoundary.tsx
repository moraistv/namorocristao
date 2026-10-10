import { Component, type ErrorInfo, type ReactNode } from "react";

interface Props {
  children: ReactNode;
  resetKey?: string;
  fullScreen?: boolean;
}

interface State {
  error: Error | null;
}

function isChunkLoadError(error: Error): boolean {
  return /chunk|dynamically imported module|importing a module script|failed to fetch module/i.test(
    error.message
  );
}

export default class RouteErrorBoundary extends Component<Props, State> {
  state: State = { error: null };

  static getDerivedStateFromError(error: Error): State {
    return { error };
  }

  componentDidCatch(error: Error, info: ErrorInfo) {
    console.error("Falha ao renderizar o painel", error, info.componentStack);
  }

  componentDidUpdate(previousProps: Props) {
    if (
      this.state.error &&
      previousProps.resetKey !== this.props.resetKey
    ) {
      this.setState({ error: null });
    }
  }

  private retry = () => {
    if (this.state.error && isChunkLoadError(this.state.error)) {
      window.location.reload();
      return;
    }
    this.setState({ error: null });
  };

  private reload = () => window.location.reload();

  render() {
    const { error } = this.state;
    if (!error) return this.props.children;

    const chunkFailure = isChunkLoadError(error);
    return (
      <div className={this.props.fullScreen ? "error-boundary error-boundary-full" : "error-boundary"}>
        <div className="card error-boundary-card" role="alert" aria-live="assertive">
          <div className="card-body text-center">
            <h1 className="h3 mb-2">
              {chunkFailure ? "Não foi possível carregar esta parte do painel" : "Ocorreu um erro nesta tela"}
            </h1>
            <p className="text-secondary mb-4">
              {chunkFailure
                ? "Uma atualização ou falha de conexão pode ter interrompido o carregamento."
                : "Seus dados não foram alterados. Tente abrir a tela novamente."}
            </p>
            <div className="d-flex flex-wrap justify-content-center gap-2">
              <button type="button" className="btn btn-primary" onClick={this.retry}>
                Tentar novamente
              </button>
              <button type="button" className="btn" onClick={this.reload}>
                Recarregar o painel
              </button>
              <a className="btn btn-ghost-secondary" href="/">
                Ir ao Dashboard
              </a>
            </div>
          </div>
        </div>
      </div>
    );
  }
}
