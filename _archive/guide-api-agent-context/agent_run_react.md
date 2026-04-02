# Calling Snowflake Agent API from React

Guide for calling the Snowflake agent:run API from an external React application.

## Architecture Overview

**Important**: Never store Snowflake credentials (PAT, password) in your React frontend. Use one of these approaches:

1. **Backend Proxy** (Recommended): React → Your Backend → Snowflake API
2. **OAuth Flow**: React → Snowflake OAuth → Get Token → Snowflake API

## Option 1: Backend Proxy (Recommended)

### Backend (Node.js/Express Example)

```javascript
// server.js
const express = require('express');
const cors = require('cors');
const fetch = require('node-fetch');

const app = express();
app.use(cors());
app.use(express.json());

const SNOWFLAKE_ACCOUNT = process.env.SNOWFLAKE_ACCOUNT;
const SNOWFLAKE_PAT = process.env.SNOWFLAKE_PAT;

// Create thread
app.post('/api/agent/thread', async (req, res) => {
  try {
    const response = await fetch(
      `https://${SNOWFLAKE_ACCOUNT}.snowflakecomputing.com/api/v2/cortex/threads`,
      {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${SNOWFLAKE_PAT}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ origin_application: 'my_react_app' })
      }
    );

    const data = await response.json();
    res.json(data);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Run agent with streaming
