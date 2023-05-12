#!/bin/sh

set -e

function digitalocean_get_ssh_key_id_by_name() {
  NAME=$1
  SSH_KEYS=$(curl --fail \
    -X GET \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $DIGITALOCEAN_TOKEN" \
    "https://api.digitalocean.com/v2/account/keys")
  SSH_KEY_ID=$(echo "$SSH_KEYS" | jq --arg NAME "$NAME" -r '.ssh_keys[] | select(.name==$NAME) | .id')
  if [ -z "$SSH_KEY_ID" ]
  then
    echo "null"
  else
    echo "$SSH_KEY_ID"
  fi
}

function digitalocean_get_droplet_id_by_name() {
  NAME=$1
  DROPLETS=$(curl --fail \
    -X GET \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $DIGITALOCEAN_TOKEN" \
    "https://api.digitalocean.com/v2/droplets")
  DROPLET_ID=$(echo "$DROPLETS" | jq --arg NAME "$NAME" -r '.droplets[] | select(.name==$NAME) | .id')
  if [ -z "$DROPLET_ID" ]
  then
    echo "null"
  else
    echo "$DROPLET_ID"
  fi
}

function digitalocean_get_droplet_external_ip_by_id() {
  ID=$1
  DROPLETS=$(curl --fail \
    -X GET \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $DIGITALOCEAN_TOKEN" \
    "https://api.digitalocean.com/v2/droplets")
  EXTERNAL_IP=$(echo "$DROPLETS" | jq --argjson ID "$ID" -r '.droplets[] | select(.id==$ID) | .networks.v4[] | select(.type=="public") | .ip_address')
  if [ -z "$EXTERNAL_IP" ]
  then
    echo "null"
  else
    echo "$EXTERNAL_IP"
  fi
}

function digitalocean_create_ssh_key() {
  NAME=$1
  PUBLIC_KEY=$2
  REQUEST_BODY=$(cat <<EOF
{
  "name": "$NAME",
  "public_key": "$PUBLIC_KEY"
}
EOF
)
  curl --fail \
    -X POST \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $DIGITALOCEAN_TOKEN" \
    -d "$REQUEST_BODY" \
    "https://api.digitalocean.com/v2/account/keys" 
}

function digitalocean_create_droplet() {
  NAME=$1
  SIZE=$2
  REGION=$3
  IMAGE=$4
  SSH_KEY_ID=$5
  REQUEST_BODY=$(cat <<EOF
{
  "name": "$NAME",
  "region": "$REGION",
  "size": "$SIZE",
  "image": "$IMAGE",
  "ssh_keys": [$SSH_KEY_ID],
  "backups": false,
  "ipv6": false,
  "monitoring": false,
  "tags": [],
  "user_data": ""
}
EOF
)
  curl --fail \
    -X POST \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $DIGITALOCEAN_TOKEN" \
    -d "$REQUEST_BODY" \
    "https://api.digitalocean.com/v2/droplets"
}

# ssh key
KEY_NAME="argocd-poc"
PUBLIC_KEY=$(cat ~/.ssh/id_rsa.pub) # TODO: check if exists/ssh-keygen already ran
# droplet
DROPLET_NAME="argocd-poc"
DROPLET_SIZE="s-2vcpu-4gb"
DROPLET_REGION="nyc3"
DROPLET_IMAGE="debian-11-x64"

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
EXTERNAL_IP=$(digitalocean_get_droplet_external_ip_by_id "$DROPLET_ID")
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
COMMAND=$(cat <<-'EOF'
set -e
# Check for kubectl binary
if ! command -v kubectl &> /dev/null
then
  # Download and install k3s if kubectl not found
  curl -sfL https://get.k3s.io | sh -
fi
# write user kubeconfig if not already written
USER_KUBE_PATH="/home/debian/.kube" # TODO: do not hardcode username but can't mix and match variables with heredoc
if [ ! -f "$USER_KUBE_PATH/config" ]
then
  KUBECONFIG=$(sudo k3s kubectl config view --raw)
  # Define user kube path (replace with the actual path)
  # Configure kubeconfig for user
  mkdir -p "$USER_KUBE_PATH"
  echo "$KUBECONFIG" > "$USER_KUBE_PATH/config"
  chmod 600 "$USER_KUBE_PATH/config"
fi
EOF
)
ssh -t debian@$EXTERNAL_IP "$COMMAND" # allocate tty for sudo in k3s sh pipe
# droplet deploy argocd
COMMAND=$(cat <<-'EOF'
set -e
export KUBECONFIG="/home/debian/.kube/config" # TODO: do not hardcode username but can't mix and match variables with heredoc
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.6.7/manifests/install.yaml
kubectl wait deployment -n argocd argocd-server --for condition=Available=True --timeout=90s
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o json | jq -r '.data.password' | base64 -d)
echo "ARGOCD_USERNAME: admin"
echo "ARGOCD_PASSWORD: $ARGOCD_PASSWORD"
EOF
)
ssh debian@$EXTERNAL_IP "$COMMAND"
# droplet deploy tekton
COMMAND=$(cat <<-'EOF'
set -e  
export KUBECONFIG="/home/debian/.kube/config" # TODO: do not hardcode username but can't mix and match variables with heredoc
# tekton pipeline deploy
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f https://storage.googleapis.com/tekton-releases/pipeline/latest/release.yaml
kubectl wait deployment -n tekton-pipelines tekton-pipelines-webhook --for condition=Available=True --timeout=90s
# tekton argocd-task-sync-and-wait deploy
kubectl apply -n tekton -f https://raw.githubusercontent.com/tektoncd/catalog/main/task/argocd-task-sync-and-wait/0.2/argocd-task-sync-and-wait.yaml
EOF
)
ssh debian@$EXTERNAL_IP "$COMMAND"
# droplet deploy argocd app (kubernetes-dashboard)
COMMAND=$(cat <<-'EOF'
set -e  
export KUBECONFIG="/home/debian/.kube/config" # TODO: do not hardcode username but can't mix and match variables with heredoc
YAML=$(cat <<-'INNER_EOF'
kind: Namespace
apiVersion: v1
metadata:
  name: kubernetes-dashboard
  labels:
    name: kubernetes-dashboard
---
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: kubernetes-dashboard
  namespace: argocd
spec:
  clusterResourceWhitelist:
  - group: '*'
    kind: '*'
  destinations:
  - namespace: kubernetes-dashboard
    server: https://kubernetes.default.svc
  orphanedResources:
    warn: false
  sourceRepos:
  - '*'
---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: kubernetes-dashboard
  namespace: argocd
spec:
  destination:
    server: https://kubernetes.default.svc
    namespace: kubernetes-dashboard
  project: kubernetes-dashboard
  source:
    repoURL: https://github.com/kubernetes/dashboard.git
    targetRevision: master
    path: charts/helm-chart/kubernetes-dashboard/
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kubernetes-dashboard
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: kubernetes-dashboard
INNER_EOF
)
echo "$YAML" | kubectl apply -f -
EOF
)
ssh -debian@$EXTERNAL_IP "$COMMAND"
# droplet pipelinerun argocd sync + wait
COMMAND=$(cat <<-'EOF'
set -e  
export KUBECONFIG="/home/debian/.kube/config" # TODO: do not hardcode username but can't mix and match variables with heredoc
# tekton pipeline + pipelinerun
YAML=$(cat <<-'INNER_EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-env-configmap
  namespace: tekton
data:
  ARGOCD_SERVER: argocd-server.argocd.svc:443
---
apiVersion: v1
kind: Secret
metadata:
  name: argocd-env-secret
  namespace: tekton
stringData:
  # choose one of username/password or auth token (TODO: do not hardcode password)
  ARGOCD_USERNAME: admin
  ARGOCD_PASSWORD: qokG1tJUkAobbKHA
---
apiVersion: tekton.dev/v1beta1
kind: Pipeline
metadata:
  name: argocd-pipeline
  namespace: tekton
spec:
  tasks:
    - name: sync-application
      taskRef:
        name: argocd-task-sync-and-wait
      params:
        - name: argocd-version
          value: v2.6.7
        - name: application-name
          value: kubernetes-dashboard
---
apiVersion: tekton.dev/v1beta1
kind: PipelineRun
metadata:
  name: argocd-pipelinerun
  namespace: tekton
spec:
  pipelineRef:
    name: argocd-pipeline
INNER_EOF
)
# cleanup any old?
kubectl delete --ignore-not-found=true -n tekton pipelinerun/argocd-pipelinerun
# apply new
echo "$YAML" | kubectl apply -f -
# wait for pipeline run
PIPELINERUN_NAME="argocd-pipelinerun"
while true
do
  status=$(kubectl get pipelinerun -n tekton $PIPELINERUN_NAME -o jsonpath='{.status.conditions[0].status}')
  if [ "$status" == "True" ]
  then
    echo "PipelineRun has completed successfully."
    break
  elif [ "$status" == "False" ]
  then
    echo "PipelineRun has failed."
    exit 1
  else
    echo "PipelineRun is still running."
    sleep 10
  fi
done
# get token to log in with
TOKEN=$(kubectl -n kubernetes-dashboard create token admin-user)
echo "TOKEN: $TOKEN"
EOF
)
ssh -t debian@$EXTERNAL_IP "$COMMAND"
# port forward
ssh -L 8443:127.0.0.1:8443 debian@$EXTERNAL_IP 'bash -c "KUBECONFIG=~/.kube/config kubectl port-forward svc/kubernetes-dashboard -n kubernetes-dashboard 8443:443"'
