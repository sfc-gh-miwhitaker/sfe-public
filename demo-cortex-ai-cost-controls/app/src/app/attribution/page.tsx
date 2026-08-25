import { getSpendByUser, getAgentAttribution } from "@/lib/snowflake";
import { DataTable } from "@/components/DataTable";
import { AttributionCharts } from "./AttributionCharts";

export default async function AttributionPage() {
  const [users, agents] = await Promise.all([
    getSpendByUser(),
    getAgentAttribution(),
  ]);

  // Aggregate per user across service types for the bar chart
  const userTotals = Object.values(
    users.reduce<Record<string, { user: string; credits: number }>>((acc, r) => {
      const key = r.USER_NAME ?? String(r.USER_ID);
      if (!acc[key]) acc[key] = { user: key, credits: 0 };
      acc[key].credits += r.TOTAL_CREDITS;
      return acc;
    }, {})
  )
    .sort((a, b) => b.credits - a.credits)
    .slice(0, 10);

  // Extract cost-center from USER_TAGS for table display
  const userRows = users.map((r) => {
    let costCenter = "—";
    if (Array.isArray(r.USER_TAGS)) {
      const tag = (r.USER_TAGS as { tag_name: string; tag_value: string }[]).find(
        (t) => t.tag_name?.toLowerCase() === "cost-center"
      );
      if (tag) costCenter = tag.tag_value;
    }
    return {
      USER_NAME: r.USER_NAME ?? String(r.USER_ID),
      SERVICE_TYPE: r.SERVICE_TYPE,
      TOTAL_CREDITS: r.TOTAL_CREDITS,
      REQUEST_COUNT: r.REQUEST_COUNT,
      COST_CENTER: costCenter,
    };
  });

  return (
    <>
      <h2 className="section-title">Attribution</h2>
      <AttributionCharts userTotals={userTotals} />

      <DataTable
        title="User Spend Breakdown (30d)"
        columns={[
          { key: "USER_NAME", label: "User" },
          { key: "SERVICE_TYPE", label: "Service" },
          { key: "TOTAL_CREDITS", label: "Credits", align: "right" },
          { key: "REQUEST_COUNT", label: "Requests", align: "right" },
          { key: "COST_CENTER", label: "Cost Center" },
        ]}
        rows={userRows}
      />

      <DataTable
        title="Agent Attribution (30d)"
        columns={[
          { key: "AGENT_NAME", label: "Agent" },
          { key: "AGENT_DATABASE_NAME", label: "Database" },
          { key: "COST_CENTER_TAG", label: "Cost Center" },
          { key: "TOTAL_CREDITS", label: "Token Credits", align: "right" },
          { key: "SQL_QUERY_CREDITS", label: "SQL Credits", align: "right" },
          { key: "REQUEST_COUNT", label: "Requests", align: "right" },
          { key: "INTERACTION_INTERFACE", label: "Interface" },
        ]}
        rows={agents}
      />
    </>
  );
}
