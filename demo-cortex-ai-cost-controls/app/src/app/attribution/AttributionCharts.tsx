"use client";

import { BarBreakdown } from "@/components/BarBreakdown";

interface AttributionChartsProps {
  userTotals: { user: string; credits: number }[];
}

export function AttributionCharts({ userTotals }: AttributionChartsProps) {
  return (
    <BarBreakdown
      data={userTotals as unknown as Record<string, string | number>[]}
      xKey="user"
      bars={[{ dataKey: "credits", color: "#3B82F6", name: "Credits" }]}
      title="Top 10 Users by AI Credit Spend (30d)"
    />
  );
}
