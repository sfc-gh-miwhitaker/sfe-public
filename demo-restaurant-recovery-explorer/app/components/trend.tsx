// Pair-programmed by SE Community + Cortex Code
import type { Exploration } from "../lib/analytics";

export default function TrendChart({ result }: { result: Exploration }) {
  const points = result.peers.trend;
  const values = points
    .flatMap((row) => [row.index, row.peerIndex])
    .filter((value): value is number => value !== null);
  const minimum = Math.floor((Math.min(70, ...values) - 5) / 10) * 10;
  const maximum = Math.ceil((Math.max(110, ...values) + 5) / 10) * 10;
  const horizontal = (index: number) =>
    45 + (index / Math.max(points.length - 1, 1)) * 645;
  const vertical = (value: number) =>
    155 - ((value - minimum) / (maximum - minimum)) * 125;
  const path = (field: "index" | "peerIndex") =>
    points
      .map((row, index) =>
        row[field] === null
          ? ""
          : `${index === 0 || points[index - 1][field] === null ? "M" : "L"}${horizontal(index)},${vertical(row[field]!)}`,
      )
      .join(" ");
  const analysisIndex = points.findIndex(
    (row) => row.week === result.market.start,
  );
  return (
    <div className="trend">
      <div className="section-title">
        <h3>Before and after</h3>
        <span>Pre-period average = 100</span>
      </div>
      <svg
        viewBox="0 0 720 195"
        role="img"
        aria-label="Restaurant and matched peer trends normalized to their pre-period means"
      >
        <rect
          x={horizontal(analysisIndex)}
          y="15"
          width={700 - horizontal(analysisIndex)}
          height="145"
          fill="#edf7fc"
        />
        {[minimum, 100, maximum]
          .filter((value, index, array) => array.indexOf(value) === index)
          .map((value) => (
            <g key={value}>
              <line
                x1="45"
                x2="700"
                y1={vertical(value)}
                y2={vertical(value)}
                stroke="#dce3e8"
                strokeDasharray="3 4"
              />
              <text x="6" y={vertical(value) + 4} fontSize="11" fill="#475569">
                {value}
              </text>
            </g>
          ))}
        <path
          d={path("peerIndex")}
          fill="none"
          stroke="#8997a6"
          strokeWidth="2.5"
          strokeDasharray="6 4"
        />
        <path d={path("index")} fill="none" stroke="#147fa8" strokeWidth="3" />
        <text x="45" y="183" fontSize="11" fill="#475569">
          {points[0]?.week}
        </text>
        <text
          x={horizontal(analysisIndex)}
          y="183"
          fontSize="11"
          fill="#475569"
        >
          Analysis
        </text>
        <text x="700" y="183" textAnchor="end" fontSize="11" fill="#475569">
          {points.at(-1)?.week}
        </text>
      </svg>
      <div className="chart-legend">
        <span className="focal-line">Restaurant</span>
        <span className="peer-line">Equal-weight matched peers</span>
        <span>Missing observations remain gaps</span>
      </div>
    </div>
  );
}
