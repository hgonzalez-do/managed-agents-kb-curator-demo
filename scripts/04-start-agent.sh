#!/usr/bin/env bash
# Render agent/spec.yaml with your values and start the Managed Agent session.
#
# Managed Agents is in Private Preview. The `doctl agent` command set comes with the
# preview build referenced in the Design Partner Guide; the flags below follow that
# guide (`doctl agent start`). Adjust to your build if the CLI differs.
#
# Usage:
#   scripts/04-start-agent.sh            # start an interactive session (attach to it)
#   scripts/04-start-agent.sh --detach   # start in the background; cron trigger keeps it scheduled
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
load_env
require AGENT_NAME AGENT_MODEL AGENT_CRON MODEL_ACCESS_KEY DO_API_TOKEN \
        SPACES_ACCESS_KEY SPACES_SECRET_KEY SPACES_REGION SPACES_BUCKET \
        KB_UUID KB_DATA_SOURCE_UUID GITHUB_OWNER APP_REPO
export SPACES_PREFIX="${SPACES_PREFIX:-docs}"

mkdir -p "$RENDERED_DIR"
SPEC="$RENDERED_DIR/agent-spec.yaml"
render "$ROOT/agent/spec.yaml" > "$SPEC"
cp "$ROOT/agent/prompts/curator.md" "$RENDERED_DIR/curator.md"

banner "Rendered spec: $SPEC"
echo "  (secrets are passed via spec.secrets and stored in Secrets Manager; they are not echoed here)"

banner "Starting Managed Agent '$AGENT_NAME'"
doctl agent start --spec "$SPEC" "$@"

echo
echo "Useful follow-ups:"
echo "  doctl agent list                 # sessions and their state"
echo "  doctl agent attach <session-id>  # live terminal"
echo "  doctl agent trigger <session-id> # run the curator now instead of waiting for cron"
