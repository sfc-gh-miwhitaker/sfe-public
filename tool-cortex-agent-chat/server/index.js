const path = require('path');
const fs = require('fs');
const { createHash, createPublicKey, createSign } = require('crypto');
const express = require('express');
const cors = require('cors');
const dotenv = require('dotenv');

// Load server-specific env first if present, then fall back to default .env
dotenv.config({ path: path.join(__dirname, '..', '.env.server.local') });
dotenv.config({ path: path.join(__dirname, '..', '.env') });

const app = express();
app.use(cors());
app.use(express.json({ limit: '1mb' }));

const PORT = process.env.PORT || 4000;

const resolvePrivateKeyPem = () => {
  const fromEnv = process.env.SNOWFLAKE_PRIVATE_KEY_PEM;
  if (fromEnv && `${fromEnv}`.trim()) {
    return `${fromEnv}`;
  }

  const fromPath = process.env.SNOWFLAKE_PRIVATE_KEY_PATH;
  if (fromPath && `${fromPath}`.trim()) {
    const p = path.resolve(`${fromPath}`.trim());
    return fs.readFileSync(p, 'utf8');
  }

  return '';
};

const CONFIG = {
  account: process.env.SNOWFLAKE_ACCOUNT,
  user: process.env.SNOWFLAKE_USER,
  privateKey: resolvePrivateKeyPem(),
  database: process.env.SNOWFLAKE_DATABASE,
  schema: process.env.SNOWFLAKE_SCHEMA,
  agentName: process.env.SNOWFLAKE_AGENT_NAME
};

const ensureConfig = () => {
  const missing = Object.entries(CONFIG)
    .filter(([, value]) => !value || !`${value}`.trim())
    .map(([key]) => key);

  if (missing.length) {
    throw new Error(
      `Missing required environment variables: ${missing.join(
        ', '
      )}. Expected in .env.server.local or environment.`
    );
  }
};

const normalizeAccount = (account) =>
  account
    .replace('.snowflakecomputing.com', '')
    .replace(/\./g, '-')
    .toUpperCase();

const buildBaseUrl = (account) => {
  const trimmed = account.trim();
  return trimmed.includes('.snowflakecomputing.com')
    ? `https://${trimmed}`
    : `https://${trimmed}.snowflakecomputing.com`;
};

// JWT cache (5 minute buffer before expiry)
let cachedJwt = null;

const toBase64Url = (input) =>
  Buffer.from(input).toString('base64url');

const buildFingerprint = (privateKeyPem) => {
  const publicKeyDer = createPublicKey(privateKeyPem).export({
    type: 'spki',
    format: 'der'
  });
  return createHash('sha256').update(publicKeyDer).digest('base64');
};

const signJwt = ({ account, user, privateKey, expiresInSeconds = 3600 }) => {
  const now = Math.floor(Date.now() / 1000);
  const exp = now + expiresInSeconds;

  const normalizedAccount = normalizeAccount(account);
  const username = user.trim().toUpperCase();
  const qualified = `${normalizedAccount}.${username}`;

  const normalizedKey = privateKey.replace(/\\n/g, '\n').trim();
  const fingerprint = buildFingerprint(normalizedKey);

  const header = { alg: 'RS256', typ: 'JWT' };
  const payload = {
    iss: `${qualified}.SHA256:${fingerprint}`,
    sub: qualified,
    iat: now,
    exp
  };

  const signingInput = `${toBase64Url(JSON.stringify(header))}.${toBase64Url(
    JSON.stringify(payload)
  )}`;

  const signature = createSign('RSA-SHA256')
    .update(signingInput)
    .end()
    .sign(normalizedKey, 'base64url');

  return { token: `${signingInput}.${signature}`, exp };
};

const getJwt = () => {
  const now = Math.floor(Date.now() / 1000);
  if (cachedJwt && cachedJwt.exp - 300 > now) {
    return cachedJwt.token;
  }

  const { token, exp } = signJwt({
    account: CONFIG.account,
    user: CONFIG.user,
    privateKey: CONFIG.privateKey
  });
  cachedJwt = { token, exp };
  return token;
};

const snowflakeFetch = async (url, options = {}) => {
  const jwt = getJwt();
  const headers = {
    ...options.headers,
    Authorization: `Bearer ${jwt}`,
    'X-Snowflake-Authorization-Token-Type': 'KEYPAIR_JWT'
  };

  return fetch(url, { ...options, headers });
};

const buildAgentRunUrl = () =>
  `${buildBaseUrl(CONFIG.account)}/api/v2/databases/${encodeURIComponent(
    CONFIG.database
  )}/schemas/${encodeURIComponent(CONFIG.schema)}/agents/${encodeURIComponent(
    CONFIG.agentName
  )}:run`;

