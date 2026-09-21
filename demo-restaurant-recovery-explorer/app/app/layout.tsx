// Pair-programmed by SE Community + Cortex Code
import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Restaurant Recovery Explorer",
  description:
    "Synthetic restaurant analysis and evidence-backed action planning.",
  icons: { icon: "/icon.svg" },
};
export default function Layout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
