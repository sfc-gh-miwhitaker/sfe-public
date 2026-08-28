import { getOverviewKpis, getDailySpend } from "../lib/snowflake";
import { KpiCard } from "../components/KpiCard";
import { OverviewCharts } from "./OverviewCharts";

export default async function OverviewPage() {
  const [kpis, dailySpend] = await Promise.all([
    getOverviewKpis(),
    getDailySpend(30),
  ]);

  // Aggregate daily totals for the line chart
  const dailyTotals = Object.values(
    dailySpend.reduce<Record<string, { date: string; credits: number }>>((acc, row) => {
      const date = row.USAGE_DATE;
      if (!acc[date]) acc[date] = { date, credits: 0 };
      acc[date].credits += row.TOTAL_CREDITS;
      return acc;
    }, {})
  ).sort((a, b) => a.date.localeCompare(b.date));

  // 7-day moving average
  const withMovingAvg = dailyTotals.map((d, i) => {
    if (i < 6) return { ...d, movingAvg: undefined };
    const window = dailyTotals.slice(i - 6, i + 1);
    const avg = window.reduce((s, w) => s + w.credits, 0) / 7;
    return { ...d, movingAvg: avg };
  });

  // By-service stacked data
  const serviceTypes = [...new Set(dailySpend.map((r) => r.SERVICE_TYPE))];
  const byServiceMap: Record<string, Record<string, number>> = {};
  for (const row of dailySpend) {
    if (!byServiceMap[row.USAGE_DATE]) byServiceMap[row.USAGE_DATE] = { date: row.USAGE_DATE } as unknown as Record<string, number>;
    (byServiceMap[row.USAGE_DATE] as Record<string, unknown>)["date"] = row.USAGE_DATE;
    byServiceMap[row.USAGE_DATE][row.SERVICE_TYPE] = row.TOTAL_CREDITS;
  }
  const byServiceData = Object.values(byServiceMap).sort((a, b) =>
    String(a.date).localeCompare(String(b.date))
  );

  return (
    <>
      <div className="kpi-grid">
        <KpiCard label="Total AI Credits (30d)" value={kpis.totalCredits} />
        <KpiCard label="Daily Average" value={kpis.dailyAvg} subtitle="credits/day" />
        <KpiCard label="Unique Users" value={kpis.uniqueUsers} />
        <KpiCard label="Active Days" value={kpis.activeDays} subtitle="of last 30" />
      </div>
      <OverviewCharts
        dailyData={withMovingAvg}
        serviceData={byServiceData}
        serviceTypes={serviceTypes}
      />
    </>
  );
}
