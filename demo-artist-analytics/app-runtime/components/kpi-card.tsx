"use client"

interface KpiCardProps {
  label: string
  value: string | number
  subvalue?: string
  trend?: "up" | "down" | "neutral"
}

function formatNumber(val: string | number): string {
  const n = typeof val === "string" ? parseFloat(val) : val
  if (isNaN(n)) return String(val)
  if (n >= 1_000_000) return `${(n / 1_000_000).toFixed(1)}M`
  if (n >= 1_000) return `${(n / 1_000).toFixed(1)}K`
  return n.toFixed(n % 1 === 0 ? 0 : 1)
}

export function KpiCard({ label, value, subvalue }: KpiCardProps) {
  return (
    <div className="rounded-xl bg-card border border-border p-5">
      <p className="text-xs font-medium text-muted-foreground uppercase tracking-wider">{label}</p>
      <p className="mt-2 text-2xl font-bold text-foreground">{formatNumber(value)}</p>
      {subvalue && <p className="mt-1 text-xs text-muted-foreground">{subvalue}</p>}
    </div>
  )
}
