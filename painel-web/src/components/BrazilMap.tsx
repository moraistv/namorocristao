import { useState } from "react";
import { ComposableMap, Geographies, Geography } from "react-simple-maps";

interface StateRow { uf: string; nome: string; count: number; }

function lerp(a: number, b: number, t: number) { return Math.round(a + (b - a) * t); }
function colorFor(count: number, max: number) {
  if (count <= 0) return "#e3e7f0"; // cinza claro pra estados sem usuários
  const t = Math.min(1, count / max);
  // de navy claro (#6b79a8) a nossa navy (#111d40)
  const r = lerp(0x6b, 0x11, t), g = lerp(0x79, 0x1d, t), b = lerp(0xa8, 0x40, t);
  return `rgb(${r},${g},${b})`;
}

export default function BrazilMap({ data, height = 340 }: { data: StateRow[]; height?: number }) {
  const byUf: Record<string, StateRow> = {};
  data.forEach((d) => { if (d.uf && d.uf !== "—") byUf[d.uf] = d; });
  const max = Math.max(1, ...data.map((d) => d.count));
  const [sel, setSel] = useState<StateRow | null>(null);

  return (
    <div>
      <div style={{ height }}>
        <ComposableMap
          projection="geoMercator"
          projectionConfig={{ scale: 400, center: [-54, -15] }}
          width={400} height={height}
          style={{ width: "100%", height: "100%" }}
        >
          <Geographies geography="/br-states.json">
            {({ geographies }: any) =>
              geographies.map((geo: any) => {
                const uf = geo.properties.SIGLA;
                const row = byUf[uf];
                const count = row?.count ?? 0;
                return (
                  <Geography
                    key={geo.rsmKey}
                    geography={geo}
                    fill={colorFor(count, max)}
                    stroke="#ffffff"
                    strokeWidth={1}
                    onMouseEnter={() => setSel({ uf, nome: geo.properties.Estado, count })}
                    onClick={() => setSel({ uf, nome: geo.properties.Estado, count })}
                    style={{
                      default: { outline: "none" },
                      hover: { fill: "#d4af37", outline: "none", cursor: "pointer" },
                      pressed: { fill: "#b8962f", outline: "none" },
                    }}
                  />
                );
              })
            }
          </Geographies>
        </ComposableMap>
      </div>
      <div className="d-flex align-items-center justify-content-between mt-2">
        <div>
          {sel ? (
            <span><strong>{sel.nome}</strong> ({sel.uf}) — <strong>{sel.count}</strong> usuário(s)</span>
          ) : (
            <span className="text-secondary">Passe o mouse ou clique num estado</span>
          )}
        </div>
        <div className="d-flex align-items-center" style={{ fontSize: 12, color: "#919baf", gap: 6 }}>
          menos
          <span style={{ width: 60, height: 8, borderRadius: 4, background: "linear-gradient(90deg,#6b79a8,#111d40)" }} />
          mais
        </div>
      </div>
    </div>
  );
}
