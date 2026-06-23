#!/usr/bin/env bash
# =============================================================================
# get-project.sh — sparse-clone a single project from sfe-public
#
# Usage:
#   bash <(curl -sL https://raw.githubusercontent.com/sfc-gh-miwhitaker/sfe-public/main/shared/get-project.sh) <project-name>
#
# Example:
#   bash <(curl -sL .../get-project.sh) guide-cowork-only-users
# =============================================================================
set -euo pipefail

REPO="sfc-gh-miwhitaker/sfe-public"
BASE_URL="https://github.com/${REPO}"
PROJECT="${1:-}"

AVAILABLE_PROJECTS=(
  guide-cowork-only-users
  guide-connecting-claude-snowflake
  guide-vscode-copilot-cortex
)

# -- Usage / validation -------------------------------------------------------
if [ -z "${PROJECT}" ]; then
  echo "Usage: bash <(curl -sL ${BASE_URL}/raw/main/shared/get-project.sh) <project-name>"
  echo ""
  echo "Available projects:"
  for p in "${AVAILABLE_PROJECTS[@]}"; do
    echo "  ${p}"
  done
  exit 1
fi

VALID=0
for p in "${AVAILABLE_PROJECTS[@]}"; do
  [ "${PROJECT}" = "${p}" ] && VALID=1 && break
done
if [ "${VALID}" -eq 0 ]; then
  echo "Unknown project: ${PROJECT}"
  echo "Available: ${AVAILABLE_PROJECTS[*]}"
  exit 1
fi

# -- Clone (sparse — only the requested project + shared tooling) -------------
if [ -d "sfe-public" ]; then
  echo "sfe-public/ already exists — updating..."
  cd sfe-public
  git pull --ff-only
  git sparse-checkout add "${PROJECT}" shared
else
  echo "Cloning ${PROJECT} from sfc-gh-miwhitaker/sfe-public..."
  git clone --filter=blob:none --sparse "${BASE_URL}.git" sfe-public
  cd sfe-public
  git sparse-checkout set "${PROJECT}" shared
fi

echo ""
echo "Project ready at: $(pwd)/${PROJECT}"

# -- First-time developer setup -----------------------------------------------
CURRENT_HOOKS=$(git config --global core.hooksPath 2>/dev/null || true)
if [ -z "${CURRENT_HOOKS}" ]; then
  echo ""
  echo "Running first-time developer setup..."
  bash shared/setup-dev.sh
else
  echo "[ok] Developer hooks already configured (${CURRENT_HOOKS})"
fi

# -- Next steps ---------------------------------------------------------------
echo ""
echo "Open $(pwd)/${PROJECT} in your AI assistant and say:"
echo "  'Help me get started with this project'"
echo ""
echo "  Cortex Code: cortex"
echo "  Claude Code:  claude"
echo "  Cursor:       open the folder in Cursor"
