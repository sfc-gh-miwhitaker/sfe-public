# Multi-Tenant Snowflake Agent with Azure AD OAuth and Row Access Policies

Complete guide for building a customer-facing React application where each customer only sees their own data using Azure AD OAuth and Snowflake Row Access Policies.

## Architecture Overview

```
┌─────────────────┐
│  React App      │
│  (Customer UI)  │
└────────┬────────┘
         │ 1. OAuth Login
         ▼
┌─────────────────┐
│   Azure AD      │
│   (OAuth IdP)   │
└────────┬────────┘
         │ 2. JWT Token (with customer_id claim)
         ▼
┌─────────────────┐
│  Backend Proxy  │
│  (Node.js)      │
└────────┬────────┘
         │ 3. Validate JWT + Call Snowflake
         │    (OAuth token provides context)
         ▼
┌─────────────────┐
│  Snowflake      │
│  + Agent API    │
│  + Row Access   │
│    Policies     │
└─────────────────┘
```

**Data Isolation Strategy:**
1. Customer authenticates via Azure AD OAuth
2. JWT token contains `customer_id` claim
3. Backend validates token and extracts `customer_id`
4. Backend sets Snowflake session variable with customer context
5. Row Access Policies filter data based on session variable
6. Agent queries automatically respect RAPs

---

## Part 1: Azure AD OAuth Setup

### 1.1 Register Application in Azure AD

```bash
# Azure Portal Steps:
# 1. Go to Azure Active Directory > App registrations > New registration
# 2. Name: "MyApp Customer Portal"
# 3. Redirect URI: https://yourdomain.com/auth/callback
# 4. Register

# Note these values:
# - Application (client) ID: abc123...
# - Directory (tenant) ID: def456...
# - Create Client Secret: xyz789...
```

### 1.2 Configure Token Claims

Add custom claim for `customer_id`:

```json
// Azure AD > App registrations > Token configuration > Add optional claim
{
  "optionalClaims": {
    "idToken": [
      {
        "name": "customer_id",
        "source": "user",
        "essential": true
      }
    ]
  }
}
```

**Alternative**: Use Azure AD extension attributes or group membership to map users to customer IDs.

### 1.3 API Permissions

```
Microsoft Graph:
  - User.Read (to get user profile)
  - openid, profile, email (for OAuth)
```

---

## Part 2: Snowflake Setup

### 2.1 Create External OAuth Security Integration

```sql
-- Create security integration for Azure AD OAuth
CREATE SECURITY INTEGRATION azure_oauth
  TYPE = EXTERNAL_OAUTH
  ENABLED = TRUE
  EXTERNAL_OAUTH_TYPE = AZURE
  EXTERNAL_OAUTH_ISSUER = 'https://sts.windows.net/<TENANT_ID>/'
  EXTERNAL_OAUTH_JWS_KEYS_URL = 'https://login.microsoftonline.com/<TENANT_ID>/discovery/v2.0/keys'
  EXTERNAL_OAUTH_AUDIENCE_LIST = ('<APPLICATION_CLIENT_ID>')
  EXTERNAL_OAUTH_TOKEN_USER_MAPPING_CLAIM = 'upn'
  EXTERNAL_OAUTH_SNOWFLAKE_USER_MAPPING_ATTRIBUTE = 'LOGIN_NAME'
  EXTERNAL_OAUTH_ANY_ROLE_MODE = 'ENABLE';

-- Grant usage to roles that will use OAuth
GRANT USAGE ON INTEGRATION azure_oauth TO ROLE customer_app_role;
```

### 2.2 Create Users Mapped to Azure AD

```sql
-- Create Snowflake users that map to Azure AD users
CREATE USER customer1_user
  LOGIN_NAME = 'customer1@yourdomain.com'
  DISPLAY_NAME = 'Customer 1 User'
  DEFAULT_ROLE = customer_app_role
  DEFAULT_WAREHOUSE = customer_wh;

CREATE USER customer2_user
  LOGIN_NAME = 'customer2@yourdomain.com'
  DISPLAY_NAME = 'Customer 2 User'
  DEFAULT_ROLE = customer_app_role
  DEFAULT_WAREHOUSE = customer_wh;

-- Grant role
GRANT ROLE customer_app_role TO USER customer1_user;
GRANT ROLE customer_app_role TO USER customer2_user;
```

### 2.3 Setup Customer Mapping Table

