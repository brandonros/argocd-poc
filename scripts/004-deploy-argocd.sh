#!/bin/bash
set -e
export KUBECONFIG=~/.kube/config
# create namespace
kubectl create namespace argocd
# install argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.6.7/manifests/install.yaml
# wait for it to roll out
kubectl wait deployment -n argocd argocd-server --for condition=Available=True --timeout=90s
# install argocd cli
wget https://github.com/argoproj/argo-cd/releases/download/v2.6.7/argocd-linux-amd64
chmod +x argocd-linux-amd64
sudo mv argocd-linux-amd64 /usr/local/bin/argocd
# install dependencies
sudo apt-get install -y jq
# log in to argocd
ARGOCD_SERVER_CLUSTER_IP=$(kubectl -n argocd get service/argocd-server -o=jsonpath='{.spec.clusterIP}')
ARGOCD_PASSWORD=$(kubectl --namespace argocd get secret argocd-initial-admin-secret -o json | jq -r '.data.password' | base64 -d)
argocd login $ARGOCD_SERVER_CLUSTER_IP:443 --username admin --password $ARGOCD_PASSWORD --insecure
