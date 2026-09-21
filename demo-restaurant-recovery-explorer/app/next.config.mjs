// Pair-programmed by SE Community + Cortex Code
import path from "node:path";
import { fileURLToPath } from "node:url";

const projectRoot = path.dirname(fileURLToPath(import.meta.url));
export default {
  output: "standalone",
  outputFileTracingRoot: projectRoot,
  turbopack: { root: projectRoot },
  images: { unoptimized: true },
  poweredByHeader: false,
};
