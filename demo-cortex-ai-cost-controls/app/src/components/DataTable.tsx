interface DataTableProps {
  columns: { key: string; label: string; align?: "left" | "right" }[];
  rows: Record<string, unknown>[];
  title?: string;
}

export function DataTable({ columns, rows, title }: DataTableProps) {
  return (
    <div className="table-container">
      {title && <h3>{title}</h3>}
      <div className="table-scroll">
        <table>
          <thead>
            <tr>
              {columns.map((col) => (
                <th key={col.key} style={{ textAlign: col.align ?? "left" }}>
                  {col.label}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {rows.length === 0 ? (
              <tr>
                <td colSpan={columns.length} style={{ textAlign: "center", color: "#6B7280" }}>
                  No data available
                </td>
              </tr>
            ) : (
              rows.map((row, i) => (
                <tr key={i}>
                  {columns.map((col) => (
                    <td key={col.key} style={{ textAlign: col.align ?? "left" }}>
                      {formatCell(row[col.key])}
                    </td>
                  ))}
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}

function formatCell(value: unknown): string {
  if (value === null || value === undefined) return "—";
  if (typeof value === "number") return value.toLocaleString(undefined, { maximumFractionDigits: 2 });
  return String(value);
}
