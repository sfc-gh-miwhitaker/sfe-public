import { querySnowflake } from "@/lib/snowflake"
import { DB_SCHEMA } from "@/lib/constants"

export const dynamic = "force-dynamic"

export async function GET() {
  try {
    const shows = await querySnowflake(`
      SELECT show_name, venue_city, show_date, days_until_show, momentum_score, momentum_label
      FROM ${DB_SCHEMA}.V_SHOW_MOMENTUM
      ORDER BY show_date
    `)

    return Response.json({ shows })
  } catch (e) {
    console.error(new Date().toISOString(), "[momentum]", e)
    return Response.json(
      { error: e instanceof Error ? e.message : "Failed to fetch momentum" },
      { status: 500 }
    )
  }
}
