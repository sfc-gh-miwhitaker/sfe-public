// Pair-programmed by SE Community + Cortex Code
import { createHash } from "node:crypto";
import { validateDataset, type Dataset } from "../contracts/dataset";
import { generateSynthetic } from "../data/synthetic";

export interface DatasetProvider {
  load(): unknown;
}
export class SyntheticProvider implements DatasetProvider {
  constructor(private seed = 417) {}
  load() {
    return generateSynthetic(this.seed);
  }
}
export class JsonFixtureProvider implements DatasetProvider {
  constructor(private json: string) {}
  load(): unknown {
    return JSON.parse(this.json);
  }
}
export function loadDataset(provider: DatasetProvider): Dataset {
  return validateDataset(provider.load());
}
let cached: { dataset: Dataset; revision: string } | undefined;
export function getDataset() {
  if (!cached) {
    const dataset = loadDataset(new SyntheticProvider());
    cached = {
      dataset,
      revision: createHash("sha256")
        .update(JSON.stringify(dataset))
        .digest("hex")
        .slice(0, 16),
    };
  }
  return cached;
}
