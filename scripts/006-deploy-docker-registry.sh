#!/bin/bash
# exit on errors
set -e
# load kubeconfig
export KUBECONFIG=~/.kube/config
# create namespace
kubectl create namespace docker-registry --dry-run=client -o yaml | kubectl apply -f -
# deploy
argocd app create docker-registry --repo "https://github.com/twuni/docker-registry.helm.git" --path . --revision "d74c33abd95567d1641fbfe68f2db85b6135b064" --dest-namespace docker-registry --dest-server https://kubernetes.default.svc --helm-set autoscaling.maxReplicas=1
argocd app sync docker-registry && argocd app wait docker-registry
# mark registry http instead of https
CLUSTER_IP=$(kubectl -n docker-registry get service/docker-registry -o=jsonpath='{.spec.clusterIP}')
REGISTRIES_YAML=$(
cat <<EOF
mirrors:
  "$CLUSTER_IP:5000":
    endpoint:
      - "http://$CLUSTER_IP:5000"

EOF
)
echo "$REGISTRIES_YAML" | sudo tee /etc/rancher/k3s/registries.yaml 
# restart
sudo systemctl restart k3s 
