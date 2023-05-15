#!/bin/sh

SCRIPT_DIR=$(dirname "${BASH_SOURCE[0]}")
. "$SCRIPT_DIR/tekton.sh"

function get_postgres_password() {
  EXTERNAL_IP=$1
  COMMAND=$(cat <<EOF
    export KUBECONFIG="/home/debian/.kube/config"
    kubectl -n postgresql get secret postgresql -o json | jq -r '.data["postgres-password"]' | base64 --decode
EOF
)
  OUTPUT=$(ssh -t debian@$EXTERNAL_IP "$COMMAND")
  echo "$OUTPUT"
}

function run_postgres_query() {
  EXTERNAL_IP=$1
  POSTGRES_CONNECTION_STRING=$2
  QUERY=$3
  ENCODED_QUERY=$(echo "$QUERY" | base64)
  PIPELINE_YAML=$(cat $SCRIPT_DIR/../../yaml/templates/psql-migrate-database-pipeline.yaml)
  PIPELINE_YAML=$(echo "$PIPELINE_YAML" | sed "s#{{ENCODED_QUERY}}#$ENCODED_QUERY#g")
  PIPELINE_YAML=$(echo "$PIPELINE_YAML" | sed "s#{{POSTGRES_CONNECTION_STRING}}#$POSTGRES_CONNECTION_STRING#g")
  tekton_run_pipeline "$EXTERNAL_IP" "psql-migrate-database-pipeline-run" "$PIPELINE_YAML"
  get_tekton_pipeline_run_logs "$EXTERNAL_IP" "psql-migrate-database-pipeline-run"
}
