// Pair-programmed by SE Community + Cortex Code
import { z } from "zod";

export const DAYPARTS = ["Breakfast", "Lunch", "Dinner", "Late night"] as const;
export const CHANNELS = ["Dine-in", "Takeaway", "Delivery"] as const;
const date = z.iso.date();
const nonnegative = z.number().finite().nonnegative();
export const datasetSchema = z
  .object({
    metadata: z
      .object({
        version: z.literal("1.0"),
        seed: z.number().int(),
        scenarioVersion: z.string().min(1),
        asOf: date,
        synthetic: z.literal(true),
        provenance: z.string().min(1),
        guestUnit: z.literal("guest occasions"),
        salesUnit: z.literal("net sales excluding tax"),
        attribution: z.literal("Pair-programmed by SE Community + Cortex Code"),
      })
      .strict(),
    restaurants: z
      .array(
        z
          .object({
            id: z.string().min(1),
            name: z.string().min(1),
            market: z.string().min(1),
            latitude: z.number().min(-90).max(90),
            longitude: z.number().min(-180).max(180),
            timezone: z.string().refine((value) => {
              try {
                new Intl.DateTimeFormat("en", { timeZone: value });
                return true;
              } catch {
                return false;
              }
            }, "Use an IANA timezone"),
            openDate: date,
            closeDate: date.nullable(),
            format: z.string().min(1),
          })
          .strict(),
      )
      .min(1),
    calendar: z
      .array(
        z
          .object({
            week: date,
            baselineWeek: date.nullable(),
            complete: z.boolean(),
            holiday: z.boolean(),
            exception: z.string().nullable(),
          })
          .strict(),
      )
      .min(1),
    performance: z.array(
      z
        .object({
          restaurantId: z.string(),
          week: date,
          daypart: z.enum(DAYPARTS),
          channel: z.enum(CHANNELS),
          guests: nonnegative.int().nullable(),
          sales: z.number().finite().nullable(),
          currency: z.literal("USD"),
          complete: z.boolean(),
        })
        .strict(),
    ),
    operations: z.array(
      z
        .object({
          restaurantId: z.string(),
          week: date,
          daypart: z.enum(DAYPARTS),
          openHours: nonnegative.nullable(),
          laborHours: nonnegative.nullable(),
          serviceMinutes: nonnegative.nullable(),
          serviceObservations: nonnegative.int(),
        })
        .strict(),
    ),
    events: z.array(
      z
        .object({
          id: z.string(),
          restaurantId: z.string(),
          start: date,
          end: date.nullable(),
          type: z.enum([
            "Staffing change",
            "Hours change",
            "Closure",
            "Promotion",
          ]),
          daypart: z.enum(DAYPARTS).nullable(),
          source: z.string().min(1),
        })
        .strict(),
    ),
  })
  .strict();
export type Dataset = z.infer<typeof datasetSchema>;
export type Restaurant = Dataset["restaurants"][number];
export type Performance = Dataset["performance"][number];
export type Operation = Dataset["operations"][number];

export function validateDataset(input: unknown): Dataset {
  const result = datasetSchema.safeParse(input);
  if (!result.success)
    throw new Error(
      `Invalid input contract. Correct the source adapter: ${result.error.issues
        .slice(0, 3)
        .map((issue) => `${issue.path.join(".")}: ${issue.message}`)
        .join("; ")}`,
    );
  const dataset = result.data;
  const unique = (values: string[], label: string) => {
    if (new Set(values).size !== values.length)
      throw new Error(
        `Duplicate ${label}. Deduplicate the adapter output before analysis.`,
      );
  };
  unique(
    dataset.restaurants.map((row) => row.id),
    "restaurant ID",
  );
  unique(
    dataset.calendar.map((row) => row.week),
    "calendar week",
  );
  unique(
    dataset.performance.map(
      (row) => `${row.restaurantId}|${row.week}|${row.daypart}|${row.channel}`,
    ),
    "performance grain",
  );
  unique(
    dataset.operations.map(
      (row) => `${row.restaurantId}|${row.week}|${row.daypart}`,
    ),
    "operations grain",
  );
  unique(
    dataset.events.map((row) => row.id),
    "event ID",
  );
  const restaurants = new Map(dataset.restaurants.map((row) => [row.id, row]));
  const weeks = new Set(dataset.calendar.map((row) => row.week));
  const calendar = [...weeks].sort();
  for (const [index, week] of calendar.entries()) {
    if (
      index &&
      Date.parse(week) - Date.parse(calendar[index - 1]) !== 604800000
    )
      throw new Error(
        "Calendar must contain contiguous weekly periods. Add missing weeks and mark incomplete.",
      );
  }
  for (const row of dataset.calendar) {
    if (
      row.baselineWeek &&
      (!weeks.has(row.baselineWeek) || row.baselineWeek >= row.week)
    )
      throw new Error(
        "Invalid baseline mapping. Reference an earlier calendar week.",
      );
    if (
      row.complete &&
      Date.parse(row.week) + 604800000 > Date.parse(dataset.metadata.asOf)
    )
      throw new Error(
        "Incomplete calendar period marked complete. Correct the as-of date or completeness flag.",
      );
  }
  for (const row of dataset.restaurants) {
    if (row.closeDate && row.closeDate < row.openDate)
      throw new Error(
        "Closure predates opening. Correct restaurant lifecycle dates.",
      );
  }
  for (const row of [...dataset.performance, ...dataset.operations]) {
    if (!restaurants.has(row.restaurantId) || !weeks.has(row.week))
      throw new Error(
        "Unknown restaurant or week. Supply the corresponding roster/calendar row.",
      );
  }
  for (const row of dataset.performance) {
    if (row.complete && (row.guests === null || row.sales === null))
      throw new Error(
        "Complete performance rows need guest and sales values. Mark missing extracts incomplete.",
      );
    const restaurant = restaurants.get(row.restaurantId)!;
    if (
      (row.week < restaurant.openDate ||
        (restaurant.closeDate && row.week >= restaurant.closeDate)) &&
      (row.guests ?? 0) > 0
    )
      throw new Error(
        "Guests outside restaurant lifecycle. Correct opening/closure dates or observations.",
      );
  }
  for (const row of dataset.events) {
    if (!restaurants.has(row.restaurantId) || (row.end && row.end < row.start))
      throw new Error(
        "Invalid event reference or interval. Correct the event source.",
      );
  }
  return dataset;
}
