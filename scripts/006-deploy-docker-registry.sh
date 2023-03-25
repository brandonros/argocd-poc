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
# create configmap (auth can be empty/is not required)
kubectl delete configmap -n kaniko registry-auth 
kubectl create configmap -n kaniko registry-auth --from-file=/dev/stdin -- << EOF
{
  "auths": {
    "http://docker-registry.docker-registry.svc.cluster.local:5000/v2/": {
      "auth": ""
    },
    "http://docker-registry.docker-registry.svc:5000/v2/": {
      "auth": ""
    }
  }
}
EOF
# mark registry http instead of https
REGISTRIES_YAML=$(
cat <<EOF
mirrors:
  "docker-registry.docker-registry.svc:5000":
    endpoint:
      - "http://docker-registry.docker-registry.svc:5000"
  "docker-registry.docker-registry.svc.cluster.local:5000":
    endpoint:
      - "http://docker-registry.docker-registry.svc.cluster.local:5000"

EOF
)
echo "$REGISTRIES_YAML" | sudo tee /etc/rancher/k3s/registries.yaml 
# restart
sudo systemctl restart k3s 
