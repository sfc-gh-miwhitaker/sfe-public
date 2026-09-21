// Pair-programmed by SE Community + Cortex Code
import { describe, expect, it } from "vitest";
import { generateSynthetic } from "../data/synthetic";
import { validateDataset } from "../contracts/dataset";
import {
  analysisPeriods,
  explore,
  marketAnalysis,
  matchedPeers,
  operationsComparison,
  totalFor,
  type Filters,
} from "../lib/analytics";
import { buildBrief } from "../lib/brief";
import {
  JsonFixtureProvider,
  loadDataset,
  SyntheticProvider,
} from "../lib/provider";
import { parseRequest } from "../lib/request";

const dataset = validateDataset(generateSynthetic());
const filters: Filters = {
  market: "Mesa Vale",
  weeks: 8,
  daypart: "All",
  channel: "All",
};
const restaurant = dataset.restaurants[0];
const result = explore(dataset, "fixture", filters, restaurant.id);

describe("replaceable contracts", () => {
  it("reproduces fixtures and supports an independent JSON adapter", () => {
    expect(
      loadDataset(new JsonFixtureProvider(JSON.stringify(generateSynthetic()))),
    ).toEqual(loadDataset(new SyntheticProvider()));
    expect(generateSynthetic(418).performance).not.toEqual(dataset.performance);
  });
  it("rejects duplicate grains", () => {
    const duplicate = {
      ...dataset,
      performance: [...dataset.performance, dataset.performance[0]],
    };
    expect(() => validateDataset(duplicate)).toThrow(
      "Duplicate performance grain",
    );
  });
  it("rejects bad coordinates and unknown keys", () => {
    expect(() =>
      validateDataset({
        ...dataset,
        restaurants: [{ ...restaurant, latitude: 120 }],
      }),
    ).toThrow("Invalid input contract");
    expect(() =>
      validateDataset({
        ...dataset,
        performance: [{ ...dataset.performance[0], restaurantId: "unknown" }],
      }),
    ).toThrow("Unknown restaurant");
  });
  it("rejects unsupported units and null complete observations", () => {
    expect(() =>
      validateDataset({
        ...dataset,
        metadata: { ...dataset.metadata, guestUnit: "orders" },
      }),
    ).toThrow("Invalid input contract");
    expect(() =>
      validateDataset({
        ...dataset,
        performance: [{ ...dataset.performance[0], guests: null }],
      }),
    ).toThrow("Complete performance");
  });
  it("rejects invalid calendar mappings and gaps", () => {
    expect(() =>
      validateDataset({ ...dataset, calendar: dataset.calendar.slice(1) }),
    ).toThrow();
    expect(() =>
      validateDataset({
        ...dataset,
        calendar: dataset.calendar.filter((_, index) => index !== 10),
      }),
    ).toThrow("contiguous");
  });
  it("validates filter values", () => {
    expect(() => parseRequest("http://localhost/api?weeks=9")).toThrow(
      "Invalid filters",
    );
    expect(() => parseRequest("http://localhost/api?channel=Unknown")).toThrow(
      "Invalid filters",
    );
  });
  it.each([4, 8])(
    "rejects missing final or internal mappings without shifting a %s-week window",
    (weeks) => {
      for (const missing of [103, 101]) {
        const changed = {
          ...dataset,
          calendar: dataset.calendar.map((row, index) =>
            index === missing ? { ...row, baselineWeek: null } : row,
          ),
        };
        expect(() => analysisPeriods(changed, weeks)).toThrow("will not shift");
      }
    },
  );
});

describe("loss attribution", () => {
  it.each(["Mesa Vale", "Juniper Coast", "Cedar Basin", "All"])(
    "reconciles signed contributions in %s",
    (market) => {
      const output = marketAnalysis(dataset, { ...filters, market });
      expect(output.gains - output.grossLoss).toBe(output.change);
      expect(output.bridge.reduce((total, row) => total + row.change, 0)).toBe(
        output.change,
      );
      expect(
        output.stores.reduce((total, row) => total + row.lossShare, 0),
      ).toBeCloseTo(100);
    },
  );
  it("reconciles alternative breakdowns and combined cells", () => {
    for (const rows of [result.dayparts, result.channels, result.cells])
      expect(rows.reduce((total, row) => total + row.change, 0)).toBe(
        result.selected.change,
      );
  });
  it("separates opening, closure, and missing data", () => {
    expect(
      result.market.stores.find((row) => row.restaurant.id === "R014")
        ?.lifecycle,
    ).toBe("Closure");
    expect(
      result.market.stores.find((row) => row.restaurant.id === "R015")
        ?.lifecycle,
    ).toBe("Opening");
    expect(
      result.market.stores.find((row) => row.restaurant.id === "R016")
        ?.excluded,
    ).toBe(12);
  });
  it("treats absent observations as missing rather than zero", () => {
    const changed = {
      ...dataset,
      performance: dataset.performance.filter(
        (row) =>
          !(
            row.restaurantId === restaurant.id && row.week === result.market.end
          ),
      ),
    };
    expect(totalFor(changed, restaurant, filters).excluded).toBe(12);
  });
  it("does not present a wholly unobserved period as zero guest change", () => {
    const changed = {
      ...dataset,
      performance: dataset.performance.filter(
        (row) =>
          !(
            row.restaurantId === restaurant.id &&
            row.week >= result.market.start
          ),
      ),
    };
    expect(() => explore(changed, "missing", filters, restaurant.id)).toThrow(
      "No paired observations",
    );
  });
  it("withholds change rates for zero baselines", () => {
    const opening = dataset.restaurants.find((row) => row.id === "R015")!;
    expect(totalFor(dataset, opening, filters).percent).toBeNull();
  });
  it("does not fan operational hours out across channels", () => {
    const output = operationsComparison(dataset, restaurant, filters);
    expect(output.currentHours).toBe(8 * (35 + 28 + 35 + 14));
    expect(
      operationsComparison(dataset, restaurant, {
        ...filters,
        channel: "Delivery",
      }),
    ).toEqual(output);
  });
  it("retains gaps and rejects incomplete periods from totals", () => {
    const changed = {
      ...dataset,
      calendar: dataset.calendar.map((row) =>
        row.week === result.market.end ? { ...row, complete: false } : row,
      ),
    };
    const output = explore(changed, "incomplete", filters, restaurant.id);
    expect(output.selected.excluded).toBe(12);
    expect(output.peers.trend.at(-1)?.index).toBeNull();
  });
});

