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
