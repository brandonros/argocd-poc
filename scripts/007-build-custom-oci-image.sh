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
# get context
git clone https://github.com/brandonros/argocd-poc.git
# build json overrides
OVERRIDES=$(
cat <<EOF
{
  "apiVersion": "v1",
  "spec": {
    "containers": [
      {
        "name": "kaniko",
        "image": "gcr.io/kaniko-project/executor:latest",
        "stdin": true,
        "stdinOnce": true,
        "args": [
          "--dockerfile=Dockerfile",
          "--context=tar://stdin",
          "--destination=$REGISTRY_URL/$IMAGE_TAG"
        ],
        "volumeMounts": [
          {
            "name": "registry-auth",
            "mountPath": "/kaniko/.docker/"
          }
        ]
      }
    ],
    "volumes": [
      {
        "name": "registry-auth",
        "configMap": {
          "name": "registry-auth"
        }
      }
    ]
  }
}
EOF
)
# tar context and send toi kubectl run which will pull kaniko executor image
tar -cf - argocd-poc/test/ | gzip -9 | kubectl run -n docker-registry \
  kaniko \
  --rm \
  --stdin=true \
  --image=gcr.io/kaniko-project/executor:latest \
  --restart=Never \
  --overrides="$OVERRIDES"
