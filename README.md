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
./scripts/deploy.sh
```

## Tunneling

```shell
# TODO: spell out https://github.com/pixel-point/kube-forwarder config + usage
```
