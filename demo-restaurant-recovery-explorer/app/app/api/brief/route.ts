// Pair-programmed by SE Community + Cortex Code
import { explore } from "../../../lib/analytics";
import { buildBrief } from "../../../lib/brief";
import { getDataset } from "../../../lib/provider";
import { parseRequest } from "../../../lib/request";
export const dynamic = "force-dynamic";

export async function POST(request: Request) {
  try {
    const { filters, restaurantId } = parseRequest(request.url);
    const { dataset, revision } = getDataset();
    return Response.json(
      buildBrief(explore(dataset, revision, filters, restaurantId)),
    );
  } catch (error) {
    return Response.json(
      {
        error:
          error instanceof Error
            ? error.message
            : "Brief unavailable. Recompute analysis and try again.",
      },
      { status: 400 },
    );
  }
}