const buildAgentPayload = (body) => {
  const message = (body.message || '').trim();
  const threadId = body.threadId ?? body.thread_id;
  const parentMessageId =
    body.parentMessageId ?? body.parent_message_id ?? 0;
  const stream = body.stream ?? false;

  if (!message) {
    const err = new Error('Message is required.');
    err.status = 400;
    throw err;
  }

  if (threadId === undefined || threadId === null) {
    const err = new Error('threadId is required. Create a thread first.');
    err.status = 400;
    throw err;
  }

  return {
    thread_id: threadId,
    parent_message_id: parentMessageId,
    messages: [
      {
        role: 'user',
        content: [
          {
            type: 'text',
            text: message
          }
        ]
      }
    ],
    stream
  };
};

const parseSnowflakeError = async (response) => {
  const text = await response.text();
  return text || response.statusText || 'Unknown Snowflake error';
};

app.get('/health', (_req, res) => {
  try {
    ensureConfig();
    res.json({ status: 'ok' });
  } catch (err) {
    res.status(500).json({ status: 'error', message: err.message });
  }
});

app.post('/api/threads', async (req, res) => {
  try {
    ensureConfig();
    const payload = {};
    if (req.body?.origin_application) {
      payload.origin_application = req.body.origin_application;
    }

    const response = await snowflakeFetch(
      `${buildBaseUrl(CONFIG.account)}/api/v2/cortex/threads`,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Accept: 'application/json'
        },
        body: JSON.stringify(payload)
      }
    );

    if (!response.ok) {
      const detail = await parseSnowflakeError(response);
      return res
        .status(response.status)
        .json({ error: 'Snowflake thread creation failed', detail });
    }

    const data = await response.json();
    const threadId = data.thread_id || data.id || data;

    return res.json({ thread_id: threadId });
  } catch (err) {
    console.error('Thread creation error:', err);
    res
      .status(err.status || 500)
      .json({ error: err.message || 'Failed to create thread' });
  }
});

app.get('/api/threads/:id', async (req, res) => {
  try {
    ensureConfig();
    const threadId = req.params.id;
    const response = await snowflakeFetch(
      `${buildBaseUrl(CONFIG.account)}/api/v2/cortex/threads/${threadId}`,
      {
        method: 'GET',
        headers: {
          Accept: 'application/json'
        }
      }
    );

    if (!response.ok) {
      const detail = await parseSnowflakeError(response);
      return res
        .status(response.status)
        .json({ error: 'Snowflake thread fetch failed', detail });
    }

    const data = await response.json();
    return res.json(data);
  } catch (err) {
    console.error('Describe thread error:', err);
    res
      .status(err.status || 500)
      .json({ error: err.message || 'Failed to fetch thread' });
  }
});

app.post('/api/agent/run', async (req, res) => {
  try {
    ensureConfig();
    const payload = buildAgentPayload(req.body);
    payload.stream = false;

    const response = await snowflakeFetch(buildAgentRunUrl(), {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Accept: 'application/json'
      },
      body: JSON.stringify(payload)
    });

    if (!response.ok) {
      const detail = await parseSnowflakeError(response);
      return res
        .status(response.status)
        .json({ error: 'Snowflake agent:run failed', detail });
    }

    const data = await response.json();
    return res.json(data);
  } catch (err) {
    console.error('Agent run (non-stream) error:', err);
    res
      .status(err.status || 500)
      .json({ error: err.message || 'Failed to call agent:run' });
  }
});

app.post('/api/agent/run/stream', async (req, res) => {
  try {
    ensureConfig();
    const payload = buildAgentPayload(req.body);
    payload.stream = true;

    const response = await snowflakeFetch(buildAgentRunUrl(), {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Accept: 'text/event-stream'
      },
      body: JSON.stringify(payload)
    });

    if (!response.ok) {
      const detail = await parseSnowflakeError(response);
      return res
        .status(response.status)
        .json({ error: 'Snowflake agent:run (stream) failed', detail });
    }

    res.writeHead(200, {
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache',
      Connection: 'keep-alive'
    });

    // Handle Web Stream (Fetch API) using reader
    const reader = response.body.getReader();
    const decoder = new TextDecoder();

    // Handle client disconnect
    let cancelled = false;
    req.on('close', () => {
      cancelled = true;
      reader.cancel().catch(() => {});
    });

    try {
      while (!cancelled) {
        const { done, value } = await reader.read();

        if (done) {
          res.end();
          break;
        }

        // Write the chunk to the response
        res.write(value);
      }
    } catch (err) {
      console.error('Streaming error from Snowflake:', err);
      if (!res.headersSent) {
        res.status(500).json({ error: 'Streaming error', detail: err.message });
      } else {
        res.write(`event: error\ndata: ${JSON.stringify({ message: err.message })}\n\n`);
        res.end();
      }
    }
  } catch (err) {
    console.error('Agent run (stream) error:', err);
    if (!res.headersSent) {
      res
        .status(err.status || 500)
        .json({ error: err.message || 'Failed to stream agent:run' });
    } else {
      res.write(`event: error\ndata: ${JSON.stringify({ message: err.message })}\n\n`);
      res.end();
    }
  }
});

app.listen(PORT, () => {
  console.log(`Backend proxy listening on http://localhost:${PORT}`);
});
