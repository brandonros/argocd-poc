#!/bin/bash
# exit on errors
set -e
# load kubeconfig
export KUBECONFIG=~/.kube/config
# variables
REGISTRY_URL="docker-registry.docker-registry.svc.cluster.local:5000"
IMAGE_TAG="my-image:0.0.1"
REPO_URL="https://github.com/brandonros/argocd-poc.git"
BRANCH_NAME="master"
BUILD_CONTEXT_DIRECTORY="./test/"
# get repo
WORK_DIR=$(mktemp -d -p /tmp)
git clone --depth=1 --branch "$BRANCH_NAME" "$REPO_URL" "$WORK_DIR"
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
RANDOM_BYTES=$(echo $RANDOM | md5sum | head -c 10)
POD_NAME="kaniko-$RANDOM_BYTES"
DIRECTORY=$(realpath "$WORK_DIR/$BUILD_CONTEXT_DIRECTORY")
tar --create --file=- --verbose --directory="$DIRECTORY" --gzip index.mjs package.json package-lock.json Dockerfile .dockerignore | kubectl run -n kaniko \
  "$POD_NAME" \
  --rm \
  --stdin=true \
  --image=gcr.io/kaniko-project/executor:latest \
  --restart=Never \
  --overrides="$OVERRIDES"
# cleanup
rm -rf "$WORK_DIR"
