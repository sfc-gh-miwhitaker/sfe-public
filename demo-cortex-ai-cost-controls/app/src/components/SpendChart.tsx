"use client";

import {
  LineChart,
  Line,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  Legend,
} from "recharts";

interface SpendChartProps {
  data: { date: string; credits: number; movingAvg?: number }[];
  title?: string;
}

export function SpendChart({ data, title }: SpendChartProps) {
  return (
    <div className="chart-container">
      {title && <h3>{title}</h3>}
      <ResponsiveContainer width="100%" height={300}>
        <LineChart data={data} margin={{ top: 5, right: 30, left: 20, bottom: 5 }}>
          <CartesianGrid strokeDasharray="3 3" stroke="#374151" />
          <XAxis dataKey="date" stroke="#9CA3AF" fontSize={12} />
          <YAxis stroke="#9CA3AF" fontSize={12} />
          <Tooltip
            contentStyle={{ backgroundColor: "#1F2937", border: "1px solid #374151" }}
            labelStyle={{ color: "#F9FAFB" }}
          />
          <Legend />
          <Line type="monotone" dataKey="credits" stroke="#3B82F6" strokeWidth={2} dot={false} name="Daily Credits" />
          {data.some((d) => d.movingAvg !== undefined) && (
            <Line type="monotone" dataKey="movingAvg" stroke="#F59E0B" strokeWidth={2} strokeDasharray="5 5" dot={false} name="7-day Avg" />
          )}
        </LineChart>
      </ResponsiveContainer>
    </div>
  );
}
