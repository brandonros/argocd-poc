#!/bin/sh

set -e

SCRIPT_DIR=$(dirname "${BASH_SOURCE[0]}")
. "$SCRIPT_DIR/config.sh"
. "$SCRIPT_DIR/helpers/digitalocean.sh"
. "$SCRIPT_DIR/helpers/tekton.sh"

# get droplet external IP
echo "getting droplet external IP..."
EXTERNAL_IP=$(digitalocean_get_droplet_external_ip_by_name "$DROPLET_NAME")
if [ "$EXTERNAL_IP" == "null" ]
then
  echo "failed to get EXTERNAL_IP"
  exit 1
fi
# run pipeline
QUERY="SELECT 1"
ENCODED_QUERY=$(echo "$QUERY" | base64)
POSTGRES_CONNECTION_STRING="postgres://postgres:GmDZGeoTxb@postgresql.postgresql.svc/" # TODO: get password dynamically
PIPELINE_YAML=$(cat $SCRIPT_DIR/../yaml/pipelines/psql-migrate-database.yaml)
PIPELINE_YAML=$(echo "$PIPELINE_YAML" | sed "s#{{ENCODED_QUERY}}#$ENCODED_QUERY#g")
PIPELINE_YAML=$(echo "$PIPELINE_YAML" | sed "s#{{POSTGRES_CONNECTION_STRING}}#$POSTGRES_CONNECTION_STRING#g")
tekton_run_pipeline "$EXTERNAL_IP" "psql-migrate-database-pipeline-run" "$PIPELINE_YAML"
get_tekton_pipeline_run_logs "$EXTERNAL_IP" "psql-migrate-database-pipeline-run"
