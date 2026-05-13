import { useState, useEffect, useCallback, useRef } from 'react';
import type { Garment, GarmentEvent, RetentionAlert } from '../App';

const POLL_INTERVAL_MS = 5000;

interface PipelineStage {
  stage: string;
  count: number;
}

interface PipelineData {
  factory: PipelineStage[];
  loop: PipelineStage[];
}

const STAGE_META: Record<string, { label: string; icon: string; color: string; bg: string }> = {
  CHECK_IN: { label: 'Check In', icon: '📥', color: 'text-blue-400', bg: 'bg-blue-500/10 border-blue-500/40' },
  WASH:     { label: 'Wash',     icon: '🫧', color: 'text-cyan-400', bg: 'bg-cyan-500/10 border-cyan-500/40' },
  DRY:      { label: 'Dry',      icon: '🔥', color: 'text-yellow-400', bg: 'bg-yellow-500/10 border-yellow-500/40' },
  FOLD:     { label: 'Fold',     icon: '👔', color: 'text-purple-400', bg: 'bg-purple-500/10 border-purple-500/40' },
  DISPATCH: { label: 'Dispatch', icon: '🚚', color: 'text-orange-400', bg: 'bg-orange-500/10 border-orange-500/40' },
  DELIVER:  { label: 'Deliver',  icon: '✅', color: 'text-green-400', bg: 'bg-green-500/10 border-green-500/40' },
  CLEAN_OUT:     { label: 'Clean Out',     icon: '📦', color: 'text-emerald-400', bg: 'bg-emerald-500/10 border-emerald-500/40' },
  AT_CUSTOMER:   { label: 'At Customer',   icon: '🏢', color: 'text-amber-400', bg: 'bg-amber-500/10 border-amber-500/40' },
  SOILED_RETURN: { label: 'Soiled Return', icon: '🔄', color: 'text-pink-400', bg: 'bg-pink-500/10 border-pink-500/40' },
};

const STATUS_COLORS: Record<string, string> = {
  IN_SERVICE: 'bg-green-500/20 text-green-400 border-green-500/30',
  LOST: 'bg-red-500/20 text-red-400 border-red-500/30',
  RETIRED: 'bg-gray-500/20 text-gray-400 border-gray-500/30',
};

const LIFECYCLE_COLORS: Record<string, string> = {
  IN_PLANT: 'text-blue-400',
  IN_TRANSIT_OUT: 'text-orange-400',
  AT_CUSTOMER: 'text-amber-400',
  IN_TRANSIT_BACK: 'text-pink-400',
  ZOMBIE: 'text-red-400',
  RETIRED: 'text-gray-400',
};

const EVENT_COLORS: Record<string, string> = {
  CHECK_IN: 'text-blue-400',
  WASH: 'text-cyan-400',
  DRY: 'text-yellow-400',
  FOLD: 'text-purple-400',
  DISPATCH: 'text-orange-400',
  DELIVER: 'text-green-400',
  CLEAN_OUT: 'text-emerald-400',
  AT_CUSTOMER: 'text-amber-400',
  SOILED_RETURN: 'text-pink-400',
  LOST: 'text-red-400',
};

