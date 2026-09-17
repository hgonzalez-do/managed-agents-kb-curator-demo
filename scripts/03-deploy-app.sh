#!/usr/bin/env bash
# Deploy (or update) the support chatbot on App Platform from app-platform/app.yaml.
# Prerequisite: the DigitalOcean GitHub app is authorized for $GITHUB_OWNER
# (App Platform -> Create App -> GitHub -> Manage Access) so deploy-on-push works.
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
load_env
require APP_NAME APP_REGION GITHUB_OWNER APP_REPO KB_UUID MODEL_ACCESS_KEY INFERENCE_MODEL
export DO_API_TOKEN_READ="${DO_API_TOKEN_READ:-$DO_API_TOKEN}"
[ "$DO_API_TOKEN_READ" != "$DO_API_TOKEN" ] || echo "NOTE: DO_API_TOKEN_READ is empty; the app will run with the full-access token. Use a GenAI-read scoped token for anything beyond a demo."

mkdir -p "$RENDERED_DIR"
SPEC="$RENDERED_DIR/app.yaml"
render "$ROOT/app-platform/app.yaml" > "$SPEC"

if [ -n "${APP_ID:-}" ]; then
  banner "Updating app $APP_ID"
  doctl apps update "$APP_ID" --spec "$SPEC" >/dev/null
else
  banner "Creating app '$APP_NAME'"
  APP_ID="$(doctl apps create --spec "$SPEC" -o json | jq -r '.[0].id')"
  save_state APP_ID "$APP_ID"
fi

banner "Deployment"
echo "  Follow progress: doctl apps list-deployments $APP_ID"
echo "  Waiting for the first deployment to become live (this can take a few minutes)..."
for _ in $(seq 1 60); do
  PHASE="$(doctl apps list-deployments "$APP_ID" -o json | jq -r '.[0].phase')"
  echo "  $(date -u +%H:%M:%S) $PHASE"
  case "$PHASE" in ACTIVE) break ;; ERROR|CANCELED) echo "Deployment failed. See: doctl apps logs $APP_ID --type build"; exit 1 ;; esac
  sleep 15
done

APP_URL="$(doctl apps get "$APP_ID" -o json | jq -r '.[0].live_url')"
save_state APP_URL "$APP_URL"
echo; echo "Chatbot is live: $APP_URL"
curl -sS "$APP_URL/api/health" | jq . || true
