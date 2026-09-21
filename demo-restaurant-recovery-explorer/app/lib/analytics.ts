// Pair-programmed by SE Community + Cortex Code
import { createHash } from "node:crypto";
import {
  CHANNELS,
  DAYPARTS,
  type Dataset,
  type Operation,
  type Performance,
  type Restaurant,
} from "../contracts/dataset";

export const ANALYSIS_VERSION = "1.0";
export const MATCH_POLICY = "pre26-v1";
export type Filters = {
  market: string;
  weeks: 4 | 8;
  daypart: string;
  channel: string;
};
export type Totals = {
  current: number;
  baseline: number;
  change: number;
  salesCurrent: number;
  salesBaseline: number;
  pairs: number;
  expected: number;
  excluded: number;
  percent: number | null;
};
export type StoreResult = Totals & {
  restaurant: Restaurant;
  lifecycle: "Comparable" | "Opening" | "Closure" | "Outside comparison";
  loss: number;
  lossShare: number;
};
export type Trend = {
  week: string;
  guests: number | null;
  peerIndex: number | null;
  index: number | null;
};
type Index = {
  performance: Map<string, Performance>;
  operations: Map<string, Operation>;
};
const indices = new WeakMap<Dataset, Index>();
const sum = (values: number[]) =>
  values.reduce((total, value) => total + value, 0);
export const percent = (current: number, baseline: number) =>
  baseline > 0 ? ((current - baseline) / baseline) * 100 : null;
const cellKey = (
  restaurant: string,
  week: string,
  daypart: string,
  channel: string,
) => `${restaurant}|${week}|${daypart}|${channel}`;

function indexDataset(dataset: Dataset): Index {
  let index = indices.get(dataset);
  if (!index) {
    index = {
      performance: new Map(
        dataset.performance.map((row) => [
          cellKey(row.restaurantId, row.week, row.daypart, row.channel),
          row,
        ]),
      ),
      operations: new Map(
        dataset.operations.map((row) => [
          `${row.restaurantId}|${row.week}|${row.daypart}`,
          row,
        ]),
      ),
    };
    indices.set(dataset, index);
  }
  return index;
}

export function analysisPeriods(dataset: Dataset, weeks: number) {
  const calendar = [...dataset.calendar].sort((left, right) =>
    left.week.localeCompare(right.week),
  );
  const periods = calendar.slice(-weeks);
  if (periods.length !== weeks || periods.some((row) => !row.baselineWeek))
    throw new Error(
      "Missing baseline mapping in the requested calendar window. Supply every mapping; the analysis window will not shift to earlier weeks.",
    );
  return periods;
}

function dimensions(filters: Filters) {
  return {
    dayparts: DAYPARTS.filter(
      (value) => filters.daypart === "All" || value === filters.daypart,
    ),
    channels: CHANNELS.filter(
      (value) => filters.channel === "All" || value === filters.channel,
    ),
  };
}

export function totalFor(
  dataset: Dataset,
  restaurant: Restaurant,
  filters: Filters,
): Totals {
  const index = indexDataset(dataset);
  const periods = analysisPeriods(dataset, filters.weeks);
  const calendar = new Map(dataset.calendar.map((row) => [row.week, row]));
  const { dayparts, channels } = dimensions(filters);
  let current = 0,
    baseline = 0,
    salesCurrent = 0,
    salesBaseline = 0,
    pairs = 0;
  for (const period of periods) {
    if (!period.complete || !calendar.get(period.baselineWeek!)?.complete)
      continue;
    for (const daypart of dayparts)
      for (const channel of channels) {
        const latest = index.performance.get(
          cellKey(restaurant.id, period.week, daypart, channel),
        );
        const earlier = index.performance.get(
          cellKey(restaurant.id, period.baselineWeek!, daypart, channel),
        );
        if (
          !latest?.complete ||
          !earlier?.complete ||
          latest.guests === null ||
          earlier.guests === null ||
          latest.sales === null ||
          earlier.sales === null
        )
          continue;
        current += latest.guests;
        baseline += earlier.guests;
        salesCurrent += latest.sales;
        salesBaseline += earlier.sales;
        pairs++;
      }
  }
  const expected = filters.weeks * dayparts.length * channels.length;
  return {
    current,
    baseline,
    change: current - baseline,
    salesCurrent,
    salesBaseline,
    pairs,
    expected,
    excluded: expected - pairs,
    percent: percent(current, baseline),
  };
}

