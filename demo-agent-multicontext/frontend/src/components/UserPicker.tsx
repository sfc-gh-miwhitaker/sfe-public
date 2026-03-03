import type { UserType, DemoUser } from '../types';

const TIER_META: Record<UserType, { label: string; description: string; color: string }> = {
  anonymous: {
    label: 'Anonymous',
    description: 'No login -- general questions only, Cortex Search KB',
    color: '#6b7280',
  },
  low: {
    label: 'Basic Member',
    description: 'Logged in -- KB + limited Analyst (viewership)',
    color: '#2563eb',
  },
  full: {
    label: 'Station Admin',
    description: 'Full access -- KB + full Analyst (metrics, members, revenue)',
    color: '#7c3aed',
  },
};

interface UserPickerProps {
  userType: UserType;
  selectedUser: DemoUser | null;
  demoUsers: DemoUser[];
  onUserTypeChange: (t: UserType) => void;
  onDemoUserChange: (u: DemoUser | null) => void;
}

export function UserPicker({
  userType,
  selectedUser,
  demoUsers,
  onUserTypeChange,
  onDemoUserChange,
}: UserPickerProps) {
  const filteredUsers = demoUsers.filter(u => {
    if (userType === 'low') return ['Sustainer', 'Basic'].includes(u.tier);
    if (userType === 'full') return u.tier === 'Leadership';
    return false;
  });

  return (
    <div className="picker-section">
      <h3>User Context</h3>

      <div className="tier-buttons">
        {(Object.keys(TIER_META) as UserType[]).map(t => {
          const meta = TIER_META[t];
          return (
            <button
              key={t}
              className={`tier-btn ${userType === t ? 'active' : ''}`}
              style={{ '--accent': meta.color } as React.CSSProperties}
              onClick={() => {
                onUserTypeChange(t);
                onDemoUserChange(null);
              }}
            >
              <span className="tier-label">{meta.label}</span>
              <span className="tier-desc">{meta.description}</span>
            </button>
          );
        })}
      </div>

      {userType !== 'anonymous' && (
        <div className="user-select">
          <label>Simulated User</label>
          <select
            value={selectedUser?.key ?? ''}
            onChange={e => {
              const user = demoUsers.find(u => u.key === e.target.value) ?? null;
              onDemoUserChange(user);
            }}
          >
            <option value="">Select a demo user...</option>
            {filteredUsers.map(u => (
              <option key={u.key} value={u.key}>
                {u.name} ({u.stationName} -- {u.tier})
              </option>
            ))}
          </select>
        </div>
      )}
    </div>
  );
}
