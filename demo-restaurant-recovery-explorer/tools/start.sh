#!/usr/bin/env bash
# Pair-programmed by SE Community + Cortex Code
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if ! command -v node >/dev/null || ! command -v npm >/dev/null; then
  printf '%s\n' 'Node.js 22+ and npm are required. Install Node.js, then run this script again.' >&2
  exit 1
fi
node -e 'if (Number(process.versions.node.split(".")[0]) < 22) { console.error("Upgrade to Node.js 22 or later, then retry."); process.exit(1); }'
if [[ ! -d "$PROJECT_ROOT/app/node_modules" ]]; then
  npm --prefix "$PROJECT_ROOT/app" ci --ignore-scripts
fi
export NEXT_TELEMETRY_DISABLED=1
exec npm --prefix "$PROJECT_ROOT/app" run dev -- --port 3217
