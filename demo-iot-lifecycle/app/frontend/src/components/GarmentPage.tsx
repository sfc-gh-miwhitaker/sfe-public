import { useState, useEffect, useCallback } from 'react';
import type { Garment, GarmentEvent } from '../App';

const POLL_INTERVAL_MS = 5000;

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

export default function GarmentPage() {
  const [garments, setGarments] = useState<Garment[]>([]);
  const [events, setEvents] = useState<GarmentEvent[]>([]);
  const [loading, setLoading] = useState(true);

  const fetchData = useCallback(async () => {
    try {
      const [gRes, eRes] = await Promise.all([
        fetch('/api/garments'),
        fetch('/api/garment-events'),
      ]);
      setGarments(await gRes.json());
      setEvents(await eRes.json());
    } catch (e) {
      console.error('Failed to fetch garment data', e);
    }
  }, []);

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

      <div className="flex-1 flex overflow-hidden">
        <div className="flex-1 overflow-auto p-4">
          <h2 className="text-sm font-semibold text-gray-400 uppercase tracking-wider mb-3">Garment Inventory</h2>
          <table className="w-full text-sm">
            <thead>
              <tr className="text-left text-gray-500 border-b border-gray-800">
                <th className="pb-2 pr-3">ID</th>
                <th className="pb-2 pr-3">RFID</th>
                <th className="pb-2 pr-3">Type</th>
                <th className="pb-2 pr-3">Customer</th>
                <th className="pb-2 pr-3">Status</th>
                <th className="pb-2 pr-3">Washes</th>
                <th className="pb-2 pr-3">Last Event</th>
                <th className="pb-2">Hours Ago</th>
              </tr>
            </thead>
            <tbody>
              {garments.map(g => (
                <tr key={g.garment_id} className="border-b border-gray-800/50 hover:bg-gray-800/30">
                  <td className="py-2 pr-3 font-mono text-xs">{g.garment_id}</td>
                  <td className="py-2 pr-3 font-mono text-xs text-gray-500">{g.rfid_tag}</td>
                  <td className="py-2 pr-3">{g.garment_type}</td>
                  <td className="py-2 pr-3 text-gray-400">{g.customer_name || '-'}</td>
                  <td className="py-2 pr-3">
                    <span className={`px-2 py-0.5 rounded border text-xs font-medium ${STATUS_COLORS[g.status] || 'text-gray-400'}`}>
                      {g.status}
                    </span>
                  </td>
                  <td className="py-2 pr-3 text-center">{g.wash_count}</td>
                  <td className="py-2 pr-3 text-gray-400">{g.last_event || '-'}</td>
                  <td className="py-2 text-gray-500">{g.hours_since_last_event ?? '-'}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        <div className="w-96 border-l border-gray-800 overflow-auto p-4">
          <h2 className="text-sm font-semibold text-gray-400 uppercase tracking-wider mb-3">Event Feed</h2>
          <div className="space-y-2">
            {events.map(e => (
              <div key={e.event_id} className="p-3 rounded bg-gray-800/50 border border-gray-700/50">
                <div className="flex items-center justify-between mb-1">
                  <span className={`text-xs font-bold ${EVENT_COLORS[e.event_type] || 'text-gray-400'}`}>
                    {e.event_type}
                  </span>
                  <span className="text-[10px] text-gray-500">{e.timestamp}</span>
                </div>
                <div className="text-xs text-gray-300">
                  {e.garment_id} &middot; {e.garment_type}
                </div>
                <div className="text-xs text-gray-500 mt-0.5">
                  {e.location} {e.notes && `— ${e.notes}`}
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