function lifecycle(
  restaurant: Restaurant,
  start: string,
  baselineStart: string,
  end: string,
): StoreResult["lifecycle"] {
  if (restaurant.closeDate && restaurant.closeDate <= baselineStart)
    return "Outside comparison";
  const exclusiveEnd = new Date(Date.parse(end) + 604800000)
    .toISOString()
    .slice(0, 10);
  if (
    restaurant.closeDate &&
    restaurant.closeDate > baselineStart &&
    restaurant.closeDate < exclusiveEnd
  )
    return "Closure";
  if (restaurant.openDate > baselineStart) return "Opening";
  return restaurant.openDate <= start ? "Comparable" : "Outside comparison";
}

export function marketAnalysis(dataset: Dataset, filters: Filters) {
  const periods = analysisPeriods(dataset, filters.weeks);
  if (!periods.length)
    throw new Error(
      "No aligned analysis periods. Add calendar baseline mappings.",
    );
  const stores: StoreResult[] = dataset.restaurants
    .filter((row) => filters.market === "All" || row.market === filters.market)
    .map((restaurant) => {
      const totals = totalFor(dataset, restaurant, filters);
      return {
        ...totals,
        restaurant,
        lifecycle: lifecycle(
          restaurant,
          periods[0].week,
          periods[0].baselineWeek!,
          periods.at(-1)!.week,
        ),
        loss: Math.max(0, -totals.change),
        lossShare: 0,
      };
    });
  const grossLoss = sum(stores.map((row) => row.loss));
  for (const store of stores)
    store.lossShare = grossLoss ? (store.loss / grossLoss) * 100 : 0;
  stores.sort(
    (left, right) =>
      left.change - right.change ||
      left.restaurant.id.localeCompare(right.restaurant.id),
  );
  const baseline = sum(stores.map((row) => row.baseline));
  const current = sum(stores.map((row) => row.current));
  const bridge = ["Comparable", "Opening", "Closure", "Outside comparison"].map(
    (label) => ({
      label,
      change: sum(
        stores
          .filter((row) => row.lifecycle === label)
          .map((row) => row.change),
      ),
      count: stores.filter((row) => row.lifecycle === label).length,
    }),
  );
  return {
    stores,
    baseline,
    current,
    change: current - baseline,
    percent: percent(current, baseline),
    grossLoss,
    gains: sum(stores.map((row) => Math.max(0, row.change))),
    excluded: sum(stores.map((row) => row.excluded)),
    expected: sum(stores.map((row) => row.expected)),
    bridge,
    start: periods[0].week,
    end: periods.at(-1)!.week,
    baselineStart: periods[0].baselineWeek!,
    baselineEnd: periods.at(-1)!.baselineWeek!,
  };
}

export function breakdown(
  dataset: Dataset,
  restaurant: Restaurant,
  filters: Filters,
  dimension: "daypart" | "channel",
) {
  const labels = dimension === "daypart" ? DAYPARTS : CHANNELS;
  return labels
    .filter(
      (label) => filters[dimension] === "All" || filters[dimension] === label,
    )
    .map((label) => ({
      label,
      ...totalFor(dataset, restaurant, { ...filters, [dimension]: label }),
    }));
}

function weeklyGuests(
  dataset: Dataset,
  restaurant: Restaurant,
  week: string,
  filters: Filters,
): number | null {
  const { dayparts, channels } = dimensions(filters);
  const index = indexDataset(dataset);
  if (!dataset.calendar.find((row) => row.week === week)?.complete) return null;
  let guests = 0;
  for (const daypart of dayparts)
    for (const channel of channels) {
      const row = index.performance.get(
        cellKey(restaurant.id, week, daypart, channel),
      );
      if (!row?.complete || row.guests === null) return null;
      guests += row.guests;
    }
  return guests;
}

function preFeatures(dataset: Dataset, restaurant: Restaurant, start: string) {
  const periods = dataset.calendar
    .filter((row) => row.week < start)
    .sort((left, right) => left.week.localeCompare(right.week))
    .slice(-26);
  if (
    periods.length !== 26 ||
    periods.some((row) => !row.complete) ||
    restaurant.openDate > periods[0].week ||
    (restaurant.closeDate && restaurant.closeDate < start)
  )
    return null;
  const all: Filters = {
    market: "All",
    weeks: 8,
    daypart: "All",
    channel: "All",
  };
  const weekly = periods.map((period) =>
    weeklyGuests(dataset, restaurant, period.week, all),
  );
  if (weekly.some((value) => value === null) || !sum(weekly as number[]))
    return null;
  const guests = sum(weekly as number[]);
  const breakfast = periods.map((period) =>
    weeklyGuests(dataset, restaurant, period.week, {
      ...all,
      daypart: "Breakfast",
    }),
  ) as number[];
  const delivery = periods.map((period) =>
    weeklyGuests(dataset, restaurant, period.week, {
      ...all,
      channel: "Delivery",
    }),
  ) as number[];
  const index = indexDataset(dataset);
  const operations = periods.flatMap((period) =>
    DAYPARTS.map((daypart) =>
      index.operations.get(`${restaurant.id}|${period.week}|${daypart}`),
    ),
  );
  if (operations.some((row) => !row || row.openHours === null)) return null;
  const first = sum((weekly as number[]).slice(0, 13));
  if (!first) return null;
  return [
    guests / 26,
    sum(breakfast) / guests,
    sum(delivery) / guests,
    sum(operations.map((row) => row!.openHours!)) / 26,
    sum((weekly as number[]).slice(13)) / first - 1,
  ];
}

