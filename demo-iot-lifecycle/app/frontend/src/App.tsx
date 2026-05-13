import { useState, useEffect, useCallback, useRef } from 'react';
import FleetMap from './components/FleetMap';
import KpiBar from './components/KpiBar';
import GarmentPage from './components/GarmentPage';
import Toast from './components/Toast';

export interface Position {
  vehicle_id: string;
  latitude: number;
  longitude: number;
  speed_mph: number;
  engine_status: string;
  timestamp: string;
}

export interface Customer {
  customer_id: string;
  customer_name: string;
  industry: string;
  latitude: number;
  longitude: number;
  risk_band: string;
  zombie_count: number;
  financial_exposure_usd: number;
}

export interface Garment {
  garment_id: string;
  rfid_tag: string;
  garment_type: string;
  size: string;
  color: string;
  customer_id: string;
  status: string;
  wash_count: number;
  last_event: string | null;
  last_event_time: string | null;
  hours_since_last_event: number | null;
  customer_name: string | null;
  lifecycle_state: string;
  days_at_location: number;
  replacement_cost: number;
  useful_life_cycles: number;
  wash_cycle_pct: number;
}

export interface GarmentEvent {
  event_id: number;
  garment_id: string;
  garment_type: string;
  event_type: string;
  timestamp: string;
  location: string;
  scanner_id: string;
  notes: string;
}

export interface RetentionAlert {
  alert_id: string;
  customer_id: string;
  customer_name: string;
  industry: string;
  route_name: string | null;
  driver_name: string | null;
  alert_date: string;
  missing_tag_count: number;
  financial_save_usd: number;
  driver_talking_point: string;
  alert_status: string;
  csat_score: number | null;
}

export interface ZombieSummary {
  zombie_count: number;
  total_exposure_usd: number;
  avg_days_stalled: number;
}

type Page = 'fleet' | 'garments';

const POLL_INTERVAL_MS = 3000;

function App() {
  const [page, setPage] = useState<Page>('fleet');
  const [positions, setPositions] = useState<Position[]>([]);
  const [customers, setCustomers] = useState<Customer[]>([]);
  const [zombieSummary, setZombieSummary] = useState<ZombieSummary>({ zombie_count: 0, total_exposure_usd: 0, avg_days_stalled: 0 });
  const [lastUpdated, setLastUpdated] = useState<Date | null>(null);
  const [loading, setLoading] = useState(true);
  const [simulating, setSimulating] = useState(false);
  const [toasts, setToasts] = useState<string[]>([]);
  const prevPositionsRef = useRef<Position[]>([]);

  const addToast = useCallback((msg: string) => {
    setToasts(prev => [...prev.slice(-4), msg]);
    setTimeout(() => setToasts(prev => prev.slice(1)), 4000);
  }, []);

  const fetchPositions = useCallback(async () => {
    try {
      const res = await fetch('/api/positions');
      const data: Position[] = await res.json();

      const prev = prevPositionsRef.current;
      if (prev.length > 0) {
        for (const pos of data) {
          const old = prev.find(p => p.vehicle_id === pos.vehicle_id);
          if (old && (old.latitude !== pos.latitude || old.longitude !== pos.longitude)) {
            if (pos.engine_status === 'IDLE') {
              addToast(`${pos.vehicle_id} arrived at stop`);
            } else {
              addToast(`${pos.vehicle_id} moving — ${pos.speed_mph} mph`);
            }
          }
        }
      }
      prevPositionsRef.current = data;

      setPositions(data);
      setLastUpdated(new Date());
    } catch (e) {
      console.error('Failed to fetch positions', e);
    }
  }, [addToast]);

  useEffect(() => {
    Promise.all([
      fetch('/api/customers').then(r => r.json()).then(setCustomers),
      fetch('/api/zombie-summary').then(r => r.json()).then(setZombieSummary),
      fetch('/api/simulate/status').then(r => r.json()).then(d => setSimulating(d.running)),
      fetchPositions(),
    ]).then(() => setLoading(false));
  }, [fetchPositions]);

  useEffect(() => {
    const interval = setInterval(fetchPositions, POLL_INTERVAL_MS);
    return () => clearInterval(interval);
  }, [fetchPositions]);

  const toggleSimulation = async () => {
    const endpoint = simulating ? '/api/simulate/stop' : '/api/simulate/start';
    const res = await fetch(endpoint);
    const data = await res.json();
    setSimulating(data.status === 'started' || data.status === 'already_running');
    if (!simulating) addToast('Simulation started — vehicles en route');
  };

  if (loading) {
    return (
      <div className="h-full flex items-center justify-center">
        <div className="text-2xl text-gray-400 animate-pulse">Connecting to fleet...</div>
      </div>
    );
  }

  return (
    <div className="h-full flex flex-col">
      <header className="flex items-center justify-between px-6 py-3 bg-gray-900 border-b border-gray-800">
        <div className="flex items-center gap-6">
          <h1 className="text-lg font-semibold tracking-tight">Metro Textile Services</h1>
          <nav className="flex gap-1">
            <NavTab active={page === 'fleet'} onClick={() => setPage('fleet')}>Fleet</NavTab>
            <NavTab active={page === 'garments'} onClick={() => setPage('garments')}>Garments</NavTab>
          </nav>
        </div>
        <div className="flex items-center gap-4">
          <a
            href="https://app.snowflake.com/intelligence"
            target="_blank"
            rel="noopener noreferrer"
            className="px-3 py-1.5 rounded text-xs font-medium bg-indigo-600/20 text-indigo-300 border border-indigo-500/30 hover:bg-indigo-600/30 transition-all"
          >
            Ask Agent
          </a>
          <button
            onClick={toggleSimulation}
            className={`px-3 py-1.5 rounded text-xs font-medium transition-all ${
              simulating
                ? 'bg-red-600/20 text-red-400 border border-red-500/30 hover:bg-red-600/30'
                : 'bg-green-600/20 text-green-400 border border-green-500/30 hover:bg-green-600/30'
            }`}
          >
            {simulating ? 'Stop Simulation' : 'Start Simulation'}
          </button>
          {lastUpdated && (
            <span className="text-xs text-gray-500">
              {lastUpdated.toLocaleTimeString()}
            </span>
          )}
          <div className={`w-2 h-2 rounded-full ${simulating ? 'bg-green-500 animate-pulse' : 'bg-gray-600'}`} />
        </div>
      </header>

      {page === 'fleet' && (
        <>
          <KpiBar positions={positions} totalCustomers={customers.length} zombieSummary={zombieSummary} />
          <div className="flex-1 relative">
            <FleetMap positions={positions} customers={customers} />
          </div>
        </>
      )}

      {page === 'garments' && <GarmentPage onToast={addToast} />}

      <Toast messages={toasts} />
    </div>
  );
}

function NavTab({ active, onClick, children }: { active: boolean; onClick: () => void; children: React.ReactNode }) {
  return (
    <button
      onClick={onClick}
      className={`px-3 py-1.5 rounded text-sm font-medium transition-colors ${
        active ? 'bg-blue-600 text-white' : 'text-gray-400 hover:text-white hover:bg-gray-800'
      }`}
    >
      {children}
    </button>
  );
}

export default App;
