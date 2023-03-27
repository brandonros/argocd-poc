# argocd-poc
Building + deploying OCI images + dependencies through DigitalOcean + Ansible + Helm + ArgoCD + k3s + Kaniko

## Pre-requisites

```shell
# open Terminal.app (Finder -> Applications -> Utilities -> Terminal.app or Spotlight search "Terminal") to run commands
# install xcode command line tools
xcode-select --install
# install brew package manager
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
# add brew into zsh profile + load it
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
eval "$(/opt/homebrew/bin/brew shellenv)"
# install ansible through brew package manager
brew install ansible
# generate SSH key
ssh-keygen -b 2048 -t rsa -f ~/.ssh/id_rsa -q -N ''
# sign up for DigitalOcean account at https://cloud.digitalocean.com/registrations/new and add payment method for Linux-based virtual machine hosting
# set DIGITALOCEAN_TOKEN from https://cloud.digitalocean.com/account/api/tokens
echo 'export DIGITIALOCEAN_TOKEN="PASTE_TOKEN_HERE"' >> ~/.zprofile
source ~/.zprofile
```

## Run Ansible playbook

```shell
# clone git repo locally
git clone https://github.com/brandonros/argocd-poc.git
# cd into repo folder
cd argocd-poc
# run ansible playbook from repo
ansible-playbook --ask-become ansible/playbook.yaml # password is foobar123
```

## Provision application + dependencies

```shell
# get digitalocean droplet external IP
EXTERNAL_IP=$(cat /tmp/droplet-ip.txt) # created by ansible
# copy scripts to virtual machine
scp ./scripts/build-custom-oci-image.sh ./scripts/deploy-custom-oci-image.sh 
# build app custom OCI image + deploy app custom OCI image as argocd app through helm charts
ssh -t debian@$EXTERNAL_IP 'bash /tmp/build-custom-oci-image.sh'
ssh -t debian@$EXTERNAL_IP 'bash /tmp/deploy-custom-oci-image.sh'
```

## Tunneling

```shell
ssh -L 8080:127.0.0.1:8080 debian@$EXTERNAL_IP 'bash -c "KUBECONFIG=~/.kube/config kubectl port-forward svc/argocd-server -n argocd 8080:443"' # argocd will be at https://localhost:8080 (username admin / password in /tmp/argocd-password.txt)
ssh -L 8443:127.0.0.1:8443 debian@$EXTERNAL_IP 'bash -c "KUBECONFIG=~/.kube/config kubectl port-forward svc/kubernetes-dashboard -n kubernetes-dashboard 8443:443"' # kubernetes dashboard will be at https://localhost:8443 (token will be in /tmp/kubernetes-dashboard-token.txt)
ssh -L 9200:127.0.0.1:9200 debian@$EXTERNAL_IP 'bash -c "KUBECONFIG=~/.kube/config kubectl port-forward svc/elasticsearch-master-headless -n elk 9200:9200"' # elasticsearch will be at https://localhost:9200 (username elastic / password in /tmp/elastic-password.txt)
ssh -L 5601:127.0.0.1:5601 debian@$EXTERNAL_IP 'bash -c "KUBECONFIG=~/.kube/config kubectl port-forward svc/kibana-kibana -n elk 5601:5601"' # kibana will be at http://localhost:5601 (username elastic / password in /tmp/elastic-password.txt)
ssh -L 3000:127.0.0.1:3000 debian@$EXTERNAL_IP 'bash -c "KUBECONFIG=~/.kube/config kubectl port-forward svc/test -n test 3000:3000"' # node.js express http server will be at http://localhost:3000
```

## Sample API request

```shell
curl -X POST -H 'Content-Type: application/json' http://localhost:3000/index -d '{
  "indexName": "test",
  "messageId": 1,
  "message": {
    "foo": "bar"
  }
}'
```

## Debugging DNS resolution

```shell
kubectl run test-dns-busybox -i --tty --image=busybox:1.36.0 --rm --restart=Never -- nslookup elasticsearch-master-headless.elk.svc.cluster.local
```
