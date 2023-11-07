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
# read from stdin
YAML=$(cat)
# apply
COMMAND=$(cat <<EOF
  export KUBECONFIG="/home/debian/.kube/config" # TODO: do not hardcode username but can't mix and match variables with heredoc
  echo "$YAML" | kubectl apply -f -
EOF
)
ssh debian@$EXTERNAL_IP "$COMMAND"
