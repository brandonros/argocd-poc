#!/bin/sh

set -e

SCRIPT_DIR=$(dirname "${BASH_SOURCE[0]}")
. "$SCRIPT_DIR/config.sh"
. "$SCRIPT_DIR/helpers/digitalocean.sh"
. "$SCRIPT_DIR/helpers/vultr.sh"

# get external IP
EXTERNAL_IP=""
if [ "$VPS_PROVIDER" == "vultr" ]
then
  EXTERNAL_IP=$(vultr_get_instance_external_ip_by_label "$INSTANCE_LABEL")
else
  EXTERNAL_IP=$(digitalocean_get_droplet_external_ip_by_name "$DROPLET_NAME")
fi
# import kubectl config
echo "importing kubectl config"
ssh debian@$EXTERNAL_IP "cat /home/debian/.kube/config" > ~/.kube/config
# tunnel
echo "opening tunnel"
#autossh -M 0 -N -L 6443:localhost:6443 debian@$EXTERNAL_IP
ssh -L 6443:localhost:6443 -N -vvv debian@$EXTERNAL_IP
