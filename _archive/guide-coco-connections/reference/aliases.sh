#!/usr/bin/env bash
# Cortex Code aliases for Partner SEs
# Add to ~/.zshrc or ~/.bashrc:  source ~/path/to/this/aliases.sh
#
# Pattern: coco-<customer>
# Each alias:  sets the connection, sets the workdir, loads the right AGENTS.md

# ─── CUSTOMER ALIASES ──────────────────────────────────────────────────────────
# Replace paths and connection names with your actual values.

alias coco-acme='cortex -c acme-prod --workdir ~/projects/acme'
alias coco-acme-dev='cortex -c acme-dev --workdir ~/projects/acme'
alias coco-globex='cortex -c globex-prod --workdir ~/projects/globex'

# ─── INTERNAL ──────────────────────────────────────────────────────────────────

alias coco='cortex --workdir ~/projects/internal'                    # default connection, internal project
alias coco-sandbox='cortex -c internal-sandbox --workdir ~/projects/sandbox'

# ─── ISOLATED ALIASES (separate memory per project) ────────────────────────────
# Use for regulated customers or competing engagements requiring hard isolation.
# Requires a per-project .coco-settings.json with SNOVA_MEMORY_LOCATION set.
#
# Example .coco-settings.json (save at ~/projects/acme/.coco-settings.json):
# {
#   "env": {
#     "SNOVA_MEMORY_LOCATION": "/Users/yourname/projects/acme/.coco-memory"
#   }
# }

alias coco-acme-isolated='cortex -c acme-prod \
  --config ~/projects/acme/.coco-settings.json \
  --workdir ~/projects/acme'

# ─── UTILITY ───────────────────────────────────────────────────────────────────

# List all configured connections
alias coco-list='cortex connections list'

# Quick account verification — pass connection name as argument
# Usage: coco-whoami acme-prod
coco-whoami() {
  local conn="${1:-default}"
  cortex -c "$conn" -p "SELECT CURRENT_ACCOUNT() AS account, CURRENT_USER() AS user, CURRENT_ROLE() AS role;"
}
