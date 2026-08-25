"use client";

import {
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  Legend,
} from "recharts";

interface BarBreakdownProps {
  data: Record<string, string | number>[];
  xKey: string;
  bars: { dataKey: string; color: string; name?: string }[];
  title?: string;
  stacked?: boolean;
}

export function BarBreakdown({ data, xKey, bars, title, stacked }: BarBreakdownProps) {
  return (
    <div className="chart-container">
      {title && <h3>{title}</h3>}
      <ResponsiveContainer width="100%" height={300}>
        <BarChart data={data} margin={{ top: 5, right: 30, left: 20, bottom: 5 }}>
          <CartesianGrid strokeDasharray="3 3" stroke="#374151" />
          <XAxis dataKey={xKey} stroke="#9CA3AF" fontSize={12} />
          <YAxis stroke="#9CA3AF" fontSize={12} />
          <Tooltip
            contentStyle={{ backgroundColor: "#1F2937", border: "1px solid #374151" }}
            labelStyle={{ color: "#F9FAFB" }}
          />
          <Legend />
          {bars.map((bar) => (
            <Bar
              key={bar.dataKey}
              dataKey={bar.dataKey}
              fill={bar.color}
              name={bar.name ?? bar.dataKey}
              stackId={stacked ? "stack" : undefined}
            />
          ))}
        </BarChart>
      </ResponsiveContainer>
    </div>
  );
}
