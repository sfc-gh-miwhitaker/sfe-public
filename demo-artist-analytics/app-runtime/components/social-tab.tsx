"use client"

import { useEffect, useState } from "react"
import { KpiCard } from "@/components/kpi-card"
import { LineChart, Line, XAxis, YAxis, Tooltip, ResponsiveContainer, BarChart, Bar } from "recharts"

interface PlatformRow {
  PLATFORM_NAME: string
  TOTAL_IMPRESSIONS: number
  TOTAL_ENGAGEMENTS: number
  TOTAL_SHARES: number
}

interface DailyRow {
  METRIC_DATE: string
  PLATFORM_NAME: string
  IMPRESSIONS: number
  ENGAGEMENTS: number
}

export function SocialTab({ days }: { days: number }) {
  const [daily, setDaily] = useState<DailyRow[]>([])
  const [byPlatform, setByPlatform] = useState<PlatformRow[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    setLoading(true)
    fetch(`/api/social?days=${days}`)
      .then((r) => r.json())
      .then((d) => {
        setDaily(d.daily ?? [])
        setByPlatform(d.byPlatform ?? [])
        setLoading(false)
      })
  }, [days])

  if (loading) return <div className="h-96 animate-pulse rounded-xl bg-card border border-border" />

  const totalImpressions = byPlatform.reduce((a, b) => a + b.TOTAL_IMPRESSIONS, 0)
  const totalEngagements = byPlatform.reduce((a, b) => a + b.TOTAL_ENGAGEMENTS, 0)
  const totalShares = byPlatform.reduce((a, b) => a + b.TOTAL_SHARES, 0)
  const engagementRate = totalImpressions > 0 ? ((totalEngagements / totalImpressions) * 100).toFixed(2) : "0"

  const platforms = [...new Set(daily.map((d) => d.PLATFORM_NAME))]
  const dates = [...new Set(daily.map((d) => d.METRIC_DATE))].sort()
  const chartData = dates.map((date) => {
    const row: Record<string, any> = { date: new Date(date).toLocaleDateString("en-US", { month: "short", day: "numeric" }) }
    platforms.forEach((p) => {
      const match = daily.find((d) => d.METRIC_DATE === date && d.PLATFORM_NAME === p)
      row[p] = match?.IMPRESSIONS ?? 0
    })
    return row
  })

  const engagementData = byPlatform.map((p) => ({
    ...p,
    ENGAGEMENT_RATE: p.TOTAL_IMPRESSIONS > 0 ? ((p.TOTAL_ENGAGEMENTS / p.TOTAL_IMPRESSIONS) * 100) : 0,
  }))

  const colors = ["#0ea5e9", "#d97706", "#10b981", "#8b5cf6", "#ec4899"]

  return (
    <div className="space-y-6">
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        <KpiCard label="Impressions" value={totalImpressions} subvalue={`Last ${days} days`} />
        <KpiCard label="Engagements" value={totalEngagements} subvalue={`Last ${days} days`} />
        <KpiCard label="Shares" value={totalShares} subvalue={`Last ${days} days`} />
        <KpiCard label="Engagement Rate" value={`${engagementRate}%`} subvalue="Avg across platforms" />
      </div>

      <div className="rounded-xl bg-card border border-border p-5">
        <h3 className="text-sm font-medium text-foreground mb-4">Daily Impressions by Platform</h3>
        <ResponsiveContainer width="100%" height={300}>
          <LineChart data={chartData}>
            <XAxis dataKey="date" tick={{ fill: "#a8a29e", fontSize: 11 }} axisLine={false} tickLine={false} />
            <YAxis tick={{ fill: "#a8a29e", fontSize: 11 }} axisLine={false} tickLine={false} />
            <Tooltip contentStyle={{ background: "#1c1917", border: "1px solid #44403c", borderRadius: 8 }} labelStyle={{ color: "#fafaf9" }} />
            {platforms.map((p, i) => (
              <Line key={p} type="monotone" dataKey={p} stroke={colors[i % colors.length]} strokeWidth={2} dot={false} />
            ))}
          </LineChart>
        </ResponsiveContainer>
      </div>

      <div className="rounded-xl bg-card border border-border p-5">
        <h3 className="text-sm font-medium text-foreground mb-4">Engagement Rate by Platform</h3>
        <ResponsiveContainer width="100%" height={200}>
          <BarChart data={engagementData} layout="vertical">
            <XAxis type="number" tick={{ fill: "#a8a29e", fontSize: 11 }} axisLine={false} tickLine={false} unit="%" />
            <YAxis type="category" dataKey="PLATFORM_NAME" tick={{ fill: "#a8a29e", fontSize: 11 }} axisLine={false} tickLine={false} width={100} />
            <Tooltip contentStyle={{ background: "#1c1917", border: "1px solid #44403c", borderRadius: 8 }} labelStyle={{ color: "#fafaf9" }} formatter={(v: number) => `${v.toFixed(2)}%`} />
            <Bar dataKey="ENGAGEMENT_RATE" fill="#0ea5e9" radius={[0, 4, 4, 0]} />
          </BarChart>
        </ResponsiveContainer>
      </div>
    </div>
  )
}
