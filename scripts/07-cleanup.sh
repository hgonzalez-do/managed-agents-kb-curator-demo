#!/usr/bin/env bash
# Tear down everything the demo created: triggers, sessions, app, knowledge base, bucket.
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
load_env

echo "This will delete:"
echo "  Managed Agent triggers/sessions named ${AGENT_NAME}*"
echo "  App Platform app:  ${APP_ID:-<none>}"
echo "  Knowledge base:    ${KB_UUID:-<none>}"
echo "  Spaces bucket:     s3://${SPACES_BUCKET:-<none>} (all objects)"
read -r -p "Type 'delete' to continue: " ans
[ "$ans" = "delete" ] || { echo "Aborted."; exit 0; }

if doctl agent --help >/dev/null 2>&1; then
  banner "Triggers"
  doctl agent triggers list --format TriggerID,Name --no-header | awk -v n="$AGENT_NAME" 'index($2,n)==1 {print $1}' \
    | while read -r id; do doctl agent triggers delete "$id" --force && echo "  trigger $id deleted"; done
  banner "Sessions"
  doctl agent list --format SessionID,Name --no-header | awk -v n="$AGENT_NAME" 'index($2,n)==1 {print $1}' \
    | while read -r id; do doctl agent remove "$id" && echo "  session $id removed"; done
fi
if [ -n "${APP_ID:-}" ]; then banner "App"; doctl apps delete "$APP_ID" --force && echo "  deleted"; fi
if [ -n "${KB_UUID:-}" ]; then banner "Knowledge base"; doctl gradient knowledge-base delete "$KB_UUID" --force && echo "  deleted"; fi
if [ -n "${SPACES_BUCKET:-}" ]; then
  banner "Spaces bucket"
  export AWS_ACCESS_KEY_ID="$SPACES_ACCESS_KEY" AWS_SECRET_ACCESS_KEY="$SPACES_SECRET_KEY" AWS_DEFAULT_REGION=us-east-1
  aws s3 rb "s3://$SPACES_BUCKET" --force --endpoint-url "https://${SPACES_REGION}.digitaloceanspaces.com" && echo "  deleted"
fi
rm -f "$STATE_FILE"; rm -rf "$RENDERED_DIR"
echo; echo "Cleanup complete."
