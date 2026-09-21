// Pair-programmed by SE Community + Cortex Code
import { CHANNELS, DAYPARTS, type Dataset } from "./dataset.ts";

export function generateSynthetic(seed = 417): Dataset {
  let state = seed >>> 0;
  const random = () => {
    state = (1664525 * state + 1013904223) >>> 0;
    return state / 4294967296;
  };
  const weekDate = (index: number) =>
    new Date(Date.UTC(2024, 8, 16) + index * 604800000)
      .toISOString()
      .slice(0, 10);
  const calendar = Array.from({ length: 104 }, (_, index) => ({
    week: weekDate(index),
    baselineWeek: index >= 52 ? weekDate(index - 52) : null,
    complete: true,
    holiday: index % 52 === 14,
    exception: index % 52 === 14 ? "Synthetic holiday week" : null,
  }));
  const markets = ["Mesa Vale", "Juniper Coast", "Cedar Basin"];
  const restaurants = Array.from({ length: 48 }, (_, index) => ({
    id: `R${String(index + 1).padStart(3, "0")}`,
    name: `${["Copper", "Willow", "Orchard", "Canyon", "Laurel", "River", "Summit", "Aspen"][index % 8]} ${["Table", "Kitchen", "Grill", "House", "Corner", "Terrace"][Math.floor(index / 8)]}`,
    market: markets[Math.floor(index / 16)],
    latitude:
      34 +
      Math.floor(index / 16) * 1.8 +
      Math.floor((index % 16) / 4) * 0.22 +
      random() * 0.06,
    longitude: -113 + (index % 4) * 0.32 + random() * 0.08,
    timezone: "America/Phoenix",
    openDate: index === 14 ? weekDate(97) : "2020-01-06",
    closeDate: index === 13 ? weekDate(99) : null,
    format: index === 47 ? "Roadside express" : "Neighborhood dining",
  }));
  const performance: Dataset["performance"] = [];
  const operations: Dataset["operations"] = [];
  const events: Dataset["events"] = [
    {
      id: "E001",
      restaurantId: "R001",
      start: weekDate(95),
      end: null,
      type: "Staffing change",
      daypart: "Breakfast",
      source: "Synthetic staffing register",
    },
    {
      id: "E002",
      restaurantId: "R003",
      start: weekDate(96),
      end: null,
      type: "Hours change",
      daypart: "Breakfast",
      source: "Synthetic opening-hours register",
    },
    {
      id: "E003",
      restaurantId: "R014",
      start: weekDate(99),
      end: null,
      type: "Closure",
      daypart: null,
      source: "Synthetic restaurant roster",
    },
  ];
  for (const [restaurantIndex, restaurant] of restaurants.entries()) {
    for (const [weekIndex, period] of calendar.entries()) {
      const active =
        period.week >= restaurant.openDate &&
        (!restaurant.closeDate || period.week < restaurant.closeDate);
      for (const [daypartIndex, daypart] of DAYPARTS.entries()) {
        const hourFactor =
          restaurantIndex === 2 && weekIndex >= 96 && daypartIndex === 0
            ? 0.62
            : 1;
        const openHours = active
          ? [35, 28, 35, 14][daypartIndex] * hourFactor
          : 0;
        const laborFactor =
          restaurantIndex === 0 && weekIndex >= 95 && daypartIndex === 0
            ? 0.76
            : 1;
        operations.push({
          restaurantId: restaurant.id,
          week: period.week,
          daypart,
          openHours,
          laborHours: openHours * 3.5 * laborFactor,
          serviceMinutes: active
            ? restaurantIndex === 0 && weekIndex >= 96 && daypartIndex === 0
              ? 14
              : 9
            : null,
          serviceObservations: active ? 150 : 0,
        });
        for (const [channelIndex, channel] of CHANNELS.entries()) {
          const season = 1 + 0.1 * Math.sin(((weekIndex % 52) * Math.PI) / 26);
          const base =
            (3100 + (restaurantIndex % 8) * 65) *
            [0.34, 0.27, 0.3, 0.09][daypartIndex] *
            [0.72, 0.18, 0.1][channelIndex];
          let factor = restaurantIndex === 14 ? 0.35 : 1;
          if (weekIndex >= 96) {
            if (restaurantIndex === 0 && daypartIndex === 0) factor = 0.65;
            else if (restaurantIndex === 1) factor = 1.1;
            else if (restaurantIndex >= 16 && restaurantIndex < 32)
              factor = 0.89;
            else if (restaurantIndex === 47) factor = 0.8;
          }
          const guests = active
            ? Math.round(
                base * season * factor * hourFactor * (0.985 + random() * 0.03),
              )
            : 0;
          const complete = !(restaurantIndex === 15 && weekIndex === 101);
          performance.push({
            restaurantId: restaurant.id,
            week: period.week,
            daypart,
            channel,
            guests: complete ? guests : null,
            sales: complete
              ? Math.round(guests * (14.5 + daypartIndex * 1.4) * 100) / 100
              : null,
            currency: "USD",
            complete,
          });
        }
      }
    }
  }
  return {
    metadata: {
      version: "1.0",
      seed,
      scenarioVersion: "1",
      asOf: "2026-09-14",
      synthetic: true,
      provenance: "Seeded fictional restaurant network; no customer data",
      guestUnit: "guest occasions",
      salesUnit: "net sales excluding tax",
      attribution: "Pair-programmed by SE Community + Cortex Code",
    },
    restaurants,
    calendar,
    performance,
    operations,
    events,
  };
}