app.post('/api/agent/run', async (req, res) => {
  const { database, schema, agentName, threadId, message, role, warehouse } = req.body;

  const headers = {
    'Authorization': `Bearer ${SNOWFLAKE_PAT}`,
    'Content-Type': 'application/json',
  };

  // Use official Snowflake headers for role and warehouse context
  // See: https://docs.snowflake.com/en/developer-guide/snowflake-rest-api/setting-context
  if (role) {
    headers['X-Snowflake-Role'] = role;
  }
  if (warehouse) {
    headers['X-Snowflake-Warehouse'] = warehouse;
  }

  const url = `https://${SNOWFLAKE_ACCOUNT}.snowflakecomputing.com/api/v2/databases/${database}/schemas/${schema}/agents/${agentName}:run`;

  try {
    const response = await fetch(url, {
      method: 'POST',
      headers,
      body: JSON.stringify({
        thread_id: threadId,
        parent_message_id: 0,
        messages: [
          {
            role: 'user',
            content: [{ type: 'text', text: message }]
          }
        ]
      })
    });

    // Set headers for SSE streaming
    res.setHeader('Content-Type', 'text/event-stream');
    res.setHeader('Cache-Control', 'no-cache');
    res.setHeader('Connection', 'keep-alive');

    // Stream response to client
    response.body.pipe(res);

  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.listen(3001, () => {
  console.log('Proxy server running on port 3001');
});
```

### React Frontend

```typescript
// hooks/useSnowflakeAgent.ts
import { useState, useCallback } from 'react';

interface AgentMessage {
  role: 'user' | 'assistant';
  content: string;
}

interface UseSnowflakeAgentProps {
  database: string;
  schema: string;
  agentName: string;
  role?: string;
  warehouse?: string;
}

export const useSnowflakeAgent = ({
  database,
  schema,
  agentName,
  role,
  warehouse
}: UseSnowflakeAgentProps) => {
  const [messages, setMessages] = useState<AgentMessage[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const [threadId, setThreadId] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  const API_BASE = 'http://localhost:3001/api';

  // Create thread (call once at start)
  const createThread = useCallback(async () => {
    try {
      const response = await fetch(`${API_BASE}/agent/thread`, {
        method: 'POST',
      });
      const data = await response.json();
      setThreadId(data.id);
      return data.id;
    } catch (err) {
      setError(err.message);
      throw err;
    }
  }, []);

  // Send message to agent
  const sendMessage = useCallback(async (message: string) => {
    setIsLoading(true);
    setError(null);

    // Add user message immediately
    setMessages(prev => [...prev, { role: 'user', content: message }]);

    try {
      // Create thread if doesn't exist
      let currentThreadId = threadId;
      if (!currentThreadId) {
        currentThreadId = await createThread();
      }

      const response = await fetch(`${API_BASE}/agent/run`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          database,
          schema,
          agentName,
          threadId: currentThreadId,
          message,
          role,
          warehouse
        })
      });

      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`);
      }

      // Handle streaming response
      const reader = response.body?.getReader();
      const decoder = new TextDecoder();
      let assistantMessage = '';
      let currentEvent = '';

      while (true) {
        const { done, value } = await reader!.read();
        if (done) break;

        const chunk = decoder.decode(value);
        const lines = chunk.split('\n');

        for (const line of lines) {
          if (line.startsWith('event:')) {
            currentEvent = line.split(':', 2)[1].trim();
          } else if (line.startsWith('data:')) {
            const data = line.slice(5).trim();

            try {
              const eventData = JSON.parse(data);

              if (currentEvent === 'response.text.delta') {
                assistantMessage += eventData.text || '';
                // Update the assistant message in real-time
                setMessages(prev => {
                  const lastMessage = prev[prev.length - 1];
                  if (lastMessage?.role === 'assistant') {
                    return [
                      ...prev.slice(0, -1),
                      { role: 'assistant', content: assistantMessage }
                    ];
                  } else {
                    return [
                      ...prev,
                      { role: 'assistant', content: assistantMessage }
                    ];
                  }
                });
              }
            } catch (e) {
              // Ignore JSON parse errors
            }
          }
        }
      }

    } catch (err) {
      setError(err.message);
      console.error('Error sending message:', err);
    } finally {
      setIsLoading(false);
    }
  }, [threadId, database, schema, agentName, role, warehouse, createThread]);

  return {
    messages,
    sendMessage,
    isLoading,
    error,
    threadId
  };
};
```

```tsx
// components/AgentChat.tsx
import React, { useState } from 'react';
import { useSnowflakeAgent } from '../hooks/useSnowflakeAgent';

export const AgentChat: React.FC = () => {
  const [input, setInput] = useState('');

  const { messages, sendMessage, isLoading, error } = useSnowflakeAgent({
    database: 'MYDB',
    schema: 'MYSCHEMA',
    agentName: 'my_agent',
    role: 'ANALYST_ROLE',
    warehouse: 'COMPUTE_WH'
  });

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!input.trim() || isLoading) return;

    await sendMessage(input);
    setInput('');
  };

  return (
    <div className="chat-container">
      <div className="messages">
        {messages.map((msg, idx) => (
          <div key={idx} className={`message ${msg.role}`}>
            <strong>{msg.role}:</strong> {msg.content}
          </div>
        ))}
        {isLoading && <div className="loading">Agent is thinking...</div>}
        {error && <div className="error">Error: {error}</div>}
      </div>

      <form onSubmit={handleSubmit}>
        <input
          type="text"
          value={input}
          onChange={(e) => setInput(e.target.value)}
          placeholder="Ask a question..."
          disabled={isLoading}
        />
        <button type="submit" disabled={isLoading}>
          Send
        </button>
      </form>
    </div>
  );
};
```

## Option 2: Direct API Call with OAuth

If you implement OAuth in your React app to get a token:

```typescript
// utils/snowflakeAgent.ts
export class SnowflakeAgentClient {
  constructor(
    private account: string,
    private token: string
  ) {}

  async createThread(): Promise<string> {
    const response = await fetch(
      `https://${this.account}.snowflakecomputing.com/api/v2/cortex/threads`,
      {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${this.token}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ origin_application: 'my_react_app' })
      }
    );

    const data = await response.json();
    return data.id;
  }

  async *runAgent(
    database: string,
    schema: string,
    agentName: string,
    threadId: string,
    message: string,
    role?: string,
    warehouse?: string
  ): AsyncGenerator<string, void, unknown> {
    const headers: Record<string, string> = {
      'Authorization': `Bearer ${this.token}`,
      'Content-Type': 'application/json',
    };

    // Use official Snowflake headers for role and warehouse context
    if (role) {
      headers['X-Snowflake-Role'] = role;
    }
    if (warehouse) {
      headers['X-Snowflake-Warehouse'] = warehouse;
    }

    const url = `https://${this.account}.snowflakecomputing.com/api/v2/databases/${database}/schemas/${schema}/agents/${agentName}:run`;

    const response = await fetch(url, {
      method: 'POST',
      headers,
      body: JSON.stringify({
        thread_id: threadId,
        parent_message_id: 0,
        messages: [
          {
            role: 'user',
            content: [{ type: 'text', text: message }]
          }
        ]
      })
    });

    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }

    const reader = response.body?.getReader();
    const decoder = new TextDecoder();
    let currentEvent = '';

    while (true) {
      const { done, value } = await reader!.read();
      if (done) break;

      const chunk = decoder.decode(value);
      const lines = chunk.split('\n');

      for (const line of lines) {
        if (line.startsWith('event:')) {
          currentEvent = line.split(':', 2)[1].trim();
        } else if (line.startsWith('data:')) {
          const data = line.slice(5).trim();

          try {
            const eventData = JSON.parse(data);

            if (currentEvent === 'response.text.delta') {
              yield eventData.text || '';
            }
          } catch (e) {
            // Ignore JSON parse errors
          }
        }
      }
    }
  }
}

