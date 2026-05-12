import type { TelemetryPoint } from '../App';

interface Props {
  activeVehicles: number;
  totalCustomers: number;
  currentPositions: TelemetryPoint[];
}

export default function KpiBar({ activeVehicles, totalCustomers, currentPositions }: Props) {
  const inTransit = currentPositions.filter(p => p.speed_mph > 0).length;
  const atStop = currentPositions.filter(p => p.engine_status === 'IDLE').length;
  const avgSpeed = currentPositions.length > 0
    ? (currentPositions.reduce((sum, p) => sum + p.speed_mph, 0) / currentPositions.length).toFixed(1)
    : '0.0';

  return (
    <div className="flex items-center gap-6 px-6 py-2 bg-gray-900/80 border-b border-gray-800">
      <Kpi label="Vehicles Active" value={activeVehicles} color="text-green-400" />
      <Kpi label="In Transit" value={inTransit} color="text-emerald-400" />
      <Kpi label="At Stop" value={atStop} color="text-yellow-400" />
      <Kpi label="Avg Speed" value={`${avgSpeed} mph`} color="text-blue-400" />
      <Kpi label="Customers" value={totalCustomers} color="text-indigo-400" />
    </div>
  );
}

function Kpi({ label, value, color }: { label: string; value: string | number; color: string }) {
  return (
    <div className="flex flex-col">
      <span className="text-[10px] uppercase tracking-wider text-gray-500">{label}</span>
      <span className={`text-xl font-bold ${color}`}>{value}</span>
    </div>
  );
}
