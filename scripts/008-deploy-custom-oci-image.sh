#!/bin/bash
# exit on errors
set -e
# load kubeconfig
export KUBECONFIG=~/.kube/config
# get registry IP
DOCKER_REGISTRY_CLUSTER_IP=$(kubectl -n docker-registry get service/docker-registry -o=jsonpath='{.spec.clusterIP}')
PORT=5000
REGISTRY_URL="$DOCKER_REGISTRY_CLUSTER_IP:$PORT"
# variables
IMAGE_TAG="my-image:0.0.1"
# create namespace
#kubectl create namespace test
# deploy
argocd app create test --repo "https://github.com/brandonros/argocd-poc.git" --path ./test/helm/ --dest-namespace test --dest-server https://kubernetes.default.svc --helm-set image.repository="$REGISTRY_URL" --helm-set image.tag="$IMAGE_TAG"
argocd app sync test
# wait for it to roll out
argocd app wait test
