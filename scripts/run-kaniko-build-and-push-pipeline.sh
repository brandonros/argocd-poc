#!/bin/sh

set -e

SCRIPT_DIR="$(dirname "$0")"
. "$SCRIPT_DIR/config.sh"
. "$SCRIPT_DIR/helpers/digitalocean.sh"
. "$SCRIPT_DIR/helpers/vultr.sh"
. "$SCRIPT_DIR/helpers/kaniko.sh"

# get external IP
EXTERNAL_IP=""
if [ "$VPS_PROVIDER" == "vultr" ]
then
  EXTERNAL_IP=$(vultr_get_instance_external_ip_by_label "$INSTANCE_LABEL")
else
  EXTERNAL_IP=$(digitalocean_get_droplet_external_ip_by_name "$DROPLET_NAME")
fi
# deploy and sync
GIT_URL=$1
IMAGE=$2
DOCKERFILE=$3
CONTEXT=$4
kaniko_build_and_push "$EXTERNAL_IP" "$GIT_URL" "$IMAGE" "$DOCKERFILE" "$CONTEXT"
