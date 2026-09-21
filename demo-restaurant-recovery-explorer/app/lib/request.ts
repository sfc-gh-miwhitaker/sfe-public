// Pair-programmed by SE Community + Cortex Code
import { CHANNELS, DAYPARTS } from "../contracts/dataset";
import type { Filters } from "./analytics";

export function parseRequest(url: string) {
  const params = new URL(url).searchParams;
  const weeks = Number(params.get("weeks") ?? 8);
  const daypart = params.get("daypart") ?? "All";
  const channel = params.get("channel") ?? "All";
  if (
    ![4, 8].includes(weeks) ||
    !["All", ...DAYPARTS].includes(daypart) ||
    !["All", ...CHANNELS].includes(channel)
  )
    throw new Error(
      "Invalid filters. Choose 4 or 8 weeks and a listed daypart/channel.",
    );
  return {
    filters: {
      market: params.get("market") ?? "Mesa Vale",
      weeks,
      daypart,
      channel,
    } as Filters,
    restaurantId: params.get("restaurant") ?? "R001",
  };
}
