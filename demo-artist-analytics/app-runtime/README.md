# Jade Hollow Analytics — App Runtime

Next.js dashboard deployed to Snowflake via Snowpark Container Services.

## Quick Start (Local Dev)

```bash
npm install
npm run dev
```

Opens at http://localhost:3000. Requires data layer deployed first (see parent `deploy_all.sql`).

## Deploy to Snowflake

```bash
snow app deploy
```

Then: **Snowsight → Apps → ARTIST_ANALYTICS**

## Teardown

```bash
snow app teardown
```

## Stack

- Next.js 16 (Turbopack)
- Recharts for visualization
- Tailwind CSS (dark theme, amber/warm brand)
- Snowflake SDK via `lib/snowflake.ts` (auto-detects SPCS vs local dev auth)

## Data Sources

All queries target `SNOWFLAKE_EXAMPLE.ARTIST_ANALYTICS`:

| API Route | Snowflake Source |
|-----------|-----------------|
| `/api/overview` | `FACT_DAILY_STREAMS`, `FACT_SOCIAL_METRICS`, `FACT_INCOME`, `V_SHOW_MOMENTUM` |
| `/api/streams` | `FACT_DAILY_STREAMS` + `DIM_PLATFORM` |
| `/api/social` | `FACT_SOCIAL_METRICS` + `DIM_SOCIAL_PLATFORM` |
| `/api/income` | `FACT_INCOME`, `V_INCOME_KPI` |
| `/api/momentum` | `V_SHOW_MOMENTUM` |
