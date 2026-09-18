#!/usr/bin/env bash
# Shared helpers. Sourced by every numbered script; not meant to be run directly.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
ENV_FILE="${ENV_FILE:-$ROOT/.env}"
STATE_FILE="${STATE_FILE:-$ROOT/.state.env}"
RENDERED_DIR="$ROOT/.rendered"
DO_API="https://api.digitalocean.com/v2"

load_env() {
  if [ ! -f "$ENV_FILE" ]; then
    echo "No $ENV_FILE found. Copy .env.example to .env and fill it in." >&2
    exit 1
  fi
  set -a
  # shellcheck disable=SC1090
  . "$ENV_FILE"
  [ -f "$STATE_FILE" ] && . "$STATE_FILE"
  set +a
  export DIGITALOCEAN_ACCESS_TOKEN="${DIGITALOCEAN_ACCESS_TOKEN:-$DO_API_TOKEN}"   # doctl reads this
  # Managed Agents commands live in the doctl beta build. Point DOCTL_BETA_DIR at the folder
  # holding that binary to prefer it over the doctl on your PATH.
  [ -n "${DOCTL_BETA_DIR:-}" ] && export PATH="$DOCTL_BETA_DIR:$PATH"
  return 0
}

require() {
  local missing=0
  for v in "$@"; do
    if [ -z "${!v:-}" ]; then echo "Missing required variable: $v (set it in $ENV_FILE)" >&2; missing=1; fi
  done
  [ "$missing" -eq 0 ] || exit 1
}

# save_state KEY VALUE  — persist generated IDs so later scripts can use them.
save_state() {
  touch "$STATE_FILE"
  { grep -v "^$1=" "$STATE_FILE" || true; echo "$1=$2"; } > "$STATE_FILE.tmp"
  mv "$STATE_FILE.tmp" "$STATE_FILE"
  export "$1=$2"
  echo "  saved $1=$2 -> $STATE_FILE"
}

# render TEMPLATE  — substitute ${VAR} placeholders from the environment, print to stdout.
render() {
  python3 -c 'import os,sys; print(os.path.expandvars(sys.stdin.read()), end="")' < "$1"
}

do_api() {  # do_api METHOD PATH [JSON_BODY]
  local method="$1" path="$2" body="${3:-}"
  if [ -n "$body" ]; then
    curl -sS -X "$method" -H "Authorization: Bearer $DO_API_TOKEN" -H "Content-Type: application/json" "$DO_API$path" -d "$body"
  else
    curl -sS -X "$method" -H "Authorization: Bearer $DO_API_TOKEN" "$DO_API$path"
  fi
}

# wait_for_kb_index KB_UUID [TIMEOUT_SECONDS] — poll the KB's last indexing job.
wait_for_kb_index() {
  local kb="$1" timeout="${2:-900}" start status
  start=$(date +%s)
  echo "Waiting for knowledge base $kb to finish indexing..."
  while :; do
    status="$(do_api GET "/gen-ai/knowledge_bases/$kb" | jq -r '.knowledge_base.last_indexing_job | "\(.status // "PENDING") \(.phase // "")"')"
    echo "  $(date -u +%H:%M:%S) $status"
    case "$status" in
      *COMPLETED*) return 0 ;;
      *FAILED*|*CANCEL*) echo "Indexing did not complete: $status" >&2; return 1 ;;
    esac
    if [ $(( $(date +%s) - start )) -ge "$timeout" ]; then echo "Timed out waiting for indexing." >&2; return 1; fi
    sleep 15
  done
}

banner() { printf '\n==> %s\n' "$*"; }

# The message every trigger (and the live run) sends to the agent. The details live in the
# doctl-docs-curator skill embedded in the spec.
TRIGGER_PROMPT="Use the doctl-docs-curator skill. Check for new doctl releases, update the docs, push, sync Spaces, re-index the knowledge base, and finish with the run report."

# render_agent_spec — expand ${VARS} in agent/spec.yaml and splice in the runbook as a skill.
# Prints the path of the rendered file.
render_agent_spec() {
  mkdir -p "$RENDERED_DIR"
  local out="$RENDERED_DIR/agent-spec.yaml"
  python3 - "$ROOT/agent/spec.yaml" "$ROOT/agent/prompts/curator.md" "$out" <<'PY'
import os, sys, textwrap
tpl, runbook, out = sys.argv[1:4]
spec = os.path.expandvars(open(tpl).read())
skill = textwrap.indent(open(runbook).read().rstrip("\n"), "      ")
open(out, "w").write(spec.replace("__CURATOR_RUNBOOK__", skill))
os.chmod(out, 0o600)
PY
  echo "$out"
}

do_api_yaml() {  # do_api_yaml METHOD PATH FILE  — POST a YAML body
  curl -sS -X "$1" -H "Authorization: Bearer $DO_API_TOKEN" -H "Content-Type: application/x-yaml" --data-binary @"$3" "$DO_API$2"
}
