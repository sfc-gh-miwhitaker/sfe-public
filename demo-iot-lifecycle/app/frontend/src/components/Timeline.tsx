interface Props {
  currentTime: number;
  minTime: number;
  maxTime: number;
  playing: boolean;
  speed: number;
  onTimeChange: (t: number) => void;
  onPlayToggle: () => void;
  onSpeedChange: (s: number) => void;
}

function formatTime(epoch: number): string {
  const d = new Date(epoch * 1000);
  return d.toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit', hour12: true });
}

export default function Timeline({
  currentTime, minTime, maxTime, playing, speed,
  onTimeChange, onPlayToggle, onSpeedChange,
}: Props) {
  const progress = maxTime > minTime ? ((currentTime - minTime) / (maxTime - minTime)) * 100 : 0;

  return (
    <div className="bg-gray-900 border-t border-gray-800 px-6 py-3">
      <div className="flex items-center gap-4">
        <button
          onClick={onPlayToggle}
          className="w-10 h-10 flex items-center justify-center rounded-full bg-blue-600 hover:bg-blue-500 transition-colors"
        >
          {playing ? (
            <svg className="w-4 h-4" fill="currentColor" viewBox="0 0 24 24"><rect x="6" y="4" width="4" height="16"/><rect x="14" y="4" width="4" height="16"/></svg>
          ) : (
            <svg className="w-4 h-4 ml-0.5" fill="currentColor" viewBox="0 0 24 24"><polygon points="5,3 19,12 5,21"/></svg>
          )}
        </button>

        <div className="flex-1 relative">
          <div className="h-2 bg-gray-700 rounded-full overflow-hidden">
            <div className="h-full bg-blue-500 rounded-full transition-all duration-75" style={{ width: `${progress}%` }} />
          </div>
          <input
            type="range"
            min={minTime}
            max={maxTime}
            step={1}
            value={currentTime}
            onChange={e => onTimeChange(Number(e.target.value))}
            className="absolute inset-0 w-full h-full opacity-0 cursor-pointer"
          />
        </div>

        <div className="text-sm text-gray-400 w-24 text-center font-mono">
          {formatTime(currentTime)}
        </div>

        <div className="flex items-center gap-2">
          <span className="text-xs text-gray-500">Speed:</span>
          {[30, 60, 120].map(s => (
            <button
              key={s}
              onClick={() => onSpeedChange(s)}
              className={`px-2 py-0.5 rounded text-xs ${speed === s ? 'bg-blue-600 text-white' : 'bg-gray-700 text-gray-400 hover:bg-gray-600'}`}
            >
              {s === 30 ? '1x' : s === 60 ? '2x' : '4x'}
            </button>
          ))}
        </div>
      </div>
    </div>
  );
}
