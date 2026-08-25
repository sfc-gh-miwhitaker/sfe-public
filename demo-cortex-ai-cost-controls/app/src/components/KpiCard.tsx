interface KpiCardProps {
  label: string;
  value: string | number;
  subtitle?: string;
}

export function KpiCard({ label, value, subtitle }: KpiCardProps) {
  return (
    <div className="kpi-card">
      <div className="kpi-label">{label}</div>
      <div className="kpi-value">{typeof value === "number" ? value.toLocaleString(undefined, { maximumFractionDigits: 1 }) : value}</div>
      {subtitle && <div className="kpi-subtitle">{subtitle}</div>}
    </div>
  );
}
