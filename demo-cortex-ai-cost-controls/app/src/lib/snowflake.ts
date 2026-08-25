import { querySnowflake } from "@snowflake/app-sdk";

const SCHEMA = "SNOWFLAKE_EXAMPLE.CORTEX_AI_COST_CONTROLS";

export interface DailySpend {
  USAGE_DATE: string;
  SERVICE_TYPE: string;
  TOTAL_CREDITS: number;
  TOTAL_TOKENS: number;
  UNIQUE_USERS: number;
}

export interface UserSpend {
  USER_ID: number;
  USER_NAME: string;
  SERVICE_TYPE: string;
  TOTAL_CREDITS: number;
  TOTAL_TOKENS: number;
  REQUEST_COUNT: number;
  USER_TAGS: unknown;
  LAST_SEEN: string;
}

export interface AgentAttribution {
  AGENT_NAME: string;
  AGENT_DATABASE_NAME: string;
  AGENT_SCHEMA_NAME: string;
  COST_CENTER_TAG: string | null;
  TOTAL_CREDITS: number;
  TOTAL_TOKENS: number;
  REQUEST_COUNT: number;
  INTERACTION_INTERFACE: string | null;
  SQL_QUERY_CREDITS: number | null;
}

export interface QuotaStatus {
  QUOTA_NAME: string;
  PER_USER_LIMIT: number;
  DAILY_LIMIT: number | null;
  BLOCK_ENFORCEMENT: boolean;
  TOTAL_USERS: number;
  BLOCKED_USERS: number;
}

export async function getDailySpend(days = 30): Promise<DailySpend[]> {
  const rows = await querySnowflake(`
    SELECT USAGE_DATE, SERVICE_TYPE, TOTAL_CREDITS, TOTAL_TOKENS, UNIQUE_USERS
    FROM ${SCHEMA}.MAT_AI_SPEND_DAILY
    WHERE USAGE_DATE >= DATEADD('day', -${days}, CURRENT_DATE())
    ORDER BY USAGE_DATE
  `);
  return rows as DailySpend[];
}

export async function getSpendByUser(): Promise<UserSpend[]> {
  const rows = await querySnowflake(`
    SELECT USER_ID, USER_NAME, SERVICE_TYPE, TOTAL_CREDITS, TOTAL_TOKENS,
           REQUEST_COUNT, USER_TAGS, LAST_SEEN
    FROM ${SCHEMA}.MAT_AI_SPEND_BY_USER
    ORDER BY TOTAL_CREDITS DESC
  `);
  return rows as UserSpend[];
}

export async function getAgentAttribution(): Promise<AgentAttribution[]> {
  const rows = await querySnowflake(`
    SELECT AGENT_NAME, AGENT_DATABASE_NAME, AGENT_SCHEMA_NAME,
           COST_CENTER_TAG, TOTAL_CREDITS, TOTAL_TOKENS, REQUEST_COUNT,
           INTERACTION_INTERFACE, SQL_QUERY_CREDITS
    FROM ${SCHEMA}.MAT_AGENT_ATTRIBUTION
    ORDER BY TOTAL_CREDITS DESC
  `);
  return rows as AgentAttribution[];
}

export async function getOverviewKpis(): Promise<{
  totalCredits: number;
  dailyAvg: number;
  uniqueUsers: number;
  activeDays: number;
}> {
  const rows = await querySnowflake(`
    SELECT
      SUM(TOTAL_CREDITS) AS total_credits,
      AVG(daily_credits) AS daily_avg,
      SUM(UNIQUE_USERS) AS unique_users,
      COUNT(DISTINCT USAGE_DATE) AS active_days
    FROM (
      SELECT USAGE_DATE, SUM(TOTAL_CREDITS) AS daily_credits, MAX(UNIQUE_USERS) AS UNIQUE_USERS
      FROM ${SCHEMA}.MAT_AI_SPEND_DAILY
      WHERE USAGE_DATE >= DATEADD('day', -30, CURRENT_DATE())
      GROUP BY USAGE_DATE
    )
  `);
  const r = (rows as Record<string, number>[])[0];
  return {
    totalCredits: r?.TOTAL_CREDITS ?? 0,
    dailyAvg: r?.DAILY_AVG ?? 0,
    uniqueUsers: r?.UNIQUE_USERS ?? 0,
    activeDays: r?.ACTIVE_DAYS ?? 0,
  };
}

export async function getQuotaStatus(): Promise<QuotaStatus[]> {
  try {
    const rows = await querySnowflake(`
      SHOW SNOWFLAKE.CORE.QUOTAS IN ACCOUNT
    `);
    // SHOW returns quota metadata; parse into our interface
    return (rows as Record<string, unknown>[]).map((r) => ({
      QUOTA_NAME: String(r.name ?? ""),
      PER_USER_LIMIT: Number(r.per_user_limit ?? 0),
      DAILY_LIMIT: r.daily_limit ? Number(r.daily_limit) : null,
      BLOCK_ENFORCEMENT: Boolean(r.block_enforcement_enabled),
      TOTAL_USERS: Number(r.users_in_scope ?? 0),
      BLOCKED_USERS: Number(r.users_blocked ?? 0),
    }));
  } catch {
    // No quotas configured or insufficient privileges
    return [];
  }
}

export async function getTrendData(days = 90): Promise<DailySpend[]> {
  const rows = await querySnowflake(`
    SELECT USAGE_DATE, SERVICE_TYPE, TOTAL_CREDITS, TOTAL_TOKENS, UNIQUE_USERS
    FROM ${SCHEMA}.MAT_AI_SPEND_DAILY
    WHERE USAGE_DATE >= DATEADD('day', -${days}, CURRENT_DATE())
    ORDER BY USAGE_DATE
  `);
  return rows as DailySpend[];
}
