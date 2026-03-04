#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://github.com/sfc-gh-miwhitaker/sfe-public.git"
BRANCH="main"

usage() {
  echo "Usage: $0 <project-name>"
  echo ""
  echo "Clone a single project from the sfe-public monorepo using git sparse-checkout."
  echo ""
  echo "Examples:"
  echo "  $0 demo-agent-multicontext"
  echo "  $0 tool-cortex-cost-calculator"
  echo ""
  echo "Or run directly from GitHub:"
  echo "  bash <(curl -sL https://raw.githubusercontent.com/sfc-gh-miwhitaker/sfe-public/main/shared/get-project.sh) demo-agent-multicontext"
  exit 1
}

if [[ $# -ne 1 ]]; then
  usage
fi

PROJECT="$1"

if ! command -v git &>/dev/null; then
  echo "Error: git is required but not installed."
  echo "  Mac:     xcode-select --install"
  echo "  Windows: https://git-scm.com/downloads"
  exit 1
fi

GIT_VERSION=$(git version | grep -oE '[0-9]+\.[0-9]+' | head -1)
GIT_MAJOR=$(echo "$GIT_VERSION" | cut -d. -f1)
GIT_MINOR=$(echo "$GIT_VERSION" | cut -d. -f2)
if [[ "$GIT_MAJOR" -lt 2 ]] || { [[ "$GIT_MAJOR" -eq 2 ]] && [[ "$GIT_MINOR" -lt 25 ]]; }; then
  echo "Error: git 2.25+ required for sparse-checkout (found $GIT_VERSION)."
  echo "  Update: https://git-scm.com/downloads"
  exit 1
fi

echo "Cloning $PROJECT from sfe-public..."
git clone --filter=blob:none --sparse --depth 1 -b "$BRANCH" "$REPO_URL" sfe-public 2>&1

cd sfe-public
git sparse-checkout set "$PROJECT" shared

if [[ ! -d "$PROJECT" ]]; then
  echo ""
  echo "Error: '$PROJECT' not found in the repository."
  echo ""
  echo "Available projects:"
  git ls-tree --name-only HEAD | grep -E '^(demo-|tool-|guide-)' | sed 's/^/  /'
  cd ..
  rm -rf sfe-public
  exit 1
fi

echo ""
echo "Done. Cloned '$PROJECT' + shared/ into ./sfe-public/"
echo ""
echo "Next steps:"
echo "  cd sfe-public/$PROJECT"
echo "  cortex                    # AI-assisted deployment"
echo "  # or open deploy_all.sql in Snowsight"
