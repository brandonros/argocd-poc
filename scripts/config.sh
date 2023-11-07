#!/bin/sh

# vps provider
VPS_PROVIDER="vultr"
# ssh key
KEY_NAME="k3s-poc"
PUBLIC_KEY=$(cat ~/.ssh/id_rsa.pub) # TODO: check if exists/ssh-keygen already ran
# droplet
DROPLET_NAME="k3s-poc"
DROPLET_SIZE="s-4vcpu-8gb"
DROPLET_REGION="nyc3"
DROPLET_IMAGE="debian-11-x64"
# instance
INSTANCE_LABEL="instance1"
INSTANCE_REGION="ewr"
INSTANCE_PLAN="vc2-4c-8gb"
INSTANCE_OS_NAME="Debian 12 x64 (bookworm)"
# user settings
USERNAME="debian"
PASSWORD="9220320c-02f2-4b39-ab17-e5dc1cfc4541" # TODO: not great to hardcode a password
