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
# import kubectl config
echo "importing kubectl config"
ssh debian@$EXTERNAL_IP "cat /home/debian/.kube/config" > /tmp/kubeconfig
# tunnel
echo "opening tunnel"
autossh -M 0 -N -L 6443:localhost:6443 debian@$EXTERNAL_IP
