#!/usr/bin/env bash
# Deploy (or update) the support chatbot on App Platform from app-platform/app.yaml.
# APP_SOURCE=github (deploy on push) needs the DigitalOcean GitHub integration linked to your
# account (App Platform -> Create App -> GitHub). APP_SOURCE=git clones the public URL instead.
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
load_env
require APP_NAME APP_REGION GITHUB_OWNER APP_REPO KB_UUID MODEL_ACCESS_KEY INFERENCE_MODEL
export DO_API_TOKEN_READ="${DO_API_TOKEN_READ:-$DO_API_TOKEN}"
[ "$DO_API_TOKEN_READ" != "$DO_API_TOKEN" ] || echo "NOTE: DO_API_TOKEN_READ is empty; the app will run with the full-access token. Use a GenAI-read scoped token for anything beyond a demo."

mkdir -p "$RENDERED_DIR"
SPEC="$RENDERED_DIR/app.yaml"
case "${APP_SOURCE:-github}" in
  github) TEMPLATE="$ROOT/app-platform/app.yaml" ;;             # deploy on push; needs GitHub linked to DO
  git)    TEMPLATE="$ROOT/app-platform/app.public-git.yaml" ;;  # public clone URL; no GitHub link needed
  *) echo "APP_SOURCE must be github or git" >&2; exit 1 ;;
esac
echo "Using $TEMPLATE (APP_SOURCE=${APP_SOURCE:-github})"
render "$TEMPLATE" > "$SPEC"

if [ -n "${APP_ID:-}" ]; then
  banner "Updating app $APP_ID"
  doctl apps update "$APP_ID" --spec "$SPEC" >/dev/null
else
  banner "Creating app '$APP_NAME'"
  ERR="$RENDERED_DIR/create.err"
  CREATED="$(doctl apps create --spec "$SPEC" -o json 2>"$ERR")" || true
  APP_ID="$(printf '%s' "$CREATED" | jq -r 'if type=="array" then .[0].id else (.app.id // .id // empty) end' 2>/dev/null || true)"
  if [ -z "$APP_ID" ]; then
    echo "Create failed: $(cat "$ERR" | head -c 400) $(printf '%s' "$CREATED" | head -c 400)" >&2
    echo "Hint: 'GitHub user not authenticated' means GitHub is not linked to your DO account (App Platform -> Create App -> GitHub). Either link it, or set APP_SOURCE=git in .env." >&2
    exit 1
  fi
  save_state APP_ID "$APP_ID"
fi

banner "Deployment"
echo "  Follow progress: doctl apps list-deployments $APP_ID"
echo "  Waiting for the first deployment to become live (this can take a few minutes)..."
for _ in $(seq 1 60); do
  PHASE="$(doctl apps list-deployments "$APP_ID" -o json | jq -r 'if type=="array" then .[0].phase else .phase end')"
  echo "  $(date -u +%H:%M:%S) $PHASE"
  case "$PHASE" in ACTIVE) break ;; ERROR|CANCELED) echo "Deployment failed. See: doctl apps logs $APP_ID --type build"; exit 1 ;; esac
  sleep 15
done

APP_URL="$(doctl apps get "$APP_ID" -o json | jq -r 'if type=="array" then .[0].live_url else .live_url end')"
save_state APP_URL "$APP_URL"
echo; echo "Chatbot is live: $APP_URL"
curl -sS "$APP_URL/api/health" | jq . || true