```sql
-- Create mapping between Snowflake users and customer IDs
CREATE OR REPLACE TABLE customer_mapping (
  snowflake_user VARCHAR,
  customer_id VARCHAR,
  customer_name VARCHAR,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
);

INSERT INTO customer_mapping VALUES
  ('CUSTOMER1_USER', 'CUST001', 'Acme Corp', CURRENT_TIMESTAMP()),
  ('CUSTOMER2_USER', 'CUST002', 'Global Industries', CURRENT_TIMESTAMP());

GRANT SELECT ON customer_mapping TO ROLE customer_app_role;
```

### 2.4 Create Row Access Policy

```sql
-- Create row access policy function
CREATE OR REPLACE FUNCTION get_customer_id()
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
  SELECT customer_id
  FROM customer_mapping
  WHERE snowflake_user = CURRENT_USER()
  LIMIT 1
$$;

-- Create row access policy
CREATE OR REPLACE ROW ACCESS POLICY customer_isolation_policy
  AS (customer_id VARCHAR) RETURNS BOOLEAN ->
    customer_id = get_customer_id()
      OR CURRENT_ROLE() IN ('ACCOUNTADMIN', 'SYSADMIN');

-- Apply policy to your data tables
-- Example: Sales table
CREATE OR REPLACE TABLE sales (
  sale_id VARCHAR,
  customer_id VARCHAR,
  product_name VARCHAR,
  amount DECIMAL(10,2),
  sale_date DATE
);

ALTER TABLE sales
  ADD ROW ACCESS POLICY customer_isolation_policy ON (customer_id);

-- Insert sample data
INSERT INTO sales VALUES
  ('S001', 'CUST001', 'Widget A', 100.00, '2025-01-01'),
  ('S002', 'CUST001', 'Widget B', 150.00, '2025-01-02'),
  ('S003', 'CUST002', 'Widget C', 200.00, '2025-01-01'),
  ('S004', 'CUST002', 'Widget D', 250.00, '2025-01-03');

GRANT SELECT ON sales TO ROLE customer_app_role;
```

### 2.5 Create Agent with Customer Context

```sql
-- Create semantic model for customer data
-- Save as @my_stage/sales_semantic_model.yaml

-- Create agent using current FROM SPECIFICATION syntax (GA Jan 2025)
CREATE OR REPLACE AGENT customer_sales_agent
  FROM SPECIFICATION
  $$
  models:
    orchestration: claude-4-sonnet
  instructions:
    system: |
      You are a helpful sales data assistant.
      Only show data for the current customer.
      Always provide clear, concise answers.
  tools:
    - tool: cortex_analyst
      description: Query customer sales data
      parameters:
        semantic_view: sales_semantic_view
  $$;

GRANT USAGE ON AGENT customer_sales_agent TO ROLE customer_app_role;
```

---

## Part 3: Backend Proxy with OAuth Validation

### 3.1 Backend Server (Node.js/Express)

```javascript
// server.js
const express = require('express');
const cors = require('cors');
const jwt = require('jsonwebtoken');
const jwksClient = require('jwks-rsa');
const fetch = require('node-fetch');
const snowflake = require('snowflake-sdk');

const app = express();
app.use(cors({
  origin: process.env.FRONTEND_URL || 'http://localhost:3000',
  credentials: true
}));
app.use(express.json());

// Azure AD configuration
const AZURE_TENANT_ID = process.env.AZURE_TENANT_ID;
const AZURE_CLIENT_ID = process.env.AZURE_CLIENT_ID;
const AZURE_CLIENT_SECRET = process.env.AZURE_CLIENT_SECRET;

// Snowflake configuration
const SNOWFLAKE_ACCOUNT = process.env.SNOWFLAKE_ACCOUNT;
const SNOWFLAKE_OAUTH_INTEGRATION = 'azure_oauth';

// JWKS client for validating Azure AD tokens
const jwksClientInstance = jwksClient({
  jwksUri: `https://login.microsoftonline.com/${AZURE_TENANT_ID}/discovery/v2.0/keys`
});

function getKey(header, callback) {
  jwksClientInstance.getSigningKey(header.kid, (err, key) => {
    if (err) {
      callback(err);
    } else {
      const signingKey = key.getPublicKey();
      callback(null, signingKey);
    }
  });
}

