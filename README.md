# k3s-poc
Building + deploying OCI images + dependencies through DigitalOcean + Bash + Helm + ArgoCD + k3s + Tekton + Kaniko

## Pre-requisites

```shell
# generate SSH key
ssh-keygen -b 2048 -t rsa -f ~/.ssh/id_rsa -q -N ''
# sign up for DigitalOcean account at https://cloud.digitalocean.com/registrations/new and add payment method for Linux-based virtual machine hosting
# set DIGITALOCEAN_TOKEN from https://cloud.digitalocean.com/account/api/tokens
echo 'export DIGITIALOCEAN_TOKEN="PASTE_TOKEN_HERE"' >> ~/.zprofile
source ~/.zprofile
```

## Run deploy script

```shell
# clone git repo locally
git clone https://github.com/brandonros/argocd-poc.git
# cd into repo folder
cd argocd-poc
# run from repo directory
./scripts/provision-droplet.sh
./scripts/get-kubernetes-dashboard-token.sh
./scripts/deploy-and-sync-argocd-app.sh "kubernetes-dashboard"
./scripts/deploy-and-sync-argocd-app.sh "jaeger"
./scripts/deploy-and-sync-argocd-app.sh "loki-stack"
./scripts/deploy-and-sync-argocd-app.sh "redis"
./scripts/deploy-and-sync-argocd-app.sh "kube-prometheus-stack"
./scripts/deploy-and-sync-argocd-app.sh "docker-registry"

./scripts/build-and-push-app.sh "https://github.com/brandonros/k3s-poc.git" "docker-registry.docker-registry.svc.cluster.local:5000/nodejs-poc-app:0.0.1" "./Dockerfile" "./nodejs-poc-app"
./scripts/deploy-and-sync-argocd-app.sh "nodejs-poc-app"
```

## Tunneling

```shell
brew install txn2/tap/kubefwd
brew install autossh
./scripts/tunnel-cluster.sh
sudo kubefwd svc -c /tmp/kubeconfig -n monitoring -f metadata.name=kube-prometheus-stack-grafana
sudo kubefwd svc -c /tmp/kubeconfig -n jaeger
sudo kubefwd svc -c /tmp/kubeconfig -n kubernetes-dashboard
```

## k3s internal Docker registry HTTP workaround

```yaml
# export KUBECONFIG="/home/debian/.kube/config" 
# DOCKER_REGISTRY_IP=$(kubectl -n docker-registry get service/docker-registry -o=jsonpath='{.spec.clusterIP}')
# sudo echo "10.43.121.9 docker-registry" >> /etc/hosts
# sudo nano /etc/rancher/k3s/registries.yaml
mirrors:
  "docker-registry:5000":
    endpoint:
      - "http://docker-registry:5000"
# sudo systemctl restart k3s
```