// Usage
const client = new SnowflakeAgentClient('myorg-myaccount', 'your-token');
const threadId = await client.createThread();

for await (const text of client.runAgent(
  'MYDB',
  'MYSCHEMA',
  'my_agent',
  threadId,
  'What are the top products?',
  'ANALYST_ROLE'
)) {
  console.log(text); // Stream text chunks as they arrive
}
```

## Option 3: Backend Proxy with Key-Pair JWT

Use this when PATs are not available -- for example, service accounts, CI/CD pipelines, or organizations with no-password policies. The private key stays server-side; the React frontend is unchanged.

> **Switching an existing project from PAT to key-pair JWT?**
> See [`migrate_pat_to_keypair_jwt.md`](migrate_pat_to_keypair_jwt.md) for step-by-step recipes targeting `demo-agent-multicontext`, `guide-agent-multi-tenant`, or any Express backend.

### Prerequisites

```bash
# Generate key pair (one-time)
openssl genrsa -out rsa_key.pem 2048
openssl rsa -in rsa_key.pem -pubout -out rsa_key.pub

# Assign public key to Snowflake user (as ACCOUNTADMIN)
# ALTER USER my_service_user SET RSA_PUBLIC_KEY='<contents without header/footer>';
```

### Backend (Node.js/Express with Key-Pair JWT)

The JWT module from [`agent_run_keypair_jwt.js`](agent_run_keypair_jwt.js) can be dropped into any Express project. It uses only the built-in Node.js `crypto` module -- zero dependencies.

```javascript
// server.js -- key-pair JWT variant
const express = require('express');
const cors = require('cors');
const fs = require('fs');
const { getJwt, buildHeaders } = require('./agent_run_keypair_jwt');

const app = express();
app.use(cors());
app.use(express.json());

const SNOWFLAKE_ACCOUNT = process.env.SNOWFLAKE_ACCOUNT;
const SNOWFLAKE_USER = process.env.SNOWFLAKE_USER;
const PRIVATE_KEY = fs.readFileSync(process.env.SNOWFLAKE_PRIVATE_KEY_PATH, 'utf8');

const BASE = `https://${SNOWFLAKE_ACCOUNT}.snowflakecomputing.com`;

