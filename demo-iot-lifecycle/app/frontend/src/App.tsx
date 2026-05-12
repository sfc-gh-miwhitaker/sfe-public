import { useState, useEffect } from 'react';
import FleetMap from './components/FleetMap';
import Timeline from './components/Timeline';
import KpiBar from './components/KpiBar';

export interface TelemetryPoint {
  vehicle_id: string;
  timestamp: number;
  latitude: number;
  longitude: number;
  speed_mph: number;
  engine_status: string;
}

export interface Customer {
  customer_id: string;
  customer_name: string;
  industry: string;
  latitude: number;
  longitude: number;
}

export interface Trip {
  vehicle_id: string;
  waypoints: { coordinates: [number, number]; timestamp: number }[];
  color: [number, number, number];
}

const VEHICLE_COLORS: Record<string, [number, number, number]> = {
  'V-001': [253, 128, 93],
  'V-002': [0, 200, 140],
  'V-003': [100, 180, 255],
  'V-004': [255, 200, 50],
  'V-005': [200, 100, 255],
};

function App() {
  const [trips, setTrips] = useState<Trip[]>([]);
  const [customers, setCustomers] = useState<Customer[]>([]);
  const [telemetry, setTelemetry] = useState<TelemetryPoint[]>([]);
  const [currentTime, setCurrentTime] = useState(0);
  const [minTime, setMinTime] = useState(0);
  const [maxTime, setMaxTime] = useState(1);
  const [playing, setPlaying] = useState(false);
  const [speed, setSpeed] = useState(60);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    Promise.all([
      fetch('/api/telemetry').then(r => r.json()),
      fetch('/api/customers').then(r => r.json()),
    ]).then(([telData, custData]) => {
      setTelemetry(telData);
      setCustomers(custData);

      const grouped: Record<string, TelemetryPoint[]> = {};
      telData.forEach((p: TelemetryPoint) => {
        if (!grouped[p.vehicle_id]) grouped[p.vehicle_id] = [];
        grouped[p.vehicle_id].push(p);
      });

      const tripList: Trip[] = Object.entries(grouped).map(([vid, points]) => ({
        vehicle_id: vid,
        waypoints: points
          .sort((a, b) => a.timestamp - b.timestamp)
          .map(p => ({ coordinates: [p.longitude, p.latitude] as [number, number], timestamp: p.timestamp })),
        color: VEHICLE_COLORS[vid] || [200, 200, 200],
      }));

      setTrips(tripList);

      const timestamps = telData.map((p: TelemetryPoint) => p.timestamp);
      const mn = Math.min(...timestamps);
      const mx = Math.max(...timestamps);
      setMinTime(mn);
      setMaxTime(mx);
      setCurrentTime(mn);
      setLoading(false);
    });
  }, []);

  useEffect(() => {
    if (!playing) return;
    const interval = setInterval(() => {
      setCurrentTime(prev => {
        const next = prev + speed;
        if (next > maxTime) {
          setPlaying(false);
          return minTime;
        }
        return next;
      });
    }, 33);
    return () => clearInterval(interval);
  }, [playing, speed, maxTime, minTime]);

  const activeVehicles = trips.filter(t => {
    const first = t.waypoints[0]?.timestamp ?? Infinity;
    const last = t.waypoints[t.waypoints.length - 1]?.timestamp ?? 0;
    return currentTime >= first && currentTime <= last;
  });

  const currentPositions = telemetry.filter(p => {
    const vid = p.vehicle_id;
    const vPoints = telemetry.filter(t => t.vehicle_id === vid && t.timestamp <= currentTime);
    if (vPoints.length === 0) return false;
    const latest = vPoints.reduce((a, b) => a.timestamp > b.timestamp ? a : b);
    return p === latest;
  });

  if (loading) {
    return (
      <div className="h-full flex items-center justify-center">
        <div className="text-2xl text-gray-400 animate-pulse">Loading fleet data...</div>
      </div>
    );
  }

  return (
    <div className="h-full flex flex-col">
      <header className="flex items-center justify-between px-6 py-3 bg-gray-900 border-b border-gray-800">
        <div className="flex items-center gap-3">
          <div className="w-3 h-3 rounded-full bg-green-500 animate-pulse" />
          <h1 className="text-lg font-semibold tracking-tight">Metro Textile Services — Fleet Tracker</h1>
        </div>
        <span className="text-xs text-gray-500">DEMO • Powered by Snowflake SPCS + deck.gl</span>
      </header>

      <KpiBar
        activeVehicles={activeVehicles.length}
        totalCustomers={customers.length}
        currentPositions={currentPositions}
      />

      <div className="flex-1 relative">
        <FleetMap
          trips={trips}
          customers={customers}
          currentTime={currentTime}
          minTime={minTime}
        />
      </div>

      <Timeline
        currentTime={currentTime}
        minTime={minTime}
        maxTime={maxTime}
        playing={playing}
        speed={speed}
        onTimeChange={setCurrentTime}
        onPlayToggle={() => setPlaying(!playing)}
        onSpeedChange={setSpeed}
      />
    </div>
  );
}

export default App;