// Middleware to validate Azure AD JWT token
async function validateAzureToken(req, res, next) {
  const authHeader = req.headers.authorization;

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'No token provided' });
  }

  const token = authHeader.split(' ')[1];

  try {
    // Verify token signature and claims
    const decoded = await new Promise((resolve, reject) => {
      jwt.verify(
        token,
        getKey,
        {
          audience: AZURE_CLIENT_ID,
          issuer: `https://sts.windows.net/${AZURE_TENANT_ID}/`,
          algorithms: ['RS256']
        },
        (err, decoded) => {
          if (err) reject(err);
          else resolve(decoded);
        }
      );
    });

    // Extract customer info from token
    req.user = {
      azureId: decoded.oid,
      email: decoded.email || decoded.upn,
      name: decoded.name,
      customerId: decoded.customer_id || decoded.extension_customer_id,
      azureToken: token
    };

    // Validate customer_id exists
    if (!req.user.customerId) {
      return res.status(403).json({
        error: 'Customer ID not found in token claims'
      });
    }

    next();
  } catch (error) {
    console.error('Token validation failed:', error);
    return res.status(401).json({ error: 'Invalid token' });
  }
}

// Get Snowflake connection using OAuth token
async function getSnowflakeConnection(azureToken) {
  return new Promise((resolve, reject) => {
    const connection = snowflake.createConnection({
      account: SNOWFLAKE_ACCOUNT,
      authenticator: 'OAUTH',
      token: azureToken,
      application: 'CustomerPortal',
    });

    connection.connect((err, conn) => {
      if (err) {
        reject(err);
      } else {
        resolve(conn);
      }
    });
  });
}

// Execute SQL with Snowflake connection
async function executeSql(connection, sql) {
  return new Promise((resolve, reject) => {
    connection.execute({
      sqlText: sql,
      complete: (err, stmt, rows) => {
        if (err) {
          reject(err);
        } else {
          resolve(rows);
        }
      }
    });
  });
}

// Get Snowflake session token for API calls
async function getSnowflakeSessionToken(azureToken, customerId) {
  try {
    // Option 1: Use Azure AD token directly (if Snowflake OAuth integration configured)
    // The token will be validated by Snowflake's external OAuth integration
    return azureToken;

    // Option 2: Exchange Azure AD token for Snowflake session token
    // (Implementation depends on your Snowflake OAuth setup)
  } catch (error) {
    console.error('Failed to get Snowflake session token:', error);
    throw error;
  }
}

// Validate customer access (verify user can access this customer_id)
async function validateCustomerAccess(connection, user) {
  const sql = `
    SELECT customer_id, customer_name
    FROM customer_mapping
    WHERE snowflake_user = CURRENT_USER()
  `;

  const rows = await executeSql(connection, sql);

  if (rows.length === 0) {
    throw new Error('Customer mapping not found for user');
  }

  const customerData = rows[0];

  // Optionally verify the customer_id from token matches Snowflake mapping
  if (user.customerId && customerData.CUSTOMER_ID !== user.customerId) {
    throw new Error('Customer ID mismatch between token and Snowflake mapping');
  }

  return customerData;
}

// Create Snowflake thread
app.post('/api/agent/thread', validateAzureToken, async (req, res) => {
  try {
    const token = await getSnowflakeSessionToken(req.user.azureToken, req.user.customerId);

    const response = await fetch(
      `https://${SNOWFLAKE_ACCOUNT}.snowflakecomputing.com/api/v2/cortex/threads`,
      {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          origin_application: 'customer_portal',
          metadata: {
            customer_id: req.user.customerId
          }
        })
      }
    );

    const data = await response.json();
    res.json(data);
  } catch (error) {
    console.error('Error creating thread:', error);
    res.status(500).json({ error: error.message });
  }
});

// Run agent with customer context
app.post('/api/agent/run', validateAzureToken, async (req, res) => {
  const { database, schema, agentName, threadId, message, parentMessageId = 0 } = req.body;

  try {
    // Get Snowflake connection to validate customer access
    const connection = await getSnowflakeConnection(req.user.azureToken);

    // Validate customer access and get customer data
    const customerData = await validateCustomerAccess(connection, req.user);

    connection.destroy();

    // Get session token for API
    const token = await getSnowflakeSessionToken(req.user.azureToken, req.user.customerId);

    // Prepare headers with user context
    // NOTE: Use X-Snowflake-Role for role override, X-Snowflake-Warehouse for warehouse override
    const headers = {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json',
      // Optional: Override the default role if needed (OAuth sets default automatically)
      // 'X-Snowflake-Role': 'customer_app_role',
      // 'X-Snowflake-Warehouse': 'customer_wh',
    };

    const url = `https://${SNOWFLAKE_ACCOUNT}.snowflakecomputing.com/api/v2/databases/${database}/schemas/${schema}/agents/${agentName}:run`;

    const response = await fetch(url, {
      method: 'POST',
      headers,
      body: JSON.stringify({
        thread_id: threadId,
        parent_message_id: parentMessageId,
        messages: [
          {
            role: 'user',
            content: [{
              type: 'text',
              text: message
            }]
          }
        ]
      })
    });

    if (!response.ok) {
      const errorText = await response.text();
      throw new Error(`Snowflake API error: ${response.status} - ${errorText}`);
    }

    // Set headers for SSE streaming
    res.setHeader('Content-Type', 'text/event-stream');
    res.setHeader('Cache-Control', 'no-cache');
    res.setHeader('Connection', 'keep-alive');
    res.setHeader('X-Customer-Id', customerData.CUSTOMER_ID);
    res.setHeader('X-Customer-Name', customerData.CUSTOMER_NAME);

    // Stream response to client
    response.body.pipe(res);

  } catch (error) {
    console.error('Error running agent:', error);
    if (!res.headersSent) {
      res.status(500).json({ error: error.message });
    } else {
      res.end();
    }
  }
});