describe("peer matching and evidence", () => {
  it("selects reproducible peers using only pre-period features", () => {
    const changed = {
      ...dataset,
      performance: dataset.performance.map((row) =>
        row.week >= result.market.start
          ? { ...row, guests: row.guests === null ? null : row.guests * 3 }
          : row,
      ),
    };
    const original = matchedPeers(dataset, restaurant, filters);
    const modified = matchedPeers(changed, restaurant, filters);
    expect(
      modified.selected.map((row) => [row.restaurant.id, row.score]),
    ).toEqual(original.selected.map((row) => [row.restaurant.id, row.score]));
    expect(
      original.selected.some((row) => row.restaurant.id === restaurant.id),
    ).toBe(false);
    expect(original.selected.length).toBe(5);
  });
  it("withholds comparison for unique format and incomplete outcomes", () => {
    const unique = explore(
      dataset,
      "fixture",
      { ...filters, market: "Cedar Basin" },
      "R048",
    );
    expect(unique.peers.adequate).toBe(false);
    expect(unique.peers.gap).toBeNull();
    const incomplete = explore(dataset, "fixture", filters, "R016");
    expect(incomplete.peers.gap).toBeNull();
  });
  it("does not relabel a future closure as an observed closure", () => {
    const changed = {
      ...dataset,
      restaurants: dataset.restaurants.map((row) =>
        row.id === restaurant.id ? { ...row, closeDate: "2027-01-04" } : row,
      ),
    };
    expect(
      explore(changed, "future-closure", filters, restaurant.id).selected
        .lifecycle,
    ).toBe("Comparable");
  });
  it("includes a closure inside the final week, but not one at its exclusive end", () => {
    for (const [closeDate, expected] of [
      ["2026-09-10", "Closure"],
      ["2026-09-14", "Comparable"],
    ]) {
      const changed = {
        ...dataset,
        restaurants: dataset.restaurants.map((row) =>
          row.id === restaurant.id ? { ...row, closeDate } : row,
        ),
      };
      const output = explore(changed, closeDate, filters, restaurant.id);
      expect(output.selected.lifecycle).toBe(expected);
      if (expected === "Closure") expect(output.peers.gap).toBeNull();
    }
  });
  it("supports localized, shared, insufficient and lifecycle brief outcomes", () => {
    expect(buildBrief(result).status).toContain("breakfast service");
    expect(
      buildBrief(
        explore(
          dataset,
          "fixture",
          { ...filters, market: "Juniper Coast" },
          "R017",
        ),
      ).status,
    ).toContain("Shared decline");
    expect(
      buildBrief(
        explore(
          dataset,
          "fixture",
          { ...filters, market: "Cedar Basin" },
          "R048",
        ),
      ).status,
    ).toContain("Insufficient evidence");
    expect(
      buildBrief(explore(dataset, "fixture", filters, "R014")).status,
    ).toContain("Lifecycle");
    expect(
      buildBrief(explore(dataset, "fixture", filters, "R002")).status,
    ).toContain("No observed");
  });
  it("does not select a staffing action when chronology is missing", () => {
    const output = explore(
      { ...dataset, events: [] },
      "no-event",
      filters,
      restaurant.id,
    );
    expect(buildBrief(output).status).not.toContain("breakfast service");
  });
  it("does not substitute lunch or unrelated labor reductions for breakfast evidence", () => {
    const withoutBreakfastReduction = {
      ...dataset,
      operations: dataset.operations.map((row) =>
        row.restaurantId === restaurant.id && row.daypart === "Breakfast"
          ? { ...row, laborHours: row.openHours! * 3.5 }
          : row,
      ),
    };
    expect(
      buildBrief(
        explore(
          withoutBreakfastReduction,
          "unchanged-breakfast",
          filters,
          restaurant.id,
        ),
      ).status,
    ).not.toContain("breakfast service");
    const lunchEvents = {
      ...dataset,
      events: dataset.events.map((row) =>
        row.id === "E001" ? { ...row, daypart: "Lunch" as const } : row,
      ),
    };
    expect(
      buildBrief(explore(lunchEvents, "lunch-event", filters, restaurant.id))
        .status,
    ).not.toContain("breakfast service");
  });
  it("binds every cited claim to the selected snapshot", () => {
    const brief = buildBrief(result);
    const ids = new Set(brief.evidence.map((row) => row.id));
    for (const section of brief.sections)
      for (const claim of section.claims)
        for (const id of claim.evidenceIds) expect(ids.has(id)).toBe(true);
    expect(brief.markdown).toContain("Synthetic demonstration data");
    expect(brief.markdown).toContain("Template-generated");
    expect(brief.markdown).toContain(
      "Contribution-margin guardrail is pending",
    );
    expect(
      explore(
        dataset,
        "fixture",
        { ...filters, daypart: "Breakfast" },
        restaurant.id,
      ).snapshot,
    ).not.toBe(result.snapshot);
    expect(
      explore(dataset, "new-revision", filters, restaurant.id).snapshot,
    ).not.toBe(result.snapshot);
  });
});
