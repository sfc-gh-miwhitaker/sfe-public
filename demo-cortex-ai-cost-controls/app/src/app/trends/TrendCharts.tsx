"use client";

import {
  AreaChart,
  Area,
  Line,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  Legend,
} from "recharts";
import { BarBreakdown } from "@/components/BarBreakdown";
import { DataTable } from "@/components/DataTable";

interface TrendChartsProps {
  dailyData: { date: string; credits: number; movingAvg?: number; threshold?: number }[];
  anomalies: { date: string; credits: number; threshold: number; overshoot: string }[];
  wowData: { service: string; thisWeek: number; lastWeek: number }[];
}

export function TrendCharts({ dailyData, anomalies, wowData }: TrendChartsProps) {
  return (
    <>
      <div className="chart-container">
        <h3>Daily Spend with Anomaly Threshold</h3>
        <ResponsiveContainer width="100%" height={350}>
          <AreaChart data={dailyData} margin={{ top: 5, right: 30, left: 20, bottom: 5 }}>
            <CartesianGrid strokeDasharray="3 3" stroke="#374151" />
            <XAxis dataKey="date" stroke="#9CA3AF" fontSize={11} />
            <YAxis stroke="#9CA3AF" fontSize={12} />
            <Tooltip
              contentStyle={{ backgroundColor: "#1F2937", border: "1px solid #374151" }}
              labelStyle={{ color: "#F9FAFB" }}
            />
            <Legend />
            <Area type="monotone" dataKey="credits" stroke="#3B82F6" fill="#3B82F6" fillOpacity={0.2} name="Daily Credits" />
            <Line type="monotone" dataKey="movingAvg" stroke="#F59E0B" strokeWidth={2} dot={false} name="7-day Avg" />
            <Line type="monotone" dataKey="threshold" stroke="#EF4444" strokeWidth={1} strokeDasharray="4 4" dot={false} name="Anomaly Threshold (2x)" />
          </AreaChart>
        </ResponsiveContainer>
      </div>

      <div className="grid-2">
        <DataTable
          title="Anomaly Days (Actual > 2x Moving Avg)"
          columns={[
            { key: "date", label: "Date" },
            { key: "credits", label: "Actual Credits", align: "right" },
            { key: "threshold", label: "Threshold", align: "right" },
            { key: "overshoot", label: "Overshoot", align: "right" },
          ]}
          rows={anomalies}
        />

        <BarBreakdown
          data={wowData as unknown as Record<string, string | number>[]}
          xKey="service"
          bars={[
            { dataKey: "thisWeek", color: "#3B82F6", name: "This Week" },
            { dataKey: "lastWeek", color: "#6B7280", name: "Last Week" },
          ]}
          title="Week-over-Week by Service"
        />
      </div>
    </>
  );
}
