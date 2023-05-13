#!/bin/sh

set -e

SCRIPT_DIR="$(dirname "$0")"
. "$SCRIPT_DIR/config.sh"
. "$SCRIPT_DIR/helpers/digitalocean.sh"
. "$SCRIPT_DIR/helpers/kaniko.sh"

# get droplet external IP
echo "getting droplet external IP..."
EXTERNAL_IP=$(digitalocean_get_droplet_external_ip_by_name "$DROPLET_NAME")
if [ "$EXTERNAL_IP" == "null" ]
then
  echo "failed to get EXTERNAL_IP"
  exit 1
fi
# deploy and sync
GIT_URL=$1
IMAGE=$2
DOCKERFILE=$3
CONTEXT=$4
WORKSPACE_MOUNT_PATH=$5
kaniko_build_and_push "$EXTERNAL_IP" "$GIT_URL" "$IMAGE" "$DOCKERFILE" "$CONTEXT" "$WORKSPACE_MOUNT_PATH"
