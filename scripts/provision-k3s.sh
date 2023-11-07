#!/bin/sh

set -ex

SCRIPT_DIR=$(dirname "${BASH_SOURCE[0]}")
. "$SCRIPT_DIR/config.sh"
. "$SCRIPT_DIR/helpers/vultr.sh"
. "$SCRIPT_DIR/helpers/digitalocean.sh"

# get external IP
EXTERNAL_IP=""
if [ "$VPS_PROVIDER" == "vultr" ]
then
  EXTERNAL_IP=$(vultr_get_instance_external_ip_by_label "$INSTANCE_LABEL")
else
  EXTERNAL_IP=$(digitalocean_get_droplet_external_ip_by_name "$DROPLET_NAME")
fi
# accept host SSH key
if ! grep -q "$EXTERNAL_IP" ~/.ssh/known_hosts
then
  echo "accepting ssh key to known_hosts"
  echo "#$EXTERNAL_IP" >> ~/.ssh/known_hosts
  ssh-keyscan -H "$EXTERNAL_IP" >> ~/.ssh/known_hosts
fi
# ensure user
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
# update + upgrade + autoremove + install dependencies
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
#ssh root@$EXTERNAL_IP "reboot"
# sleep
#sleep 60
# install k3s if not already installed
COMMAND=$(cat <<'EOF'
set -e
export USERNAME="debian" # TODO: do not hardcode, do sed {{}} templating?
# Check for kubectl binary
if ! command -v kubectl &> /dev/null
then
  # Download and install k3s if kubectl not found
  curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION='v1.28.2+k3s1' sh -
fi
# write user kubeconfig if not already written
if [ ! -f "/home/$USERNAME/.kube/config" ]
then
  KUBECONFIG=$(sudo k3s kubectl config view --raw)
  mkdir -p "/home/$USERNAME/.kube"
  echo "$KUBECONFIG" > "/home/$USERNAME/.kube/config"
  chmod 600 "/home/$USERNAME/.kube/config"
fi
EOF
)
ssh -t debian@$EXTERNAL_IP "$COMMAND" # allocate tty for sudo in k3s sh pipe
# TODO: wait for node ready
# TODO: wait for coredns ready
# deploy argocd
COMMAND=$(cat <<EOF
set -e
export KUBECONFIG="/home/debian/.kube/config" # TODO: do not hardcode username but can't mix and match variables with heredoc
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.9.0/manifests/install.yaml
kubectl wait deployment -n argocd argocd-server --for condition=Available=True --timeout=90s
EOF
)
ssh debian@$EXTERNAL_IP "$COMMAND"
# deploy tekton
COMMAND=$(cat <<EOF
set -e  
export KUBECONFIG="/home/debian/.kube/config" # TODO: do not hardcode username but can't mix and match variables with heredoc
# tekton pipeline deploy
kubectl create namespace tekton --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f https://storage.googleapis.com/tekton-releases/pipeline/latest/release.yaml
kubectl wait deployment -n tekton-pipelines tekton-pipelines-webhook --for condition=Available=True --timeout=90s
# deploy tekton tasks
kubectl apply -n tekton -f https://raw.githubusercontent.com/tektoncd/catalog/main/task/argocd-task-sync-and-wait/0.2/argocd-task-sync-and-wait.yaml
kubectl apply -n tekton -f https://raw.githubusercontent.com/tektoncd/catalog/main/task/kaniko/0.6/kaniko.yaml
kubectl apply -n tekton -f https://raw.githubusercontent.com/tektoncd/catalog/main/task/git-clone/0.9/git-clone.yaml
EOF
)
ssh debian@$EXTERNAL_IP "$COMMAND"
