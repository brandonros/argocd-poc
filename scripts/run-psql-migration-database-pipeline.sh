#!/bin/sh

set -e

SCRIPT_DIR=$(dirname "${BASH_SOURCE[0]}")
. "$SCRIPT_DIR/config.sh"
. "$SCRIPT_DIR/helpers/digitalocean.sh"
. "$SCRIPT_DIR/helpers/vultr.sh"
. "$SCRIPT_DIR/helpers/postgres.sh"

# get external IP
EXTERNAL_IP=""
if [ "$VPS_PROVIDER" == "vultr" ]
then
  EXTERNAL_IP=$(vultr_get_instance_external_ip_by_label "$INSTANCE_LABEL")
else
  EXTERNAL_IP=$(digitalocean_get_droplet_external_ip_by_name "$DROPLET_NAME")
fi
# get postgres password
echo "getting postgres password"
POSTGRES_PASSWORD=$(get_postgres_password "$EXTERNAL_IP")
# run pipeline
POSTGRES_CONNECTION_STRING="postgres://postgres:$POSTGRES_PASSWORD@postgresql.postgresql.svc/"
QUERY="$1"
run_postgres_query "$EXTERNAL_IP" "$POSTGRES_CONNECTION_STRING" "$QUERY"
