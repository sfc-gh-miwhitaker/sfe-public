"use client";

import { SpendChart } from "../components/SpendChart";
import { BarBreakdown } from "../components/BarBreakdown";

const SERVICE_COLORS: Record<string, string> = {
  AI_FUNCTION: "#3B82F6",
  CORTEX_AGENT: "#10B981",
  SNOWFLAKE_COWORK: "#F59E0B",
  CORTEX_CODE: "#8B5CF6",
};

interface OverviewChartsProps {
  dailyData: { date: string; credits: number; movingAvg?: number }[];
  serviceData: Record<string, unknown>[];
  serviceTypes: string[];
}

export function OverviewCharts({ dailyData, serviceData, serviceTypes }: OverviewChartsProps) {
  const bars = serviceTypes.map((st) => ({
    dataKey: st,
    color: SERVICE_COLORS[st] ?? "#6B7280",
    name: st.replace(/_/g, " "),
  }));

  return (
    <div className="grid-2">
      <SpendChart data={dailyData} title="Daily AI Credit Spend (30d)" />
      <BarBreakdown
        data={serviceData as Record<string, string | number>[]}
        xKey="date"
        bars={bars}
        title="Credits by Service Type"
        stacked
      />
    </div>
  );
}
