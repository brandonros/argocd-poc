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
IMAGE_TAG="test:0.0.5"
# create namespace
kubectl create namespace test --dry-run=client -o yaml | kubectl apply -f -
# deploy
ELASTICSEARCH_USERNAME=$(kubectl -n elk get secret elasticsearch-master-credentials -o json | jq -r '.data.username' | base64 -d)
ELASTICSEARCH_PASSWORD=$(kubectl -n elk get secret elasticsearch-master-credentials -o json | jq -r '.data.password' | base64 -d)
argocd app create test \
  --repo "https://github.com/brandonros/argocd-poc.git" \
  --path ./test/helm/ \
  --dest-namespace test \
  --dest-server https://kubernetes.default.svc \
  --helm-set image.repository="$EXTERNAL_REGISTRY_URL" \
  --helm-set image.tag="$IMAGE_TAG" \
  --helm-set env.ELASTICSEARCH_USERNAME="$ELASTICSEARCH_USERNAME" \
  --helm-set env.ELASTICSEARCH_PASSWORD="$ELASTICSEARCH_PASSWORD" \
  --helm-set env.ELASTICSEARCH_URL="https://elasticsearch-master-headless.elk.svc.cluster.local:9200" \
  --upsert
argocd app sync test && argocd app wait test
