import type { Position, ZombieSummary } from '../App';

interface Props {
  positions: Position[];
  totalCustomers: number;
  zombieSummary: ZombieSummary;
}

export default function KpiBar({ positions, totalCustomers, zombieSummary }: Props) {
  const total = positions.length;
  const inTransit = positions.filter(p => p.speed_mph > 0).length;
  const atStop = positions.filter(p => p.engine_status === 'IDLE' && p.speed_mph === 0).length;
  const avgSpeed = total > 0
    ? (positions.reduce((sum, p) => sum + p.speed_mph, 0) / total).toFixed(1)
    : '0.0';

  return (
    <div className="flex items-center gap-8 px-6 py-2.5 bg-gray-900/80 border-b border-gray-800">
      <Kpi label="Vehicles" value={total} color="text-white" />
      <Kpi label="In Transit" value={inTransit} color="text-green-400" />
      <Kpi label="At Stop" value={atStop} color="text-yellow-400" />
      <Kpi label="Avg Speed" value={`${avgSpeed} mph`} color="text-blue-400" />
      <Kpi label="Customers" value={totalCustomers} color="text-indigo-400" />
      <div className="w-px h-6 bg-gray-700" />
      <Kpi label="Zombie Garments" value={zombieSummary.zombie_count} color="text-red-400" />
      <Kpi label="Exposure" value={`$${zombieSummary.total_exposure_usd.toLocaleString(undefined, { maximumFractionDigits: 0 })}`} color="text-red-400" />
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
