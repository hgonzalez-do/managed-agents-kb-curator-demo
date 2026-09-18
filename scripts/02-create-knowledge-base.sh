#!/usr/bin/env bash
# Create a Gradient Knowledge Base with the Spaces bucket as its data source,
# then wait for the first indexing job. Saves KB_UUID and KB_DATA_SOURCE_UUID.
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
load_env
require KB_NAME KB_REGION SPACES_BUCKET SPACES_REGION
SPACES_PREFIX="${SPACES_PREFIX:-docs}"

banner "Project"
if [ -z "${DO_PROJECT_ID:-}" ]; then
  DO_PROJECT_ID="$(doctl projects list -o json | jq -r '.[] | select(.is_default==true) | .id')"
fi
echo "  DO_PROJECT_ID=$DO_PROJECT_ID"

banner "Embedding model"
if [ -z "${KB_EMBEDDING_MODEL_UUID:-}" ]; then
  KB_EMBEDDING_MODEL_UUID="$(doctl gradient list-models -o json \
    | jq -r '(if type=="array" then . else (.models // []) end) | .[] | select((.name // "") | test("gte large"; "i")) | .uuid' | head -1)"
fi
[ -n "$KB_EMBEDDING_MODEL_UUID" ] || { echo "Could not find an embedding model; set KB_EMBEDDING_MODEL_UUID in .env" >&2; exit 1; }
echo "  KB_EMBEDDING_MODEL_UUID=$KB_EMBEDDING_MODEL_UUID"

banner "Create knowledge base '$KB_NAME' in $KB_REGION"
if [ -n "${KB_UUID:-}" ]; then
  echo "  KB_UUID already set ($KB_UUID); skipping create"
else
  DATA_SOURCES="$(jq -cn --arg b "$SPACES_BUCKET" --arg p "$SPACES_PREFIX/" --arg r "$SPACES_REGION" \
    '[{spaces_data_source:{bucket_name:$b,item_path:$p,region:$r}}]')"
  CREATED="$(doctl gradient knowledge-base create \
    --name "$KB_NAME" --region "$KB_REGION" --project-id "$DO_PROJECT_ID" \
    --embedding-model-uuid "$KB_EMBEDDING_MODEL_UUID" \
    --data-sources "$DATA_SOURCES" -o json)"
  KB_UUID="$(printf '%s' "$CREATED" | jq -r 'if type=="array" then .[0].uuid else (.knowledge_base.uuid // .uuid) end')"
  [ -n "$KB_UUID" ] && [ "$KB_UUID" != "null" ] || { echo "Create failed:"; echo "$CREATED"; exit 1; }
  save_state KB_UUID "$KB_UUID"
fi

banner "Data source"
KB_DATA_SOURCE_UUID="$(do_api GET "/gen-ai/knowledge_bases/$KB_UUID/data_sources" | jq -r '.knowledge_base_data_sources[0].uuid')"
save_state KB_DATA_SOURCE_UUID "$KB_DATA_SOURCE_UUID"

banner "Initial indexing job"
JOB="$(start_kb_index "$KB_UUID" "$KB_DATA_SOURCE_UUID")"
[ -n "$JOB" ] || { echo "Could not start an indexing job" >&2; exit 1; }
wait_for_kb_index "$JOB"

banner "Smoke-test retrieval"
curl -sS -X POST "https://kbaas.do-ai.run/v1/$KB_UUID/retrieve" \
  -H "Authorization: Bearer $DO_API_TOKEN" -H "Content-Type: application/json" \
  -d '{"query":"What is the latest doctl release?","num_results":2,"alpha":0.5}' \
  | jq '{total_results, first: .results[0].metadata.item_name}'
echo; echo "Knowledge base ready: $KB_UUID"
