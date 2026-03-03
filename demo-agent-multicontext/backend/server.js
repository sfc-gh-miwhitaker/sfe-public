const express = require('express');
const cors = require('cors');

const app = express();
app.use(cors());
app.use(express.json());

const SNOWFLAKE_ACCOUNT = process.env.SNOWFLAKE_ACCOUNT;
const SNOWFLAKE_PAT = process.env.SNOWFLAKE_PAT;

if (!SNOWFLAKE_ACCOUNT || !SNOWFLAKE_PAT) {
  console.error('Required env vars: SNOWFLAKE_ACCOUNT, SNOWFLAKE_PAT');
  process.exit(1);
}

const BASE_URL = `https://${SNOWFLAKE_ACCOUNT}.snowflakecomputing.com`;

// ---------------------------------------------------------------------------
// Station registry -- in production this comes from the database
// ---------------------------------------------------------------------------
const STATIONS = {
  STN001: { id: 'STN001', name: 'WETA Washington',    callSign: 'WETA',  market: 'Washington DC',  domain: 'weta.org' },
  STN002: { id: 'STN002', name: 'KQED San Francisco', callSign: 'KQED',  market: 'San Francisco',  domain: 'kqed.org' },
  STN003: { id: 'STN003', name: 'WGBH Boston',        callSign: 'WGBH',  market: 'Boston',         domain: 'wgbh.org' },
  STN004: { id: 'STN004', name: 'WTTW Chicago',       callSign: 'WTTW',  market: 'Chicago',        domain: 'wttw.com' },
  STN005: { id: 'STN005', name: 'KCET Los Angeles',   callSign: 'KCET',  market: 'Los Angeles',    domain: 'kcet.org' },
};

// ---------------------------------------------------------------------------
// Simulated user database -- in production these come from your auth layer
// ---------------------------------------------------------------------------
const DEMO_USERS = {
  viewer_alice:  { id: 'MBR001', name: 'Alice Johnson',  stationId: 'STN001', tier: 'Sustainer'  },
  viewer_david:  { id: 'MBR004', name: 'David Kim',      stationId: 'STN002', tier: 'Sustainer'  },
  admin_carol:   { id: 'MBR003', name: 'Carol Martinez', stationId: 'STN001', tier: 'Leadership' },
  admin_frank:   { id: 'MBR006', name: 'Frank O\'Brien', stationId: 'STN003', tier: 'Leadership' },
};

// ---------------------------------------------------------------------------
// Context builder -- the core of the "without agent object" approach
// ---------------------------------------------------------------------------
function buildSystemInstructions({ userType, userId, userName, memberTier, station }) {
  let system = `You are the ${station.name} Support Agent (${station.callSign}).`;
  system += ` You serve viewers and members in the ${station.market} market.`;
  system += ` Station website: ${station.domain}.`;

  if (userType === 'anonymous') {
    system += '\n\nThe current user is NOT logged in.';
    system += ' Only answer general questions about programming, schedules, streaming, and membership benefits.';
    system += ' If asked about account-specific information, politely ask them to log in first.';
    system += ' Do NOT access viewership metrics or member account data.';
  } else if (userType === 'low') {
    system += `\n\nThe logged-in user is ${userName} (Member ID: ${userId}, Tier: ${memberTier}).`;
    system += ' This user has basic member access.';
    system += ' You can answer questions about their station programming, general viewership trends, and support topics.';
    system += ' Do NOT share detailed member account data or financial information.';
  } else if (userType === 'full') {
    system += `\n\nThe logged-in user is ${userName} (Member ID: ${userId}, Tier: ${memberTier}).`;
    system += ' This user has ADMINISTRATIVE access.';
    system += ' You can answer questions about viewership metrics, member accounts, pledge data, and station operations.';
    system += ' Provide detailed analytics when asked.';
  }

  return system;
}

function buildResponseInstructions(userType) {
  let response = 'Be friendly and helpful. Format responses with markdown when useful.';
  if (userType === 'anonymous') {
    response += ' Keep answers concise since the user is browsing without an account.';
  }
  return response;
}

function buildOrchestrationInstructions(userType) {
  if (userType === 'anonymous') {
    return 'Only use the knowledge base search tool. Do not use the analyst tool.';
  }
  if (userType === 'low') {
    return 'Use the knowledge base for support questions. Use the analyst tool for viewership and programming questions.';
  }
  return 'Use all available tools. Prefer the analyst tool for data questions and the knowledge base for support/policy questions.';
}

