#!/usr/bin/env bash
# Check local tooling and credentials before creating anything.
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
load_env

banner "Tools"
for t in doctl gh aws jq python3 node git curl; do
  if command -v "$t" >/dev/null 2>&1; then echo "  ok   $t ($(command -v "$t"))"; else echo "  MISSING $t"; fail=1; fi
done
[ -z "${fail:-}" ] || { echo "Install the missing tools and re-run."; exit 1; }

banner "Required variables"
require DO_API_TOKEN MODEL_ACCESS_KEY SPACES_REGION SPACES_BUCKET SPACES_ACCESS_KEY SPACES_SECRET_KEY \
        KB_NAME KB_REGION GITHUB_OWNER APP_REPO APP_REPO_PATH APP_NAME APP_REGION
echo "  all set"

banner "DigitalOcean API"
doctl account get --format Email,Status --no-header | sed 's/^/  /'

banner "Serverless Inference"
curl -sS -o /dev/null -w "  GET /v1/models -> HTTP %{http_code}\n" \
  -H "Authorization: Bearer $MODEL_ACCESS_KEY" https://inference.do-ai.run/v1/models

banner "Managed Agents"
if doctl agent sizes >/dev/null 2>&1; then
  echo "  ok   doctl agent commands available and feature enabled ($(doctl version | head -1))"
else
  echo "  WARN: 'doctl agent' unavailable. Install the doctl beta build (set DOCTL_BETA_DIR in .env) and have Managed Agents enabled on your team."
fi

banner "GitHub"
gh auth status 2>&1 | sed 's/^/  /' | head -3

banner "App repo"
if [ -d "$ROOT/$APP_REPO_PATH/docs" ] || [ -d "$APP_REPO_PATH/docs" ]; then echo "  found $APP_REPO_PATH/docs"; else echo "  WARN: $APP_REPO_PATH/docs not found (clone $GITHUB_OWNER/$APP_REPO next to this repo)"; fi

echo; echo "Preflight complete."
