import { getQuotaStatus } from "@/lib/snowflake";
import { KpiCard } from "@/components/KpiCard";
import { DataTable } from "@/components/DataTable";

export default async function QuotasPage() {
  const quotas = await getQuotaStatus();

  const totalBlocked = quotas.reduce((s, q) => s + q.BLOCKED_USERS, 0);
  const totalMonitored = quotas.reduce((s, q) => s + q.TOTAL_USERS, 0);
  const avgUtilization = quotas.length > 0
    ? quotas.reduce((s, q) => s + (q.BLOCKED_USERS / Math.max(q.TOTAL_USERS, 1)), 0) / quotas.length * 100
    : 0;

  if (quotas.length === 0) {
    return (
      <>
        <h2 className="section-title">Quota Status</h2>
        <div className="empty-state">
          <p>No per-user quotas are configured in this account.</p>
          <p style={{ marginTop: "8px", fontSize: "0.875rem" }}>
            Run <code>sql/03_quota_example/01_quota_setup.sql</code> to create a sample quota,
            or configure quotas in Snowsight under Admin &gt; Cost Management &gt; Budgets.
          </p>
        </div>
      </>
    );
  }

  return (
    <>
      <h2 className="section-title">Quota Status</h2>
      <div className="kpi-grid">
        <KpiCard label="Users Blocked" value={totalBlocked} subtitle="across all quotas" />
        <KpiCard label="Users Monitored" value={totalMonitored} />
        <KpiCard label="Avg Block Rate" value={`${avgUtilization.toFixed(1)}%`} />
        <KpiCard label="Active Quotas" value={quotas.length} />
      </div>

      <DataTable
        title="Quota Configuration"
        columns={[
          { key: "QUOTA_NAME", label: "Quota" },
          { key: "PER_USER_LIMIT", label: "Monthly Limit", align: "right" },
          { key: "DAILY_LIMIT", label: "Daily Limit", align: "right" },
          { key: "BLOCK_ENFORCEMENT", label: "Block Enabled" },
          { key: "TOTAL_USERS", label: "Users in Scope", align: "right" },
          { key: "BLOCKED_USERS", label: "Users Blocked", align: "right" },
        ]}
        rows={quotas.map((q) => ({
          ...q,
          BLOCK_ENFORCEMENT: q.BLOCK_ENFORCEMENT ? "Yes" : "No",
          DAILY_LIMIT: q.DAILY_LIMIT ?? "—",
        }))}
      />

      <div className="empty-state" style={{ marginTop: "16px", padding: "24px" }}>
        <p style={{ fontSize: "0.875rem" }}>
          To modify quotas, use Snowsight (Admin &gt; Cost Management &gt; Budgets) or SQL quota methods.
          This dashboard is read-only.
        </p>
      </div>
    </>
  );
}
