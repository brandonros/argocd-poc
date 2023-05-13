#!/bin/sh

# ssh key
KEY_NAME="argocd-poc"
PUBLIC_KEY=$(cat ~/.ssh/id_rsa.pub) # TODO: check if exists/ssh-keygen already ran
# droplet
DROPLET_NAME="k3s-poc"
DROPLET_SIZE="s-4vcpu-8gb"
DROPLET_REGION="nyc3"
DROPLET_IMAGE="debian-11-x64"