export default function GarmentPage({ onToast }: { onToast: (msg: string) => void }) {
  const [garments, setGarments] = useState<Garment[]>([]);
  const [events, setEvents] = useState<GarmentEvent[]>([]);
  const [pipeline, setPipeline] = useState<PipelineData>({ factory: [], loop: [] });
  const [alerts, setAlerts] = useState<RetentionAlert[]>([]);
  const [loading, setLoading] = useState(true);
  const [pulsingStage, setPulsingStage] = useState<string | null>(null);
  const prevEventCountRef = useRef(0);

  const fetchData = useCallback(async () => {
    try {
      const [gRes, eRes, pRes, aRes] = await Promise.all([
        fetch('/api/garments'),
        fetch('/api/garment-events'),
        fetch('/api/garment-pipeline'),
        fetch('/api/retention-alerts'),
      ]);
      const newGarments = await gRes.json();
      const newEvents: GarmentEvent[] = await eRes.json();
      const newPipeline: PipelineData = await pRes.json();
      const newAlerts: RetentionAlert[] = await aRes.json();

      if (prevEventCountRef.current > 0 && newEvents.length > 0) {
        const newCount = newEvents[0].event_id;
        if (newCount > prevEventCountRef.current) {
          const latest = newEvents[0];
          onToast(`${latest.garment_id} → ${latest.event_type} at ${latest.location}`);
          setPulsingStage(latest.event_type);
          setTimeout(() => setPulsingStage(null), 2000);
        }
      }
      if (newEvents.length > 0) {
        prevEventCountRef.current = newEvents[0].event_id;
      }

      setGarments(newGarments);
      setEvents(newEvents);
      setPipeline(newPipeline);
      setAlerts(newAlerts);
    } catch (e) {
      console.error('Failed to fetch garment data', e);
    }
  }, [onToast]);

  useEffect(() => {
    fetchData().then(() => setLoading(false));
  }, [fetchData]);

  useEffect(() => {
    const interval = setInterval(fetchData, POLL_INTERVAL_MS);
    return () => clearInterval(interval);
  }, [fetchData]);

  if (loading) {
    return (
      <div className="flex-1 flex items-center justify-center">
        <div className="text-xl text-gray-400 animate-pulse">Loading garment data...</div>
      </div>
    );
  }

  const totalGarments = garments.length;
  const inService = garments.filter(g => g.status === 'IN_SERVICE').length;
  const zombieCount = garments.filter(g => g.lifecycle_state === 'ZOMBIE').length;
  const nearRetirement = garments.filter(g => g.wash_cycle_pct >= 90).length;
  const totalExposure = garments
    .filter(g => g.lifecycle_state === 'ZOMBIE')
    .reduce((sum, g) => sum + g.replacement_cost, 0);

  return (
    <div className="flex-1 flex flex-col overflow-hidden">
      <div className="flex items-center gap-8 px-6 py-2.5 bg-gray-900/80 border-b border-gray-800">
        <Kpi label="Total Tracked" value={totalGarments} color="text-white" />
        <Kpi label="In Service" value={inService} color="text-green-400" />
        <Kpi label="Zombies" value={zombieCount} color="text-red-400" />
        <Kpi label="Near Retirement" value={nearRetirement} color="text-amber-400" />
        <div className="w-px h-6 bg-gray-700" />
        <Kpi label="Financial Exposure" value={`$${totalExposure.toLocaleString(undefined, { maximumFractionDigits: 0 })}`} color="text-red-400" />
      </div>

      <div className="px-6 py-3 bg-gray-900/40 border-b border-gray-800">
        <div className="flex items-center gap-4 mb-3">
          <h2 className="text-[10px] font-semibold text-gray-500 uppercase tracking-widest">
            Customer Loop
          </h2>
          {zombieCount > 0 && (
            <span className="px-2 py-0.5 rounded bg-red-500/20 border border-red-500/40 text-red-400 text-[10px] font-bold uppercase animate-pulse">
              {zombieCount} Zombie{zombieCount !== 1 ? 's' : ''}
            </span>
          )}
        </div>
        <div className="flex items-center gap-1 mb-4">
          {pipeline.loop.map((stage, idx) => {
            const meta = STAGE_META[stage.stage];
            if (!meta) return null;
            const isPulsing = pulsingStage === stage.stage;
            return (
              <div key={stage.stage} className="flex items-center flex-1">
                <div
                  className={`flex-1 flex flex-col items-center p-2 rounded-lg border transition-all duration-500 ${meta.bg} ${
                    isPulsing ? 'ring-2 ring-white/30 scale-105' : ''
                  }`}
                >
                  <span className="text-xl mb-0.5">{meta.icon}</span>
                  <span className={`text-2xl font-bold tabular-nums ${meta.color} transition-all duration-300`}>
                    {stage.count}
                  </span>
                  <span className="text-[9px] text-gray-400 uppercase tracking-wider mt-0.5">{meta.label}</span>
                </div>
                {idx < pipeline.loop.length - 1 && (
                  <div className="px-1 text-gray-600 text-lg">→</div>
                )}
              </div>
            );
          })}
          <div className="px-1 text-gray-600 text-lg">↻</div>
        </div>

        <h2 className="text-[10px] font-semibold text-gray-500 uppercase tracking-widest mb-3">
          Factory Pipeline
        </h2>
        <div className="flex items-center justify-between gap-1">
          {pipeline.factory.map((stage, idx) => {
            const meta = STAGE_META[stage.stage];
            if (!meta) return null;
            const isPulsing = pulsingStage === stage.stage;
            return (
              <div key={stage.stage} className="flex items-center flex-1">
                <div
                  className={`flex-1 flex flex-col items-center p-2 rounded-lg border transition-all duration-500 ${meta.bg} ${
                    isPulsing ? 'ring-2 ring-white/30 scale-105' : ''
                  }`}
                >
                  <span className="text-xl mb-0.5">{meta.icon}</span>
                  <span className={`text-2xl font-bold tabular-nums ${meta.color} transition-all duration-300`}>
                    {stage.count}
                  </span>
                  <span className="text-[9px] text-gray-400 uppercase tracking-wider mt-0.5">{meta.label}</span>
                </div>
                {idx < pipeline.factory.length - 1 && (
                  <div className="px-1 text-gray-600 text-lg">→</div>
                )}
              </div>
            );
          })}
        </div>
      </div>

      <div className="flex-1 flex overflow-hidden">
        <div className="flex-1 overflow-auto p-4">
          <h2 className="text-sm font-semibold text-gray-400 uppercase tracking-wider mb-3">Garment Inventory</h2>
          <table className="w-full text-sm">
            <thead>
              <tr className="text-left text-gray-500 border-b border-gray-800">
                <th className="pb-2 pr-3">ID</th>
                <th className="pb-2 pr-3">Type</th>
                <th className="pb-2 pr-3">Customer</th>
                <th className="pb-2 pr-3">State</th>
                <th className="pb-2 pr-3">Days</th>
                <th className="pb-2 pr-3">Life %</th>
                <th className="pb-2">Cost</th>
              </tr>
            </thead>
            <tbody>
              {garments.slice(0, 60).map(g => {
                const stateColor = LIFECYCLE_COLORS[g.lifecycle_state] || 'text-gray-500';
                const isZombie = g.lifecycle_state === 'ZOMBIE';
                return (
                  <tr key={g.garment_id} className={`border-b border-gray-800/50 hover:bg-gray-800/30 ${isZombie ? 'bg-red-900/10' : ''}`}>
                    <td className="py-2 pr-3 font-mono text-xs">{g.garment_id}</td>
                    <td className="py-2 pr-3">{g.garment_type}</td>
                    <td className="py-2 pr-3 text-gray-400">{g.customer_name || '-'}</td>
                    <td className="py-2 pr-3">
                      <span className={`text-xs font-bold ${stateColor}`}>
                        {g.lifecycle_state}
                      </span>
                    </td>
                    <td className={`py-2 pr-3 text-xs ${g.days_at_location > 14 ? 'text-red-400 font-bold' : 'text-gray-400'}`}>
                      {g.days_at_location}d
                    </td>
                    <td className={`py-2 pr-3 text-xs ${g.wash_cycle_pct >= 90 ? 'text-amber-400 font-bold' : 'text-gray-400'}`}>
                      {g.wash_cycle_pct.toFixed(0)}%
                    </td>
                    <td className="py-2 text-xs text-gray-400">${g.replacement_cost.toFixed(2)}</td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>

        <div className="w-96 border-l border-gray-800 flex flex-col overflow-hidden">
          {alerts.length > 0 && (
            <div className="p-4 border-b border-gray-800 overflow-auto max-h-[45%]">
              <h2 className="text-sm font-semibold text-red-400 uppercase tracking-wider mb-3 flex items-center gap-2">
                <span className="w-2 h-2 rounded-full bg-red-500 animate-pulse" />
                Retention Alerts
              </h2>
              <div className="space-y-2">
                {alerts.map(a => (
                  <div key={a.alert_id} className="p-3 rounded bg-red-900/20 border border-red-800/40">
                    <div className="flex items-center justify-between mb-1">
                      <span className="text-xs font-bold text-red-300">{a.customer_name}</span>
                      <span className="text-xs font-bold text-red-400">${a.financial_save_usd.toFixed(0)}</span>
                    </div>
                    <div className="text-[11px] text-gray-400 mb-1">
                      {a.missing_tag_count} missing tags · {a.industry} · {a.route_name || 'Unassigned'}
                    </div>
                    <div className="text-[11px] text-gray-300 italic leading-relaxed">
                      "{a.driver_talking_point.slice(0, 150)}{a.driver_talking_point.length > 150 ? '...' : ''}"
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}

          <div className="flex-1 overflow-auto p-4">
            <h2 className="text-sm font-semibold text-gray-400 uppercase tracking-wider mb-3">Live Event Feed</h2>
            <div className="space-y-2">
              {events.slice(0, 25).map(e => (
                <div key={e.event_id} className="p-2.5 rounded bg-gray-800/50 border border-gray-700/50">
                  <div className="flex items-center justify-between mb-0.5">
                    <span className={`text-xs font-bold ${EVENT_COLORS[e.event_type] || 'text-gray-400'}`}>
                      {e.event_type}
                    </span>
                    <span className="text-[10px] text-gray-600 font-mono">
                      {new Date(e.timestamp).toLocaleTimeString()}
                    </span>
                  </div>
                  <div className="text-xs text-gray-300">
                    {e.garment_id} · {e.garment_type}
                  </div>
                  <div className="text-[11px] text-gray-500 mt-0.5">
                    {e.location}
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>
      </div>
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
