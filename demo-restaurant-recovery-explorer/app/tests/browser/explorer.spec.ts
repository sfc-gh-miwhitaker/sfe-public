// Pair-programmed by SE Community + Cortex Code
import { expect, test } from "@playwright/test";

test("localized decline: map, peers, evidence, export, invalidation", async ({
  page,
}) => {
  const failures: string[] = [];
  page.on("pageerror", (error) => failures.push(error.message));
  const external: string[] = [];
  page.on("request", (request) => {
    if (!new URL(request.url()).hostname.match(/^(127\.0\.0\.1|localhost)$/))
      external.push(request.url());
  });
  await page.goto("/");
  await expect(
    page.getByRole("heading", { name: "Copper Table", exact: true }),
  ).toBeVisible();
  await page.getByRole("button", { name: "Select Willow Table" }).click();
  await expect(
    page.getByRole("heading", { name: "Willow Table", exact: true }),
  ).toBeVisible();
  await page.getByRole("button", { name: /Copper Table R001/ }).click();
  await expect(
    page.getByRole("button", { name: "Select Copper Table" }),
  ).toHaveAttribute("aria-pressed", "true");
  await page.getByRole("button", { name: "Comparisons", exact: true }).click();
  await expect(
    page.getByText("Descriptive comparison only.", { exact: false }),
  ).toBeVisible();
  await page.getByRole("button", { name: "Action Brief", exact: true }).click();
  await page.getByRole("button", { name: "Generate action brief" }).click();
  await expect(
    page.getByText("Candidate test: breakfast service coverage", {
      exact: true,
    }),
  ).toBeVisible();
  await page.locator(".citation").first().click();
  await expect(page).toHaveURL(/#evidence-/);
  const download = page.waitForEvent("download");
  await page.getByRole("button", { name: "Export Markdown" }).click();
  expect((await download).suggestedFilename()).toMatch(/^recovery-R001-/);
  await page.getByLabel("Daypart", { exact: true }).selectOption("Breakfast");
  await expect(
    page.getByRole("button", { name: "Generate action brief" }),
  ).toBeVisible();
  await expect(page.getByTestId("brief-content")).toHaveCount(0);
  expect(failures).toEqual([]);
  expect(external).toEqual([]);
});

test("market-wide decline does not invent a store-specific cause", async ({
  page,
}) => {
  await page.goto("/?");
  await page
    .getByLabel("Market", { exact: true })
    .selectOption("Juniper Coast");
  await page.getByRole("button", { name: "Select Copper Grill" }).click();
  await expect(
    page.getByRole("heading", { name: "Copper Grill", exact: true }),
  ).toBeVisible();
  await page.getByRole("button", { name: "Action Brief", exact: true }).click();
  await page.getByRole("button", { name: "Generate action brief" }).click();
  await expect(
    page.getByText("Shared decline: investigate broader demand", {
      exact: true,
    }),
  ).toBeVisible();
});

test("no credible peers produces an investigation brief", async ({ page }) => {
  await page.goto("/");
  await page.getByLabel("Market", { exact: true }).selectOption("Cedar Basin");
  await page.getByRole("button", { name: "Select Aspen Terrace" }).click();
  await page.getByRole("button", { name: "Comparisons", exact: true }).click();
  await expect(
    page.getByText("Insufficient comparable peers.", { exact: false }),
  ).toBeVisible();
  await page.getByRole("button", { name: "Action Brief", exact: true }).click();
  await page.getByRole("button", { name: "Generate action brief" }).click();
  await expect(
    page.getByText("Insufficient evidence: investigate before acting", {
      exact: true,
    }),
  ).toBeVisible();
});

test("mobile, keyboard selection, map controls and API validation", async ({
  page,
  request,
}) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto("/");
  const point = page.getByRole("button", { name: "Select Willow Table" });
  await point.focus();
  await page.keyboard.press("Enter");
  await expect(
    page.getByRole("heading", { name: "Willow Table", exact: true }),
  ).toBeVisible();
  await page.getByRole("button", { name: "Zoom in", exact: true }).click();
  await page.getByRole("button", { name: "Reset map" }).click();
  expect(
    await page.evaluate(
      () => document.documentElement.scrollWidth <= window.innerWidth,
    ),
  ).toBe(true);
  expect((await request.get("/api/explore?weeks=0")).status()).toBe(400);
  expect((await request.get("/api/explore?market=Unknown")).status()).toBe(400);
});

test("delayed generation cannot attach a brief to a new selection", async ({
  page,
}) => {
  await page.goto("/");
  await expect(
    page.getByRole("heading", { name: "Copper Table", exact: true }),
  ).toBeVisible();
  await page.route("**/api/brief?**", async (route) => {
    const response = await route.fetch();
    await new Promise((resolve) => setTimeout(resolve, 700));
    await route.fulfill({ response });
  });
  await page.getByRole("button", { name: "Action Brief", exact: true }).click();
  await page.getByRole("button", { name: "Generate action brief" }).click();
  await page.getByRole("button", { name: "Select Willow Table" }).click();
  await expect(
    page.getByRole("heading", { name: "Willow Table", exact: true }),
  ).toBeVisible();
  await page.waitForTimeout(900);
  await expect(page.getByTestId("brief-content")).toHaveCount(0);
});

test("generation errors explain a retry without fake fallback content", async ({
  page,
}) => {
  await page.goto("/");
  await expect(
    page.getByRole("heading", { name: "Copper Table", exact: true }),
  ).toBeVisible();
  await page.route("**/api/brief?**", (route) =>
    route.fulfill({
      status: 500,
      json: { error: "Brief unavailable. Recompute analysis and try again." },
    }),
  );
  await page.getByRole("button", { name: "Action Brief", exact: true }).click();
  await page.getByRole("button", { name: "Generate action brief" }).click();
  await expect(page.locator('.brief [role="alert"]')).toContainText(
    "Recompute analysis",
  );
  await expect(page.getByTestId("brief-content")).toHaveCount(0);
});
