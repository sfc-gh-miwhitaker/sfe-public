import { useState, useEffect, useCallback, useRef } from 'react';
import type { Garment, GarmentEvent } from '../App';

const POLL_INTERVAL_MS = 5000;

interface PipelineStage {
  stage: string;
  count: number;
}

const STAGE_META: Record<string, { label: string; icon: string; color: string; bg: string }> = {
  CHECK_IN: { label: 'Check In', icon: '📥', color: 'text-blue-400', bg: 'bg-blue-500/10 border-blue-500/40' },
  WASH:     { label: 'Wash',     icon: '🫧', color: 'text-cyan-400', bg: 'bg-cyan-500/10 border-cyan-500/40' },
  DRY:      { label: 'Dry',      icon: '🔥', color: 'text-yellow-400', bg: 'bg-yellow-500/10 border-yellow-500/40' },
  FOLD:     { label: 'Fold',     icon: '👔', color: 'text-purple-400', bg: 'bg-purple-500/10 border-purple-500/40' },
  DISPATCH: { label: 'Dispatch', icon: '🚚', color: 'text-orange-400', bg: 'bg-orange-500/10 border-orange-500/40' },
  DELIVER:  { label: 'Deliver',  icon: '✅', color: 'text-green-400', bg: 'bg-green-500/10 border-green-500/40' },
};

const STATUS_COLORS: Record<string, string> = {
  IN_SERVICE: 'bg-green-500/20 text-green-400 border-green-500/30',
  LOST: 'bg-red-500/20 text-red-400 border-red-500/30',
  RETIRED: 'bg-gray-500/20 text-gray-400 border-gray-500/30',
};

const EVENT_COLORS: Record<string, string> = {
  CHECK_IN: 'text-blue-400',
  WASH: 'text-cyan-400',
  DRY: 'text-yellow-400',
  FOLD: 'text-purple-400',
  DISPATCH: 'text-orange-400',
  DELIVER: 'text-green-400',
  LOST: 'text-red-400',
};

export default function GarmentPage({ onToast }: { onToast: (msg: string) => void }) {
  const [garments, setGarments] = useState<Garment[]>([]);
  const [events, setEvents] = useState<GarmentEvent[]>([]);
  const [pipeline, setPipeline] = useState<PipelineStage[]>([]);
  const [loading, setLoading] = useState(true);
  const [pulsingStage, setPulsingStage] = useState<string | null>(null);
  const prevEventCountRef = useRef(0);
  const prevPipelineRef = useRef<PipelineStage[]>([]);

  const fetchData = useCallback(async () => {
    try {
      const [gRes, eRes, pRes] = await Promise.all([
        fetch('/api/garments'),
        fetch('/api/garment-events'),
        fetch('/api/garment-pipeline'),
      ]);
      const newGarments = await gRes.json();
      const newEvents: GarmentEvent[] = await eRes.json();
      const newPipeline: PipelineStage[] = await pRes.json();

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

      prevPipelineRef.current = newPipeline;
      setGarments(newGarments);
      setEvents(newEvents);
      setPipeline(newPipeline);
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
  const lost = garments.filter(g => g.status === 'LOST').length;
  const avgWash = totalGarments > 0
    ? (garments.reduce((sum, g) => sum + g.wash_count, 0) / totalGarments).toFixed(0)
    : '0';

  return (
    <div className="flex-1 flex flex-col overflow-hidden">
      <div className="flex items-center gap-8 px-6 py-2.5 bg-gray-900/80 border-b border-gray-800">
        <Kpi label="Total Tracked" value={totalGarments} color="text-white" />
        <Kpi label="In Service" value={inService} color="text-green-400" />
        <Kpi label="Lost" value={lost} color="text-red-400" />
        <Kpi label="Avg Washes" value={avgWash} color="text-blue-400" />
      </div>

      <div className="px-6 py-4 bg-gray-900/40 border-b border-gray-800">
        <h2 className="text-[10px] font-semibold text-gray-500 uppercase tracking-widest mb-3">
          Garment Lifecycle Pipeline
        </h2>
        <div className="flex items-center justify-between gap-1">
          {pipeline.map((stage, idx) => {
            const meta = STAGE_META[stage.stage];
            if (!meta) return null;
            const isPulsing = pulsingStage === stage.stage;
            return (
              <div key={stage.stage} className="flex items-center flex-1">
                <div
                  className={`flex-1 flex flex-col items-center p-3 rounded-lg border transition-all duration-500 ${meta.bg} ${
                    isPulsing ? 'ring-2 ring-white/30 scale-105' : ''
                  }`}
                >
                  <span className="text-2xl mb-1">{meta.icon}</span>
                  <span className={`text-3xl font-bold tabular-nums ${meta.color} transition-all duration-300`}>
                    {stage.count}
                  </span>
                  <span className="text-[10px] text-gray-400 uppercase tracking-wider mt-1">{meta.label}</span>
                </div>
                {idx < pipeline.length - 1 && (
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
                <th className="pb-2 pr-3">Status</th>
                <th className="pb-2 pr-3">Stage</th>
                <th className="pb-2 pr-3">Washes</th>
                <th className="pb-2">Last Seen</th>
              </tr>
            </thead>
            <tbody>
              {garments.map(g => {
                const stageColor = EVENT_COLORS[g.last_event || ''] || 'text-gray-500';
                return (
                  <tr key={g.garment_id} className="border-b border-gray-800/50 hover:bg-gray-800/30">
                    <td className="py-2 pr-3 font-mono text-xs">{g.garment_id}</td>
                    <td className="py-2 pr-3">{g.garment_type}</td>
                    <td className="py-2 pr-3 text-gray-400">{g.customer_name || '-'}</td>
                    <td className="py-2 pr-3">
                      <span className={`px-2 py-0.5 rounded border text-xs font-medium ${STATUS_COLORS[g.status] || 'text-gray-400'}`}>
                        {g.status}
                      </span>
                    </td>
                    <td className={`py-2 pr-3 text-xs font-bold ${stageColor}`}>{g.last_event || '—'}</td>
                    <td className="py-2 pr-3 text-center">{g.wash_count}</td>
                    <td className="py-2 text-gray-500 text-xs">
                      {g.hours_since_last_event != null ? `${g.hours_since_last_event}h ago` : '—'}
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>

        <div className="w-80 border-l border-gray-800 overflow-auto p-4">
          <h2 className="text-sm font-semibold text-gray-400 uppercase tracking-wider mb-3">Live Event Feed</h2>
          <div className="space-y-2">
            {events.slice(0, 30).map(e => (
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