function buildTools(userType) {
  const tools = [];
  const toolResources = {};

  // Cortex Search -- available to ALL tiers
  tools.push({
    tool_spec: {
      type: 'cortex_search',
      name: 'support_kb',
      description: 'Search the support knowledge base for articles about streaming, membership, programming, technical issues, and station events.',
    },
  });
  toolResources.support_kb = {
    search_service: 'SNOWFLAKE_EXAMPLE.AGENT_MULTICONTEXT.SUPPORT_KB_SEARCH',
    title_column: 'title',
    id_column: 'article_id',
  };

  // Cortex Analyst -- available to low and full auth tiers
  if (userType === 'low' || userType === 'full') {
    tools.push({
      tool_spec: {
        type: 'cortex_analyst_text_to_sql',
        name: 'viewership_analyst',
        description: 'Query viewership metrics, ratings, streaming data, and programming schedules across stations.',
      },
    });
    toolResources.viewership_analyst = {
      semantic_view: 'SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS.SV_AGENT_MULTICONTEXT_VIEWERSHIP',
      execution_environment: {
        type: 'warehouse',
        warehouse: 'SFE_AGENT_MULTICONTEXT_WH',
        query_timeout: 60,
      },
    };
  }

  return { tools, toolResources };
}

function buildAgentPayload({ userType, userId, userName, memberTier, stationId, message, threadId, parentMessageId }) {
  const station = STATIONS[stationId] || STATIONS.STN001;
  const { tools, toolResources } = buildTools(userType);

  const role = userType === 'full' ? 'TV_ADMIN_ROLE'
    : userType === 'low' ? 'TV_VIEWER_ROLE'
    : undefined;

  return {
    payload: {
      thread_id: threadId,
      parent_message_id: parentMessageId || 0,
      messages: [
        {
          role: 'user',
          content: [{ type: 'text', text: message }],
        },
      ],
      models: { orchestration: 'auto' },
      instructions: {
        system: buildSystemInstructions({ userType, userId, userName, memberTier, station }),
        response: buildResponseInstructions(userType),
        orchestration: buildOrchestrationInstructions(userType),
      },
      tools,
      tool_resources: toolResources,
    },
    role,
  };
}

// ---------------------------------------------------------------------------
// Routes
// ---------------------------------------------------------------------------

app.get('/api/stations', (_req, res) => {
  res.json(Object.values(STATIONS));
});

app.get('/api/users', (_req, res) => {
  res.json(
    Object.entries(DEMO_USERS).map(([key, u]) => ({
      key,
      ...u,
      stationName: STATIONS[u.stationId]?.name,
    }))
  );
});

app.post('/api/agent/thread', async (_req, res) => {
  try {
    const response = await fetch(`${BASE_URL}/api/v2/cortex/threads`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${SNOWFLAKE_PAT}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ origin_application: 'demo_agent_multicontext' }),
    });

    if (!response.ok) {
      const text = await response.text();
      return res.status(response.status).json({ error: text });
    }

    const data = await response.json();
    res.json(data);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Preview the payload without sending it (for the API Inspector)
app.post('/api/agent/preview', (req, res) => {
  const { userType, userId, userName, memberTier, stationId, message } = req.body;
  const { payload, role } = buildAgentPayload({
    userType: userType || 'anonymous',
    userId,
    userName,
    memberTier,
    stationId: stationId || 'STN001',
    message: message || '(your message here)',
    threadId: '<thread_id>',
    parentMessageId: 0,
  });

  res.json({
    endpoint: 'POST /api/v2/cortex/agent:run',
    headers: {
      Authorization: 'Bearer <token>',
      'Content-Type': 'application/json',
      ...(role ? { 'X-Snowflake-Role': role } : {}),
    },
    body: payload,
  });
});

app.post('/api/agent/run', async (req, res) => {
  const {
    userType,
    userId,
    userName,
    memberTier,
    stationId,
    message,
    threadId,
    parentMessageId,
  } = req.body;

  const { payload, role } = buildAgentPayload({
    userType: userType || 'anonymous',
    userId,
    userName,
    memberTier,
    stationId: stationId || 'STN001',
    message,
    threadId,
    parentMessageId: parentMessageId || 0,
  });

  const headers = {
    Authorization: `Bearer ${SNOWFLAKE_PAT}`,
    'Content-Type': 'application/json',
  };
  if (role) {
    headers['X-Snowflake-Role'] = role;
  }

  try {
    const response = await fetch(`${BASE_URL}/api/v2/cortex/agent:run`, {
      method: 'POST',
      headers,
      body: JSON.stringify(payload),
    });

    if (!response.ok) {
      const text = await response.text();
      return res.status(response.status).json({ error: text });
    }

    res.setHeader('Content-Type', 'text/event-stream');
    res.setHeader('Cache-Control', 'no-cache');
    res.setHeader('Connection', 'keep-alive');

    response.body.pipe(res);
  } catch (error) {
    if (!res.headersSent) {
      res.status(500).json({ error: error.message });
    } else {
      res.end();
    }
  }
});

app.get('/health', (_req, res) => {
  res.json({ status: 'ok', account: SNOWFLAKE_ACCOUNT });
});

const PORT = process.env.PORT || 3001;
app.listen(PORT, () => {
  console.log(`Backend proxy running on http://localhost:${PORT}`);
  console.log(`Snowflake account: ${SNOWFLAKE_ACCOUNT}`);
});
