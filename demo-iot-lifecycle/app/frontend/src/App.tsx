import { useState, useEffect, useCallback } from 'react';
import FleetMap from './components/FleetMap';
import KpiBar from './components/KpiBar';
import GarmentPage from './components/GarmentPage';

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

type Page = 'fleet' | 'garments';

const POLL_INTERVAL_MS = 3000;

function App() {
  const [page, setPage] = useState<Page>('fleet');
  const [positions, setPositions] = useState<Position[]>([]);
  const [customers, setCustomers] = useState<Customer[]>([]);
  const [lastUpdated, setLastUpdated] = useState<Date | null>(null);
  const [loading, setLoading] = useState(true);

  const fetchPositions = useCallback(async () => {
    try {
      const res = await fetch('/api/positions');
      const data = await res.json();
      setPositions(data);
      setLastUpdated(new Date());
    } catch (e) {
      console.error('Failed to fetch positions', e);
    }
  }, []);

  useEffect(() => {
    fetch('/api/customers').then(r => r.json()).then(setCustomers);
    fetchPositions().then(() => setLoading(false));
  }, [fetchPositions]);

  useEffect(() => {
    if (page !== 'fleet') return;
    const interval = setInterval(fetchPositions, POLL_INTERVAL_MS);
    return () => clearInterval(interval);
  }, [fetchPositions, page]);

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
          {lastUpdated && (
            <span className="text-xs text-gray-500">
              Updated {lastUpdated.toLocaleTimeString()}
            </span>
          )}
          <div className="w-2 h-2 rounded-full bg-green-500 animate-pulse" />
        </div>
      </header>

      {page === 'fleet' && (
        <>
          <KpiBar positions={positions} totalCustomers={customers.length} />
          <div className="flex-1 relative">
            <FleetMap positions={positions} customers={customers} />
          </div>
        </>
      )}

      {page === 'garments' && <GarmentPage />}
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
