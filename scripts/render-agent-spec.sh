#!/usr/bin/env bash
# Render agent/spec.yaml (values from .env/.state.env, runbook spliced in as a skill) to
# .rendered/agent-spec.yaml and keep it, then print copy-paste `doctl agent` commands with
# absolute paths so they work from any directory.
# The rendered file contains secrets: it is git-ignored and mode 600. Delete it when done.
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
load_env
require AGENT_NAME AGENT_MODEL AGENT_SIZE MODEL_ACCESS_KEY DO_API_TOKEN SPACES_ACCESS_KEY SPACES_SECRET_KEY \
        SPACES_REGION SPACES_BUCKET KB_UUID KB_DATA_SOURCE_UUID GITHUB_OWNER APP_REPO
export SPACES_PREFIX="${SPACES_PREFIX:-docs}"

SPEC="$(render_agent_spec)"
PROMPT_FILE="$ROOT/agent/prompts/curator.md"
DOCTL="$(command -v doctl)"          # DOCTL_BETA_DIR (from .env) is already first on PATH
OUT_ARGS="--output-mode ${OUTPUT_MODE:-none}"
case "${OUTPUT_MODE:-none}" in
  email) OUT_ARGS="$OUT_ARGS --output-email ${OUTPUT_EMAIL:-you@example.com}" ;;
  slack) OUT_ARGS="$OUT_ARGS --output-slack-webhook ${OUTPUT_SLACK_WEBHOOK:-<webhook-url>}" ;;
esac

if [ -n "${GITHUB_FINE_GRAINED_PAT:-}" ]; then GH_MODE="fine-grained PAT (repo-scoped)"; else GH_MODE="oauth/github slot (accepted, not yet enforced in the preview: set GITHUB_FINE_GRAINED_PAT in .env for a working push)"; fi

cat <<TXT

Rendered spec : $SPEC
Runbook/prompt: $PROMPT_FILE
doctl binary  : $DOCTL ($("$DOCTL" version 2>/dev/null | head -1))
GitHub access : $GH_MODE

# 1) validate
"$DOCTL" agent validate "$SPEC"

# 2) preview the resolved manifest (secrets redacted, creates nothing)
"$DOCTL" agent start "$SPEC" --name ${AGENT_NAME}-live-1 --prompt "\$(cat $PROMPT_FILE)" --dry-run

# 3) run the curator now, attached  (add --on-hitl approve for headless)
"$DOCTL" agent start "$SPEC" --name ${AGENT_NAME}-live-1 --prompt "\$(cat $PROMPT_FILE)"

# 4) weekly cron trigger
"$DOCTL" agent triggers create --kind cron --name ${AGENT_NAME}-weekly --session-mode fresh \\
  --spec "$SPEC" --prompt "\$(cat $PROMPT_FILE)" \\
  --cron-expr "${AGENT_CRON:-0 9 * * 1}" --timezone ${AGENT_TIMEZONE:-UTC} $OUT_ARGS

# after editing the runbook: push the new prompt into an existing trigger
"$DOCTL" agent triggers update ${TRIGGER_ID:-<trigger-id>} --prompt "\$(cat $PROMPT_FILE)"

# afterwards
"$DOCTL" agent logs ${AGENT_NAME}-live-1
"$DOCTL" agent triggers list
"$DOCTL" agent remove ${AGENT_NAME}-live-1
TXT
