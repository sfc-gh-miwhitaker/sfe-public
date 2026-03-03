import type { Station } from '../types';

interface StationPickerProps {
  stations: Station[];
  selectedStationId: string;
  onChange: (stationId: string) => void;
}

export function StationPicker({ stations, selectedStationId, onChange }: StationPickerProps) {
  return (
    <div className="picker-section">
      <h3>Station / Brand</h3>
      <p className="picker-hint">
        Simulates which station the user arrives from (e.g. weta.org vs kqed.org).
        This changes the agent&apos;s identity in <code>instructions.system</code>.
      </p>
      <div className="station-grid">
        {stations.map(s => (
          <button
            key={s.id}
            className={`station-btn ${selectedStationId === s.id ? 'active' : ''}`}
            onClick={() => onChange(s.id)}
          >
            <span className="station-call">{s.callSign}</span>
            <span className="station-market">{s.market}</span>
          </button>
        ))}
      </div>
    </div>
  );
}