// Get customer info
app.get('/api/customer/info', validateAzureToken, async (req, res) => {
  try {
    const connection = await getSnowflakeConnection(req.user.azureToken);
    const customerData = await validateCustomerAccess(connection, req.user);
    connection.destroy();

    res.json({
      customerId: customerData.CUSTOMER_ID,
      customerName: customerData.CUSTOMER_NAME,
      user: {
        name: req.user.name,
        email: req.user.email
      }
    });
  } catch (error) {
    console.error('Error getting customer info:', error);
    res.status(500).json({ error: error.message });
  }
});

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'ok' });
});

const PORT = process.env.PORT || 3001;
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
```

### 3.2 Environment Variables

```bash
# .env
AZURE_TENANT_ID=your-tenant-id
AZURE_CLIENT_ID=your-client-id
AZURE_CLIENT_SECRET=your-client-secret

SNOWFLAKE_ACCOUNT=myorg-myaccount
SNOWFLAKE_OAUTH_INTEGRATION=azure_oauth

FRONTEND_URL=http://localhost:3000

PORT=3001
```

---

## Part 4: React Frontend with OAuth

### 4.1 Install Dependencies

```bash
npm install @azure/msal-browser @azure/msal-react
```

### 4.2 MSAL Configuration

```typescript
// src/auth/msalConfig.ts
import { Configuration, PublicClientApplication } from '@azure/msal-browser';

export const msalConfig: Configuration = {
  auth: {
    clientId: process.env.REACT_APP_AZURE_CLIENT_ID!,
    authority: `https://login.microsoftonline.com/${process.env.REACT_APP_AZURE_TENANT_ID}`,
    redirectUri: window.location.origin,
  },
  cache: {
    cacheLocation: 'localStorage',
    storeAuthStateInCookie: false,
  },
};

export const loginRequest = {
  scopes: ['openid', 'profile', 'email', 'User.Read'],
};

export const msalInstance = new PublicClientApplication(msalConfig);

// Initialize MSAL
await msalInstance.initialize();
```

### 4.3 App Setup with MSAL Provider

```tsx
// src/index.tsx
import React from 'react';
import ReactDOM from 'react-dom/client';
import { MsalProvider } from '@azure/msal-react';
import { msalInstance } from './auth/msalConfig';
import App from './App';

const root = ReactDOM.createRoot(document.getElementById('root')!);

root.render(
  <React.StrictMode>
    <MsalProvider instance={msalInstance}>
      <App />
    </MsalProvider>
  </React.StrictMode>
);
```

### 4.4 Custom Hook for Snowflake Agent

```typescript
// src/hooks/useSnowflakeAgent.ts
import { useState, useCallback, useEffect } from 'react';
import { useMsal } from '@azure/msal-react';
import { loginRequest } from '../auth/msalConfig';

interface CustomerInfo {
  customerId: string;
  customerName: string;
  user: {
    name: string;
    email: string;
  };
}

interface AgentMessage {
  role: 'user' | 'assistant';
  content: string;
  timestamp: Date;
}

interface UseSnowflakeAgentProps {
  database: string;
  schema: string;
  agentName: string;
}

const API_BASE = process.env.REACT_APP_API_BASE || 'http://localhost:3001/api';

