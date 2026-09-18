#!/usr/bin/env bash
# Render agent/spec.yaml, validate it, and create the weekly cron trigger that runs the
# curator unattended. Optionally also creates a GitHub webhook trigger.
#
# One-time prerequisites (see README):
#   - the doctl *beta* build with `doctl agent` commands (set DOCTL_BETA_DIR in .env if not on PATH)
#   - `doctl agent auth github`  (team GitHub OAuth; backs the GITHUB_TOKEN: oauth/github secret)
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
load_env
require AGENT_NAME AGENT_MODEL AGENT_SIZE AGENT_CRON AGENT_TIMEZONE MODEL_ACCESS_KEY DO_API_TOKEN \
        SPACES_ACCESS_KEY SPACES_SECRET_KEY SPACES_REGION SPACES_BUCKET \
        KB_UUID KB_DATA_SOURCE_UUID GITHUB_OWNER APP_REPO OUTPUT_MODE
export SPACES_PREFIX="${SPACES_PREFIX:-docs}"

banner "Render and validate spec"
SPEC="$(render_agent_spec)"          # expanded copy in .rendered/ (git-ignored, mode 600, removed on exit)
trap 'rm -f "$SPEC"' EXIT
doctl agent validate "$SPEC"

banner "Cron trigger '${AGENT_NAME}-weekly': $AGENT_CRON ($AGENT_TIMEZONE)"
OUT_ARGS=(--output-mode "$OUTPUT_MODE")
case "$OUTPUT_MODE" in
  email) require OUTPUT_EMAIL; OUT_ARGS+=(--output-email "$OUTPUT_EMAIL") ;;
  slack) require OUTPUT_SLACK_WEBHOOK; OUT_ARGS+=(--output-slack-webhook "$OUTPUT_SLACK_WEBHOOK") ;;
esac
TRIGGER_ID="$(doctl agent triggers create \
  --kind cron \
  --name "${AGENT_NAME}-weekly" \
  --session-mode fresh \
  --spec "$SPEC" \
  --prompt "$TRIGGER_PROMPT" \
  --cron-expr "$AGENT_CRON" \
  --timezone "$AGENT_TIMEZONE" \
  "${OUT_ARGS[@]}" \
  --format TriggerID --no-header)"
save_state TRIGGER_ID "$TRIGGER_ID"

if [ "${TRIGGER_WEBHOOK:-false}" = "true" ]; then
  banner "Webhook trigger '${AGENT_NAME}-on-release' (GitHub 'release published' events)"
  echo "  The webhook URL and secret are shown ONCE. Add them to a repo's Settings -> Webhooks"
  echo "  (event: Releases). Rotate later with: doctl agent triggers rotate-secret <id>"
  doctl agent triggers create \
    --kind webhook \
    --name "${AGENT_NAME}-on-release" \
    --session-mode fresh \
    --spec "$SPEC" \
    --provider github \
    --prompt "A doctl release was just published: {{.release.tag_name}}. $TRIGGER_PROMPT" \
    "${OUT_ARGS[@]}"
fi

banner "Triggers"
doctl agent triggers list --format TriggerID,Name,Kind,Status,NextRunAt
echo
echo "Each firing is an execution:  doctl agent triggers list-executions $TRIGGER_ID"
echo "Next: scripts/05-demo-rewind.sh to stage a gap, then scripts/06-run-curator-now.sh to watch a run live."
