import { querySnowflake } from "@/lib/snowflake"
import { DB_SCHEMA } from "@/lib/constants"

export const dynamic = "force-dynamic"

export async function GET(request: Request) {
  const { searchParams } = new URL(request.url)
  const days = parseInt(searchParams.get("days") || "30", 10)

  try {
    const [daily, rolling] = await Promise.all([
      querySnowflake(`
        SELECT income_date, stream_royalties, merch_estimate, sync_licensing, total_income
        FROM ${DB_SCHEMA}.FACT_INCOME
        WHERE income_date >= DATEADD('day', -${days}, CURRENT_DATE())
        ORDER BY income_date
      `),
      querySnowflake(`
        SELECT income_date, rolling_30d_income
        FROM ${DB_SCHEMA}.V_INCOME_KPI
        WHERE income_date >= DATEADD('day', -${days}, CURRENT_DATE())
        ORDER BY income_date
      `),
    ])

    return Response.json({ daily, rolling })
  } catch (e) {
    console.error(new Date().toISOString(), "[income]", e)
    return Response.json(
      { error: e instanceof Error ? e.message : "Failed to fetch income" },
      { status: 500 }
    )
  }
}
