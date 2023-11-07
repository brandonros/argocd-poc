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
# apply
COMMAND=$(cat <<'EOF'
set -e
export KUBECONFIG="/home/debian/.kube/config"
if ! grep -q "docker-registry" /etc/hosts
then
  DOCKER_REGISTRY_IP=$(kubectl -n docker-registry get service/docker-registry -o=jsonpath='{.spec.clusterIP}')
  echo "$DOCKER_REGISTRY_IP docker-registry" | sudo tee -a /etc/hosts
  YAML=$(cat <<INNER_EOF
  mirrors:
    "docker-registry:5000":
      endpoint:
        - "http://docker-registry:5000"
INNER_EOF
  )
  echo "$YAML" | sudo tee /etc/rancher/k3s/registries.yaml
  sudo systemctl restart k3s
fi
EOF
)
ssh -t debian@$EXTERNAL_IP "$COMMAND"
