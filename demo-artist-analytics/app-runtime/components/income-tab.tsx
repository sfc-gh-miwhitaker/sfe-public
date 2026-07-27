"use client"

import { useEffect, useState } from "react"
import { KpiCard } from "@/components/kpi-card"
import { AreaChart, Area, LineChart, Line, XAxis, YAxis, Tooltip, ResponsiveContainer } from "recharts"

interface DailyRow {
  INCOME_DATE: string
  STREAM_ROYALTIES: number
  MERCH_ESTIMATE: number
  SYNC_LICENSING: number
  TOTAL_INCOME: number
}

interface RollingRow {
  INCOME_DATE: string
  ROLLING_30D_INCOME: number
}

export function IncomeTab({ days }: { days: number }) {
  const [daily, setDaily] = useState<DailyRow[]>([])
  const [rolling, setRolling] = useState<RollingRow[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    setLoading(true)
    fetch(`/api/income?days=${days}`)
      .then((r) => r.json())
      .then((d) => {
        setDaily(d.daily ?? [])
        setRolling(d.rolling ?? [])
        setLoading(false)
      })
  }, [days])

  if (loading) return <div className="h-96 animate-pulse rounded-xl bg-card border border-border" />

  const totalRoyalties = daily.reduce((a, b) => a + (b.STREAM_ROYALTIES || 0), 0)
  const totalMerch = daily.reduce((a, b) => a + (b.MERCH_ESTIMATE || 0), 0)
  const totalSync = daily.reduce((a, b) => a + (b.SYNC_LICENSING || 0), 0)
  const totalIncome = daily.reduce((a, b) => a + (b.TOTAL_INCOME || 0), 0)

  const areaData = daily.map((d) => ({
    date: new Date(d.INCOME_DATE).toLocaleDateString("en-US", { month: "short", day: "numeric" }),
    Royalties: d.STREAM_ROYALTIES || 0,
    Merch: d.MERCH_ESTIMATE || 0,
    Sync: d.SYNC_LICENSING || 0,
  }))

  const rollingData = rolling.map((d) => ({
    date: new Date(d.INCOME_DATE).toLocaleDateString("en-US", { month: "short", day: "numeric" }),
    rolling: d.ROLLING_30D_INCOME || 0,
  }))

  return (
    <div className="space-y-6">
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        <KpiCard label="Streaming Royalties" value={`$${(totalRoyalties / 100).toFixed(0)}`} subvalue={`Last ${days} days`} />
        <KpiCard label="Merch" value={`$${(totalMerch / 100).toFixed(0)}`} subvalue={`Last ${days} days`} />
        <KpiCard label="Sync Licensing" value={`$${(totalSync / 100).toFixed(0)}`} subvalue={`Last ${days} days`} />
        <KpiCard label="Total Income" value={`$${(totalIncome / 100).toFixed(0)}`} subvalue={`Last ${days} days`} />
      </div>

      <div className="rounded-xl bg-card border border-border p-5">
        <h3 className="text-sm font-medium text-foreground mb-4">Income Breakdown</h3>
        <ResponsiveContainer width="100%" height={300}>
          <AreaChart data={areaData}>
            <XAxis dataKey="date" tick={{ fill: "#a8a29e", fontSize: 11 }} axisLine={false} tickLine={false} />
            <YAxis tick={{ fill: "#a8a29e", fontSize: 11 }} axisLine={false} tickLine={false} />
            <Tooltip contentStyle={{ background: "#1c1917", border: "1px solid #44403c", borderRadius: 8 }} labelStyle={{ color: "#fafaf9" }} />
            <Area type="monotone" dataKey="Royalties" stackId="1" stroke="#d97706" fill="#d97706" fillOpacity={0.6} />
            <Area type="monotone" dataKey="Merch" stackId="1" stroke="#10b981" fill="#10b981" fillOpacity={0.6} />
            <Area type="monotone" dataKey="Sync" stackId="1" stroke="#8b5cf6" fill="#8b5cf6" fillOpacity={0.6} />
          </AreaChart>
        </ResponsiveContainer>
      </div>

      {rollingData.length > 0 && (
        <div className="rounded-xl bg-card border border-border p-5">
          <h3 className="text-sm font-medium text-foreground mb-4">30-Day Rolling Income</h3>
          <ResponsiveContainer width="100%" height={200}>
            <LineChart data={rollingData}>
              <XAxis dataKey="date" tick={{ fill: "#a8a29e", fontSize: 11 }} axisLine={false} tickLine={false} />
              <YAxis tick={{ fill: "#a8a29e", fontSize: 11 }} axisLine={false} tickLine={false} />
              <Tooltip contentStyle={{ background: "#1c1917", border: "1px solid #44403c", borderRadius: 8 }} labelStyle={{ color: "#fafaf9" }} />
              <Line type="monotone" dataKey="rolling" stroke="#d97706" strokeWidth={2} dot={false} />
            </LineChart>
          </ResponsiveContainer>
        </div>
      )}
    </div>
  )
}
