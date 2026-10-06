#!/usr/bin/env bash
# Pair-programmed by SE Community + Cortex Code
set -euo pipefail

REPOSITORY="${SFE_REPOSITORY:-https://github.com/sfc-gh-miwhitaker/sfe-public.git}"
DESTINATION="${SFE_DESTINATION:-${PWD}/sfe-public}"
PROJECT="${1:---list}"

fail() { printf '%s\n' "$*" >&2; exit 1; }

if [[ $# -gt 1 ]]; then
  fail "Usage: bash get-project.sh [--list | guide-name | demo-name]"
fi
if [[ "$PROJECT" != '--list' && ! "$PROJECT" =~ ^(guide|demo)-[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
  fail "Invalid project name. Run with --list and choose a listed guide or demo."
fi
command -v git >/dev/null || fail "Git is required. Install Git, then run this command again."

TEMP_ROOT=$(mktemp -d)
trap 'rm -rf "$TEMP_ROOT"' EXIT
git -c core.hooksPath=/dev/null clone --quiet --bare --depth=1 --single-branch \
  "$REPOSITORY" "$TEMP_ROOT/source.git" || fail "Cannot read repository. Check the URL and your network, then retry."
REVISION=$(git --git-dir="$TEMP_ROOT/source.git" rev-parse HEAD)
BRANCH=$(git --git-dir="$TEMP_ROOT/source.git" symbolic-ref --short HEAD)
PROJECTS=()
while IFS= read -r entry; do
  if [[ "$entry" =~ ^(guide|demo)-[a-z0-9]+(-[a-z0-9]+)*$ ]] && \
    [[ "$(git --git-dir="$TEMP_ROOT/source.git" cat-file -t "$REVISION:$entry/README.md" 2>/dev/null || true)" == blob ]]; then
    PROJECTS+=("$entry")
  fi
done < <(git --git-dir="$TEMP_ROOT/source.git" ls-tree --name-only "$REVISION")

if [[ "$PROJECT" == '--list' ]]; then
  printf '%s\n' "${PROJECTS[@]}"
  exit 0
fi
FOUND=0
for entry in "${PROJECTS[@]}"; do
  [[ "$entry" != "$PROJECT" ]] || FOUND=1
done
[[ "$FOUND" == 1 ]] || fail "Unknown project: $PROJECT. Run with --list to see current projects."

if [[ -e "$DESTINATION" || -L "$DESTINATION" ]]; then
  [[ ! -L "$DESTINATION" && -d "$DESTINATION/.git" ]] || fail "Destination is not a standalone checkout. Choose an unused SFE_DESTINATION."
  ACTUAL_REMOTE=$(git -C "$DESTINATION" remote get-url origin)
  [[ "${ACTUAL_REMOTE%.git}" == "${REPOSITORY%.git}" ]] || fail "Destination belongs to another repository. Choose an unused SFE_DESTINATION."
  [[ -z "$(git -C "$DESTINATION" status --porcelain --untracked-files=all)" ]] || fail "Destination has local changes. Preserve them first or choose an unused SFE_DESTINATION."
  [[ -z "$(git -C "$DESTINATION" ls-files --others --ignored --exclude-standard)" ]] || fail "Destination has ignored local files. Preserve them or choose an unused SFE_DESTINATION before updating."
  [[ "$(git -C "$DESTINATION" symbolic-ref --short HEAD 2>/dev/null || true)" == "$BRANCH" ]] || fail "Destination is not on $BRANCH. Choose an unused SFE_DESTINATION or switch branches yourself."
  [[ "$(git -C "$DESTINATION" config --bool core.sparseCheckout || true)" == true ]] || fail "Destination is a full checkout. Use it directly or choose an unused SFE_DESTINATION."
  git -C "$DESTINATION" -c core.hooksPath=/dev/null fetch --quiet origin "$BRANCH"
  git -C "$DESTINATION" merge-base --is-ancestor HEAD FETCH_HEAD || fail "Destination has local or divergent commits. Preserve them and update manually."
  git -C "$DESTINATION" -c core.hooksPath=/dev/null merge --ff-only --no-overwrite-ignore FETCH_HEAD
  git -C "$DESTINATION" -c core.hooksPath=/dev/null sparse-checkout add "$PROJECT" shared
else
  git -c core.hooksPath=/dev/null clone --quiet --filter=blob:none --sparse --branch "$BRANCH" \
    "$REPOSITORY" "$DESTINATION"
  git -C "$DESTINATION" -c core.hooksPath=/dev/null sparse-checkout set "$PROJECT" shared
fi
printf '\nProject ready: %s/%s\nRead its README.md to begin. No developer hooks were installed.\n' "$DESTINATION" "$PROJECT"
