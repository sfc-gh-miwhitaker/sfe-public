import type { AgentContext, Station } from '../types';

const STATIONS: Record<string, Station> = {
  STN001: { id: 'STN001', name: 'WETA Washington',    callSign: 'WETA',  market: 'Washington DC',  domain: 'weta.org' },
  STN002: { id: 'STN002', name: 'KQED San Francisco', callSign: 'KQED',  market: 'San Francisco',  domain: 'kqed.org' },
  STN003: { id: 'STN003', name: 'WGBH Boston',        callSign: 'WGBH',  market: 'Boston',         domain: 'wgbh.org' },
  STN004: { id: 'STN004', name: 'WTTW Chicago',       callSign: 'WTTW',  market: 'Chicago',        domain: 'wttw.com' },
  STN005: { id: 'STN005', name: 'KCET Los Angeles',   callSign: 'KCET',  market: 'Los Angeles',    domain: 'kcet.org' },
};

export function getStation(stationId: string): Station {
  return STATIONS[stationId] ?? STATIONS.STN001;
}

export function getStationList(): Station[] {
  return Object.values(STATIONS);
}

/**
 * Builds a client-side preview of the agent:run payload.
 * Mirrors the backend's buildAgentPayload for the API Inspector panel.
 */
export function buildPayloadPreview(ctx: AgentContext, message: string) {
  const station = getStation(ctx.stationId);

  let system = `You are the ${station.name} Support Agent (${station.callSign}).`;
  system += ` You serve viewers and members in the ${station.market} market.`;
  system += ` Station website: ${station.domain}.`;

  if (ctx.userType === 'anonymous') {
    system += '\n\nThe current user is NOT logged in.';
    system += ' Only answer general questions about programming, schedules, streaming, and membership benefits.';
    system += ' If asked about account-specific information, politely ask them to log in first.';
    system += ' Do NOT access viewership metrics or member account data.';
  } else if (ctx.userType === 'low') {
    system += `\n\nThe logged-in user is ${ctx.userName} (Member ID: ${ctx.userId}, Tier: ${ctx.memberTier}).`;
    system += ' This user has basic member access.';
    system += ' You can answer questions about their station programming, general viewership trends, and support topics.';
    system += ' Do NOT share detailed member account data or financial information.';
  } else if (ctx.userType === 'full') {
    system += `\n\nThe logged-in user is ${ctx.userName} (Member ID: ${ctx.userId}, Tier: ${ctx.memberTier}).`;
    system += ' This user has ADMINISTRATIVE access.';
    system += ' You can answer questions about viewership metrics, member accounts, pledge data, and station operations.';
    system += ' Provide detailed analytics when asked.';
  }

  const tools: unknown[] = [
    {
      tool_spec: {
        type: 'cortex_search',
        name: 'support_kb',
        description: 'Search the support knowledge base for articles about streaming, membership, programming, technical issues, and station events.',
      },
    },
  ];

  const tool_resources: Record<string, unknown> = {
    support_kb: {
      search_service: 'SNOWFLAKE_EXAMPLE.AGENT_MULTICONTEXT.SUPPORT_KB_SEARCH',
      title_column: 'title',
      id_column: 'article_id',
    },
  };

  if (ctx.userType === 'low' || ctx.userType === 'full') {
    tools.push({
      tool_spec: {
        type: 'cortex_analyst_text_to_sql',
        name: 'viewership_analyst',
        description: 'Query viewership metrics, ratings, streaming data, and programming schedules across stations.',
      },
    });
    tool_resources.viewership_analyst = {
      semantic_view: 'SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS.SV_AGENT_MULTICONTEXT_VIEWERSHIP',
      execution_environment: {
        type: 'warehouse',
        warehouse: 'SFE_AGENT_MULTICONTEXT_WH',
        query_timeout: 60,
      },
    };
  }

  let orchestration = 'Only use the knowledge base search tool. Do not use the analyst tool.';
  if (ctx.userType === 'low') {
    orchestration = 'Use the knowledge base for support questions. Use the analyst tool for viewership and programming questions.';
  } else if (ctx.userType === 'full') {
    orchestration = 'Use all available tools. Prefer the analyst tool for data questions and the knowledge base for support/policy questions.';
  }

  const role = ctx.userType === 'full' ? 'TV_ADMIN_ROLE'
    : ctx.userType === 'low' ? 'TV_VIEWER_ROLE'
    : undefined;

  return {
    endpoint: 'POST /api/v2/cortex/agent:run',
    headers: {
      Authorization: 'Bearer <token>',
      'Content-Type': 'application/json',
      ...(role ? { 'X-Snowflake-Role': role } : {}),
    },
    body: {
      thread_id: '<thread_id>',
      parent_message_id: 0,
      messages: [
        { role: 'user', content: [{ type: 'text', text: message || '(your message here)' }] },
      ],
      models: { orchestration: 'auto' },
      orchestration: { budget: { seconds: 30, tokens: 16000 } },
      instructions: {
        system,
        response: ctx.userType === 'anonymous'
          ? 'Be friendly and helpful. Format responses with markdown when useful. Keep answers concise since the user is browsing without an account.'
          : 'Be friendly and helpful. Format responses with markdown when useful.',
        orchestration,
      },
      tools,
      tool_resources,
    },
  };
}