app.post('/api/agent/thread', async (req, res) => {
  try {
    const jwt = getJwt(SNOWFLAKE_ACCOUNT, SNOWFLAKE_USER, PRIVATE_KEY);
    const response = await fetch(`${BASE}/api/v2/cortex/threads`, {
      method: 'POST',
      headers: buildHeaders(jwt),
      body: JSON.stringify({ origin_application: 'my_react_app' }),
    });
    const data = await response.json();
    res.json(data);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.post('/api/agent/run', async (req, res) => {
  const { database, schema, agentName, threadId, message, role, warehouse } = req.body;
  const jwt = getJwt(SNOWFLAKE_ACCOUNT, SNOWFLAKE_USER, PRIVATE_KEY);
  const headers = buildHeaders(jwt);
  if (role) headers['X-Snowflake-Role'] = role;
  if (warehouse) headers['X-Snowflake-Warehouse'] = warehouse;

  const url = `${BASE}/api/v2/databases/${database}/schemas/${schema}/agents/${agentName}:run`;

  try {
    const response = await fetch(url, {
      method: 'POST',
      headers,
      body: JSON.stringify({
        thread_id: threadId,
        parent_message_id: 0,
        messages: [{ role: 'user', content: [{ type: 'text', text: message }] }],
      }),
    });
    res.setHeader('Content-Type', 'text/event-stream');
    res.setHeader('Cache-Control', 'no-cache');
    res.setHeader('Connection', 'keep-alive');
    response.body.pipe(res);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.listen(3001, () => console.log('Proxy (key-pair JWT) on port 3001'));
```

### Environment Variables (Key-Pair JWT)

```bash
export SNOWFLAKE_ACCOUNT="myorg-myaccount"
export SNOWFLAKE_USER="MY_SERVICE_USER"
export SNOWFLAKE_PRIVATE_KEY_PATH="./rsa_key.pem"
```

### When to Use Key-Pair JWT vs PAT

| | PAT | Key-Pair JWT |
|---|---|---|
| **Setup** | Snowsight > Settings > Auth > PATs | `openssl` + `ALTER USER` |
| **Best for** | Quick testing, dev | Service accounts, CI/CD, no-password orgs |
| **Token lifetime** | Configurable | 1 hour (auto-refreshed by `getJwt()`) |
| **Rotation** | Manual regeneration | Rotate RSA key pair |
| **Security** | Token is a secret | Private key never leaves the server |

---

## Security Considerations

1. **Never expose credentials in frontend code**
2. **Use HTTPS** for all API calls
3. **Implement rate limiting** on your backend proxy
4. **Validate and sanitize** user inputs
5. **Use CORS properly** - only allow your React app's origin
6. **Consider token expiration** and refresh logic
7. **Implement authentication** for your backend proxy

## CORS Setup

If calling directly from React (OAuth scenario), Snowflake needs to allow your origin:

```javascript
// This is configured in Snowflake, not your React app
// Contact your Snowflake admin to whitelist your domain
```

## Complete React Example with Error Handling

```tsx
// App.tsx
import React, { useState, useEffect } from 'react';

function App() {
  const [threadId, setThreadId] = useState<string | null>(null);
  const [messages, setMessages] = useState<Array<{role: string, content: string}>>([]);
  const [input, setInput] = useState('');
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    // Create thread on mount
    fetch('http://localhost:3001/api/agent/thread', { method: 'POST' })
      .then(res => res.json())
      .then(data => setThreadId(data.id))
      .catch(err => console.error('Failed to create thread:', err));
  }, []);

  const sendMessage = async () => {
    if (!input.trim() || !threadId) return;

    const userMessage = { role: 'user', content: input };
    setMessages(prev => [...prev, userMessage]);
    setInput('');
    setLoading(true);

    try {
      const response = await fetch('http://localhost:3001/api/agent/run', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          database: 'MYDB',
          schema: 'MYSCHEMA',
          agentName: 'my_agent',
          threadId,
          message: input,
          role: 'ANALYST_ROLE'
        })
      });

      const reader = response.body?.getReader();
      const decoder = new TextDecoder();
      let assistantContent = '';
      let currentEvent = '';

      while (true) {
        const { done, value } = await reader!.read();
        if (done) break;

        const chunk = decoder.decode(value);
        const lines = chunk.split('\n');

        for (const line of lines) {
          if (line.startsWith('event:')) {
            currentEvent = line.split(':', 2)[1].trim();
          } else if (line.startsWith('data:')) {
            try {
              const eventData = JSON.parse(line.slice(5));

              if (currentEvent === 'response.text.delta') {
                assistantContent += eventData.text || '';
                setMessages(prev => {
                  const lastMsg = prev[prev.length - 1];
                  if (lastMsg?.role === 'assistant') {
                    return [...prev.slice(0, -1), { role: 'assistant', content: assistantContent }];
                  }
                  return [...prev, { role: 'assistant', content: assistantContent }];
                });
              }
            } catch (e) {
              // Skip invalid JSON
            }
          }
        }
      }
    } catch (error) {
      console.error('Error:', error);
      setMessages(prev => [...prev, { role: 'error', content: 'Failed to get response' }]);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div style={{ maxWidth: '800px', margin: '0 auto', padding: '20px' }}>
      <h1>Snowflake Agent Chat</h1>

      <div style={{ border: '1px solid #ccc', padding: '10px', minHeight: '400px', marginBottom: '10px' }}>
        {messages.map((msg, idx) => (
          <div key={idx} style={{ marginBottom: '10px', padding: '8px', background: msg.role === 'user' ? '#e3f2fd' : '#f5f5f5' }}>
            <strong>{msg.role}:</strong> {msg.content}
          </div>
        ))}
        {loading && <div>Agent is thinking...</div>}
      </div>

      <div style={{ display: 'flex', gap: '10px' }}>
        <input
          type="text"
          value={input}
          onChange={(e) => setInput(e.target.value)}
          onKeyPress={(e) => e.key === 'Enter' && sendMessage()}
          placeholder="Ask a question..."
          style={{ flex: 1, padding: '10px' }}
          disabled={!threadId || loading}
        />
        <button
          onClick={sendMessage}
          disabled={!threadId || loading}
          style={{ padding: '10px 20px' }}
        >
          Send
        </button>
      </div>
    </div>
  );
}

export default App;
```

## Running the Example

1. **Start backend proxy**:
   ```bash
   export SNOWFLAKE_ACCOUNT="myorg-myaccount"
   export SNOWFLAKE_PAT="your-pat"
   node server.js
   ```

2. **Start React app**:
   ```bash
   npm start
   ```

3. Navigate to `http://localhost:3000`

## Key Takeaways

- **Backend proxy is recommended** for security
- Use **Server-Sent Events (SSE)** for streaming
- Handle **async generators** for clean streaming in React
- Always **sanitize inputs** and validate responses
- Consider **WebSocket** alternative for bi-directional communication
