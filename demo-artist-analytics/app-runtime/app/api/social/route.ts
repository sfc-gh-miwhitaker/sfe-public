import { querySnowflake } from "@/lib/snowflake"
import { DB_SCHEMA } from "@/lib/constants"

export const dynamic = "force-dynamic"

export async function GET(request: Request) {
  const { searchParams } = new URL(request.url)
  const days = parseInt(searchParams.get("days") || "30", 10)

  try {
    const [daily, byPlatform] = await Promise.all([
      querySnowflake(`
        SELECT fsm.metric_date, dsp.platform_name, SUM(fsm.impressions) AS impressions, SUM(fsm.engagements) AS engagements
        FROM ${DB_SCHEMA}.FACT_SOCIAL_METRICS fsm
        JOIN ${DB_SCHEMA}.DIM_SOCIAL_PLATFORM dsp ON dsp.social_platform_id = fsm.social_platform_id
        WHERE fsm.metric_date >= DATEADD('day', -${days}, CURRENT_DATE())
        GROUP BY fsm.metric_date, dsp.platform_name
        ORDER BY fsm.metric_date
      `),
      querySnowflake(`
        SELECT dsp.platform_name, SUM(fsm.impressions) AS total_impressions, SUM(fsm.engagements) AS total_engagements, SUM(fsm.shares) AS total_shares
        FROM ${DB_SCHEMA}.FACT_SOCIAL_METRICS fsm
        JOIN ${DB_SCHEMA}.DIM_SOCIAL_PLATFORM dsp ON dsp.social_platform_id = fsm.social_platform_id
        WHERE fsm.metric_date >= DATEADD('day', -${days}, CURRENT_DATE())
        GROUP BY dsp.platform_name
        ORDER BY total_impressions DESC
      `),
    ])

    return Response.json({ daily, byPlatform })
  } catch (e) {
    console.error(new Date().toISOString(), "[social]", e)
    return Response.json(
      { error: e instanceof Error ? e.message : "Failed to fetch social" },
      { status: 500 }
    )
  }
}
