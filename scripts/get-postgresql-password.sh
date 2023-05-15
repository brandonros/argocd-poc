#!/bin/sh

set -e

SCRIPT_DIR=$(dirname "${BASH_SOURCE[0]}")
. "$SCRIPT_DIR/config.sh"
. "$SCRIPT_DIR/helpers/digitalocean.sh"

# get droplet external IP
echo "getting droplet external IP..."
EXTERNAL_IP=$(digitalocean_get_droplet_external_ip_by_name "$DROPLET_NAME")
if [ "$EXTERNAL_IP" == "null" ]
then
  echo "failed to get EXTERNAL_IP"
  exit 1
fi
# get password
COMMAND=$(cat <<EOF
  export KUBECONFIG="/home/debian/.kube/config"
  kubectl -n postgresql get secret postgresql -o json | jq -r '.data["postgres-password"]' | base64 --decode
EOF
)
OUTPUT=$(ssh -t debian@$EXTERNAL_IP "$COMMAND")
echo "$OUTPUT"
