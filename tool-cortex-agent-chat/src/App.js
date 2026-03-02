import React, { useState } from 'react';
import ChatInterface from './components/ChatInterface';
import ConfigPanel from './components/ConfigPanel';
import './App.css';

function App() {
  const [config, setConfig] = useState({
    account: process.env.REACT_APP_SNOWFLAKE_ACCOUNT || '',
    user: process.env.REACT_APP_SNOWFLAKE_USER || '',
    database: process.env.REACT_APP_SNOWFLAKE_DATABASE || '',
    schema: process.env.REACT_APP_SNOWFLAKE_SCHEMA || '',
    agentName: process.env.REACT_APP_CORTEX_AGENT_NAME || '',
    isConfigured: false
  });

  // Check if all required environment variables are present
  const hasEnvConfig = process.env.REACT_APP_SNOWFLAKE_ACCOUNT &&
                       process.env.REACT_APP_SNOWFLAKE_USER &&
                       process.env.REACT_APP_SNOWFLAKE_DATABASE &&
                       process.env.REACT_APP_SNOWFLAKE_SCHEMA &&
                       process.env.REACT_APP_CORTEX_AGENT_NAME;

  // Debug environment variables (remove in production)
  console.log('Environment variables check:', {
    account: process.env.REACT_APP_SNOWFLAKE_ACCOUNT ? 'SET' : 'NOT SET',
    user: process.env.REACT_APP_SNOWFLAKE_USER ? 'SET' : 'NOT SET',
    database: process.env.REACT_APP_SNOWFLAKE_DATABASE ? 'SET' : 'NOT SET',
    schema: process.env.REACT_APP_SNOWFLAKE_SCHEMA ? 'SET' : 'NOT SET',
    agentName: process.env.REACT_APP_CORTEX_AGENT_NAME ? 'SET' : 'NOT SET',
    hasEnvConfig: hasEnvConfig
  });

  const [showConfig, setShowConfig] = useState(!hasEnvConfig);

  // Auto-configure if environment variables are present
  React.useEffect(() => {
    if (hasEnvConfig && !config.isConfigured) {
      setConfig(prev => ({ ...prev, isConfigured: true }));
      setShowConfig(false);
    }
  }, [hasEnvConfig, config.isConfigured]);

  const handleConfigSave = (newConfig) => {
    setConfig({ ...newConfig, isConfigured: true });
    setShowConfig(false);
  };

  const handleConfigEdit = () => {
    setShowConfig(true);
  };

  return (
    <div className="App">
      <header className="app-header">
        <h1>Snowflake Cortex Agent Chat</h1>
        {config.isConfigured && (
          <button className="config-button" onClick={handleConfigEdit}>
            ⚙️ Configure
          </button>
        )}
      </header>

      <main className="app-main">
        {showConfig || !config.isConfigured ? (
          <ConfigPanel
            config={config}
            onSave={handleConfigSave}
            onCancel={config.isConfigured ? () => setShowConfig(false) : null}
          />
        ) : (
          <ChatInterface config={config} />
        )}
      </main>
    </div>
  );
}

export default App;
