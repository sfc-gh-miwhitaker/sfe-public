"use client"

import { useEffect, useState } from "react"
import { KpiCard } from "@/components/kpi-card"
import { LineChart, Line, XAxis, YAxis, Tooltip, ResponsiveContainer, BarChart, Bar } from "recharts"

interface PlatformRow {
  PLATFORM_NAME: string
  TOTAL_STREAMS: number
  TOTAL_SAVES: number
  TOTAL_LISTENERS: number
}

interface DailyRow {
  STREAM_DATE: string
  PLATFORM_NAME: string
  STREAMS: number
}

export function StreamsTab({ days }: { days: number }) {
  const [daily, setDaily] = useState<DailyRow[]>([])
  const [byPlatform, setByPlatform] = useState<PlatformRow[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    setLoading(true)
    fetch(`/api/streams?days=${days}`)
      .then((r) => r.json())
      .then((d) => {
        setDaily(d.daily ?? [])
        setByPlatform(d.byPlatform ?? [])
        setLoading(false)
      })
  }, [days])

  if (loading) return <div className="h-96 animate-pulse rounded-xl bg-card border border-border" />

  const totalStreams = byPlatform.reduce((a, b) => a + b.TOTAL_STREAMS, 0)
  const totalSaves = byPlatform.reduce((a, b) => a + b.TOTAL_SAVES, 0)
  const totalListeners = byPlatform.reduce((a, b) => a + b.TOTAL_LISTENERS, 0)

  const platforms = [...new Set(daily.map((d) => d.PLATFORM_NAME))]
  const dates = [...new Set(daily.map((d) => d.STREAM_DATE))].sort()
  const chartData = dates.map((date) => {
    const row: Record<string, any> = { date: new Date(date).toLocaleDateString("en-US", { month: "short", day: "numeric" }) }
    platforms.forEach((p) => {
      const match = daily.find((d) => d.STREAM_DATE === date && d.PLATFORM_NAME === p)
      row[p] = match?.STREAMS ?? 0
    })
    return row
  })

  const colors = ["#d97706", "#0ea5e9", "#10b981", "#8b5cf6", "#ec4899"]

  return (
    <div className="space-y-6">
      <div className="grid grid-cols-3 gap-4">
        <KpiCard label="Total Streams" value={totalStreams} subvalue={`Last ${days} days`} />
        <KpiCard label="Saves" value={totalSaves} subvalue={`Last ${days} days`} />
        <KpiCard label="Listeners" value={totalListeners} subvalue={`Last ${days} days`} />
      </div>

      <div className="rounded-xl bg-card border border-border p-5">
        <h3 className="text-sm font-medium text-foreground mb-4">Daily Streams by Platform</h3>
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
        <h3 className="text-sm font-medium text-foreground mb-4">Streams by Platform</h3>
        <ResponsiveContainer width="100%" height={200}>
          <BarChart data={byPlatform} layout="vertical">
            <XAxis type="number" tick={{ fill: "#a8a29e", fontSize: 11 }} axisLine={false} tickLine={false} />
            <YAxis type="category" dataKey="PLATFORM_NAME" tick={{ fill: "#a8a29e", fontSize: 11 }} axisLine={false} tickLine={false} width={100} />
            <Tooltip contentStyle={{ background: "#1c1917", border: "1px solid #44403c", borderRadius: 8 }} labelStyle={{ color: "#fafaf9" }} />
            <Bar dataKey="TOTAL_STREAMS" fill="#d97706" radius={[0, 4, 4, 0]} />
          </BarChart>
        </ResponsiveContainer>
      </div>
    </div>
  )
}
