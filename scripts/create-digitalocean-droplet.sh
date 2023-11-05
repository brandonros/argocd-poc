#!/bin/sh

set -e

SCRIPT_DIR=$(dirname "${BASH_SOURCE[0]}")
. "$SCRIPT_DIR/config.sh"
. "$SCRIPT_DIR/helpers/digitalocean.sh"

# ensure SSH key
echo "getting SSH key ID..."
SSH_KEY_ID=$(digitalocean_get_ssh_key_id_by_name "$KEY_NAME")
if [ "$SSH_KEY_ID" == "null" ]
then
  echo "key does not already exist, creating..."
  digitalocean_create_ssh_key "$KEY_NAME" "$PUBLIC_KEY"
  SSH_KEY_ID=$(digitalocean_get_ssh_key_id_by_name "$KEY_NAME")
fi
echo "SSH_KEY_ID = $SSH_KEY_ID"
# ensure droplet
echo "getting droplet ID..."
DROPLET_ID=$(digitalocean_get_droplet_id_by_name "$DROPLET_NAME")
if [ "$DROPLET_ID" == "null" ]
then
  echo "droplet does not already exist, creating..."
  digitalocean_create_droplet "$DROPLET_NAME" "$DROPLET_SIZE" "$DROPLET_REGION" "$DROPLET_IMAGE" "$SSH_KEY_ID"
  echo "sleeping..." # TODO: poll status instead?
  sleep 60
  DROPLET_ID=$(digitalocean_get_droplet_id_by_name "$DROPLET_NAME")
fi
echo "DROPLET_ID = $DROPLET_ID"
# get droplet external IP
echo "getting droplet external IP..."
EXTERNAL_IP=$(digitalocean_get_droplet_external_ip_by_name "$DROPLET_NAME")
if [ "$EXTERNAL_IP" == "null" ]
then
  echo "failed to get EXTERNAL_IP"
  exit 1
fi
echo "EXTERNAL_IP = $EXTERNAL_IP"
# wait for host to be up by checking ssh port 22
echo "Waiting for $EXTERNAL_IP to come online..."
PORT=22
while ! nc -z -v -w5 $EXTERNAL_IP $PORT
do
  sleep 5
done
echo "$EXTERNAL_IP is online."
