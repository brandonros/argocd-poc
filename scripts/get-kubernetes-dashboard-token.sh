#!/bin/sh

set -e

SCRIPT_DIR="$(dirname "$0")"
. "$SCRIPT_DIR/config.sh"
. "$SCRIPT_DIR/helpers/digitalocean.sh"
. "$SCRIPT_DIR/helpers/argocd.sh"

# get droplet external IP
echo "getting droplet external IP..."
EXTERNAL_IP=$(digitalocean_get_droplet_external_ip_by_name "$DROPLET_NAME")
if [ "$EXTERNAL_IP" == "null" ]
then
  echo "failed to get EXTERNAL_IP"
  exit 1
fi
# get token
echo "getting kubernetes dashboard token"
COMMAND=$(cat <<EOF
export KUBECONFIG="/home/debian/.kube/config"
kubectl -n kubernetes-dashboard create token admin-user
EOF
)
TOKEN=$(ssh -t debian@$EXTERNAL_IP "$COMMAND")
echo "$TOKEN"
