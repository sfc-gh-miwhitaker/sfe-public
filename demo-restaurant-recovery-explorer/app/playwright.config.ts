// Pair-programmed by SE Community + Cortex Code
import { defineConfig } from "@playwright/test";

export default defineConfig({
  testDir: "./tests/browser",
  workers: 1,
  use: { baseURL: "http://127.0.0.1:3217", channel: "chrome", headless: true },
  webServer: {
    command: "npm run dev -- --port 3217",
    url: "http://127.0.0.1:3217",
    reuseExistingServer: !process.env.CI,
    timeout: 120000,
  },
});
