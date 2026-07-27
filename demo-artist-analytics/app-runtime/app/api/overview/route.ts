import { querySnowflake } from "@/lib/snowflake"
import { DB_SCHEMA } from "@/lib/constants"

export const dynamic = "force-dynamic"

export async function GET(request: Request) {
  const { searchParams } = new URL(request.url)
  const days = parseInt(searchParams.get("days") || "30", 10)

  try {
    const [streams, impressions, income, momentum] = await Promise.all([
      querySnowflake(`
        SELECT SUM(streams) AS total_streams, SUM(saves) AS total_saves, SUM(listeners) AS total_listeners
        FROM ${DB_SCHEMA}.FACT_DAILY_STREAMS
        WHERE stream_date >= DATEADD('day', -${days}, CURRENT_DATE())
      `),
      querySnowflake(`
        SELECT SUM(impressions) AS total_impressions, SUM(engagements) AS total_engagements
        FROM ${DB_SCHEMA}.FACT_SOCIAL_METRICS
        WHERE metric_date >= DATEADD('day', -${days}, CURRENT_DATE())
      `),
      querySnowflake(`
        SELECT SUM(total_income) AS total_income
        FROM ${DB_SCHEMA}.FACT_INCOME
        WHERE income_date >= DATEADD('day', -${days}, CURRENT_DATE())
      `),
      querySnowflake(`
        SELECT AVG(momentum_score) AS avg_momentum
        FROM ${DB_SCHEMA}.V_SHOW_MOMENTUM
      `),
    ])

    return Response.json({
      totalStreams: streams[0]?.TOTAL_STREAMS ?? 0,
      totalSaves: streams[0]?.TOTAL_SAVES ?? 0,
      totalListeners: streams[0]?.TOTAL_LISTENERS ?? 0,
      totalImpressions: impressions[0]?.TOTAL_IMPRESSIONS ?? 0,
      totalEngagements: impressions[0]?.TOTAL_ENGAGEMENTS ?? 0,
      totalIncome: income[0]?.TOTAL_INCOME ?? 0,
      avgMomentum: momentum[0]?.AVG_MOMENTUM ?? 0,
    })
  } catch (e) {
    console.error(new Date().toISOString(), "[overview]", e)
    return Response.json(
      { error: e instanceof Error ? e.message : "Failed to fetch overview" },
      { status: 500 }
    )
  }
}
