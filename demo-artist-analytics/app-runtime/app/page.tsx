"use client"

import { useState } from "react"
import { TabNav } from "@/components/tab-nav"
import { OverviewTab } from "@/components/overview-tab"
import { StreamsTab } from "@/components/streams-tab"
import { SocialTab } from "@/components/social-tab"
import { IncomeTab } from "@/components/income-tab"

export const dynamic = "force-dynamic"

const TABS = [
  { id: "overview", label: "Overview" },
  { id: "streams", label: "Streams" },
  { id: "social", label: "Social" },
  { id: "income", label: "Income" },
]

const PERIODS = [
  { label: "7d", value: 7 },
  { label: "30d", value: 30 },
  { label: "60d", value: 60 },
  { label: "90d", value: 90 },
]

export default function Page() {
  const [activeTab, setActiveTab] = useState("overview")
  const [days, setDays] = useState(30)

  return (
    <main className="w-full max-w-7xl mx-auto px-4 py-6">
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-2xl font-bold text-foreground">Jade Hollow</h1>
          <p className="text-sm text-muted-foreground">Indie Pop &middot; Nashville &middot; Independent</p>
        </div>
        <div className="flex gap-1 rounded-lg bg-secondary p-1">
          {PERIODS.map((p) => (
            <button
              key={p.value}
              onClick={() => setDays(p.value)}
              className={`px-3 py-1.5 text-xs font-medium rounded-md transition-colors ${
                days === p.value ? "bg-card text-foreground shadow-sm" : "text-muted-foreground hover:text-foreground"
              }`}
            >
              {p.label}
            </button>
          ))}
        </div>
      </div>

      <TabNav tabs={TABS} activeTab={activeTab} onTabChange={setActiveTab} />

      <div className="mt-6">
        {activeTab === "overview" && <OverviewTab days={days} />}
        {activeTab === "streams" && <StreamsTab days={days} />}
        {activeTab === "social" && <SocialTab days={days} />}
        {activeTab === "income" && <IncomeTab days={days} />}
      </div>
    </main>
  )
}