export function matchedPeers(
  dataset: Dataset,
  restaurant: Restaurant,
  filters: Filters,
) {
  const start = analysisPeriods(dataset, filters.weeks)[0].week;
  const features = new Map(
    dataset.restaurants.map((row) => [
      row.id,
      preFeatures(dataset, row, start),
    ]),
  );
  const focal = features.get(restaurant.id);
  const eligible = dataset.restaurants.filter(
    (row) =>
      row.market === restaurant.market &&
      row.format === restaurant.format &&
      features.get(row.id),
  );
  const scales = [300, 0.05, 0.05, 15, 0.05].map((floor, index) => {
    const values = eligible.map((row) => features.get(row.id)![index]);
    const average = sum(values) / Math.max(values.length, 1);
    return Math.max(
      floor,
      Math.sqrt(
        sum(values.map((value) => (value - average) ** 2)) /
          Math.max(values.length, 1),
      ),
    );
  });
  const weights = [0.3, 0.2, 0.15, 0.2, 0.15];
  const candidates = dataset.restaurants
    .filter((row) => row.id !== restaurant.id)
    .map((candidate) => {
      const candidateFeatures = features.get(candidate.id);
      const differences =
        focal && candidateFeatures
          ? focal.map((value, index) =>
              Math.abs(value - candidateFeatures[index]),
            )
          : [];
      const score = differences.length
        ? sum(
            differences.map(
              (value, index) => (value / scales[index]) * weights[index],
            ),
          )
        : null;
      const reason =
        candidate.market !== restaurant.market
          ? "Different market"
          : candidate.format !== restaurant.format
            ? "Different format"
            : !focal || !candidateFeatures
              ? "Incomplete pre-period or lifecycle"
              : score! > 1
                ? "Outside similarity threshold"
                : "Eligible";
      return {
        restaurant: candidate,
        score,
        differences,
        reason,
        features: candidateFeatures,
      };
    })
    .sort(
      (left, right) =>
        (left.score ?? Infinity) - (right.score ?? Infinity) ||
        left.restaurant.id.localeCompare(right.restaurant.id),
    );
  const selected = candidates
    .filter((row) => row.reason === "Eligible")
    .slice(0, 5);
  const adequate = !!focal && selected.length >= 3;
  const totals = selected.map((row) =>
    totalFor(dataset, row.restaurant, filters),
  );
  const focalTotals = totalFor(dataset, restaurant, filters);
  const periods = analysisPeriods(dataset, filters.weeks);
  const comparableOutcomes = [
    restaurant,
    ...selected.map((row) => row.restaurant),
  ].every(
    (row) =>
      lifecycle(row, start, periods[0].baselineWeek!, periods.at(-1)!.week) ===
      "Comparable",
  );
  const outcomeComplete =
    adequate &&
    comparableOutcomes &&
    totals.every((row) => row.excluded === 0 && row.baseline > 0) &&
    focalTotals.excluded === 0 &&
    focalTotals.baseline > 0;
  const peerPercent = outcomeComplete
    ? sum(totals.map((row) => row.percent!)) / selected.length
    : null;
  const gap =
    peerPercent !== null && focalTotals.percent !== null
      ? focalTotals.percent - peerPercent
      : null;
  const prePeriods = dataset.calendar
    .filter((row) => row.week < start)
    .sort((left, right) => left.week.localeCompare(right.week))
    .slice(-26);
  const trendPeriods = dataset.calendar
    .filter((row) => row.week >= prePeriods[0].week)
    .sort((left, right) => left.week.localeCompare(right.week));
  const meanBefore = (store: Restaurant) => {
    const values = prePeriods.map((row) =>
      weeklyGuests(dataset, store, row.week, filters),
    );
    return values.some((value) => value === null)
      ? null
      : sum(values as number[]) / values.length;
  };
  const focalMean = meanBefore(restaurant);
  const peerMeans = selected.map((row) => meanBefore(row.restaurant));
  const trend: Trend[] = trendPeriods.map((period) => {
    const guests = weeklyGuests(dataset, restaurant, period.week, filters);
    const peerValues = selected.map((row, index) => {
      const value = weeklyGuests(dataset, row.restaurant, period.week, filters);
      return value !== null && peerMeans[index]
        ? (value / peerMeans[index]!) * 100
        : null;
    });
    return {
      week: period.week,
      guests,
      index: guests !== null && focalMean ? (guests / focalMean) * 100 : null,
      peerIndex:
        adequate && peerValues.every((value) => value !== null)
          ? sum(peerValues as number[]) / peerValues.length
          : null,
    };
  });
  return {
    adequate,
    outcomeComplete,
    selected: adequate ? selected : [],
    candidates,
    peerPercent,
    gap,
    trend,
    focalFeatures: focal ?? null,
    scales,
    weights,
    policy: MATCH_POLICY,
    preStart: prePeriods[0].week,
    preEnd: prePeriods.at(-1)!.week,
  };
}

