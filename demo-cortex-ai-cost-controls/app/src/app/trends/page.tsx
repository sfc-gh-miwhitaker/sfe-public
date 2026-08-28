import { getTrendData } from "../../lib/snowflake";
import { TrendCharts } from "./TrendCharts";

export default async function TrendsPage() {
  const rawData = await getTrendData(90);

  // Aggregate daily totals
  const dailyMap: Record<string, number> = {};
  for (const row of rawData) {
    dailyMap[row.USAGE_DATE] = (dailyMap[row.USAGE_DATE] ?? 0) + row.TOTAL_CREDITS;
  }
  const dailyTotals = Object.entries(dailyMap)
    .map(([date, credits]) => ({ date, credits }))
    .sort((a, b) => a.date.localeCompare(b.date));

  // 7-day moving average + projected threshold (2x avg as anomaly line)
  const withAnalysis = dailyTotals.map((d, i) => {
    if (i < 6) return { ...d, movingAvg: undefined, threshold: undefined };
    const window = dailyTotals.slice(i - 6, i + 1);
    const avg = window.reduce((s, w) => s + w.credits, 0) / 7;
    return { ...d, movingAvg: avg, threshold: avg * 2 };
  });

  // Anomaly days: actual > 2x moving average
  const anomalies = withAnalysis
    .filter((d) => d.threshold !== undefined && d.credits > (d.threshold ?? Infinity))
    .map((d) => ({
      date: d.date,
      credits: d.credits,
      threshold: d.threshold!,
      overshoot: `${(((d.credits - d.threshold!) / d.threshold!) * 100).toFixed(0)}%`,
    }));

  // Week-over-week by service
  const serviceTypes = [...new Set(rawData.map((r) => r.SERVICE_TYPE))];
  const thisWeek: Record<string, number> = {};
  const lastWeek: Record<string, number> = {};
  const today = new Date();
  for (const row of rawData) {
    const rowDate = new Date(row.USAGE_DATE);
    const daysAgo = Math.floor((today.getTime() - rowDate.getTime()) / 86400000);
    if (daysAgo < 7) {
      thisWeek[row.SERVICE_TYPE] = (thisWeek[row.SERVICE_TYPE] ?? 0) + row.TOTAL_CREDITS;
    } else if (daysAgo < 14) {
      lastWeek[row.SERVICE_TYPE] = (lastWeek[row.SERVICE_TYPE] ?? 0) + row.TOTAL_CREDITS;
    }
  }
  const wowData = serviceTypes.map((st) => ({
    service: st.replace(/_/g, " "),
    thisWeek: thisWeek[st] ?? 0,
    lastWeek: lastWeek[st] ?? 0,
  }));

  return (
    <>
      <h2 className="section-title">Trends (90d)</h2>
      <TrendCharts dailyData={withAnalysis} anomalies={anomalies} wowData={wowData} />
    </>
  );
}
