#!/bin/sh

set -e

SCRIPT_DIR=$(dirname "${BASH_SOURCE[0]}")
. "$SCRIPT_DIR/config.sh"
. "$SCRIPT_DIR/helpers/digitalocean.sh"
. "$SCRIPT_DIR/helpers/postgres.sh"

# get droplet external IP
echo "getting droplet external IP..."
EXTERNAL_IP=$(digitalocean_get_droplet_external_ip_by_name "$DROPLET_NAME")
if [ "$EXTERNAL_IP" == "null" ]
then
  echo "failed to get EXTERNAL_IP"
  exit 1
fi
# get postgres password
echo "getting postgres password"
POSTGRES_PASSWORD=$(get_postgres_password "$EXTERNAL_IP")
# run pipeline
POSTGRES_CONNECTION_STRING="postgres://postgres:$POSTGRES_PASSWORD@postgresql.postgresql.svc/"
QUERY="$1"
run_postgres_query "$EXTERNAL_IP" "$POSTGRES_CONNECTION_STRING" "$QUERY"
