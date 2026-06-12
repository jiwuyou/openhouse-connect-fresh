#!/usr/bin/env bash
set -euo pipefail

remote="${OPENHOUSE_UPSTREAM_REMOTE:-upstream}"
remote_url="${OPENHOUSE_UPSTREAM_URL:-https://github.com/chenhg5/cc-connect.git}"
integration_branch="${OPENHOUSE_INTEGRATION_BRANCH:-openhouse/integrate-cc-connect}"
remote_branch="${OPENHOUSE_UPSTREAM_BRANCH:-main}"

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

if [[ -n "$(git status --porcelain=v1)" ]]; then
  echo "Refusing to sync: working tree is not clean." >&2
  echo "Commit, stash, or move local changes before syncing OpenHouse." >&2
  exit 1
fi

if ! git remote get-url "$remote" >/dev/null 2>&1; then
  echo "Missing remote '$remote'." >&2
  echo "Add it with:" >&2
  echo "  git remote add $remote $remote_url" >&2
  echo "Then rerun this script." >&2
  exit 2
fi

echo "Fetching $remote..."
git fetch "$remote" --prune

if ! git show-ref --verify --quiet "refs/remotes/$remote/$remote_branch"; then
  echo "Remote branch '$remote/$remote_branch' was not found." >&2
  exit 3
fi

upstream_ref="$remote/$remote_branch"

if git show-ref --verify --quiet "refs/heads/$integration_branch"; then
  echo "Switching to existing integration branch '$integration_branch'."
  git switch "$integration_branch"
  echo "Fast-forwarding from '$upstream_ref' when possible."
  if git merge --ff-only "$upstream_ref"; then
    echo "Integration branch is up to date with $upstream_ref."
  else
    echo "Fast-forward was not possible." >&2
    echo "Resolve the upstream integration manually on '$integration_branch'." >&2
    exit 4
  fi
else
  echo "Creating integration branch '$integration_branch' from '$upstream_ref'."
  git switch -c "$integration_branch" "$upstream_ref"
fi

cat <<EOF

OpenHouse upstream sync complete.

Next steps:
  1. Replay or merge OpenHouse overlay commits onto '$integration_branch'.
  2. Keep SmallPhone-specific files under overlay/smallphone, config, docs, and scripts.
  3. Send generic Bridge, attachment, and config-validation improvements upstream.
EOF
