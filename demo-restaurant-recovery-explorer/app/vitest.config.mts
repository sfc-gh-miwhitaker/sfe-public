// Pair-programmed by SE Community + Cortex Code
import { defineConfig } from "vitest/config";
import path from "node:path";
import { fileURLToPath } from "node:url";

export default defineConfig({
  test: { environment: "node", include: ["tests/**/*.test.ts"] },
  resolve: { alias: { "@": path.dirname(fileURLToPath(import.meta.url)) } },
});