export const useSnowflakeAgent = ({
  database,
  schema,
  agentName
}: UseSnowflakeAgentProps) => {
  const { instance, accounts } = useMsal();
  const [messages, setMessages] = useState<AgentMessage[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const [threadId, setThreadId] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [customerInfo, setCustomerInfo] = useState<CustomerInfo | null>(null);

  // Get access token
  const getAccessToken = useCallback(async () => {
    if (accounts.length === 0) {
      throw new Error('No active account');
    }

    try {
      const response = await instance.acquireTokenSilent({
        ...loginRequest,
        account: accounts[0],
      });
      return response.accessToken;
    } catch (error) {
      // If silent token acquisition fails, trigger interactive login
      const response = await instance.acquireTokenPopup(loginRequest);
      return response.accessToken;
    }
  }, [instance, accounts]);

  // Fetch customer info
  useEffect(() => {
    const fetchCustomerInfo = async () => {
      try {
        const token = await getAccessToken();
        const response = await fetch(`${API_BASE}/customer/info`, {
          headers: {
            'Authorization': `Bearer ${token}`,
          },
        });

        if (!response.ok) {
          throw new Error('Failed to fetch customer info');
        }

        const data = await response.json();
        setCustomerInfo(data);
      } catch (err: any) {
        console.error('Error fetching customer info:', err);
        setError(err.message);
      }
    };

    if (accounts.length > 0) {
      fetchCustomerInfo();
    }
  }, [accounts, getAccessToken]);

  // Create thread
  const createThread = useCallback(async () => {
    const token = await getAccessToken();

    const response = await fetch(`${API_BASE}/agent/thread`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${token}`,
      },
    });

    if (!response.ok) {
      throw new Error('Failed to create thread');
    }

    const data = await response.json();
    setThreadId(data.id);
    return data.id;
  }, [getAccessToken]);

  // Send message to agent
  const sendMessage = useCallback(async (message: string) => {
    setIsLoading(true);
    setError(null);

    // Add user message immediately
    const userMessage: AgentMessage = {
      role: 'user',
      content: message,
      timestamp: new Date()
    };
    setMessages(prev => [...prev, userMessage]);

    try {
      // Create thread if doesn't exist
      let currentThreadId = threadId;
      if (!currentThreadId) {
        currentThreadId = await createThread();
      }

      const token = await getAccessToken();

      const response = await fetch(`${API_BASE}/agent/run`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          database,
          schema,
          agentName,
          threadId: currentThreadId,
          message,
        }),
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

                // Update assistant message in real-time
                setMessages(prev => {
                  const lastMessage = prev[prev.length - 1];
                  if (lastMessage?.role === 'assistant') {
                    return [
                      ...prev.slice(0, -1),
                      {
                        role: 'assistant',
                        content: assistantMessage,
                        timestamp: lastMessage.timestamp
                      }
                    ];
                  } else {
                    return [
                      ...prev,
                      {
                        role: 'assistant',
                        content: assistantMessage,
                        timestamp: new Date()
                      }
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
    } catch (err: any) {
      setError(err.message);
      console.error('Error sending message:', err);

      // Add error message
      setMessages(prev => [
        ...prev,
        {
          role: 'assistant',
          content: `Error: ${err.message}`,
          timestamp: new Date()
        }
      ]);
    } finally {
      setIsLoading(false);
    }
  }, [threadId, database, schema, agentName, getAccessToken, createThread]);

  return {
    messages,
    sendMessage,
    isLoading,
    error,
    threadId,
    customerInfo
  };
};
```

### 4.5 Main App Component

```tsx
// src/App.tsx
import React from 'react';
import { AuthenticatedTemplate, UnauthenticatedTemplate, useMsal } from '@azure/msal-react';
import { loginRequest } from './auth/msalConfig';
import AgentChat from './components/AgentChat';
import './App.css';

function App() {
  const { instance } = useMsal();

  const handleLogin = () => {
    instance.loginPopup(loginRequest).catch(e => {
      console.error('Login failed:', e);
    });
  };

  const handleLogout = () => {
    instance.logoutPopup().catch(e => {
      console.error('Logout failed:', e);
    });
  };

  return (
    <div className="App">
      <AuthenticatedTemplate>
        <div className="app-container">
          <header className="app-header">
            <h1>Customer Data Portal</h1>
            <button onClick={handleLogout} className="logout-btn">
              Logout
            </button>
          </header>

          <AgentChat
            database="MYDB"
            schema="MYSCHEMA"
            agentName="customer_sales_agent"
          />
        </div>
      </AuthenticatedTemplate>

      <UnauthenticatedTemplate>
        <div className="login-container">
          <div className="login-card">
            <h1>Customer Data Portal</h1>
            <p>Please sign in to access your data</p>
            <button onClick={handleLogin} className="login-btn">
              Sign in with Microsoft
            </button>
          </div>
        </div>
      </UnauthenticatedTemplate>
    </div>
  );
}

export default App;
```

### 4.6 Agent Chat Component

```tsx
// src/components/AgentChat.tsx
import React, { useState, useRef, useEffect } from 'react';
import { useSnowflakeAgent } from '../hooks/useSnowflakeAgent';
import './AgentChat.css';

interface AgentChatProps {
  database: string;
  schema: string;
  agentName: string;
}

const AgentChat: React.FC<AgentChatProps> = ({ database, schema, agentName }) => {
  const [input, setInput] = useState('');
  const messagesEndRef = useRef<HTMLDivElement>(null);

  const { messages, sendMessage, isLoading, error, customerInfo } = useSnowflakeAgent({
    database,
    schema,
    agentName
  });

  // Auto-scroll to bottom
  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!input.trim() || isLoading) return;

    await sendMessage(input);
    setInput('');
  };

  return (
    <div className="chat-container">
      {customerInfo && (
        <div className="customer-info">
          <div className="customer-badge">
            <strong>{customerInfo.customerName}</strong>
            <span className="customer-id">ID: {customerInfo.customerId}</span>
          </div>
          <div className="user-info">
            {customerInfo.user.name} ({customerInfo.user.email})
          </div>
        </div>
      )}

      <div className="messages-container">
        {messages.length === 0 && (
          <div className="empty-state">
            <h3>Welcome to your Data Assistant</h3>
            <p>Ask questions about your sales data, and I'll help you find insights.</p>
            <div className="example-queries">
              <p>Try asking:</p>
              <ul>
                <li>"What are my total sales this month?"</li>
                <li>"Show me my top products"</li>
                <li>"What was my revenue last quarter?"</li>
              </ul>
            </div>
          </div>
        )}

        {messages.map((msg, idx) => (
          <div key={idx} className={`message ${msg.role}`}>
            <div className="message-header">
              <strong>{msg.role === 'user' ? 'You' : 'Assistant'}</strong>
              <span className="message-time">
                {msg.timestamp.toLocaleTimeString()}
              </span>
            </div>
            <div className="message-content">
              {msg.content}
            </div>
          </div>
        ))}

        {isLoading && (
          <div className="message assistant">
            <div className="message-header">
              <strong>Assistant</strong>
            </div>
            <div className="message-content">
              <div className="typing-indicator">
                <span></span>
                <span></span>
                <span></span>
              </div>
            </div>
          </div>
        )}

        {error && (
          <div className="error-message">
            <strong>Error:</strong> {error}
          </div>
        )}

        <div ref={messagesEndRef} />
      </div>

      <form onSubmit={handleSubmit} className="input-form">
        <input
          type="text"
          value={input}
          onChange={(e) => setInput(e.target.value)}
          placeholder="Ask a question about your data..."
          disabled={isLoading}
          className="message-input"
        />
        <button
          type="submit"
          disabled={isLoading || !input.trim()}
          className="send-button"
        >
          {isLoading ? 'Sending...' : 'Send'}
        </button>
      </form>
    </div>
  );
};

export default AgentChat;
```

### 4.7 Styling

```css
/* src/App.css */
.App {
  min-height: 100vh;
  background: #f5f5f5;
}

.login-container {
  display: flex;
  justify-content: center;
  align-items: center;
  min-height: 100vh;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
}

.login-card {
  background: white;
  padding: 3rem;
  border-radius: 12px;
  box-shadow: 0 10px 40px rgba(0,0,0,0.1);
  text-align: center;
  max-width: 400px;
}

.login-card h1 {
  margin-bottom: 1rem;
  color: #333;
}

.login-card p {
  color: #666;
  margin-bottom: 2rem;
}

.login-btn {
  background: #667eea;
  color: white;
  border: none;
  padding: 12px 32px;
  border-radius: 6px;
  font-size: 16px;
  cursor: pointer;
  transition: background 0.3s;
}

.login-btn:hover {
  background: #5568d3;
}

.app-container {
  max-width: 1200px;
  margin: 0 auto;
  padding: 20px;
  min-height: 100vh;
}

.app-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 20px;
  background: white;
  border-radius: 12px;
  margin-bottom: 20px;
  box-shadow: 0 2px 8px rgba(0,0,0,0.1);
}

.app-header h1 {
  margin: 0;
  color: #333;
}

.logout-btn {
  background: #dc3545;
  color: white;
  border: none;
  padding: 10px 24px;
  border-radius: 6px;
  cursor: pointer;
  transition: background 0.3s;
}

.logout-btn:hover {
  background: #c82333;
}
```

```css
/* src/components/AgentChat.css */
.chat-container {
  background: white;
  border-radius: 12px;
  box-shadow: 0 2px 8px rgba(0,0,0,0.1);
  display: flex;
  flex-direction: column;
  height: calc(100vh - 200px);
}

.customer-info {
  padding: 16px 20px;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  color: white;
  border-radius: 12px 12px 0 0;
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.customer-badge {
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.customer-id {
  font-size: 0.85rem;
  opacity: 0.9;
}

.user-info {
  font-size: 0.9rem;
  opacity: 0.9;
}

.messages-container {
  flex: 1;
  overflow-y: auto;
  padding: 20px;
  display: flex;
  flex-direction: column;
  gap: 16px;
}

.empty-state {
  text-align: center;
  padding: 40px 20px;
  color: #666;
}

.empty-state h3 {
  color: #333;
  margin-bottom: 12px;
}

.example-queries {
  margin-top: 32px;
  text-align: left;
  background: #f8f9fa;
  padding: 20px;
  border-radius: 8px;
}

.example-queries ul {
  list-style: none;
  padding: 0;
  margin-top: 12px;
}

.example-queries li {
  padding: 8px 0;
  color: #667eea;
  cursor: pointer;
}

.example-queries li:hover {
  text-decoration: underline;
}

.message {
  display: flex;
  flex-direction: column;
  gap: 8px;
  max-width: 80%;
  animation: fadeIn 0.3s;
}

@keyframes fadeIn {
  from { opacity: 0; transform: translateY(10px); }
  to { opacity: 1; transform: translateY(0); }
}

.message.user {
  align-self: flex-end;
}

.message.assistant {
  align-self: flex-start;
}

.message-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 12px;
  font-size: 0.85rem;
  color: #666;
}

.message-time {
  font-size: 0.75rem;
}

.message-content {
  padding: 12px 16px;
  border-radius: 12px;
  white-space: pre-wrap;
  word-wrap: break-word;
}

.message.user .message-content {
  background: #667eea;
  color: white;
  border-bottom-right-radius: 4px;
}

.message.assistant .message-content {
  background: #f1f3f4;
  color: #333;
  border-bottom-left-radius: 4px;
}

.typing-indicator {
  display: flex;
  gap: 4px;
  padding: 8px 0;
}

.typing-indicator span {
  width: 8px;
  height: 8px;
  background: #999;
  border-radius: 50%;
  animation: typing 1.4s infinite;
}

.typing-indicator span:nth-child(2) {
  animation-delay: 0.2s;
}

.typing-indicator span:nth-child(3) {
  animation-delay: 0.4s;
}

@keyframes typing {
  0%, 60%, 100% { transform: translateY(0); }
  30% { transform: translateY(-10px); }
}

.error-message {
  background: #f8d7da;
  color: #721c24;
  padding: 12px 16px;
  border-radius: 8px;
  border: 1px solid #f5c6cb;
}

.input-form {
  display: flex;
  gap: 12px;
  padding: 20px;
  border-top: 1px solid #e0e0e0;
}

.message-input {
  flex: 1;
  padding: 12px 16px;
  border: 1px solid #ddd;
  border-radius: 24px;
  font-size: 14px;
  outline: none;
  transition: border-color 0.3s;
}

.message-input:focus {
  border-color: #667eea;
}

.message-input:disabled {
  background: #f5f5f5;
  cursor: not-allowed;
}

.send-button {
  background: #667eea;
  color: white;
  border: none;
  padding: 12px 32px;
  border-radius: 24px;
  cursor: pointer;
  font-size: 14px;
  font-weight: 600;
  transition: background 0.3s;
}

.send-button:hover:not(:disabled) {
  background: #5568d3;
}

.send-button:disabled {
  background: #ccc;
  cursor: not-allowed;
}
```

---

## Part 5: Environment Variables

### 5.1 Backend `.env`

```bash
# Azure AD
AZURE_TENANT_ID=12345678-1234-1234-1234-123456789012
AZURE_CLIENT_ID=abcdefgh-abcd-abcd-abcd-abcdefghijkl
AZURE_CLIENT_SECRET=your-secret-value

# Snowflake
SNOWFLAKE_ACCOUNT=myorg-myaccount
SNOWFLAKE_OAUTH_INTEGRATION=azure_oauth

# App
FRONTEND_URL=http://localhost:3000
PORT=3001
```

### 5.2 React `.env`

```bash
REACT_APP_AZURE_TENANT_ID=12345678-1234-1234-1234-123456789012
REACT_APP_AZURE_CLIENT_ID=abcdefgh-abcd-abcd-abcd-abcdefghijkl
REACT_APP_API_BASE=http://localhost:3001/api
```

---

## Part 6: Testing the Setup

### 6.1 Test Row Access Policy

```sql
-- As admin, verify policy is applied
SHOW ROW ACCESS POLICIES;

-- Test as customer1_user
USE ROLE customer_app_role;
SELECT * FROM sales;
-- Should only see CUST001 rows

-- Test as customer2_user
-- Should only see CUST002 rows
```

### 6.2 Test Agent Access

```bash
# Start backend
cd backend
npm install
node server.js

# Start React app
cd frontend
npm install
npm start
```

1. Navigate to `http://localhost:3000`
2. Click "Sign in with Microsoft"
3. Authenticate with Azure AD user (customer1@yourdomain.com)
4. Ask: "What are my total sales?"
5. Verify only customer's data is returned

---

## Security Best Practices

### 1. Token Management
- Never store tokens in localStorage (use httpOnly cookies for refresh tokens)
- Implement token refresh logic
- Set appropriate token expiration times

### 2. API Security
- Implement rate limiting
- Add request logging and monitoring
- Use HTTPS in production
- Validate all inputs

### 3. Database Security
- Use least privilege principle for roles
- Audit Row Access Policy changes
- Monitor for policy bypasses
- Regularly review customer mappings

### 4. Customer Isolation
- Test cross-customer data access
- Implement audit logging for all data access
- Monitor for suspicious queries
- Regular security audits

### 5. Error Handling
- Don't expose sensitive info in errors
- Log errors server-side
- Provide user-friendly messages
- Implement error alerting

---

## Monitoring and Observability

### Backend Logging

```javascript
// Add to server.js
const winston = require('winston');

const logger = winston.createLogger({
  level: 'info',
  format: winston.format.json(),
  defaultMeta: { service: 'customer-portal' },
  transports: [
    new winston.transports.File({ filename: 'error.log', level: 'error' }),
    new winston.transports.File({ filename: 'combined.log' }),
  ],
});

// Log all agent calls
app.post('/api/agent/run', validateAzureToken, async (req, res) => {
  logger.info('Agent request', {
    customerId: req.user.customerId,
    email: req.user.email,
    message: req.body.message,
    timestamp: new Date().toISOString()
  });
  // ... rest of handler
});
```

### Snowflake Query Monitoring

```sql
-- Monitor agent queries by customer
SELECT
  user_name,
  query_text,
  execution_time,
  rows_produced,
  start_time
FROM snowflake.account_usage.query_history
WHERE query_text LIKE '%sales%'
  AND user_name IN (SELECT snowflake_user FROM customer_mapping)
ORDER BY start_time DESC
LIMIT 100;
```

---

## Troubleshooting

### Issue: User sees no data

**Check:**
1. Row Access Policy is applied: `SHOW ROW ACCESS POLICIES`
2. Customer mapping exists: `SELECT * FROM customer_mapping WHERE snowflake_user = CURRENT_USER()`
3. User has correct role: `SELECT CURRENT_ROLE()`

### Issue: OAuth token invalid

**Check:**
1. Token expiration
2. Azure AD app configuration
3. Snowflake OAuth integration settings
4. Clock skew between systems

### Issue: Cross-customer data leak

**Immediate action:**
1. Revoke all sessions
2. Audit query history for the user
3. Review Row Access Policy
4. Check customer_mapping table

---

## Deployment Checklist

- [ ] Configure Azure AD app registration
- [ ] Create Snowflake External OAuth integration
- [ ] Create and test Row Access Policies
- [ ] Set up customer mapping table
- [ ] Deploy backend with environment variables
- [ ] Deploy frontend with MSAL configuration
- [ ] Enable HTTPS/SSL
- [ ] Configure CORS properly
- [ ] Set up monitoring and alerting
- [ ] Test with multiple customer accounts
- [ ] Perform security audit
- [ ] Document customer onboarding process
- [ ] Set up backup and disaster recovery

---

## Next Steps

1. **Add Multi-factor Authentication** via Azure AD
2. **Implement Audit Logging** for all data access
3. **Add Usage Analytics** to track customer queries
4. **Create Admin Dashboard** for customer management
5. **Implement Data Export** capabilities with customer isolation
6. **Add Real-time Notifications** for important events
7. **Create Customer Onboarding** workflow
8. **Implement SLA Monitoring** and alerting
