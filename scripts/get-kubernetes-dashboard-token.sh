#!/bin/sh

set -e

SCRIPT_DIR=$(dirname "${BASH_SOURCE[0]}")
. "$SCRIPT_DIR/config.sh"
. "$SCRIPT_DIR/helpers/digitalocean.sh"
. "$SCRIPT_DIR/helpers/vultr.sh"
. "$SCRIPT_DIR/helpers/argocd.sh"

# get external IP
EXTERNAL_IP=""
if [ "$VPS_PROVIDER" == "vultr" ]
then
  EXTERNAL_IP=$(vultr_get_instance_external_ip_by_label "$INSTANCE_LABEL")
else
  EXTERNAL_IP=$(digitalocean_get_droplet_external_ip_by_name "$DROPLET_NAME")
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
