#!/usr/bin/env bash
# Run the curator right now, attached, so an audience can watch it work.
#
# Starts a fresh session from the same spec the cron trigger uses and drops you into the
# chat. Paste the prompt it prints. Detach with Ctrl-D; the session auto-pauses after
# 15 idle minutes. Remove it afterwards with `doctl agent remove <name>`.
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
load_env
require AGENT_NAME AGENT_MODEL AGENT_SIZE MODEL_ACCESS_KEY DO_API_TOKEN \
        SPACES_ACCESS_KEY SPACES_SECRET_KEY SPACES_REGION SPACES_BUCKET \
        KB_UUID KB_DATA_SOURCE_UUID GITHUB_OWNER APP_REPO
export SPACES_PREFIX="${SPACES_PREFIX:-docs}"
export AGENT_NAME="${AGENT_NAME}-live-$(date +%H%M%S)"   # session names must be unique per team

SPEC="$(render_agent_spec)"

banner "Prompt to paste once the session is READY"
echo
echo "  $TRIGGER_PROMPT"
echo
banner "Starting session $AGENT_NAME (about 10-15 s to first prompt)"
doctl agent start --spec "$SPEC" "$@"
