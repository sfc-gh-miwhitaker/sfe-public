#!/usr/bin/env bash
# =============================================================================
# SFE Developer Setup — one-time machine configuration
#
# Installs pre-commit and configures git's core.hooksPath so that pre-commit
# runs automatically on every commit in any repo that has a
# .pre-commit-config.yaml — no per-repo 'pre-commit install' required.
#
# Usage:  bash shared/setup-dev.sh
#    or:  bash <(curl -sL https://raw.githubusercontent.com/sfc-gh-miwhitaker/sfe-public/main/shared/setup-dev.sh)
#
# Safe to re-run — idempotent.
# =============================================================================
set -euo pipefail

echo "=== SFE Developer Setup ==="
echo "Configures pre-commit to run automatically in every git repository."
echo ""

# -- 1. Ensure pre-commit is installed ----------------------------------------
if command -v pre-commit &>/dev/null; then
  echo "[ok] pre-commit $(pre-commit --version) already installed"
else
  echo "Installing pre-commit..."
  if command -v pipx &>/dev/null; then
    pipx install pre-commit
  else
    pip install --quiet pre-commit
  fi
  echo "[ok] pre-commit installed ($(pre-commit --version))"
fi

# -- 2. Write the global dispatcher hook --------------------------------------
HOOKS_DIR="${HOME}/.config/git/hooks"
mkdir -p "${HOOKS_DIR}"

cat > "${HOOKS_DIR}/pre-commit" << 'HOOK'
#!/usr/bin/env bash
# Global pre-commit dispatcher — installed by sfe-public/shared/setup-dev.sh
# Runs pre-commit on any repo that has .pre-commit-config.yaml.
# Repos without the config file are skipped silently (exit 0).

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
[ -f "${REPO_ROOT}/.pre-commit-config.yaml" ] || exit 0

if ! command -v pre-commit &>/dev/null; then
  echo "ERROR: pre-commit is not installed."
  echo "Fix:  pip install pre-commit  OR  pipx install pre-commit"
  echo "Then: re-run sfe-public/shared/setup-dev.sh"
  exit 1
fi

cd "${REPO_ROOT}" && exec pre-commit run --hook-stage commit
HOOK

chmod +x "${HOOKS_DIR}/pre-commit"
echo "[ok] Hook written to ${HOOKS_DIR}/pre-commit"

# -- 3. Register the hooks directory with git globally ------------------------
git config --global core.hooksPath "${HOOKS_DIR}"
echo "[ok] git config --global core.hooksPath ${HOOKS_DIR}"

echo ""
echo "=== Setup complete ==="
echo "Pre-commit now runs automatically on every commit in any repo that"
echo "has a .pre-commit-config.yaml — no per-repo 'pre-commit install' needed."
echo ""
echo "To add this protection to a repo that does not yet have a config:"
echo "  cp shared/pre-commit-config-template.yaml /path/to/repo/.pre-commit-config.yaml"
echo "  cd /path/to/repo && detect-secrets scan > .secrets.baseline"
