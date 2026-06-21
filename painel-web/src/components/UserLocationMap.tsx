import { ComposableMap, Geographies, Geography, Marker } from "react-simple-maps";

interface Props {
  uf?: string | null;
  latitude?: number | null;
  longitude?: number | null;
  height?: number;
}

export default function UserLocationMap({ uf, latitude, longitude, height = 300 }: Props) {
  return (
    <div style={{ height }}>
      <ComposableMap
        projection="geoMercator"
        projectionConfig={{ scale: 520, center: [-54, -15] }}
        width={400}
        height={height}
        style={{ width: "100%", height: "100%" }}
      >
        <Geographies geography="/br-states.json">
          {({ geographies }: any) =>
            geographies.map((geo: any) => {
              const isSel = uf && geo.properties.SIGLA === uf;
              return (
                <Geography
                  key={geo.rsmKey}
                  geography={geo}
                  fill={isSel ? "#d4af37" : "#e3e7f0"}
                  stroke="#ffffff"
                  strokeWidth={0.8}
                  style={{
                    default: { outline: "none" },
                    hover: { outline: "none", fill: isSel ? "#d4af37" : "#cdd3e0" },
                    pressed: { outline: "none" },
                  }}
                />
              );
            })
          }
        </Geographies>
        {latitude != null && longitude != null && (
          <Marker coordinates={[longitude, latitude]}>
            <circle r={6} fill="#e23744" stroke="#fff" strokeWidth={2} />
            <circle r={12} fill="#e23744" opacity={0.25} />
          </Marker>
        )}
      </ComposableMap>
    </div>
  );
}
