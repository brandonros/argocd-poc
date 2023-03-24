#!/bin/bash
set -e
export KUBECONFIG=~/.kube/config
# create namespace
kubectl create namespace elk
# deploy elasticsearch
argocd app create elasticsearch --repo https://github.com/elastic/helm-charts.git --revision "v8.5.1" --path elasticsearch --dest-namespace elk --dest-server https://kubernetes.default.svc --helm-set minimumMasterNodes=1 --helm-set replicas=1 --helm-set minimumMasterNodes=1 --helm-set resources.requests.cpu=0 --helm-set resources.requests.memory=0
argocd app sync elasticsearch
# wait for it to roll out
sleep 180 # TODO: use kubectl wait?
# deploy kibana
argocd app create kibana --repo https://github.com/elastic/helm-charts.git --revision "v8.5.1" --path kibana --dest-namespace elk --dest-server https://kubernetes.default.svc --helm-set resources.requests.cpu=0 --helm-set resources.requests.memory=0
argocd app sync kibana
# wait for it to roll out
sleep 180 # TODO: use kubectl wait?
