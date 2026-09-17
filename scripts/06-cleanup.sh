#!/usr/bin/env bash
# Tear down everything the demo created: app, knowledge base, Spaces bucket, agent session.
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
load_env

echo "This will delete:"
echo "  App Platform app:  ${APP_ID:-<none>}"
echo "  Knowledge base:    ${KB_UUID:-<none>}"
echo "  Spaces bucket:     s3://${SPACES_BUCKET:-<none>} (all objects)"
echo "  Managed Agent:     ${AGENT_NAME:-<none>} sessions (manual step, see below)"
read -r -p "Type 'delete' to continue: " ans
[ "$ans" = "delete" ] || { echo "Aborted."; exit 0; }

if [ -n "${APP_ID:-}" ]; then banner "App"; doctl apps delete "$APP_ID" --force && echo "  deleted"; fi
if [ -n "${KB_UUID:-}" ]; then banner "Knowledge base"; doctl gradient knowledge-base delete "$KB_UUID" --force && echo "  deleted"; fi
if [ -n "${SPACES_BUCKET:-}" ]; then
  banner "Spaces bucket"
  export AWS_ACCESS_KEY_ID="$SPACES_ACCESS_KEY" AWS_SECRET_ACCESS_KEY="$SPACES_SECRET_KEY" AWS_DEFAULT_REGION=us-east-1
  aws s3 rb "s3://$SPACES_BUCKET" --force --endpoint-url "https://${SPACES_REGION}.digitaloceanspaces.com" && echo "  deleted"
fi

banner "Managed Agent"
echo "  List and stop sessions with: doctl agent list && doctl agent stop <session-id>"

rm -f "$STATE_FILE"; rm -rf "$RENDERED_DIR"
echo; echo "Cleanup complete."
