#!/usr/bin/env bash
# Render agent/spec.yaml (values from .env/.state.env, runbook spliced in as a skill) to
# .rendered/agent-spec.yaml and keep it, so you can pass it to `doctl agent ...` by hand.
# The file contains secrets: it is git-ignored and mode 600. Delete it when done.
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
load_env
require AGENT_NAME AGENT_MODEL AGENT_SIZE MODEL_ACCESS_KEY DO_API_TOKEN SPACES_ACCESS_KEY SPACES_SECRET_KEY \
        SPACES_REGION SPACES_BUCKET KB_UUID KB_DATA_SOURCE_UUID GITHUB_OWNER APP_REPO
export SPACES_PREFIX="${SPACES_PREFIX:-docs}"
SPEC="$(render_agent_spec)"
echo "Rendered: $SPEC"
echo "Prompt:   $TRIGGER_PROMPT"
