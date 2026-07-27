import { querySnowflake } from "@/lib/snowflake"
import { DB_SCHEMA } from "@/lib/constants"

export const dynamic = "force-dynamic"

export async function GET(request: Request) {
  const { searchParams } = new URL(request.url)
  const days = parseInt(searchParams.get("days") || "30", 10)

  try {
    const [daily, byPlatform] = await Promise.all([
      querySnowflake(`
        SELECT fds.stream_date, dp.platform_name, SUM(fds.streams) AS streams
        FROM ${DB_SCHEMA}.FACT_DAILY_STREAMS fds
        JOIN ${DB_SCHEMA}.DIM_PLATFORM dp ON dp.platform_id = fds.platform_id
        WHERE fds.stream_date >= DATEADD('day', -${days}, CURRENT_DATE())
        GROUP BY fds.stream_date, dp.platform_name
        ORDER BY fds.stream_date
      `),
      querySnowflake(`
        SELECT dp.platform_name, SUM(fds.streams) AS total_streams, SUM(fds.saves) AS total_saves, SUM(fds.listeners) AS total_listeners
        FROM ${DB_SCHEMA}.FACT_DAILY_STREAMS fds
        JOIN ${DB_SCHEMA}.DIM_PLATFORM dp ON dp.platform_id = fds.platform_id
        WHERE fds.stream_date >= DATEADD('day', -${days}, CURRENT_DATE())
        GROUP BY dp.platform_name
        ORDER BY total_streams DESC
      `),
    ])

    return Response.json({ daily, byPlatform })
  } catch (e) {
    console.error(new Date().toISOString(), "[streams]", e)
    return Response.json(
      { error: e instanceof Error ? e.message : "Failed to fetch streams" },
      { status: 500 }
    )
  }
}
