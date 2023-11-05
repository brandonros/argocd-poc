#!/bin/sh

set -e

SCRIPT_DIR=$(dirname "${BASH_SOURCE[0]}")
. "$SCRIPT_DIR/config.sh"
. "$SCRIPT_DIR/helpers/vultr.sh"

# ensure SSH key
echo "getting SSH key ID..."
SSH_KEY_ID=$(vultr_get_ssh_key_id_by_name "$KEY_NAME")
if [ "$SSH_KEY_ID" == "" ]
then
  echo "key does not already exist, creating..."
  vultr_create_ssh_key "$KEY_NAME" "$PUBLIC_KEY"
  SSH_KEY_ID=$(vultr_get_ssh_key_id_by_name "$KEY_NAME")
fi
echo "SSH_KEY_ID = $SSH_KEY_ID"
# ensure instance
echo "getting instance ID..."
INSTANCE_ID=$(vultr_get_instance_id_by_label "$INSTANCE_LABEL")
if [ "$INSTANCE_ID" == "" ]
then
  echo "instance does not already exist, creating..."
  vultr_create_instance "$INSTANCE_LABEL" "$INSTANCE_REGION" "$INSTANCE_PLAN" "$INSTANCE_OS_NAME" "$SSH_KEY_ID"
  echo "sleeping..." # TODO: poll status instead?
  sleep 60
  INSTANCE_ID=$(vultr_get_instance_id_by_label "$INSTANCE_LABEL")
fi
echo "INSTANCE_ID = $INSTANCE_ID"
# get external IP
echo "getting external IP..."
EXTERNAL_IP=$(vultr_get_instance_external_ip_by_label "$INSTANCE_LABEL")
if [ "$EXTERNAL_IP" == "" ]
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
