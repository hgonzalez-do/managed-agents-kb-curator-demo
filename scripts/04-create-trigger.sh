#!/usr/bin/env bash
# Render agent/spec.yaml, validate its policy, and create the weekly cron trigger that
# runs the curator unattended. Optionally also creates a GitHub webhook trigger.
#
# One-time prerequisites (see README):
#   - the doctl *beta* build with `doctl agent` commands
#   - `doctl agent auth github`  (connects the team's GitHub OAuth; needed for GITHUB_TOKEN: oauth/github)
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
load_env
require AGENT_NAME AGENT_MODEL AGENT_SIZE AGENT_CRON AGENT_TIMEZONE MODEL_ACCESS_KEY DO_API_TOKEN \
        SPACES_ACCESS_KEY SPACES_SECRET_KEY SPACES_REGION SPACES_BUCKET \
        KB_UUID KB_DATA_SOURCE_UUID GITHUB_OWNER APP_REPO OUTPUT_MODE
export SPACES_PREFIX="${SPACES_PREFIX:-docs}"

banner "Render spec"
SPEC="$(render_agent_spec)"
echo "  $SPEC  (contains secrets; .rendered/ is git-ignored)"

banner "Validate policy (no session started)"
do_api_yaml POST /agents/sessions/policy/validate "$SPEC" | jq . || true

banner "Cron trigger: $AGENT_CRON ($AGENT_TIMEZONE)"
OUT_ARGS=(--output-mode "$OUTPUT_MODE")
case "$OUTPUT_MODE" in
  email) require OUTPUT_EMAIL; OUT_ARGS+=(--output-email "$OUTPUT_EMAIL") ;;
  slack) require OUTPUT_SLACK_WEBHOOK; OUT_ARGS+=(--output-slack-webhook "$OUTPUT_SLACK_WEBHOOK") ;;
esac
doctl agent triggers create \
  --kind cron \
  --name "${AGENT_NAME}-weekly" \
  --session-mode fresh \
  --spec "$SPEC" \
  --prompt "$TRIGGER_PROMPT" \
  --cron-expr "$AGENT_CRON" \
  --timezone "$AGENT_TIMEZONE" \
  "${OUT_ARGS[@]}"

if [ "${TRIGGER_WEBHOOK:-false}" = "true" ]; then
  banner "Webhook trigger (GitHub 'release published' events)"
  echo "  The webhook URL and secret are printed ONCE below. Add them to"
  echo "  https://github.com/digitalocean/doctl/settings/hooks (or your fork) for event: Releases."
  doctl agent triggers create \
    --kind webhook \
    --name "${AGENT_NAME}-on-release" \
    --session-mode fresh \
    --spec "$SPEC" \
    --provider github \
    --prompt "A doctl release was just published: {{.release.tag_name}}. $TRIGGER_PROMPT" \
    "${OUT_ARGS[@]}"
fi

echo
echo "Triggers:"; doctl agent triggers list
echo
echo "Next: scripts/05-demo-rewind.sh to stage a gap, then scripts/06-run-curator-now.sh to watch a run live."
