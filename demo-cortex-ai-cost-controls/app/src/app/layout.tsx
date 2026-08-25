import type { Metadata } from "next";
import { Nav } from "@/components/Nav";
import "./globals.css";

export const metadata: Metadata = {
  title: "AI Cost Controls",
  description: "Cortex AI spend attribution, quota status, and trend analysis",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>
        <header className="header">
          <h1>AI Cost Controls</h1>
          <span className="header-subtitle">Cortex AI Spend Dashboard</span>
        </header>
        <Nav />
        <main className="main">{children}</main>
      </body>
    </html>
  );
}
