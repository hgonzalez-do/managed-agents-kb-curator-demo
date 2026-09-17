#!/usr/bin/env bash
# Create the Spaces bucket that backs the knowledge base and upload the current docs/.
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
load_env
require SPACES_REGION SPACES_BUCKET SPACES_ACCESS_KEY SPACES_SECRET_KEY APP_REPO_PATH
SPACES_PREFIX="${SPACES_PREFIX:-docs}"

export AWS_ACCESS_KEY_ID="$SPACES_ACCESS_KEY" AWS_SECRET_ACCESS_KEY="$SPACES_SECRET_KEY" AWS_DEFAULT_REGION=us-east-1
ENDPOINT="https://${SPACES_REGION}.digitaloceanspaces.com"

banner "Bucket s3://$SPACES_BUCKET ($SPACES_REGION)"
if aws s3api head-bucket --bucket "$SPACES_BUCKET" --endpoint-url "$ENDPOINT" 2>/dev/null; then
  echo "  already exists"
else
  aws s3api create-bucket --bucket "$SPACES_BUCKET" --endpoint-url "$ENDPOINT" >/dev/null
  echo "  created"
fi

banner "Initial docs upload"
DOCS_DIR="$APP_REPO_PATH/docs"; [ -d "$DOCS_DIR" ] || DOCS_DIR="$ROOT/$APP_REPO_PATH/docs"
aws s3 sync "$DOCS_DIR" "s3://$SPACES_BUCKET/$SPACES_PREFIX/" --endpoint-url "$ENDPOINT" --delete --exclude ".*" --acl private
echo "  synced $DOCS_DIR -> s3://$SPACES_BUCKET/$SPACES_PREFIX/"
