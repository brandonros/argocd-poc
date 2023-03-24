#!/bin/bash
# exit on errors
set -e
# load kubeconfig
export KUBECONFIG=~/.kube/config
# create namespace
kubectl create namespace docker-registry
# deploy
argocd app create docker-registry --repo "https://github.com/twuni/docker-registry.helm.git" --path . --revision "d74c33abd95567d1641fbfe68f2db85b6135b064" --dest-namespace docker-registry --dest-server https://kubernetes.default.svc --helm-set autoscaling.maxReplicas=1
argocd app sync docker-registry
# wait for it to roll out
argocd app wait docker-registry
# get registry IP
DOCKER_REGISTRY_CLUSTER_IP=$(kubectl -n docker-registry get service/docker-registry -o=jsonpath='{.spec.clusterIP}')
PORT=5000
REGISTRY_URL="$DOCKER_REGISTRY_CLUSTER_IP:$PORT"
# create configmap (auth can be empty/is not required)
kubectl create configmap -n docker-registry registry-auth --from-file=/dev/stdin -- << EOF
{
  "auths": {
    "http://$REGISTRY_URL/v2/": {
      "auth": ""
    }
  }
}
EOF
# TODO: mark registry as insecure with k3s
# sudo cat /etc/rancher/k3s/registries.yaml 
#mirrors:
#  "10.43.129.67:5000":
#    endpoint:
#      - "http://10.43.129.67:5000"
# restart
sudo systemctl restart k3s 
