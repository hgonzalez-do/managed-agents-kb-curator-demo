#!/usr/bin/env bash
# Stage a live demo: make the knowledge base "forget" the newest N doctl releases.
#
# It deletes the newest N release docs from the app repo, re-indexes the JSON/changelog,
# commits and pushes, re-syncs Spaces, and re-indexes the KB. After this, the chatbot
# cannot answer questions about those releases. Then trigger the curator agent and
# watch it bring the docs, the Spaces bucket and the knowledge base back up to date.
#
# Usage: scripts/05-demo-rewind.sh [N]   (default 1)
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
load_env
require APP_REPO_PATH KB_UUID KB_DATA_SOURCE_UUID SPACES_ACCESS_KEY SPACES_SECRET_KEY SPACES_REGION SPACES_BUCKET
N="${1:-1}"
APP_DIR="$APP_REPO_PATH"; [ -d "$APP_DIR" ] || APP_DIR="$ROOT/$APP_REPO_PATH"

banner "Rewinding docs by $N release(s) in $APP_DIR"
( cd "$APP_DIR"
  python3 scripts/releases.py rewind --count "$N"
  git add docs
  git commit -q -m "demo: rewind docs by $N release(s) to stage curator run" || echo "  nothing to commit"
  git push -q origin main
  echo "  pushed"
)

banner "Sync Spaces + re-index knowledge base"
export SPACES_PREFIX="${SPACES_PREFIX:-docs}"
"$APP_DIR/scripts/sync-docs-to-spaces.sh"
"$APP_DIR/scripts/reindex-kb.sh"

echo
echo "Staged. Docs are now current through: $(jq -r .last_processed_tag "$APP_DIR/docs/curator-state.json")"
echo "Ask the chatbot about the newest release (it should not know), then trigger the agent."
