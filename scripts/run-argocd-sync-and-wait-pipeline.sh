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
# get argocd password
echo "getting argocd password"
ARGOCD_PASSWORD=$(get_argocd_password "$EXTERNAL_IP")
# droplet pipeline run argocd sync + wait
echo "deploying argocd sync + wait pipeline run + waiting"
# sync
ARGOCD_APPLICATION_NAME=$1
sync_argocd_app "$EXTERNAL_IP" "$ARGOCD_APPLICATION_NAME" "$ARGOCD_PASSWORD"
