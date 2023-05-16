# k3s-poc
Building + deploying OCI images + dependencies through DigitalOcean + Bash + k3s + ArgoCD + Helm + ArgoCD + Tekton + Kaniko

## Pre-requisites

```shell
# generate SSH key
ssh-keygen -b 2048 -t rsa -f ~/.ssh/id_rsa -q -N ''
# switch default shell from zsh to bash on mac os x
chsh -s /bin/bash
# sign up for DigitalOcean account at https://cloud.digitalocean.com/registrations/new and add payment method for Linux-based virtual machine hosting
# set DIGITALOCEAN_TOKEN from https://cloud.digitalocean.com/account/api/tokens
echo 'export DIGITIALOCEAN_TOKEN="PASTE_TOKEN_HERE"' >> ~/.bash_profile
source ~/.bash_profile
```

## Run deploy script

```shell
# clone git repo locally
git clone https://github.com/brandonros/k3s-poc.git
# cd into repo folder
cd k3s-poc
# run from repo directory
./scripts/provision-droplet.sh
# deploy third-party infrastructure
./scripts/kubectl-apply.sh "./yaml/applications/kubernetes-dashboard.yaml" && ./scripts/run-argocd-sync-and-wait-pipeline.sh "kubernetes-dashboard"
./scripts/kubectl-apply.sh "./yaml/applications/jaeger.yaml" && ./scripts/run-argocd-sync-and-wait-pipeline.sh "jaeger"
./scripts/kubectl-apply.sh "./yaml/applications/loki-stack.yaml" && ./scripts/run-argocd-sync-and-wait-pipeline.sh "loki-stack"
./scripts/kubectl-apply.sh "./yaml/applications/redis.yaml" && ./scripts/run-argocd-sync-and-wait-pipeline.sh "redis"
./scripts/kubectl-apply.sh "./yaml/applications/rabbitmq.yaml" && ./scripts/run-argocd-sync-and-wait-pipeline.sh "rabbitmq"
./scripts/kubectl-apply.sh "./yaml/applications/postgresql.yaml" && ./scripts/run-argocd-sync-and-wait-pipeline.sh "postgresql"
./scripts/kubectl-apply.sh "./yaml/applications/kube-prometheus-stack.yaml" && ./scripts/run-argocd-sync-and-wait-pipeline.sh "kube-prometheus-stack"
./scripts/kubectl-apply.sh "./yaml/applications/docker-registry.yaml" && ./scripts/run-argocd-sync-and-wait-pipeline.sh "docker-registry"
./scripts/kubectl-apply.sh "./yaml/applications/code-server.yaml" && ./scripts/run-argocd-sync-and-wait-pipeline.sh "code-server"
./scripts/kubectl-apply.sh "./yaml/applications/windmill.yaml" && ./scripts/run-argocd-sync-and-wait-pipeline.sh "windmill" # manually set database password + migrate databse creating database
./scripts/kubectl-apply.sh "./yaml/applications/temporal.yaml" && ./scripts/run-argocd-sync-and-wait-pipeline.sh "temporal" # manually set database password + migrate databse creating database
# build internal apps
./scripts/run-kaniko-build-and-push-pipeline.sh "https://github.com/brandonros/k3s-poc.git" "docker-registry.docker-registry.svc.cluster.local:5000/nodejs-poc-app:latest" "./Dockerfile" "./apps/nodejs-poc-app"
./scripts/run-kaniko-build-and-push-pipeline.sh "https://github.com/brandonros/k3s-poc.git" "docker-registry.docker-registry.svc.cluster.local:5000/rust-poc-app:latest" "./Dockerfile" "./apps/rust-poc-app"
./scripts/run-kaniko-build-and-push-pipeline.sh "https://github.com/brandonros/k3s-poc.git" "docker-registry.docker-registry.svc.cluster.local:5000/java-poc-app:latest" "./Dockerfile" "./apps/java-poc-app"
./scripts/run-kaniko-build-and-push-pipeline.sh "https://github.com/brandonros/k3s-poc.git" "docker-registry.docker-registry.svc.cluster.local:5000/dotnet-poc-app:latest" "./Dockerfile" "./apps/rust-poc-app"
# deploy internal apps
./scripts/kubectl-apply.sh "./yaml/applications/nodejs-poc-app.yaml" && ./scripts/run-argocd-sync-and-wait-pipeline.sh "nodejs-poc-app"
./scripts/kubectl-apply.sh "./yaml/applications/rust-poc-app.yaml" && ./scripts/run-argocd-sync-and-wait-pipeline.sh "rust-poc-app"
./scripts/kubectl-apply.sh "./yaml/applications/java-poc-app.yaml" && ./scripts/run-argocd-sync-and-wait-pipeline.sh "java-poc-app"
./scripts/kubectl-apply.sh "./yaml/applications/dotnet-poc-app.yaml" && ./scripts/run-argocd-sync-and-wait-pipeline.sh "dotnet-poc-app"
# migrate database
./scripts/run-psql-migration-database-pipeline.sh
```

## Tunneling

```shell
brew install txn2/tap/kubefwd
brew install autossh
./scripts/tunnel-cluster.sh
# infrastructure
sudo kubefwd svc -c /tmp/kubeconfig -n monitoring -f metadata.name=kube-prometheus-stack-grafana
sudo kubefwd svc -c /tmp/kubeconfig -n jaeger
sudo kubefwd svc -c /tmp/kubeconfig -n kubernetes-dashboard
sudo kubefwd svc -c /tmp/kubeconfig -n postgresql
sudo kubefwd svc -c /tmp/kubeconfig -n windmill
sudo kubefwd svc -c /tmp/kubeconfig -n argocd -f metadata.name=argocd-server
sudo kubefwd svc -c /tmp/kubeconfig -n code-server
# apps
sudo kubefwd svc -c /tmp/kubeconfig -n nodejs-poc-app
sudo kubefwd svc -c /tmp/kubeconfig -n rust-poc-app
sudo kubefwd svc -c /tmp/kubeconfig -n java-poc-app
sudo kubefwd svc -c /tmp/kubeconfig -n dotnet-poc-app
```

## k3s internal Docker registry HTTP workaround

```yaml
# export KUBECONFIG="/home/debian/.kube/config" 
# DOCKER_REGISTRY_IP=$(kubectl -n docker-registry get service/docker-registry -o=jsonpath='{.spec.clusterIP}')
# sudo echo "$DOCKER_REGISTRY_IP docker-registry" >> /etc/hosts
# sudo nano /etc/rancher/k3s/registries.yaml
mirrors:
  "docker-registry:5000":
    endpoint:
      - "http://docker-registry:5000"
# sudo systemctl restart k3s
```