export function operationsComparison(
  dataset: Dataset,
  restaurant: Restaurant,
  filters: Filters,
) {
  const periods = analysisPeriods(dataset, filters.weeks);
  const index = indexDataset(dataset);
  const { dayparts } = dimensions(filters);
  const collect = (baseline: boolean) =>
    periods.flatMap((period) =>
      dayparts.map((daypart) =>
        index.operations.get(
          `${restaurant.id}|${baseline ? period.baselineWeek : period.week}|${daypart}`,
        ),
      ),
    );
  const current = collect(false),
    baseline = collect(true);
  const complete = [...current, ...baseline].every(
    (row) => row && row.openHours !== null && row.laborHours !== null,
  );
  const currentHours = complete
    ? sum(current.map((row) => row!.openHours!))
    : null;
  const baselineHours = complete
    ? sum(baseline.map((row) => row!.openHours!))
    : null;
  const currentLabor = complete
    ? sum(current.map((row) => row!.laborHours!))
    : null;
  const baselineLabor = complete
    ? sum(baseline.map((row) => row!.laborHours!))
    : null;
  const allChannel = totalFor(dataset, restaurant, {
    ...filters,
    channel: "All",
  });
  return {
    complete,
    currentHours,
    baselineHours,
    currentLabor,
    baselineLabor,
    currentRate:
      currentHours && !allChannel.excluded
        ? allChannel.current / currentHours
        : null,
    baselineRate:
      baselineHours && !allChannel.excluded
        ? allChannel.baseline / baselineHours
        : null,
  };
}

export function explore(
  dataset: Dataset,
  revision: string,
  filters: Filters,
  restaurantId?: string,
) {
  const market = marketAnalysis(dataset, filters);
  const selected =
    market.stores.find((row) => row.restaurant.id === restaurantId) ??
    market.stores[0];
  if (!selected)
    throw new Error("No restaurants match this market. Select another market.");
  if (!selected.pairs)
    throw new Error(
      "No paired observations are available for this restaurant and selection. Restore the missing extracts or choose another restaurant; missing data is not zero guest change.",
    );
  const restaurant = selected.restaurant;
  const peers = matchedPeers(dataset, restaurant, filters);
  const operations = operationsComparison(dataset, restaurant, filters);
  const snapshot = createHash("sha256")
    .update(
      JSON.stringify({
        revision,
        filters,
        restaurantId: restaurant.id,
        version: ANALYSIS_VERSION,
      }),
    )
    .digest("hex")
    .slice(0, 16);
  return {
    metadata: dataset.metadata,
    revision,
    snapshot,
    filters,
    market,
    selected,
    peers,
    operations,
    breakfastOperations: operationsComparison(dataset, restaurant, {
      ...filters,
      daypart: "Breakfast",
      channel: "All",
    }),
    dayparts: breakdown(dataset, restaurant, filters, "daypart"),
    channels: breakdown(dataset, restaurant, filters, "channel"),
    cells: DAYPARTS.filter(
      (daypart) => filters.daypart === "All" || filters.daypart === daypart,
    ).flatMap((daypart) =>
      CHANNELS.filter(
        (channel) => filters.channel === "All" || filters.channel === channel,
      ).map((channel) => ({
        daypart,
        channel,
        ...totalFor(dataset, restaurant, { ...filters, daypart, channel }),
      })),
    ),
    events: dataset.events.filter(
      (row) =>
        row.restaurantId === restaurant.id &&
        Date.parse(row.start) < Date.parse(market.end) + 604800000 &&
        (!row.end || row.end >= peers.preStart),
    ),
    markets: [...new Set(dataset.restaurants.map((row) => row.market))],
  };
}
export type Exploration = ReturnType<typeof explore>;
