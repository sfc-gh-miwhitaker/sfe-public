"use client"

import { useEffect, useState } from "react"
import { KpiCard } from "@/components/kpi-card"
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer } from "recharts"

interface OverviewData {
  totalStreams: number
  totalImpressions: number
  totalIncome: number
  avgMomentum: number
}

interface ShowRow {
  SHOW_NAME: string
  VENUE_CITY: string
  SHOW_DATE: string
  DAYS_UNTIL_SHOW: number
  MOMENTUM_SCORE: number
  MOMENTUM_LABEL: string
}

export function OverviewTab({ days }: { days: number }) {
  const [data, setData] = useState<OverviewData | null>(null)
  const [shows, setShows] = useState<ShowRow[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    setLoading(true)
    Promise.all([
      fetch(`/api/overview?days=${days}`).then((r) => r.json()),
      fetch("/api/momentum").then((r) => r.json()),
    ]).then(([overview, momentum]) => {
      setData(overview)
      setShows(momentum.shows ?? [])
      setLoading(false)
    })
  }, [days])

  if (loading) return <LoadingSkeleton />

  if (!data) return null

  return (
    <div className="space-y-6">
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        <KpiCard label="Total Streams" value={data.totalStreams} subvalue={`Last ${days} days`} />
        <KpiCard label="Impressions" value={data.totalImpressions} subvalue={`Last ${days} days`} />
        <KpiCard label="Revenue" value={`$${(data.totalIncome / 100).toFixed(0)}`} subvalue={`Last ${days} days`} />
        <KpiCard label="Avg Momentum" value={data.avgMomentum != null ? data.avgMomentum.toFixed(1) : "—"} subvalue="Upcoming shows" />
      </div>

      {shows.length > 0 && (
        <div className="rounded-xl bg-card border border-border p-5">
          <h3 className="text-sm font-medium text-foreground mb-4">Upcoming Shows</h3>
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="text-left text-muted-foreground text-xs uppercase tracking-wider border-b border-border">
                  <th className="pb-3 pr-4">Show</th>
                  <th className="pb-3 pr-4">City</th>
                  <th className="pb-3 pr-4">Date</th>
                  <th className="pb-3 pr-4 text-right">Days Out</th>
                  <th className="pb-3 text-right">Momentum</th>
                </tr>
              </thead>
              <tbody>
                {shows.map((show) => (
                  <tr key={show.SHOW_NAME} className="border-b border-border/50 last:border-0">
                    <td className="py-3 pr-4 font-medium text-foreground">{show.SHOW_NAME}</td>
                    <td className="py-3 pr-4 text-muted-foreground">{show.VENUE_CITY}</td>
                    <td className="py-3 pr-4 text-muted-foreground">{new Date(show.SHOW_DATE).toLocaleDateString()}</td>
                    <td className="py-3 pr-4 text-right text-muted-foreground">{show.DAYS_UNTIL_SHOW}</td>
                    <td className="py-3 text-right">
                      <MomentumBadge score={show.MOMENTUM_SCORE} label={show.MOMENTUM_LABEL} />
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}
    </div>
  )
}

function MomentumBadge({ score, label }: { score: number; label: string }) {
  const color = score >= 120 ? "text-green-400" : score >= 80 ? "text-amber-400" : "text-red-400"
  return (
    <span className={`font-semibold ${color}`}>
      {score.toFixed(0)} <span className="text-xs font-normal text-muted-foreground">{label}</span>
    </span>
  )
}

function LoadingSkeleton() {
  return (
    <div className="space-y-6">
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        {[...Array(4)].map((_, i) => (
          <div key={i} className="rounded-xl bg-card border border-border p-5 h-24 animate-pulse" />
        ))}
      </div>
      <div className="rounded-xl bg-card border border-border p-5 h-64 animate-pulse" />
    </div>
  )
}
