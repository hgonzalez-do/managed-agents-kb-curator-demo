#!/usr/bin/env bash
# Run the curator right now so an audience can watch it work.
#
#   scripts/06-run-curator-now.sh              attended: creates a session from the same spec the
#                                              cron uses, sends the prompt, drops you into the chat
#   scripts/06-run-curator-now.sh --headless   unattended: no TUI, approvals auto-resolved, exits
#                                              when the run finishes (what a trigger firing does)
#   scripts/06-run-curator-now.sh --dry-run    print the fully resolved manifest (secrets redacted)
#
# Afterwards: doctl agent logs <name> replays the transcript; doctl agent remove <name> tears it down.
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
load_env
require AGENT_NAME AGENT_MODEL AGENT_SIZE MODEL_ACCESS_KEY DO_API_TOKEN \
        SPACES_ACCESS_KEY SPACES_SECRET_KEY SPACES_REGION SPACES_BUCKET \
        KB_UUID KB_DATA_SOURCE_UUID GITHUB_OWNER APP_REPO CURATOR_REPO
export SPACES_PREFIX="${SPACES_PREFIX:-docs}"

SESSION="${AGENT_NAME}-live-$(date +%H%M%S)"     # session names must be unique per team
SPEC="$(render_agent_spec)"
trap 'rm -f "$SPEC"' EXIT

MODE_ARGS=()
case "${1:-}" in
  --headless) MODE_ARGS=(--on-hitl approve) ;;
  --dry-run)  MODE_ARGS=(--dry-run) ;;
esac

banner "Session $SESSION  (about 10-15 s to first prompt)"
echo "  prompt: full runbook from agent/prompts/curator.md"
echo
doctl agent start "$SPEC" --name "$SESSION" --prompt "$TRIGGER_PROMPT" "${MODE_ARGS[@]}"
