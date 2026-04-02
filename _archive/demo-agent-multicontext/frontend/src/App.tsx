import { useState, useCallback, useEffect } from 'react';
import type { UserType, DemoUser, AgentContext, Station } from './types';
import { useAgentChat } from './hooks/useAgentChat';
import { UserPicker } from './components/UserPicker';
import { StationPicker } from './components/StationPicker';
import { AgentChat } from './components/AgentChat';
import { ApiInspector } from './components/ApiInspector';
import { getStationList } from './utils/buildAgentPayload';

export default function App() {
  const [userType, setUserType] = useState<UserType>('anonymous');
  const [selectedUser, setSelectedUser] = useState<DemoUser | null>(null);
  const [stationId, setStationId] = useState('STN001');
  const [demoUsers, setDemoUsers] = useState<DemoUser[]>([]);
  const [stations] = useState<Station[]>(getStationList);
  const [draftMessage, setDraftMessage] = useState('');

  const { messages, isLoading, error, sendMessage, resetChat } = useAgentChat();

  useEffect(() => {
    fetch('/api/users')
      .then(r => r.json())
      .then(setDemoUsers)
      .catch(() => {});
  }, []);

  const context: AgentContext = {
    userType,
    stationId,
    userId: selectedUser?.id,
    userName: selectedUser?.name,
    memberTier: selectedUser?.tier,
  };

  const handleSend = useCallback((message: string) => {
    setDraftMessage('');
    sendMessage(message, context);
  }, [sendMessage, context]);

  const handleContextChange = useCallback(() => {
    resetChat();
  }, [resetChat]);

  const handleUserTypeChange = useCallback((t: UserType) => {
    setUserType(t);
    setSelectedUser(null);
    handleContextChange();
  }, [handleContextChange]);

  const handleStationChange = useCallback((id: string) => {
    setStationId(id);
    handleContextChange();
  }, [handleContextChange]);

  const handleDemoUserChange = useCallback((u: DemoUser | null) => {
    setSelectedUser(u);
    if (u) {
      setStationId(u.stationId);
    }
    handleContextChange();
  }, [handleContextChange]);

  return (
    <div className="app">
      <header className="app-header">
        <div>
          <h1>Agent Multicontext Demo</h1>
          <p className="header-sub">
            Snowflake Agent Run API &mdash; per-request <code>instructions.system</code> injection
          </p>
        </div>
      </header>

      <div className="app-layout">
        <aside className="sidebar">
          <UserPicker
            userType={userType}
            selectedUser={selectedUser}
            demoUsers={demoUsers}
            onUserTypeChange={handleUserTypeChange}
            onDemoUserChange={handleDemoUserChange}
          />
          <StationPicker
            stations={stations}
            selectedStationId={stationId}
            onChange={handleStationChange}
          />
          <ApiInspector context={context} draftMessage={draftMessage} />
        </aside>

        <main className="main">
          <AgentChat
            messages={messages}
            isLoading={isLoading}
            error={error}
            context={context}
            onSend={handleSend}
            onReset={resetChat}
          />
        </main>
      </div>
    </div>
  );
}
