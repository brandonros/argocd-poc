#!/bin/bash
# exit on errors
set -e
# load kubeconfig
export KUBECONFIG=~/.kube/config
# get registry IP
DOCKER_REGISTRY_CLUSTER_IP=$(kubectl -n docker-registry get service/docker-registry -o=jsonpath='{.spec.clusterIP}')
PORT=5000
EXTERNAL_REGISTRY_URL="$DOCKER_REGISTRY_CLUSTER_IP:$PORT" # do not use kubernetes internal DNS because kubernetes node does not pull from pod context aka no access to internal DNS
# variables
IMAGE_TAG="test:0.0.1"
# create namespace
kubectl create namespace test --dry-run=client -o yaml | kubectl apply -f -
# deploy
argocd app create test --repo "https://github.com/brandonros/argocd-poc.git" --path ./test/helm/ --dest-namespace test --dest-server https://kubernetes.default.svc --helm-set image.repository="$EXTERNAL_REGISTRY_URL" --helm-set image.tag="$IMAGE_TAG" --helm-set env.foo="bar" --upsert
argocd app sync test && argocd app wait test
