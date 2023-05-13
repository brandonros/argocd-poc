#!/bin/sh

set -e

SCRIPT_DIR="$(dirname "$0")"
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
  sleep 30
  DROPLET_ID=$(digitalocean_get_droplet_id_by_name "$DROPLET_NAME")
fi
echo "DROPLET_ID = $DROPLET_ID"
# get droplet external IP
echo "getting droplet external IP..."
EXTERNAL_IP=$(digitalocean_get_droplet_external_ip_by_name "$NAME")
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
# accept host SSH key
if ! grep -q "$EXTERNAL_IP" ~/.ssh/known_hosts
then
  echo "accepting ssh key to known_hosts"
  echo "#$EXTERNAL_IP" >> ~/.ssh/known_hosts
  ssh-keyscan -H "$EXTERNAL_IP" >> ~/.ssh/known_hosts
fi
# ensure droplet user
USERNAME="debian"
PASSWORD="foobar123" # TODO: not great to hardcode a password
COMMAND=$(cat <<EOF
set -e
# Check if the user already exists
if id -u "$USERNAME" >/dev/null 2>&1
then
  echo "User $USERNAME already exists"
else
  useradd -m -d /home/$USERNAME -s /bin/bash -G sudo $USERNAME
  echo "$USERNAME:$PASSWORD" | chpasswd
  echo "User $USERNAME created"
  mkdir -p /home/$USERNAME/.ssh
  echo "$PUBLIC_KEY" >> /home/$USERNAME/.ssh/authorized_keys
  chown -R $USERNAME:$USERNAME /home/$USERNAME/.ssh
  chmod 700 /home/$USERNAME/.ssh
  chmod 600 /home/$USERNAME/.ssh/authorized_keys
fi
EOF
)
ssh root@$EXTERNAL_IP "$COMMAND"
# droplet update + upgrade + autoremove + install dependencies
COMMAND=$(cat <<EOF
set -e
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get upgrade -y
apt-get dist-upgrade -y
apt-get autoremove -y
apt-get install -y jq
EOF
)
ssh root@$EXTERNAL_IP "$COMMAND"
# TODO: poweroff + powercycle here to force new freshest kernel?
# droplet install k3s if not already installed
COMMAND=$(cat <<EOF
set -e
# Check for kubectl binary
if ! command -v kubectl &> /dev/null
then
  # Download and install k3s if kubectl not found
  curl -sfL https://get.k3s.io | sh -
fi
# write user kubeconfig if not already written
if [ ! -f "/home/$USERNAME/.kube/config" ]
then
  KUBECONFIG=\$(sudo k3s kubectl config view --raw)
  mkdir -p "/home/$USERNAME/.kube"
  echo "\$KUBECONFIG" > "/home/$USERNAME/.kube/config"
  chmod 600 "/home/$USERNAME/.kube/config"
fi
EOF
)
ssh -t debian@$EXTERNAL_IP "$COMMAND" # allocate tty for sudo in k3s sh pipe
# droplet deploy argocd
COMMAND=$(cat <<EOF
set -e
export KUBECONFIG="/home/debian/.kube/config" # TODO: do not hardcode username but can't mix and match variables with heredoc
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.6.7/manifests/install.yaml
kubectl wait deployment -n argocd argocd-server --for condition=Available=True --timeout=90s
EOF
)
ssh debian@$EXTERNAL_IP "$COMMAND"
# droplet deploy tekton
COMMAND=$(cat <<EOF
set -e  
export KUBECONFIG="/home/debian/.kube/config" # TODO: do not hardcode username but can't mix and match variables with heredoc
# tekton pipeline deploy
kubectl create namespace tekton --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f https://storage.googleapis.com/tekton-releases/pipeline/latest/release.yaml
kubectl wait deployment -n tekton-pipelines tekton-pipelines-webhook --for condition=Available=True --timeout=90s
# tekton argocd-task-sync-and-wait deploy
kubectl apply -n tekton -f https://raw.githubusercontent.com/tektoncd/catalog/main/task/argocd-task-sync-and-wait/0.2/argocd-task-sync-and-wait.yaml
EOF
)
ssh debian@$EXTERNAL_IP "$COMMAND"
